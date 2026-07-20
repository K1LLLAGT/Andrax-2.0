# 6. Versioning System

ANDRAX 2.0 carries version information in several places. This document is the
map of where versions live, the scheme they follow, and the rules for bumping
them consistently.

## 6.1 Where versions live

| Location | Field | Current value | Format |
|----------|-------|---------------|--------|
| `VERSION` (repo root) | whole file | `2.0` | `MAJOR.MINOR` |
| `launcher-system/tool_registry.json` | `.version` | `2.0.0` | SemVer `MAJOR.MINOR.PATCH` |
| `launcher-system/tool_registry.json` | `.schema` | `andrax-registry/1` | `<name>/<schemaMajor>` |
| `launcher-system/tool_registry.json` | `.generated` | `2026-07-18` | ISO date (build stamp) |
| `android-app/build-notes.md` → `build.gradle.kts` | `versionName` | `2.0.0` | SemVer (user-visible) |
| `android-app/build-notes.md` → `build.gradle.kts` | `versionCode` | `1` | monotonic integer (Android) |
| `magisk-module/andrax-bridge/module.prop` | `version` | `1.0` | module version string |
| `magisk-module/andrax-bridge/module.prop` | `versionCode` | `1` | monotonic integer (Magisk) |

> These are **not currently kept in lockstep by any tooling** — each is edited by
> hand. § 6.4 defines the intended relationship and a helper to enforce it.

## 6.2 The scheme

ANDRAX 2.0 uses **Semantic Versioning** (`MAJOR.MINOR.PATCH`) as the project
version, with the `VERSION` file holding the short `MAJOR.MINOR` form:

* **MAJOR** — the ANDRAX generation / breaking redesign. `2` = "user-space,
  non-rooted, Termux-based" rewrite. Bump only for an architecture-level break.
* **MINOR** — backward-compatible feature additions: new tools, new workflows,
  new registry fields (that stay optional), new engine subcommands.
* **PATCH** — fixes: bug fixes in tool scripts, doc corrections, packaging fixes,
  no new capabilities.

**Registry schema version** (`.schema = andrax-registry/1`) is versioned
*independently* of the project version. Bump the schema integer only when the
registry JSON **shape** changes in a way consumers must adapt to (e.g. renaming
`tools[].script`, or making a previously-optional field required). A project
MINOR/PATCH bump does **not** imply a schema bump.

**Android `versionCode`** is a separate, monotonic integer that must increase
with **every** APK you ship, regardless of the `versionName`. Recommended
derivation (stable and collision-free):

```
versionCode = MAJOR*10000 + MINOR*100 + PATCH
# 2.0.0 → 20000,  2.1.0 → 20100,  2.1.3 → 20103
```

## 6.3 Git tags

Releases are marked with an annotated tag `vMAJOR.MINOR.PATCH` (e.g. `v2.0.0`).
The tag is the immutable release pointer that CI's `release.yml` reacts to. The
`VERSION` file should equal the tag minus the `v` prefix at release time (CI can
assert this — see [CI/CD § B.2](04-cicd-pipeline.md#b2-releaseyml--build--publish-on-a-tag)).

## 6.4 Bumping a version (the rule)

When you cut a new version `X.Y.Z`, update **all** of these together, in one
commit, before tagging:

1. `VERSION` → `X.Y` (short form).
2. `launcher-system/tool_registry.json` `.version` → `X.Y.Z`, and `.generated`
   → today's ISO date.
3. `android-app` Gradle `versionName` → `X.Y.Z`, `versionCode` → derived integer
   (§ 6.2). *(Once the Gradle project exists.)*
4. `magisk-module/andrax-bridge/module.prop` `version`/`versionCode` — only if
   the Magisk module actually changed.
5. Update `docs/dev/07-release-lifecycle.md` changelog / release notes.

Then re-run the generators (`tools/build_registry.sh`,
`build_workflow_registry.sh`, `build_docs.sh`) so the app asset's stamp and the
generated docs reflect the new version, and commit those too.

### Recommended helper: `tools/bump_version.sh`

A single script should own this fan-out so the numbers can't drift. Sketch:

```sh
#!/usr/bin/env bash
# tools/bump_version.sh X.Y.Z  — set the project version everywhere.
set -euo pipefail
ver="${1:?usage: bump_version.sh X.Y.Z}"
[[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "SemVer X.Y.Z required"; exit 1; }
IFS=. read -r MAJ MIN PAT <<<"$ver"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

printf '%s.%s\n' "$MAJ" "$MIN" > "$ROOT/VERSION"

jq --arg v "$ver" --arg d "$(date +%F)" \
   '.version=$v | .generated=$d' \
   "$ROOT/launcher-system/tool_registry.json" > "$ROOT/.reg.tmp" \
   && mv "$ROOT/.reg.tmp" "$ROOT/launcher-system/tool_registry.json"

# Android (once build.gradle.kts exists):
code=$((MAJ*10000 + MIN*100 + PAT))
gradle="$ROOT/android-app/build.gradle.kts"
[ -f "$gradle" ] && sed -i \
   -e "s/versionName = \".*\"/versionName = \"$ver\"/" \
   -e "s/versionCode = .*/versionCode = $code/" "$gradle"

echo "Bumped to $ver (versionCode $code). Re-run tools/build_*.sh and commit."
```

## 6.5 Consistency check (for CI)

CI should assert the numbers agree. Minimal check:

```sh
v_file="$(cat VERSION)"                                   # 2.0
v_reg="$(jq -r .version launcher-system/tool_registry.json)"  # 2.0.0
[ "${v_reg%.*}" = "$v_file" ] || { echo "VERSION vs registry mismatch"; exit 1; }
# On a tag build, also assert: v$v_reg == $GITHUB_REF_NAME
```

This closes the loop between the `VERSION` file, the registry, and the git tag
so a release can't ship with mismatched numbers.
