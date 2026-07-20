# 4. CI/CD Pipeline

> **Current state:** ANDRAX 2.0 has **no continuous-integration automation** in
> the repository. There is no `.github/` directory, no CI config, and no Gradle
> wrapper. "CI/CD" today means a set of **local, developer-run shell scripts**
> under `tools/` that build the registries and docs and audit the tree. This
> document describes (A) that current local pipeline and (B) a concrete,
> ready-to-adopt GitHub Actions design.

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

> Note the current builders have known bugs (descriptions read the shebang; the
> workflow registry asset is a stub). See
> [Architecture § Known gaps](01-architecture-overview.md#known-gaps--inconsistencies)
> #3 and #6. Fixing those is a prerequisite to trusting generated artifacts in CI.

## B. Recommended CI/CD (GitHub Actions)

Adopt three workflows. Place them under `.github/workflows/`.

### B.1 `ci.yml` — validate every push & PR

Gates that should fail the build:

1. **ShellCheck** all `*.sh`.
2. **Registry/doc drift check** — regenerate the registries + docs and fail if
   `git diff` is non-empty (i.e. generated artifacts weren't committed).
3. **JSON validity** — `jq . tool_registry.json` on both copies.
4. **Consistency audit** — run `tools/backend_consistency_auditor.sh` and
   `tools/broken_script_locator.sh`; non-zero exit fails.
5. **App build** — `./gradlew assembleDebug` once the Gradle project exists.

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
      - name: Build debug APK
        working-directory: android-app
        run: ./gradlew assembleDebug        # requires the Gradle project (build-notes.md)
```

### B.2 `release.yml` — build & publish on a tag

Triggered by pushing a `v*` tag. Produces the two release artifacts:

1. The **source tarball** `ANDRAX-2.0.tar.gz` (the thing `INSTALL.md` extracts).
2. The **signed release APK** (see [Signing pipeline](05-signing-pipeline.md)).

```yaml
name: release
on:
  push: { tags: [ 'v*' ] }
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Verify VERSION matches tag
        run: test "v$(cat VERSION)" = "${GITHUB_REF_NAME%.*}" -o "v$(cat VERSION)" = "$GITHUB_REF_NAME"
      - name: Build source tarball
        run: |
          name="ANDRAX-2.0"
          git archive --format=tar.gz --prefix="$name/" -o "$name.tar.gz" HEAD
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: '17' }
      - name: Build signed APK
        working-directory: android-app
        env:
          ANDRAX_KEYSTORE_B64: ${{ secrets.ANDRAX_KEYSTORE_B64 }}
          ANDRAX_KEYSTORE_PASS: ${{ secrets.ANDRAX_KEYSTORE_PASS }}
          ANDRAX_KEY_ALIAS: ${{ secrets.ANDRAX_KEY_ALIAS }}
          ANDRAX_KEY_PASS: ${{ secrets.ANDRAX_KEY_PASS }}
        run: |
          echo "$ANDRAX_KEYSTORE_B64" | base64 -d > release.keystore
          ./gradlew assembleRelease
      - name: Publish GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: |
            ANDRAX-2.0.tar.gz
            android-app/build/outputs/apk/release/*.apk
```

### B.3 `pages.yml` (optional) — publish `docs/`

Render `docs/` (including this `dev/` set and the generated `TOOLS.md`/
`WORKFLOWS.md`) to GitHub Pages on push to `main`.

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
