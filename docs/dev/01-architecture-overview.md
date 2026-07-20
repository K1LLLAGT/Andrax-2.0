# 1. Architecture Overview

ANDRAX 2.0 is a reimagining of the ANDRAX concept for **stock, non-rooted
modern Android** (Samsung tablets/phones on One UI, Android 12–14). Where the
original ANDRAX relied on kernel-level tricks (chroot from init, loop mounts,
raw packet injection, SELinux bypass), ANDRAX 2.0 assumes **none of that is
available** and lives entirely in user space on top of **Termux** and
**proot-distro**.

## Design principles

1. **No privilege escalation is required.** Every core path works as a normal
   Termux user. Tools that genuinely need raw sockets (SYN scans, monitor mode)
   either degrade gracefully (e.g. nmap `-sS` → `-sT`) or are documented as
   unavailable. Root is an *optional* enhancement via the Magisk module, never a
   requirement.
2. **The app is a thin front-end.** The Android app performs **zero** privileged
   or security-sensitive operations. It renders a catalog and dispatches to the
   Termux backend over a documented intent. All real execution happens in
   Termux.
3. **One registry, many consumers.** A single JSON registry describes the tool
   arsenal. The CLI, the category dispatcher, the workflow engine, and the app
   all read it, so ids and script paths cannot drift.
4. **Honest logging and exit codes.** Every tool script logs to a central
   directory and returns real exit codes. No silent failures.
5. **Authorization is enforced in the backend, not the UI.** The
   `require_scope` gate lives in the shell layer so it applies to CLI *and* app
   use.

## The five layers

```
┌───────────────────────────────────────────────────────────────────────┐
│ 1. Android app  (android-app/)                                          │
│    Kotlin skeleton: category/tool browser. No privileged ops.           │
│    Dispatches via Termux RUN_COMMAND intent.                            │
└───────────────────────────┬───────────────────────────────────────────┘
                            │ com.termux.RUN_COMMAND  → engine.sh
                            ▼
┌───────────────────────────────────────────────────────────────────────┐
│ 2. Scripting engine  (scripting-engine/engine.sh)                       │
│    The `andrax` command. Single entrypoint / dispatcher.                │
│    Subcommands: doctor, list-tools, list-workflows, categories,         │
│    run-tool, run-workflow, info.                                        │
└───────────┬───────────────────────────────────┬───────────────────────┘
            │                                    │
            ▼                                    ▼
┌───────────────────────────────┐  ┌────────────────────────────────────┐
│ 3. Launcher system            │  │ 4. Workflow engine                 │
│    (launcher-system/)         │  │    (workflow-engine/)              │
│  tool_registry.json (canon)   │  │  Chained shell + YAML workflows    │
│  launch_tool.sh   (id→script) │  │  libs: logging, prompts, helpers   │
│  category_dispatch.sh         │  │  workflows/*.sh, workflows/*.yaml  │
└───────────────┬───────────────┘  └────────────────┬───────────────────┘
                │                                    │
                └───────────────┬────────────────────┘
                                ▼
┌───────────────────────────────────────────────────────────────────────┐
│ 5. Termux backend  (termux-backend/)                                    │
│    config/    paths.sh, env.sh          (environment + PATH)            │
│    setup/     install_*.sh              (idempotent installers)         │
│    tools/<category>/<tool>.sh           (one launcher per tool)         │
│    tools/lib/toolkit.sh                 (shared tool library)           │
└───────────────────────────────────────────────────────────────────────┘
```

Two additional, **optional** subsystems sit alongside the five layers:

