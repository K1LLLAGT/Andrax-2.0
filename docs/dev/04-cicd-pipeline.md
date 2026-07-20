# 4. CI/CD Pipeline

> **Current state:** CI/CD is wired up. `.github/workflows/ci.yml` runs on every
> push/PR with two jobs — a `shell` job (syntax check, ShellCheck, registry/doc
> JSON validity, generated-artifact drift check, backend audits) and an `app` job
> that builds the debug APK. `.github/workflows/release.yml` runs on a `v*` tag
> and builds the source tarball + the signed release APK and publishes a GitHub
> Release. Underneath CI, every check is just a `tools/` script or a Gradle task,
> so you can reproduce it locally. This document describes (A) the local pipeline
> and (B) the committed GitHub Actions workflows (plus an optional Pages one).

## A. Current pipeline (local, manual)

The `tools/` directory is the de-facto build & QA pipeline. Run in this order:

```
┌─ generate ────────────────────────────────────────────────────────────┐
│ tools/build_registry.sh           # tools/*  → app tool_registry.json  │
│ tools/build_workflow_registry.sh  # workflows → app workflow_registry  │
│ tools/build_docs.sh               # registries → docs/TOOLS|WORKFLOWS   │
├─ normalize ───────────────────────────────────────────────────────────┤
│ tools/normalize_shebangs.sh       # force #!/usr/bin/env bash           │
│ tools/fix_permissions.sh          # chmod +x all core .sh              │
├─ audit / lint ────────────────────────────────────────────────────────┤
│ tools/audit_sh_files.sh           # shell-script auditor               │
│ tools/backend_consistency_auditor.sh                                   │
│ tools/broken_script_locator.sh                                         │
│ tools/privileged_tool_detector.sh                                      │
│ tools/workflow_yaml_linter.sh                                          │
│ tools/tool_dependency_mapper.sh                                        │
├─ test ────────────────────────────────────────────────────────────────┤
│ tools/test_pipeline.sh            # launcher → list + run recon_basic  │
│ tools/test_android_ipc.sh         # app IPC end-to-end                 │
├─ visualize / profile (optional) ──────────────────────────────────────┤
│ tools/workflow_visualizer.sh  tools/workflow_call_graph.sh             │
│ tools/workflow_step_tracer.sh tools/tool_profiler.sh                   │
└───────────────────────────────────────────────────────────────────────┘
```

The full `tools/` inventory:

| Script | Role |
|--------|------|
| `build_registry.sh` | Generate `android-app/.../tool_registry.json` from `termux-backend/tools/*` |
| `build_workflow_registry.sh` | Generate `workflow_registry.json` from shell + YAML workflows |
| `build_docs.sh` | Generate `docs/TOOLS.md` and `docs/WORKFLOWS.md` from the registries |
| `normalize_shebangs.sh` | Force every `*.sh` to `#!/usr/bin/env bash` |
| `fix_permissions.sh` | `chmod +x` all core script locations |
| `audit_sh_files.sh` | Lint/audit shell scripts |
| `backend_consistency_auditor.sh` | Cross-check registry vs. on-disk tool scripts |
| `broken_script_locator.sh` | Find scripts that fail to source/parse |
| `privileged_tool_detector.sh` | Flag tools doing privileged operations |
| `tool_dependency_mapper.sh` | Map each tool to its required binaries |
| `tool_profiler.sh` | Time tool execution |
| `workflow_yaml_linter.sh` | Lint YAML workflow definitions |
| `workflow_call_graph.sh` | Workflow → tool call graph |
| `workflow_visualizer.sh` / `workflow_step_tracer.sh` / `workflow_debugger.sh` / `debug_workflow_builder.sh` | Workflow inspection/debugging |
| `android_workflow_preview.sh` | Render a workflow as the app would show it |
| `list_all_sh_files.sh` | Enumerate all `.sh` files |
| `test_pipeline.sh` | Integration test: launcher lists + runs `recon_basic` |
| `test_android_ipc.sh` | App↔backend IPC end-to-end test |

> The builders are trustworthy: `build_registry.sh` syncs the app tool registry
> from the curated canonical registry (and validates coverage),
> `build_workflow_registry.sh` generates the workflow registry from the actual
> workflows, and `build_docs.sh` renders the docs from those. Re-running them is
> idempotent, which is exactly what the CI drift check relies on.

## B. CI/CD workflows (GitHub Actions)

Three workflows under `.github/workflows/`. **`ci.yml` is committed and active**;
`release.yml` and `pages.yml` are recommended designs to add.

### B.1 `ci.yml` — validate every push & PR (committed)

The active workflow gates the build on:

