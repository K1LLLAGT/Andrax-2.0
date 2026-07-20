# 2. Backend Structure

The "backend" is everything that runs inside Termux: the environment config, the
tool arsenal, the launcher/dispatch layer, the workflow engine, and the
scripting-engine entrypoint. This document walks each piece.

## 2.1 `termux-backend/` — the arsenal

```
termux-backend/
├── config/
│   ├── paths.sh    # canonical variables (ANDRAX_HOME, dirs, registry, state)
│   └── env.sh      # environment loader: sources paths.sh, sets PATH, `andrax` alias
├── setup/
│   ├── install_termux_packages.sh   # base pkgs + core tools (nmap, whois, jq, …)
│   ├── install_python_tools.sh      # pip-based tools
│   ├── install_go_tools.sh          # go-based tools (ProjectDiscovery et al.)
│   ├── install_rust_tools.sh        # cargo-based tools
│   └── setup_proot_kali.sh          # optional Kali/Debian userland via proot-distro
└── tools/
    ├── lib/toolkit.sh               # shared library every tool sources
    └── <category>/<tool>.sh         # one launcher script per tool
```

### config/paths.sh

Sourced by **everything**. It resolves `ANDRAX_HOME` (unless preset) by walking
up from its own location, then exports all component roots, the registry path,
and the per-user state dirs (`~/.andrax/{logs,loot,run}`), creating the state
dirs if missing. Never run it directly — always `.`/`source` it. See the full
variable table in [Architecture § Environment & state](01-architecture-overview.md#environment--state).

### config/env.sh

The thing users `source` from their shell profile. It:

1. Sources `paths.sh` (which also sets `ANDRAX_HOME`).
2. Prepends `scripting-engine/` to `PATH` and defines the `andrax` alias.
3. Prepends `$HOME/go/bin`, `$HOME/.cargo/bin`, `$HOME/.local/bin` if present.
4. Exports "good-citizen" defaults: `ANDRAX_HTTP_UA=ANDRAX-2.0`,
   `ANDRAX_DEFAULT_THREADS=8`.

Idempotent and safe to source repeatedly and from any directory.

### setup/ installers

Each installer is idempotent and layered so a user installs only what they need:

| Script | Installs | Required? |
|--------|----------|-----------|
| `install_termux_packages.sh` | Base Termux packages + core tools | Yes |
| `install_python_tools.sh` | pip-based tools | Usually |
| `install_go_tools.sh` | Go-based tools | Optional |
| `install_rust_tools.sh` | Rust/cargo tools | Optional |
| `setup_proot_kali.sh` | proot Kali/Debian userland (`ANDRAX_PROOT_DISTRO`) | Optional; needed for tools not packaged in Termux (e.g. wpscan) |

### tools/lib/toolkit.sh — the shared tool library

**Every** tool launcher sources this first. It is the contract every tool obeys.
API:

| Function | Purpose |
|----------|---------|
| `andrax_init <name>` | Start a per-run logfile `~/.andrax/logs/<name>-<ts>.log`, write a header |
| `andrax_log <msg>` | Timestamped line to stdout **and** the logfile |
| `andrax_die <msg>` | Log at ERROR level and `exit 1` |
| `andrax_need <bin> [hint]` | Require a binary or die with an install hint |
| `andrax_need_proot` | Ensure `proot-distro` + the configured distro are installed |
| `andrax_proot <cmd...>` | Run a command inside the proot userland |
| `andrax_run <cmd...>` | Echo + run a command, teeing combined output to the logfile, preserving the command's exit code (via `PIPESTATUS`) |
| `andrax_usage_guard <argc>` | If `argc == 0`, print `$USAGE` and `exit 0` |
| `andrax_loot <name>` | Return a timestamped path under `~/.andrax/loot/<tool>/` for artifacts |

### The tool-script contract

Every `tools/<category>/<tool>.sh` follows the same shape (nmap shown):

```sh
#!/usr/bin/env bash
# ANDRAX 2.0 :: Information Gathering :: nmap          # <- human description line
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/toolkit.sh"
ANDRAX_TOOL_NAME="nmap"
read -r -d '' USAGE <<'EOF'
nmap.sh — network & service discovery (Nmap)
USAGE: ...
EXAMPLES: ...
EOF
andrax_usage_guard "$#"          # no args → print USAGE, exit 0
andrax_init "$ANDRAX_TOOL_NAME"  # start logging
andrax_need nmap "pkg install nmap"

# ... tool-specific logic, e.g. non-root -sS → -sT rewrite ...
andrax_run nmap "${args[@]}"     # run + log
```

Rules a new tool must honor:

1. Source `toolkit.sh`; set `ANDRAX_TOOL_NAME`.
2. Provide a `$USAGE` heredoc and call `andrax_usage_guard "$#"` first.
3. Call `andrax_init` before doing work.
4. Gate every external binary with `andrax_need`.
5. Run the real command through `andrax_run` so it is logged and its exit code
   propagates.
6. **No privileged operations.** Degrade gracefully when root would be needed
   (like nmap's `-sS`→`-sT` rewrite), or route through `andrax_proot`.

Tool categories in the tree today: `info_gathering`, `vuln_analysis`,
`web_apps`, `database_assessment`, `password_attacks`, `wireless_attacks`,
`reverse_engineering`, `exploitation`, `sniffing_spoofing`, `forensics`,
`reporting`.

## 2.2 `launcher-system/` — resolution & dispatch

```
launcher-system/
├── tool_registry.json     # CANONICAL registry (ANDRAX_REGISTRY)
├── launch_tool.sh         # resolve id/name → script, exec it
└── category_dispatch.sh   # list categories / tools; --json dump for the app
```

### launch_tool.sh

The central id→script resolver used by the engine, the CLI, and (intended) the
app bridge.

```
launch_tool.sh <tool-id> [-- <args...>]
launch_tool.sh --list
```

Resolution: look up `.categories[].tools[] | select(.id==$id) | .script`; if
empty, fall back to a case-insensitive `.name` match; then run
`$ANDRAX_TOOLS_DIR/<script>` with the remaining args (chmod +x if needed).
Requires `jq`. Exit codes: `2` no jq, `3` unknown tool, `4` script missing.

### category_dispatch.sh

Browsing surface. `category_dispatch.sh` with no args lists categories with tool
counts; with a `<category-id>` lists that category's tools + examples;
`--json` emits the raw `.categories` array (this is what the app's category
screens are meant to consume).

## 2.3 `scripting-engine/` — the `andrax` command

```
scripting-engine/
├── engine.sh                     # THE entrypoint / dispatcher (`andrax`)
└── scripts/
    ├── list_tools.sh             # jq pretty-print of tools (optionally by category)
    ├── list_workflows.sh         # jq pretty-print of workflows
    ├── run_tool_by_id.sh         # [see gap #4] currently execs the workflow runner
    └── run_workflow_by_id.sh     # resolve workflow id → workflow-engine script
```

`engine.sh` subcommands:

| Command | Action |
|---------|--------|
| `doctor` | Environment self-check: prints paths, root status, presence of each core tool, proot userland status |
| `list-tools [category]` | Delegate to `scripts/list_tools.sh` |
| `list-workflows` | Delegate to `scripts/list_workflows.sh` |
| `categories` | Delegate to `launcher-system/category_dispatch.sh` |
| `run-tool <id> -- <args>` | Delegate to `scripts/run_tool_by_id.sh` |
| `run-workflow <id> -- <args>` | Delegate to `scripts/run_workflow_by_id.sh` |
| `info <tool-id>` | jq lookup: name, category, script, description, example |
| `help` | Usage (extracted from the header comment) |

`run_workflow_by_id.sh` is the clean example of registry-driven dispatch: it
reads `.workflows[] | select(.id==$id) | .script` from `ANDRAX_REGISTRY`, then
execs `workflow-engine/workflows/<script>`.

> **Gap #4:** `run_tool_by_id.sh` does *not* call `launch_tool.sh`; it execs
> `bin/andrax-workflow-run.sh`. To make `andrax run-tool` resolve tools via the
> registry, point it at `launcher-system/launch_tool.sh`. See
> [Architecture § Known gaps](01-architecture-overview.md#known-gaps--inconsistencies).

## 2.4 `workflow-engine/` — chained workflows

```
workflow-engine/
├── libs/
│   ├── logging.sh   # log_info/ok/warn/err/step, colorized + file log ($WF_LOG)
│   ├── prompts.sh   # ask, confirm (honors ANDRAX_ASSUME_YES), require_scope
│   └── helpers.sh   # run_tool, have, http_title, workflow_loot
└── workflows/
    ├── recon_basic.sh
    ├── web_app_assessment.sh
    ├── network_scan_full.sh
    └── exploit_chain_example.sh   # scoped demo
```

A shell workflow sources the three libs, calls `require_scope <target>` (the
authorization gate → records `~/.andrax/.authorized`), and then chains tools via
the `run_tool` helper (which calls `launch_tool.sh <id> -- <args>`). Example
skeleton (`recon_basic.sh`):

```sh
. "$ANDRAX_WORKFLOW_DIR/libs/logging.sh"
. "$ANDRAX_WORKFLOW_DIR/libs/prompts.sh"
. "$ANDRAX_WORKFLOW_DIR/libs/helpers.sh"
require_scope "$target" || exit 1
log_step "1/4 whois";   run_tool whois "$target"   || log_warn "whois failed"
log_step "2/4 dnsenum"; run_tool dnsenum "$target" || log_warn "dnsenum failed"
log_step "3/4 nmap";    run_tool nmap -sT -sV --top-ports 100 "$target"
log_step "4/4 title";   http_title "http://$target"
```

See [Workflow registry](09-workflow-registry.md) for shell-vs-YAML details.

## 2.5 `bin/` + `launcher/` — the unified launcher (alternate path)

```
bin/
├── andrax-workflow-run.sh   # runs workflow: shell first, else YAML fallback
├── andrax-tool-wrapper.sh   # runs termux-backend/tools/<id>/<id>.sh directly
└── adapters/
    ├── adapter-termux.sh     # eval "$CMD"   (unprivileged)
    └── adapter-magisk.sh     # su -c "$CMD"  (privileged)
launcher/
├── andrax-launcher.sh        # unified front-end: workflow|tool|list-*
└── andrax-ipc-contract.sh    # app IPC verbs → andrax-launcher.sh
```

This is a **second, parallel** front-end to the scripting engine. Its workflow
runner (`andrax-workflow-run.sh`) is notable because it is what actually
implements the **YAML fallback**: if no `workflow-engine/workflows/<id>.sh`
exists, it finds `workflows/**/<id>.yaml`, extracts `name:`/`run:` pairs, and
runs each step through the Termux adapter — or the **Magisk adapter** if the
step's command contains the literal marker `[privileged]`.

> The unified launcher hardcodes `$HOME/ANDRAX/ANDRAX-2.0` and calls
> underscore-named engine subcommands that don't exist (gaps #1 and #5). Treat
> it as an alternate/experimental path until reconciled with `paths.sh`.

## 2.6 `magisk-module/andrax-bridge/` — optional root bridge

A Magisk module for rooted devices. `post-fs-data.sh` bind-mounts privileged
binaries (e.g. `tcpdump`, a privileged `nmap`) into the backend's `bin/` so the
Magisk adapter can use them. `service.sh` is a no-op placeholder for background
tasks. `module.prop` carries the module metadata (`id=andrax-bridge`,
`version=1.0`, `versionCode=1`). This is entirely optional — ANDRAX 2.0's core
value proposition is that it works **without** it.
