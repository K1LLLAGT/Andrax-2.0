# 7. Release Lifecycle

This document describes how a change travels from a working branch to a tagged,
published ANDRAX 2.0 release. It defines the branching model, the stages and
their gates, and the artifacts a release produces.

> **Current state:** the release process is **manual** today — there is no CI to
> automate it (see [CI/CD](04-cicd-pipeline.md)). The lifecycle below is the
> intended process; the "gate" column notes which checks exist as `tools/`
> scripts you can run now, versus checks that require the recommended CI.

## 7.1 Branching model

A lightweight trunk-based model:

```
main ───●───────●───────────●────────────────●──────►   (always releasable)
         \       \            \                \
          feature  fix/…       docs/…           release prep (version bump)
```

* **`main`** — always in a releasable state. Protected; changes land via PR.
* **`feature/<name>`**, **`fix/<name>`**, **`docs/<name>`** — short-lived topic
  branches, squash-merged into `main`.
* **Tags** `vX.Y.Z` — the release markers, cut from `main`. See
  [Versioning § Git tags](06-versioning-system.md#63-git-tags).
* **`release/X.Y`** (optional) — only if you need to maintain an old minor line
  with back-ported patches.

## 7.2 Lifecycle stages

```
 ┌──────────┐   ┌──────────┐   ┌───────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
 │ 1 Develop│ → │ 2 Verify │ → │ 3 Generate│ → │ 4 Release│ → │ 5 Tag &  │ → │ 6 Publish│
 │  (branch)│   │  (CI/QA) │   │ artifacts │   │  prep    │   │  build   │   │ & verify │
 └──────────┘   └──────────┘   └───────────┘   └──────────┘   └──────────┘   └──────────┘
```

| Stage | Actions | Gate |
|-------|---------|------|
| **1. Develop** | Implement a tool/workflow/app/doc change on a topic branch (see [Contribution guide](10-contribution-guide.md)). | PR review |
| **2. Verify** | ShellCheck; consistency/broken-script audits; run `tools/test_pipeline.sh`; build the app. | `tools/audit_sh_files.sh`, `backend_consistency_auditor.sh`, `broken_script_locator.sh`, `test_pipeline.sh` (now); CI `ci.yml` (recommended) |
| **3. Generate** | Rebuild registries + docs; confirm no uncommitted drift. | `tools/build_registry.sh`, `build_workflow_registry.sh`, `build_docs.sh` + `git diff --exit-code` |
| **4. Release prep** | Bump version everywhere ([Versioning § 6.4](06-versioning-system.md#64-bumping-a-version-the-rule)); write release notes; final `main` merge. | version-consistency check |
| **5. Tag & build** | Annotated tag `vX.Y.Z`; build the source tarball and the **signed** release APK. | [Signing pipeline](05-signing-pipeline.md); CI `release.yml` (recommended) |
| **6. Publish & verify** | Create the GitHub Release with artifacts + checksums + signatures; verify APK signature and tarball checksum. | `apksigner verify`, `sha256sum -c`, `gpg --verify` |

## 7.3 Release artifacts

Every release publishes:

| Artifact | Produced by | Notes |
|----------|-------------|-------|
| `ANDRAX-2.0.tar.gz` | `git archive` | The source bundle `INSTALL.md` extracts |
| `ANDRAX-2.0.tar.gz.sha256` | `sha256sum` | Integrity |
| `ANDRAX-2.0.tar.gz.asc` | `gpg --detach-sign` | Authenticity |
| `app-release.apk` | `./gradlew assembleRelease` | Signed with the release key ([Signing](05-signing-pipeline.md)) |
| `andrax-bridge.zip` (optional) | zip of `magisk-module/andrax-bridge/` | Only if the Magisk module changed |
| Release notes | hand-written | Highlights + full changelog |

## 7.4 Versioning within the lifecycle

* Feature merges accumulate on `main` **without** bumping the version.
* The version is bumped **once**, at stage 4, immediately before tagging.
* The tag `vX.Y.Z` must match the `VERSION` file and the registry `.version`
  (CI asserts this). See [Versioning](06-versioning-system.md).

## 7.5 Hotfix flow

For an urgent fix to a released version:

1. Branch `fix/<desc>` from the release tag (or `main` if unreleased work is
   compatible).
2. Fix + verify (stages 1–2).
3. Bump **PATCH** only (`X.Y.Z` → `X.Y.(Z+1)`).
4. Tag `vX.Y.(Z+1)`, build, publish (stages 5–6).
5. Ensure the fix is also on `main`.

## 7.6 Deprecating / removing a tool or workflow

Because both the app and CLI read the registry, removals must be staged:

1. Mark the tool/workflow deprecated in its script header and release notes
   (MINOR release).
2. In a later MINOR/MAJOR, remove the script, regenerate the registries + docs,
   and note the removal. Removing a registry entry is a user-visible change —
   call it out.

## 7.7 Definition of "done" for a release

- [ ] All CI/audit gates green (stage 2).
- [ ] Registries + docs regenerated and committed; `git diff` clean (stage 3).
- [ ] Version bumped consistently across all locations (stage 4).
- [ ] Release notes written.
- [ ] Tag `vX.Y.Z` pushed.
- [ ] Source tarball + APK built and **signed**.
- [ ] Checksums + GPG signature published.
- [ ] APK signature and tarball checksum **verified** post-publish.
- [ ] GitHub Release created with all artifacts.

See [Release instructions](12-release-instructions.md) for the concrete command
sequence.