1. **Syntax check** — `bash -n` on every tracked `*.sh`.
2. **ShellCheck** — at `-S error` severity (hard errors fail; style/info don't).
3. **JSON validity** — `jq empty` on the canonical registry and both app-asset
   registries.
4. **Registry/doc drift check** — regenerate the registries + docs and fail if
   `git diff` on the generated files is non-empty (artifacts weren't committed).
5. **Consistency audit** — `tools/backend_consistency_auditor.sh` and
   `tools/broken_script_locator.sh`; non-zero exit fails.

A commented-out `app` job (`./gradlew assembleDebug`) is included to enable once
the Gradle project exists. The committed file is the source of truth; the sketch
below shows the shape.

```yaml
name: ci
on:
  push: { branches: [ main ] }
  pull_request:
jobs:
  shell:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: ShellCheck
        run: sudo apt-get update && sudo apt-get install -y shellcheck jq &&
             find . -name '*.sh' -not -path './.git/*' -print0 |
             xargs -0 shellcheck -S warning
      - name: Registry / docs are up to date
        run: |
          bash tools/build_registry.sh
          bash tools/build_workflow_registry.sh
          bash tools/build_docs.sh
          git diff --exit-code || { echo "Regenerate registries/docs and commit."; exit 1; }
      - name: Consistency audit
        run: bash tools/backend_consistency_auditor.sh && bash tools/broken_script_locator.sh
  app:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: '17' }
      - uses: android-actions/setup-android@v3
      - name: Build debug APK
        working-directory: android-app
        run: ./gradlew assembleDebug --no-daemon --stacktrace
```

### B.2 `release.yml` — build & publish on a tag (committed)

Triggered by pushing a `v*` tag. The committed workflow:

1. Asserts `VERSION` + registry `.version` match the tag.
2. Builds the **source tarball** `ANDRAX-2.0.tar.gz` + SHA-256.
3. Decodes the keystore from the `ANDRAX_KEYSTORE_B64` secret (if set) and builds
   the **signed release APK** — or an unsigned one if no secret is configured —
   then verifies the signature with `apksigner`.
4. Publishes a GitHub Release with the tarball, APK, and checksums.

The committed `.github/workflows/release.yml` is the source of truth; the sketch
below shows the shape.

```yaml
name: release
on:
  push: { tags: [ 'v*' ] }
permissions: { contents: write }
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Verify VERSION matches tag
        run: |
          tag="${GITHUB_REF_NAME#v}"
          test "$(jq -r .version launcher-system/tool_registry.json)" = "$tag"
      - name: Build source tarball
        run: git archive --format=tar.gz --prefix=ANDRAX-2.0/ -o ANDRAX-2.0.tar.gz "$GITHUB_REF_NAME"
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: '17' }
      - uses: android-actions/setup-android@v3
      - name: Build signed APK
        working-directory: android-app
        env:
          ANDRAX_KEYSTORE_FILE: ${{ runner.temp }}/release.keystore
          ANDRAX_KEYSTORE_PASS: ${{ secrets.ANDRAX_KEYSTORE_PASS }}
          ANDRAX_KEY_ALIAS: ${{ secrets.ANDRAX_KEY_ALIAS }}
          ANDRAX_KEY_PASS: ${{ secrets.ANDRAX_KEY_PASS }}
        run: |
          echo "${{ secrets.ANDRAX_KEYSTORE_B64 }}" | base64 -d > "$ANDRAX_KEYSTORE_FILE"
          ./gradlew assembleRelease --no-daemon
      - uses: softprops/action-gh-release@v2
        with:
          files: |
            ANDRAX-2.0.tar.gz
            android-app/build/outputs/apk/release/*.apk
```

### B.3 `pages.yml` — publish `docs/` (committed)

Renders `docs/` (this `dev/` set plus the generated `TOOLS.md`/`WORKFLOWS.md`) to
a GitHub Pages site on push to `main` (and on demand via `workflow_dispatch`). It
uses the official Pages flow — `configure-pages` → `jekyll-build-pages`
(source `./docs`) → `upload-pages-artifact` → `deploy-pages`. `docs/_config.yml`
enables the `jekyll-relative-links`, `jekyll-optional-front-matter`, and
`jekyll-readme-index` plugins so the `.md` cross-links resolve and each folder's
`README.md` becomes its index.

**One-time setup:** enable it in **Settings → Pages → Source = GitHub Actions**.
See [Repository settings § 13.2](13-repository-settings.md#132-github-pages-for-pagesyml).

### CI/CD design principles

* **Generated artifacts are checked in** *and* CI verifies they're current — so
  reviewers see registry/doc diffs, and drift is caught.
* **Secrets never touch the repo.** The keystore is a base64 GitHub Secret,
  decoded only in the release job. See [Signing](05-signing-pipeline.md).
* **Tags are the release trigger.** No manual artifact building. See
  [Release lifecycle](07-release-lifecycle.md) and
  [Release instructions](12-release-instructions.md).
* **Everything runs locally too.** Every CI step is just a `tools/` script or a
  Gradle task, so contributors reproduce CI on their machine.
