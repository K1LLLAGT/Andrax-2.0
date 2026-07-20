# ANDRAX 2.0 — Tool Catalog
## Information Gathering (info_gathering)
- **Nmap** (`nmap`)
  - Script: `info_gathering/nmap.sh`
  - Description: Network host, port and service discovery.
  - Example: `run-tool nmap -- -sV scanme.nmap.org`
  - Privileged: no
- **Whois** (`whois`)
  - Script: `info_gathering/whois.sh`
  - Description: Domain / IP registration lookup.
  - Example: `run-tool whois -- example.com`
  - Privileged: no
- **DNS Enumeration** (`dnsenum`)
  - Script: `info_gathering/dnsenum.sh`
  - Description: DNS records + passive subdomain enumeration.
  - Example: `run-tool dnsenum -- example.com`
  - Privileged: no
## Vulnerability Analysis (vuln_analysis)
- **Nikto** (`nikto`)
  - Script: `vuln_analysis/nikto.sh`
  - Description: Web server misconfiguration & known-vuln scanner.
  - Example: `run-tool nikto -- -h http://target.example`
  - Privileged: no
- **sqlmap** (`sqlmap`)
  - Script: `vuln_analysis/sqlmap.sh`
  - Description: Automatic SQL injection detection & exploitation.
  - Example: `run-tool sqlmap -- -u "http://target/item?id=1" --batch --dbs`
  - Privileged: no
## Web Applications (web_apps)
- **WPScan** (`wpscan`)
  - Script: `web_apps/wpscan.sh`
  - Description: WordPress vulnerability / user enumeration.
  - Example: `run-tool wpscan -- --url https://blog.example --enumerate vp,u`
  - Privileged: no
- **Content Discovery** (`dirb`)
  - Script: `web_apps/dirb.sh`
  - Description: Directory/file brute-forcing (ffuf/gobuster/dirsearch).
  - Example: `run-tool dirb -- http://target/`
  - Privileged: no
## Database Assessment (database_assessment)
- **DB Assessment** (`dbassess`)
  - Script: `database_assessment/dbassess.sh`
  - Description: Discover & fingerprint database services (nmap NSE).
  - Example: `run-tool dbassess -- 10.0.0.20`
  - Privileged: no
## Password Attacks (password_attacks)
- **Hydra** (`hydra`)
  - Script: `password_attacks/hydra.sh`
  - Description: Online login brute-forcing across many protocols.
  - Example: `run-tool hydra -- -l admin -P wl.txt ssh://10.0.0.5`
  - Privileged: no
- **John the Ripper** (`john`)
  - Script: `password_attacks/john.sh`
  - Description: Offline password hash cracking.
  - Example: `run-tool john -- hashes.txt --wordlist=rockyou.txt`
  - Privileged: no
## Wireless Attacks (limited) (wireless_attacks)
- **Wi-Fi Recon** (`wifi_scan`)
  - Script: `wireless_attacks/wifi_scan.sh`
  - Description: AP enumeration (Termux:API) + offline WPA crack. No monitor mode on stock Android.
  - Example: `run-tool wifi_scan -- scan`
  - Privileged: no
## Reverse Engineering (reverse_engineering)
- **APK Inspector** (`apkinspect`)
  - Script: `reverse_engineering/apkinspect.sh`
  - Description: Static triage of an APK: manifest, strings, secrets.
  - Example: `run-tool apkinspect -- target.apk`
  - Privileged: no
## Exploitation Tools (exploitation)
- **Metasploit** (`metasploit`)
  - Script: `exploitation/metasploit.sh`
  - Description: Exploitation framework (msfconsole).
  - Example: `run-tool metasploit -- -x "version; exit"`
  - Privileged: no
- **msfvenom** (`msfvenom`)
  - Script: `exploitation/msfvenom.sh`
  - Description: Payload generator.
  - Example: `run-tool msfvenom -- -l payloads`
  - Privileged: no
## Sniffing & Spoofing (sniffing_spoofing)
- **mitmproxy** (`mitmproxy`)
  - Script: `sniffing_spoofing/mitmproxy.sh`
  - Description: Application-layer intercepting proxy (ettercap replacement).
  - Example: `run-tool mitmproxy -- web`
  - Privileged: no
## Forensics (forensics)
- **binwalk** (`binwalk`)
  - Script: `forensics/binwalk.sh`
  - Description: Firmware / binary carving and extraction.
  - Example: `run-tool binwalk -- -e firmware.bin`
  - Privileged: no
- **strings** (`strings`)
  - Script: `forensics/strings.sh`
  - Description: Printable-string extraction + artifact highlighting.
  - Example: `run-tool strings -- suspicious.bin 8`
  - Privileged: no
## Reporting Tools (reporting)
- **Generate Report** (`generate_report`)
  - Script: `reporting/generate_report.sh`
  - Description: Assemble logs + loot into a Markdown report.
  - Example: `run-tool generate_report -- "Acme external test"`
  - Privileged: no
- **Markdown → HTML** (`markdown_to_html`)
  - Script: `reporting/markdown_to_html.sh`
  - Description: Render a Markdown report to standalone HTML.
  - Example: `run-tool markdown_to_html -- report.md`
  - Privileged: no
