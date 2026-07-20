# 9. Workflow Registry

A **workflow** chains multiple tools into a repeatable procedure (recon,
web-app assessment, full network scan, a scoped exploit demo). ANDRAX 2.0
supports **two kinds** of workflow and resolves them through a registry, just
like tools.

## 9.1 Two workflow kinds

| Kind | Location | Author | Runner |
|------|----------|--------|--------|
| **Shell** | `workflow-engine/workflows/<id>.sh` | Handwritten bash sourcing the workflow libs | `scripting-engine/scripts/run_workflow_by_id.sh` (via registry) **or** `bin/andrax-workflow-run.sh` (shell-first) |
| **YAML** | `workflows/<group>/<id>.yaml` | Declarative steps | `bin/andrax-workflow-run.sh` (fallback when no shell workflow of that id exists) |

`bin/andrax-workflow-run.sh` prefers a **shell** workflow of the given id; only
if none exists does it look for `workflows/**/<id>.yaml`.

## 9.2 Where the workflow list lives

| File | Role | Read by |
|------|------|---------|
| `launcher-system/tool_registry.json` → `.workflows[]` | **Canonical** workflow list | `list_workflows.sh`, `run_workflow_by_id.sh` |
| `android-app/src/main/assets/workflow_registry.json` | App workflow catalog | (intended) the app; **currently a stub `{ "test": true }`** |

> **Gap #6:** the app-side `workflow_registry.json` is a placeholder, so
> `tools/build_docs.sh` currently produces an **empty** `docs/WORKFLOWS.md`. Run
> `tools/build_workflow_registry.sh` to generate it from the actual shell + YAML
> workflows, then `build_docs.sh` to populate `docs/WORKFLOWS.md`.

### Canonical `.workflows[]` schema

