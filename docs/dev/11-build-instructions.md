# 11. Build Instructions

ANDRAX 2.0 has three buildable outputs: the **backend** (shell — nothing to
compile, only install/configure), the **generated artifacts** (registries +
docs), and the **Android APK**. This document covers building each from a clean
checkout. For the operator-facing install, see the root
[`INSTALL.md`](../../INSTALL.md).

## Prerequisites

| For | Need |
|-----|------|
| Backend / generators | `bash`, `jq`, coreutils (`find`, `sed`, `column`) |
| Backend runtime (on device) | Termux (F-Droid/GitHub build), optionally proot-distro |
| App | JDK 17, Android SDK (compileSdk 34), Gradle |
| Signing/release | `keytool`, `apksigner`, `gpg` (see [Signing](05-signing-pipeline.md)) |

## 1. Build the generated artifacts (registries + docs)

These are checked into the repo but must be regenerated whenever tools or
workflows change.

```sh
# from the repo root
bash tools/build_registry.sh            # → android-app/.../tool_registry.json
bash tools/build_workflow_registry.sh   # → android-app/.../workflow_registry.json
bash tools/build_docs.sh                # → docs/TOOLS.md, docs/WORKFLOWS.md
```

Then normalize and set permissions:

```sh
bash tools/normalize_shebangs.sh        # force #!/usr/bin/env bash
bash tools/fix_permissions.sh           # chmod +x core scripts
```

> **Order matters:** run `build_registry.sh` and `build_workflow_registry.sh`
> **before** `build_docs.sh`, since the docs are generated from the app-asset
> registries. `build_registry.sh` syncs the app tool registry from the canonical
> `launcher-system/tool_registry.json` (and validates coverage);
> `build_workflow_registry.sh` generates the workflow registry from the actual
> workflows. See [Tool registry § 8.1](08-tool-registry.md#81-the-two-copies-important).

### Verify the artifacts

```sh
jq . launcher-system/tool_registry.json                 # valid JSON
jq . android-app/src/main/assets/tool_registry.json     # valid JSON
bash tools/backend_consistency_auditor.sh               # registry ↔ disk agree
bash tools/broken_script_locator.sh                     # no unparseable scripts
```

## 2. Build/run the backend (in Termux)

The backend is shell — there is nothing to compile. "Building" it means
installing dependencies and loading the environment. From within Termux:

```sh
# make scripts executable (idempotent)
find . -name '*.sh' -exec chmod +x {} \;

# install dependencies (idempotent; run what you need)
bash termux-backend/setup/install_termux_packages.sh    # base + core tools
bash termux-backend/setup/install_python_tools.sh
bash termux-backend/setup/install_go_tools.sh            # optional
bash termux-backend/setup/install_rust_tools.sh          # optional
bash termux-backend/setup/setup_proot_kali.sh            # optional userland

# load the environment
source termux-backend/config/env.sh

# self-check
andrax doctor
```

`andrax doctor` reports `ANDRAX_HOME`, the registry path (OK/MISSING), log/loot
dirs, root status, presence of each core tool, and proot userland status. It is
the fastest way to confirm a working build.

### Smoke test

```sh
andrax list-tools
andrax list-workflows
andrax info nmap
andrax run-tool nmap -- -sV scanme.nmap.org        # authorized test host
bash tools/test_pipeline.sh                         # launcher + recon_basic
```

## 3. Build the Android app (APK)

`android-app/` is a **complete single-module Gradle project** (AGP 8.5.2, Kotlin
1.9.24, compileSdk 34, minSdk 26). No scaffolding needed — just point it at an
Android SDK and build. See `android-app/build-notes.md` for the full layout.

### Prerequisites

* JDK 17 (JDK 21 also runs Gradle fine).
* Android SDK with `platforms;android-34` and `build-tools;34.0.0`. Set
  `ANDROID_HOME`/`ANDROID_SDK_ROOT`, or create a git-ignored
  `android-app/local.properties` with `sdk.dir=/path/to/Android/sdk`.

### Debug build

```sh
cd android-app
./gradlew assembleDebug          # → build/outputs/apk/debug/andrax-2.0-app-debug.apk
./gradlew installDebug           # onto the device that also runs Termux
```

### Release build (signed)

The `release` build type signs **only when signing credentials are present**;
otherwise it produces `…-release-unsigned.apk` (so `assembleRelease` always
runs). Provide credentials via env vars (CI) or a local, git-ignored
`android-app/keystore.properties` (copy `keystore.properties.example`). See
[Signing § 5.2](05-signing-pipeline.md#52-apk-signing-model):

```sh
cd android-app
cp keystore.properties.example keystore.properties   # fill in real values
./gradlew assembleRelease        # → build/outputs/apk/release/andrax-2.0-app-release.apk
"$ANDROID_HOME"/build-tools/34.0.0/apksigner verify --print-certs \
  build/outputs/apk/release/andrax-2.0-app-release.apk
```

### Wire up the app↔Termux bridge (one-time, on device)

```sh
# In Termux
mkdir -p ~/.termux
echo "allow-external-apps=true" >> ~/.termux/termux.properties
termux-reload-settings
```

…and grant the app `com.termux.permission.RUN_COMMAND`. Extract ANDRAX-2.0 to
the standard location `$HOME/ANDRAX-2.0`
(`/data/data/com.termux/files/home/ANDRAX-2.0/…`), which is where
`TermuxLauncher.ENGINE_PATH` and the Magisk bridge both expect it. See
[Android app § 3.4](03-android-app-structure.md#34-the-app--termux-bridge-one-time-setup).

## 4. One-shot "build everything" (local)

```sh
#!/usr/bin/env bash
set -euo pipefail
bash tools/normalize_shebangs.sh
bash tools/fix_permissions.sh
bash tools/build_registry.sh            # syncs the app asset from canonical + validates
bash tools/build_workflow_registry.sh
bash tools/build_docs.sh
bash tools/backend_consistency_auditor.sh
bash tools/broken_script_locator.sh
( cd android-app && ./gradlew assembleDebug ) || echo "app: set ANDROID_HOME / local.properties (build-notes.md)"
echo "Build complete."
```

This mirrors what CI does — the `shell` and `app` jobs in `ci.yml`. See
[CI/CD § B.1](04-cicd-pipeline.md#b1-ciyml--validate-every-push--pr).
