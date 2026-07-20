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

> **Heads-up (known gaps):** `build_registry.sh` currently reads each script's
> shebang as its description (gap #3), and `workflow_registry.json` ships as a
> stub so `build_docs.sh` yields an empty `WORKFLOWS.md` unless you run
> `build_workflow_registry.sh` first (gap #6). Until those are fixed, treat
> `launcher-system/tool_registry.json` as the authoritative registry and copy it
> to the app asset:
> ```sh
> cp launcher-system/tool_registry.json android-app/src/main/assets/tool_registry.json
> ```
> See [Tool registry § 8.1](08-tool-registry.md#81-the-two-copies-important).

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

The `android-app/src/` tree is a **skeleton** — you must add the Gradle project
around it first. Follow `android-app/build-notes.md`; the minimum is:

```
android-app/
├── build.gradle.kts          # module build file (from build-notes.md)
├── settings.gradle.kts
├── gradle/…                  # wrapper
└── src/main/
    ├── AndroidManifest.xml            # provided
    ├── assets/tool_registry.json      # provided (keep synced)
    ├── java/com/andrax/two/…          # provided
    └── res/
        ├── values/themes.xml          # define Theme.Andrax
        └── mipmap-*/ic_launcher…      # a launcher icon
```

Key `build.gradle.kts` config (see `build-notes.md` for the full file):

```kotlin
android {
    namespace = "com.andrax.two"
    compileSdk = 34
    defaultConfig {
        applicationId = "com.andrax.two"
        minSdk = 26
        targetSdk = 34
        versionCode = 1           // see Versioning §6.2 for the derivation
        versionName = "2.0.0"
    }
    kotlinOptions { jvmTarget = "17" }
}
dependencies {
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.recyclerview:recyclerview:1.3.2")
    // org.json ships with the platform — no dependency needed
}
```

### Debug build

```sh
cd android-app
./gradlew assembleDebug          # → build/outputs/apk/debug/app-debug.apk
./gradlew installDebug           # onto the device that also runs Termux
```

### Release build (signed)

Requires the release keystore + Gradle signing config from
[Signing § 5.2](05-signing-pipeline.md#52-apk-signing-model):

```sh
cd android-app
./gradlew assembleRelease        # → build/outputs/apk/release/app-release.apk
apksigner verify --print-certs build/outputs/apk/release/app-release.apk
```

### Wire up the app↔Termux bridge (one-time, on device)

```sh
# In Termux
mkdir -p ~/.termux
echo "allow-external-apps=true" >> ~/.termux/termux.properties
termux-reload-settings
```

…and grant the app `com.termux.permission.RUN_COMMAND`. Ensure ANDRAX-2.0 is
extracted where `TermuxLauncher.ENGINE_PATH` expects it
(`/data/data/com.termux/files/home/ANDRAX-2.0/…`; mind gap #1). See
[Android app § 3.4](03-android-app-structure.md#34-the-app--termux-bridge-one-time-setup).

## 4. One-shot "build everything" (local)

```sh
#!/usr/bin/env bash
set -euo pipefail
bash tools/normalize_shebangs.sh
bash tools/fix_permissions.sh
bash tools/build_registry.sh
bash tools/build_workflow_registry.sh
bash tools/build_docs.sh
cp launcher-system/tool_registry.json android-app/src/main/assets/tool_registry.json
bash tools/backend_consistency_auditor.sh
bash tools/broken_script_locator.sh
( cd android-app && ./gradlew assembleDebug ) || echo "app: add Gradle project first (build-notes.md)"
echo "Build complete."
```

This mirrors what the recommended CI `ci.yml` does — see
[CI/CD § B.1](04-cicd-pipeline.md#b1-ciyml--validate-every-push--pr).
