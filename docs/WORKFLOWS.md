# ANDRAX 2.0 — Workflow Catalog
## Exploit Chain (demo) (`exploit_chain_example`)
- Type: shell
- Source: `workflow-engine/workflows/exploit_chain_example.sh`
- Description: Recon → vuln check → Metasploit auxiliary run (scoped demo).
- Example: `andrax run-workflow exploit_chain_example -- <args>`

## Full Network Scan (`network_scan_full`)
- Type: shell
- Source: `workflow-engine/workflows/network_scan_full.sh`
- Description: All-ports scan + service/version + default NSE scripts.
- Example: `andrax run-workflow network_scan_full -- <args>`

## Basic Recon (`recon_basic`)
- Type: shell
- Source: `workflow-engine/workflows/recon_basic.sh`
- Description: whois + DNS enum + nmap service scan + HTTP title for a target.
- Example: `andrax run-workflow recon_basic -- <args>`

## Web App Assessment (`web_app_assessment`)
- Type: shell
- Source: `workflow-engine/workflows/web_app_assessment.sh`
- Description: Content discovery + nikto + sqlmap smoke test against a URL.
- Example: `andrax run-workflow web_app_assessment -- <args>`

## fast-scan (`fast-scan`)
- Type: yaml
- Source: `workflows/recon/fast-scan.yaml`
- Description: YAML workflow.
- Example: `andrax run-workflow fast-scan -- <args>`

