# ANDRAX 2.0 — DevOps / CI-CD

Status and roadmap for the build, quality, signing, versioning, and release
pipeline. This lands incrementally; each stage is a self-contained PR.

## Current state (this PR: CI foundation)

| Stage | Status |
|---|---|
| **Shell lint (ShellCheck)** | ✅ `.github/workflows/lint.yml` — 68+ scripts, error-gated |
| **Registry/JSON validation** | ✅ same workflow (`jq empty`) |
| **Workflow-YAML sanity** | ✅ same workflow (parse `workflows/**/*.yaml`) |
| Android build (APK) | ⛔ blocked — no Gradle build system in the repo yet |
| APK signing pipeline | ⛔ not started |
| Versioning automation | 🟡 `VERSION` file exists (`2.0`), not wired anywhere |
| Release automation + notes | ⛔ not started |
| Backend packaging (`.tar.gz`) | 🟡 ad-hoc scripts, no pipeline |

### Known findings (from the first lint pass)
- `bin/adapters/adapter-magisk.sh` runs `su -c "$CMD"` with an **unquoted,
  unvalidated** variable — word-splitting + command-injection surface.
- 5 scripts under `bin/`/`tools/` lack `set -euo pipefail`.
- `magisk-module/andrax-bridge/post-fs-data.sh` bind-mounts
  `/system/bin/tcpdump` and `/system/xbin/nmap` — those paths don't exist on
  stock Samsung, so the bridge currently mounts nothing. It should bind from the
  installed toolset (Kali chroot / Termux prefix).
- `workflows/*.yaml` substitute `{{target}}` straight into shell commands —
  needs input sanitization in the workflow runner.

## Roadmap (next PRs)

### 1. Android build system (prerequisite)
Re-introduce `build.gradle.kts`, `settings.gradle.kts`, `gradle.properties`,
the Gradle wrapper, and the missing `res/` (theme, icon) so the app compiles.
Then a build workflow (`assembleDebug`) uploading the APK artifact. Nothing
Android-related (CI, signing) is possible until this exists.

### 2. APK signing pipeline
- `release` `signingConfig` reading a keystore from CI secrets
  (`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`).
- `assembleRelease` + `apksigner verify` in CI, gated on tags.
- Debug builds stay unsigned/debug-signed for PRs.

### 3. Versioning system
Make `VERSION` the single source of truth:
- Gradle reads `VERSION` → `versionName`; `versionCode` derived from
  `git rev-list --count HEAD`.
- A CI check asserts the release tag matches `VERSION`.

### 4. Release automation + notes
On a version tag (`v*`):
- build the signed APK,
- run the backend packaging target → `ANDRAX-2.0.tar.gz`,
- generate release notes from Conventional Commits (git-cliff) since the last
  tag,
- create the GitHub Release and upload both assets (`ANDRAX-2.0.tar.gz` +
  `ANDRAX-2.0-app-release.apk`).

This automates the manual release/asset steps and guarantees the asset filename
the app fetches (`ANDRAX-2.0.tar.gz`) is always present on `latest`.

### 5. Backend packaging pipeline
A deterministic `tools/package_backend.sh` (or `make package`) that assembles
`ANDRAX-2.0.tar.gz` from the tracked sources, run in CI and attached to
releases. Ratchet the ShellCheck gate to `-S warning`, then `style`, as the
scripts are cleaned up.

## Conventions
- Conventional Commits (`feat:`, `fix:`, `ci:`, `docs:`…) to drive release notes.
- Tags: `vMAJOR.MINOR.PATCH`; the app resolves assets via
  `/releases/latest/download/…`, so every release must carry `ANDRAX-2.0.tar.gz`.