Same shape as tool entries (see [Tool registry § 8.2](08-tool-registry.md#82-canonical-schema-andrax-registry1)):

```jsonc
{
  "id": "recon_basic",
  "name": "Basic Recon",
  "script": "recon_basic.sh",        // relative to workflow-engine/workflows/
  "description": "whois + DNS enum + nmap service scan + HTTP title.",
  "example": "run-workflow recon_basic -- example.com"
}
```

### Generated `workflow_registry.json` schema (from `build_workflow_registry.sh`)

The generator emits a richer, typed entry that distinguishes shell vs. YAML:

```jsonc
{
  "id": "recon_basic",
  "name": "recon_basic",
  "type": "shell",                          // or "yaml"
  "source": "workflow-engine/workflows/recon_basic.sh",  // repo-relative
  "description": "…first comment line…",
  "example": "andrax run-workflow recon_basic -- <args>"
}
```

## 9.3 Anatomy of a shell workflow

Shell workflows source the three workflow libraries and chain tools via the
`run_tool` helper. Skeleton (`recon_basic.sh`):

```sh
#!/usr/bin/env bash
# ANDRAX 2.0 :: Workflow :: recon_basic
set -uo pipefail
. "$_wf/../../termux-backend/config/paths.sh"
. "$ANDRAX_WORKFLOW_DIR/libs/logging.sh"   # log_info/ok/warn/err/step + $WF_LOG
. "$ANDRAX_WORKFLOW_DIR/libs/prompts.sh"   # ask, confirm, require_scope
. "$ANDRAX_WORKFLOW_DIR/libs/helpers.sh"   # run_tool, have, http_title, workflow_loot

[ $# -ge 1 ] || { echo "usage: recon_basic.sh <domain-or-host>"; exit 1; }
target="$1"
require_scope "$target" || exit 1          # AUTHORIZATION GATE

log_step "1/4 whois";   run_tool whois "$target"   || log_warn "whois failed"
log_step "2/4 dnsenum"; run_tool dnsenum "$target" || log_warn "dnsenum failed"
log_step "3/4 nmap";    run_tool nmap -sT -sV --top-ports 100 "$target"
log_step "4/4 title";   http_title "http://$target"
log_ok "recon_basic complete. Logs: $WF_LOG"
```

### The workflow libraries (`workflow-engine/libs/`)

| Lib | Provides |
|-----|----------|
| `logging.sh` | `log_info` `log_ok` `log_warn` `log_err` `log_step` — colorized to stdout, plain to `$WF_LOG` (`~/.andrax/logs/workflow-<ts>.log`) |
| `prompts.sh` | `ask <q> [default]`; `confirm <q>` (honors `ANDRAX_ASSUME_YES=1` for non-interactive runs); **`require_scope <target>`** — the authorization gate that records `~/.andrax/.authorized` |
| `helpers.sh` | `run_tool <id> [args…]` (→ `launch_tool.sh`), `have <bin>`, `http_title <url>`, `workflow_loot <name>` |

### Rules for a shell workflow

1. Source `logging.sh`, `prompts.sh`, `helpers.sh`.
2. Validate arguments and print a `usage`.
3. Call **`require_scope "$target"`** before any active step. Never bypass it.
4. Chain tools through `run_tool <id>` so resolution stays registry-driven.
5. Use `log_step`/`log_ok`/`log_warn` so runs are traceable; tolerate individual
   step failure where appropriate (`|| log_warn …`).

## 9.4 Anatomy of a YAML workflow

```yaml
# workflows/recon/fast-scan.yaml
id: fast-scan
steps:
  - name: host-discovery
    run: "ping -c 1 {{target}}"
  - name: port-scan
    run: "nmap -T4 -p- {{target}}"
```

The YAML runner (`bin/andrax-workflow-run.sh`) extracts each `name:`/`run:`
pair and executes `run:` through an **adapter**:

* `bin/adapters/adapter-termux.sh` — `eval "$CMD"` (unprivileged, default).
* `bin/adapters/adapter-magisk.sh` — `su -c "$CMD"` (privileged) — selected only
  when the command text contains the literal marker `[privileged]`.

> The current YAML runner is intentionally minimal: it greps `name:`/`run:` and
> does **not** yet substitute `{{target}}` placeholders or parse nested YAML.
> Treat YAML workflows as an emerging feature; shell workflows are the mature
> path. A `{{var}}` substitution pass and a real YAML parser are the natural next
> steps (`tools/workflow_yaml_linter.sh` already lints the format).

## 9.5 Running workflows

```sh
andrax list-workflows                         # from the registry
andrax run-workflow recon_basic -- example.com
andrax run-workflow web_app_assessment -- http://target/

# alternate (unified launcher) path:
launcher/andrax-launcher.sh workflow recon_basic example.com
```

## 9.6 Current workflows

| id | Name | Kind | Description |
|----|------|------|-------------|
| `recon_basic` | Basic Recon | shell | whois → DNS enum → nmap service scan → HTTP title |
| `web_app_assessment` | Web App Assessment | shell | content discovery → nikto → sqlmap smoke test |
| `network_scan_full` | Full Network Scan | shell | all-ports → service/version + default NSE |
| `exploit_chain_example` | Exploit Chain (demo) | shell | recon → vuln check → scoped Metasploit auxiliary run |
| `fast-scan` | Fast Scan | yaml | ping host-discovery → `nmap -T4 -p-` |

## 9.7 Adding a workflow

1. **Shell:** create `workflow-engine/workflows/<id>.sh` per § 9.3.
   **YAML:** create `workflows/<group>/<id>.yaml` per § 9.4.
2. Register it: add to `launcher-system/tool_registry.json` `.workflows[]`
   (shell) so `list-workflows`/`run-workflow` see it.
3. Regenerate the app workflow registry + docs:
   `tools/build_workflow_registry.sh` then `tools/build_docs.sh`.
4. Validate: `andrax list-workflows`, then run it against an authorized target.