* **`bin/` + `launcher/`** — an alternate "unified launcher" front-end
  (`andrax-launcher.sh`) and workflow runner (`andrax-workflow-run.sh`) with
  Termux/Magisk *adapters* and an IPC-contract shim. This is a parallel path to
  the scripting engine (see [Known gaps](#known-gaps--inconsistencies)).
* **`magisk-module/`** — an optional Magisk module (`andrax-bridge`) that
  bind-mounts privileged binaries into the backend on rooted devices.

## Directory map

| Path | Layer | Role |
|------|-------|------|
| `android-app/` | 1 | Kotlin front-end skeleton + app-side registry asset |
| `scripting-engine/` | 2 | `engine.sh` (the `andrax` command) + helper scripts |
| `launcher-system/` | 3 | Canonical `tool_registry.json`, `launch_tool.sh`, `category_dispatch.sh` |
| `workflow-engine/` | 4 | Shell workflows + shared libs (`logging`, `prompts`, `helpers`) |
| `termux-backend/` | 5 | `config/`, `setup/`, per-tool `tools/<category>/*.sh`, `tools/lib/toolkit.sh` |
| `bin/` | opt | Alternate workflow runner, tool wrapper, Termux/Magisk adapters |
| `launcher/` | opt | Unified launcher + IPC contract shim |
| `magisk-module/` | opt | `andrax-bridge` Magisk module for rooted devices |
| `workflows/` | 4 | YAML workflow definitions (`recon/fast-scan.yaml`) |
| `tools/` | dev | Developer/maintainer tooling: registry & doc builders, auditors, profilers |
| `docs/` | docs | `TOOLS.md`, `WORKFLOWS.md` (generated), and this `dev/` set |

## Execution paths

There are two distinct entrypoints into the backend. Understanding both is key.

### Path A — the scripting engine (primary / documented)

Used by `README.md`, `INSTALL.md`, and `TermuxLauncher.kt`:

```
andrax run-tool nmap -- -sV scanme.nmap.org
   → scripting-engine/engine.sh  (case: run-tool)
      → scripting-engine/scripts/run_tool_by_id.sh
         → launcher-system/launch_tool.sh  (registry id → script)
            → termux-backend/tools/<category>/<tool>.sh
```

```
andrax run-workflow recon_basic -- example.com
   → engine.sh (case: run-workflow)
      → scripting-engine/scripts/run_workflow_by_id.sh
         → resolves script via tool_registry.json .workflows[]
            → workflow-engine/workflows/recon_basic.sh
               → run_tool whois / dnsenum / nmap
                  → launcher-system/launch_tool.sh  (id → script)
                     → termux-backend/tools/<category>/<tool>.sh
```

The canonical tool resolution is:
**registry id → `launch_tool.sh` → `$ANDRAX_TOOLS_DIR/<script>`**, where
`ANDRAX_TOOLS_DIR = termux-backend/tools`.

### Path B — the unified launcher (alternate)

```
launcher/andrax-launcher.sh workflow recon_basic
   → bin/andrax-workflow-run.sh recon_basic
      → prefers workflow-engine/workflows/recon_basic.sh
      → else YAML fallback: parses workflows/**/<id>.yaml
         → per step: adapter-termux.sh (or adapter-magisk.sh if "[privileged]")
```

`launcher/andrax-ipc-contract.sh` is a shim that maps the app's expected IPC
verbs (`workflow`, `tool`) onto `andrax-launcher.sh`.

## Environment & state

`termux-backend/config/paths.sh` is sourced by everything and defines the
canonical variables:

| Variable | Default | Meaning |
|----------|---------|---------|
| `ANDRAX_HOME` | repo root (auto-resolved) | Project root |
| `ANDRAX_BACKEND` | `$ANDRAX_HOME/termux-backend` | Backend root |
| `ANDRAX_TOOLS_DIR` | `$ANDRAX_BACKEND/tools` | Tool scripts root |
| `ANDRAX_LAUNCHER_DIR` | `$ANDRAX_HOME/launcher-system` | Launcher root |
| `ANDRAX_WORKFLOW_DIR` | `$ANDRAX_HOME/workflow-engine` | Workflow root |
| `ANDRAX_ENGINE_DIR` | `$ANDRAX_HOME/scripting-engine` | Engine root |
| `ANDRAX_REGISTRY` | `$ANDRAX_LAUNCHER_DIR/tool_registry.json` | **Canonical registry** |
| `ANDRAX_STATE` | `$HOME/.andrax` | Per-user state root |
| `ANDRAX_LOG_DIR` | `$ANDRAX_STATE/logs` | Central logs |
| `ANDRAX_LOOT_DIR` | `$ANDRAX_STATE/loot` | Captured output/artifacts |
| `ANDRAX_RUN_DIR` | `$ANDRAX_STATE/run` | Runtime scratch |
| `ANDRAX_PROOT_DISTRO` | `kali` | proot userland for un-packaged tools |

`env.sh` sources `paths.sh`, then puts the engine on `PATH` as `andrax` and
prepends Go/Rust/pip user bins.

## Known gaps & inconsistencies

Most of the original rough edges have been **fixed** — they're recorded here
(resolved) so the history is clear and so the cross-references in other docs
still make sense. The remaining open items are called out at the end.

### Resolved

1. **`ANDRAX_HOME` conventions reconciled.** ✅ The shell front-ends
   (`launcher/andrax-launcher.sh`, `launcher/andrax-ipc-contract.sh`,
   `bin/andrax-workflow-run.sh`, `bin/andrax-tool-wrapper.sh`) now source
   `termux-backend/config/paths.sh` and derive `ANDRAX_HOME` from their own
   location — install-location independent, no more hardcoded
   `$HOME/ANDRAX/ANDRAX-2.0`. The Magisk `post-fs-data.sh` and the app's
   `TermuxLauncher.ENGINE_PATH` use the documented install path
   `$HOME/ANDRAX-2.0` (`/data/data/com.termux/files/home/ANDRAX-2.0`), which is
   now the single standard location.

2. **Registry duplication resolved.** ✅ `launcher-system/tool_registry.json` is
   the sole canonical registry (`ANDRAX_REGISTRY`). `tools/build_registry.sh` is
   now a **sync + validator**: it verifies every tool script is registered (and
   vice-versa) and copies the canonical file to the app asset, so the two copies
   can no longer diverge in schema. See [Tool registry](08-tool-registry.md).

3. **`build_registry.sh` description bug gone.** ✅ Because the app asset is now a
   copy of the curated canonical registry, descriptions are the real,
   hand-written ones (no more `!/usr/bin/env bash`). `build_workflow_registry.sh`
   independently skips the shebang when it falls back to a script's header
   comment.

4. **`run_tool_by_id.sh` now runs tools.** ✅ It resolves the tool through
   `launcher-system/launch_tool.sh` (registry id → script), so `andrax run-tool`
   reaches the correct tool script.

5. **`andrax-launcher.sh` subcommands corrected.** ✅ It now calls the engine's
   real hyphenated subcommands (`run-tool … -- …`, `list-tools`,
   `list-workflows`).

6. **`workflow_registry.json` populated.** ✅ `tools/build_workflow_registry.sh`
   generates it from the actual shell + YAML workflows (enriched with curated
   names/descriptions from the canonical registry), and `docs/WORKFLOWS.md` is no
   longer empty. As a bonus, the YAML workflow runner now substitutes
   `{{target}}` and correctly strips/handles the `[privileged]` marker.

### Still open

7. **No APK signing config, no Gradle wrapper.** The Android app is still a
   source **skeleton** with no Gradle project, so there is nothing to sign yet.
   A working shell-side **CI** workflow now exists at `.github/workflows/ci.yml`
   (syntax + shellcheck + registry/doc drift + audits); the app-build and
   release/signing jobs are documented and stubbed but await the Gradle project.
   See [CI/CD](04-cicd-pipeline.md), [Signing](05-signing-pipeline.md), and
   [Build § 3](11-build-instructions.md#3-build-the-android-app-apk).
