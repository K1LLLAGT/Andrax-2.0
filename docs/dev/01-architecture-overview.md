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
      → scripting-engine/scripts/run_tool_by_id.sh   [see gap #4]
         → bin/andrax-workflow-run.sh
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

These are real rough edges in the current tree. They are documented here so
contributors don't trip over them, and are cross-referenced from the relevant
per-subsystem docs. None are fatal, but all are worth fixing.

1. **Three different `ANDRAX_HOME` conventions.**
   - `paths.sh` auto-resolves it to the repo root (correct, portable).
   - `launcher/andrax-launcher.sh`, `bin/*.sh`, and the Magisk scripts hardcode
     `$HOME/ANDRAX/ANDRAX-2.0` (an extra `ANDRAX/` level).
   - `TermuxLauncher.kt` and `android-app/docs/architecture.md` use
     `$HOME/ANDRAX-2.0` (i.e. `/data/data/com.termux/files/home/ANDRAX-2.0`).
   These must be reconciled before the app↔backend bridge and the unified
   launcher can work on the same install. The `paths.sh` convention is the one
   to standardize on.

2. **Two tool registries with different schemas.**
   - `launcher-system/tool_registry.json` — hand-maintained, rich, schema
     `andrax-registry/1`, includes a `.workflows[]` array. This is
     `ANDRAX_REGISTRY` (what the engine actually reads).
   - `android-app/src/main/assets/tool_registry.json` — the **output target** of
     `tools/build_registry.sh`, a *different* shape (adds `privileged`, no
     workflows). `INSTALL.md`/`build-notes.md` say to `cp` the canonical one
     over it. So the builder and the copy-sync instruction fight each other.
   See [Tool registry](08-tool-registry.md) for the resolution.

3. **`build_registry.sh` description extraction is wrong.** It grabs the first
   `^#` line of each tool script, which is the shebang (`#!/usr/bin/env bash`),
   so generated descriptions read `!/usr/bin/env bash` (visible in the current
   `docs/TOOLS.md`). It should skip the shebang and read the first real comment.

4. **`run_tool_by_id.sh` runs the *workflow* runner.**
   `scripting-engine/scripts/run_tool_by_id.sh` execs
   `bin/andrax-workflow-run.sh`, not `launch_tool.sh`. The name says "tool" but
   the body dispatches a workflow. `engine.sh`'s `run-tool` case therefore does
   not currently reach `launch_tool.sh`.

5. **`andrax-launcher.sh` calls non-existent engine subcommands.** It invokes
   `engine.sh run_tool_by_id / list_tools / list_workflows` (underscores), but
   `engine.sh` only recognizes the hyphenated forms (`run-tool`, `list-tools`,
   `list-workflows`). Those calls hit the engine's unknown-command branch.

6. **`workflow_registry.json` is a stub.** The app asset is `{ "test": true }`,
   so `build_docs.sh` produces an empty `docs/WORKFLOWS.md`. Run
   `tools/build_workflow_registry.sh` to populate it. The canonical workflow
   list currently lives inside `launcher-system/tool_registry.json` `.workflows[]`.

7. **No CI, no signing config, no Gradle wrapper.** There is no `.github/`,
   no `*.gradle` files, and no keystore handling in the repo. The
   [CI/CD](04-cicd-pipeline.md) and [Signing](05-signing-pipeline.md) documents
   describe the current manual reality and a recommended automated design.
