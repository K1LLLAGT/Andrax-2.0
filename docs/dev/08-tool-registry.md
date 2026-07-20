# 8. Tool Registry

The tool registry is the **single source of truth** for the ANDRAX 2.0 arsenal.
It maps stable tool ids to on-disk scripts and carries the metadata the CLI and
app render. Both consumers read the same shape, so ids and paths never drift.

## 8.1 The two copies (important)

There are **two** files named `tool_registry.json`:

| File | Role | Read by | Maintained |
|------|------|---------|------------|
| `launcher-system/tool_registry.json` | **Canonical** (`ANDRAX_REGISTRY` in `paths.sh`) | `engine.sh`, `launch_tool.sh`, `category_dispatch.sh`, `list_tools.sh`, `run_workflow_by_id.sh` | **By hand** (source of truth) |
| `android-app/src/main/assets/tool_registry.json` | App catalog asset | `ToolRepository.kt` (the app) | Synced from canonical by `tools/build_registry.sh` |

The canonical file is hand-authored; the app asset is a byte-for-byte **copy**
of it. `tools/build_registry.sh` performs that copy and also **validates** that
every tool script under `termux-backend/tools/` is registered (and every
registered script exists on disk). Because the asset is a copy, the two files
cannot diverge in schema, and the app always sees the curated names,
descriptions, examples, and icons.

```sh
bash tools/build_registry.sh    # validate coverage + sync app asset from canonical
```

> **Design note:** the registry is deliberately *not* generated from the
> filesystem. Display names (`Nmap` vs the id `nmap`), category icons, curated
> descriptions, examples, and the `.workflows[]` list can't be derived from the
> scripts, so generation would be lossy. Canonical-by-hand + validated copy keeps
> the rich data and still catches drift between the registry and the scripts.

## 8.2 Canonical schema (`andrax-registry/1`)

```jsonc
{
  "schema": "andrax-registry/1",     // registry shape version (see Versioning §6.2)
  "version": "2.0.0",                // project version at generation time
  "generated": "2026-07-18",         // ISO build stamp
  "notes": "…",                      // free-form
  "categories": [
    {
      "id": "info_gathering",        // stable category id (snake_case)
      "name": "Information Gathering",
      "icon": "search",              // icon hint for the app
      "tools": [
        {
          "id": "nmap",              // STABLE tool id — the public handle
          "name": "Nmap",            // display name
          "script": "info_gathering/nmap.sh",   // relative to termux-backend/tools/
          "description": "Network host, port and service discovery.",
          "example": "run-tool nmap -- -sV scanme.nmap.org"  // shown as `andrax <example>`
        }
      ]
    }
  ],
  "workflows": [                     // canonical workflow list lives here too
    {
      "id": "recon_basic",
      "name": "Basic Recon",
      "script": "recon_basic.sh",    // relative to workflow-engine/workflows/
      "description": "whois + DNS enum + nmap service scan + HTTP title.",
      "example": "run-workflow recon_basic -- example.com"
    }
  ]
}
```

### Field rules

| Field | Rules |
|-------|-------|
| `schema` | `andrax-registry/<int>`. Bump the int only on a breaking shape change. |
| `categories[].id` | snake_case, stable, matches the `tools/<id>/` directory name. |
| `tools[].id` | The public handle used by `run-tool`, `info`, and the app. **Never rename** without a deprecation cycle ([Release lifecycle § 7.6](07-release-lifecycle.md#76-deprecating--removing-a-tool-or-workflow)). |
| `tools[].script` | Path **relative to `termux-backend/tools/`**. Must exist. |
| `tools[].example` | The args after `andrax` (no leading `andrax`). Rendered as `andrax <example>`. |
| `workflows[].script` | Path **relative to `workflow-engine/workflows/`**. |

The app-asset variant additionally uses a boolean `privileged` per tool. In the
canonical model, privileged operations are disallowed, so the field is
effectively always `false`; if adopted canonically, keep it optional and default
`false`.

## 8.3 How the registry is consumed

```
                         launcher-system/tool_registry.json  (ANDRAX_REGISTRY)
                                          │
   ┌────────────────┬─────────────────────┼───────────────────────┬──────────────────┐
   ▼                ▼                     ▼                       ▼                  ▼
list_tools.sh   info <id>        launch_tool.sh            category_dispatch.sh  run_workflow_by_id.sh
(list/filter)   (jq detail)   (id→.script → run)        (categories / --json)  (.workflows[]→run)
                                                                 │
                                                     copied to → android-app asset → ToolRepository.kt
```

* **Resolution:** `launch_tool.sh` finds `.categories[].tools[] | select(.id==$id) | .script`,
  falling back to a case-insensitive `.name` match, then runs
  `$ANDRAX_TOOLS_DIR/<script>`.
* **Browsing:** `category_dispatch.sh --json` emits `.categories` for the app.
* **Workflows:** `run_workflow_by_id.sh` resolves `.workflows[]`.

## 8.4 Adding a tool to the registry

1. Create the script `termux-backend/tools/<category>/<tool>.sh` following the
   [tool-script contract](02-backend-structure.md#the-tool-script-contract).
2. Add an entry under the right `categories[].tools[]` in
   `launcher-system/tool_registry.json` (create the category object if new).
3. If it needs a binary not yet installed, add it to the appropriate
   `termux-backend/setup/install_*.sh`.
4. Sync the app asset (`cp …`, per § 8.1).
5. Regenerate docs: `tools/build_docs.sh` → `docs/TOOLS.md`.
6. Validate: `andrax info <tool>`, `andrax list-tools <category>`,
   `andrax run-tool <tool>` (usage guard should print with no args).

See the [Contribution guide](10-contribution-guide.md) for the full checklist.

## 8.5 Current arsenal (11 categories)

| Category (`id`) | Tools |
|-----------------|-------|
| Information Gathering (`info_gathering`) | `nmap`, `whois`, `dnsenum` |
| Vulnerability Analysis (`vuln_analysis`) | `nikto`, `sqlmap` |
| Web Applications (`web_apps`) | `wpscan`, `dirb` |
| Database Assessment (`database_assessment`) | `dbassess` |
| Password Attacks (`password_attacks`) | `hydra`, `john` |
| Wireless Attacks (`wireless_attacks`) | `wifi_scan` (limited; no monitor mode on stock Android) |
| Reverse Engineering (`reverse_engineering`) | `apkinspect` |
| Exploitation (`exploitation`) | `metasploit`, `msfvenom` |
| Sniffing & Spoofing (`sniffing_spoofing`) | `mitmproxy` |
| Forensics (`forensics`) | `binwalk`, `strings` |
| Reporting (`reporting`) | `generate_report`, `markdown_to_html` |

> `docs/TOOLS.md` is the generated, always-current version of this table, with
> the real curated descriptions (regenerate with `tools/build_docs.sh`).
