# 10. Contribution Guide

Thanks for contributing to ANDRAX 2.0. This guide covers conventions, how to add
tools and workflows, the maintainer tooling under `tools/`, and the PR checklist.

> **Authorized-use only.** Contributions must not add capabilities designed to
> evade authorization, target systems indiscriminately, or hide activity. ANDRAX
> 2.0 wraps standard, publicly available tools for **authorized** testing,
> education, and CTF use — keep it that way. See [`../../LICENSE.md`](../../LICENSE.md).

## 10.1 Ground rules

1. **No privileged operations in the core path.** Tools run as a normal Termux
   user. If root would be needed, degrade gracefully (e.g. nmap `-sS`→`-sT`) or
   route through the proot userland (`andrax_proot`). Root-only extras belong in
   the optional Magisk module, clearly labeled.
2. **The registry is the contract.** Every tool/workflow is reachable by a stable
   `id` in `launcher-system/tool_registry.json`. Don't hardcode paths that
   bypass it.
3. **Honest logging & exit codes.** Use the `toolkit.sh` / workflow-lib helpers;
   never swallow failures silently.
4. **The app stays thin.** Don't add privileged logic, network servers, or
   permissions to the app. It renders the registry and dispatches to Termux.
5. **Keep generated artifacts current.** Regenerate registries + docs and commit
   them in the same PR as the change.

## 10.2 Coding conventions

* **Shebang:** `#!/usr/bin/env bash` on every `*.sh`
  (`tools/normalize_shebangs.sh` enforces it).
* **First comment line** is a one-line human description
  (`ANDRAX 2.0 :: <Category> :: <tool>` for tools). Generators fall back to this
  line (skipping the shebang) when curated registry text is absent, so keep it
  meaningful.
* **Strict mode** where practical: `set -euo pipefail` (workflows use
  `set -uo pipefail` so a single failed step doesn't abort the chain).
* **Resolve paths portably** by sourcing `termux-backend/config/paths.sh`; never
  hardcode `$HOME/ANDRAX…`. Use the `ANDRAX_*` variables — every front-end now
  does this.
* **Pass ShellCheck** (`-S warning`) with no new findings.
* **snake_case** ids for tools/categories/workflows, matching directory names.

## 10.3 Adding a tool (step by step)

1. **Pick/confirm the category** (`termux-backend/tools/<category>/`). Create the
   category dir if new.
2. **Write** `termux-backend/tools/<category>/<tool>.sh` following the
   [tool-script contract](02-backend-structure.md#the-tool-script-contract):
   source `toolkit.sh`, set `ANDRAX_TOOL_NAME`, define `$USAGE`, call
   `andrax_usage_guard "$#"`, `andrax_init`, gate binaries with `andrax_need`,
   run via `andrax_run`.
3. **Install deps:** add any new binary to the right
   `termux-backend/setup/install_*.sh` with an install hint that matches
   `andrax_need`'s message.
4. **Register:** add an entry to `launcher-system/tool_registry.json`
   (`categories[].tools[]`) — `id`, `name`, `script` (relative to
   `termux-backend/tools/`), `description`, `example`.
5. **Sync the app asset:**
   `cp launcher-system/tool_registry.json android-app/src/main/assets/tool_registry.json`
   (see [Tool registry § 8.1](08-tool-registry.md#81-the-two-copies-important)).
6. **Regenerate docs:** `bash tools/build_docs.sh`.
7. **Verify:** `andrax info <id>`; `andrax list-tools <category>`;
   `andrax run-tool <id>` (usage guard prints with no args); a real run against
   an **authorized** target.

## 10.4 Adding a workflow

See [Workflow registry § 9.7](09-workflow-registry.md#97-adding-a-workflow).
In short: write the shell/YAML workflow, call `require_scope` before active
steps (shell), register it in `.workflows[]`, regenerate the workflow registry +
docs, and test it end-to-end.

## 10.5 Maintainer tooling (`tools/`)

Run these before opening a PR. See the full table in
[CI/CD § A](04-cicd-pipeline.md#a-current-pipeline-local-manual). The essentials:

```sh
# regenerate artifacts
bash tools/build_registry.sh
bash tools/build_workflow_registry.sh
bash tools/build_docs.sh

# normalize + permissions
bash tools/normalize_shebangs.sh
bash tools/fix_permissions.sh

# audits (should all pass)
bash tools/audit_sh_files.sh
bash tools/backend_consistency_auditor.sh
bash tools/broken_script_locator.sh
bash tools/privileged_tool_detector.sh   # expect: no privileged tools
bash tools/workflow_yaml_linter.sh

# integration
bash tools/test_pipeline.sh
```

Inspection/debug helpers (as needed): `tool_dependency_mapper.sh`,
`tool_profiler.sh`, `workflow_call_graph.sh`, `workflow_visualizer.sh`,
`workflow_step_tracer.sh`, `workflow_debugger.sh`, `android_workflow_preview.sh`,
`test_android_ipc.sh`.

## 10.6 Branch & commit conventions

* Branch from `main`: `feature/<name>`, `fix/<name>`, `docs/<name>`,
  `tool/<id>`, `workflow/<id>`.
* Small, focused commits; imperative subject lines
  (`Add wpscan tool wrapper`, not `added stuff`).
* One logical change per PR. If you add a tool, its registry entry, its docs
  regeneration, and any installer change all belong together.

## 10.7 PR checklist

- [ ] New/changed `*.sh` uses `#!/usr/bin/env bash` and passes ShellCheck.
- [ ] Tool/workflow follows the script contract and does **no** privileged ops.
- [ ] Registry entry added (`launcher-system/tool_registry.json`).
- [ ] App asset synced (`android-app/.../tool_registry.json`).
- [ ] Installer updated if a new binary is required.
- [ ] Registries + docs regenerated (`tools/build_*.sh`) and committed; `git diff`
      clean afterward.
- [ ] `tools/backend_consistency_auditor.sh` and `broken_script_locator.sh` pass.
- [ ] `tools/test_pipeline.sh` passes (or the failure is explained).
- [ ] Verified manually: `andrax info/list-tools/run-tool` (or `list/run-workflow`).
- [ ] No new permissions added to the Android app.
- [ ] Authorization gate (`require_scope`) intact for any new active workflow.

## 10.8 Good first contributions

The original consistency bugs (`ANDRAX_HOME` conventions, the registry/description
builders, the tool/workflow dispatch mismatches, the stub workflow registry) have
been fixed — see [Architecture § Known gaps](01-architecture-overview.md#known-gaps--inconsistencies).
The app now builds (Gradle project + debug/release APK), and CI (`ci.yml`) +
the tag-driven `release.yml` with APK signing are in place. The high-value
remaining work is incremental:

* **Add a `tools/bump_version.sh`** to enforce version consistency
  ([Versioning § 6.4](06-versioning-system.md#64-bumping-a-version-the-rule)).
* **Add an optional GitHub Pages workflow** to publish `docs/`
  ([CI/CD § B.3](04-cicd-pipeline.md#b3-pagesyml-optional-recommended--publish-docs)).
* **Grow the YAML workflow runner** into a real parser with multi-variable
  substitution ([Workflow registry § 9.4](09-workflow-registry.md#94-anatomy-of-a-yaml-workflow)).
* **Replace the naive app argument tokenizer** with a shell-aware splitter
  ([Android app § 3.7](03-android-app-structure.md#37-security--input-handling-notes)).
