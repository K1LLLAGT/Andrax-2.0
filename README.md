# ANDRAX 2.0

A user-space, ANDRAX-style penetration-testing workbench for modern Android (e.g. Samsung tablets) built entirely on **Termux** + **proot-distro**.

ANDRAX 2.0 is a reimagining of the original ANDRAX concept for devices where kernel-level tricks (chroot from init, loop mounts, raw packet injection, SELinux bypass) are **not available**. Instead of fighting the modern Android security model, ANDRAX 2.0 lives entirely in user space:

* **Termux** provides the base runtime (packages, Python, Go, Rust, git).
* **proot-distro** provides an optional Kali/Debian/Arch userland for tools that are not packaged for Termux.
* A **launcher system**, **workflow engine**, and **scripting engine** glue the tools together and expose them to both the CLI and a companion Android app.

> ⚠️ **Authorized use only.** ANDRAX 2.0 bundles standard, publicly available security tools (nmap, sqlmap, hydra, nikto, the Metasploit Framework, etc.). Use it **only** against systems you own or are explicitly authorized to test. You are responsible for complying with all applicable laws. See `LICENSE.md`.

---

## Layers

1. **Android app (`android-app/`)** — an ANDRAX-style category/tool browser that launches Termux scripts. It performs **no** privileged operations; it is a thin front-end that dispatches to the Termux backend.
2. **Termux backend (`termux-backend/`)** — install scripts, environment config, and one launcher script per tool. Every tool script validates its environment, prints usage when called with no args, logs to a central directory, and returns proper exit codes.
3. **Launcher + workflow + scripting engines** — `launcher-system/`, `workflow-engine/`, and `scripting-engine/` provide the ANDRAX-style registry, category dispatch, chained workflows, and a single entrypoint.

---

## Architecture Overview

ANDRAX 2.0 operates as a **five-layer system**:

```
┌─────────────────────────────────────────────────────┐
│ Layer 1: Android App (Kotlin UI)                    │
│ ├─ Tool browser, category navigation                │
│ └─ Dispatches to Termux backend via RUN_COMMAND    │
└────────────────┬────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────┐
│ Layer 2: Scripting Engine (engine.sh)              │
│ ├─ Single entrypoint: `andrax` command             │
│ ├─ Commands: run-tool, run-workflow, list-*, info  │
│ └─ Validates environment & dispatches              │
└────────────────┬────────────────────────────────────┘
                 │
       ┌─────────┴─────────────┬──────────────────┐
       ▼                       ▼                  ▼
   ┌─────────────────┐  ┌──────────────────┐  ┌─────────────┐
   │ Launcher System │  │ Workflow Engine  │  │ Environment │
   │ ├─ Registry     │  │ ├─ Shell/YAML    │  │ ├─ env.sh   │
   │ ├─ Dispatch     │  │ ├─ Chaining      │  │ ├─ paths.sh │
   │ └─ launch_tool  │  │ └─ Execution     │  │ └─ Log dirs │
   └────────┬────────┘  └────────┬─────────┘  └─────────────┘
            │                    │
            └────────┬───────────┘
                     ▼
┌─────────────────────────────────────────────────────┐
│ Layer 4: Termux Backend                             │
│ ├─ Setup scripts (packages, tools, Kali)           │
│ ├─ Config (env vars, paths, log dirs)              │
│ └─ Per-tool launcher scripts                       │
└────────────────┬────────────────────────────────────┘
                 ▼
┌─────────────────────────────────────────────────────┐
│ Layer 5: Underlying Tools & Runtimes                │
│ ├─ nmap, sqlmap, hydra, nikto, MSF, etc.           │
│ ├─ Python, Go, Rust, git, curl                     │
│ └─ proot-distro (optional Kali userland)           │
└─────────────────────────────────────────────────────┘
```

### Data Flow

1. **User input** → CLI (`andrax <cmd>`) or Android app
2. **Scripting engine** reads `tool_registry.json`, resolves metadata
3. **Launcher** maps tool ID to script path
4. **Environment** is validated (paths, dependencies)
5. **Tool script** executes, logs to `~/.andrax/logs/`, captures to `~/.andrax/loot/`
6. **Exit code** returned; output displayed or sent to app

---

## Repository Layout

```
ANDRAX-2.0/
├── README.md                    # this file
├── INSTALL.md                   # full installation & build guide
├── LICENSE.md                   # legal notice & authorized-use agreement
├── VERSION                      # version identifier (2.0)
├── ANDRAX-2.0-DIRECTORY-TREE.txt # reference directory tree
│
├── android-app/                 # Android UI front-end (Kotlin/Gradle)
│   ├── build.gradle.kts         # Gradle config (API 26–34)
│   ├── src/                     # Kotlin source & resources
│   ├── src/main/assets/         # tool_registry.json copy (synced)
│   ├── keystore.properties.example
│   ├── build-notes.md
│   └── gradlew
│
├── launcher-system/             # Tool registry & dispatcher
│   ├── tool_registry.json       # canonical tool + category definitions
│   ├── launch_tool.sh           # tool ID → script path → execution
│   ├── category_dispatch.sh     # category browser
│   └── README.md
│
├── scripting-engine/            # Single entrypoint (engine.sh)
│   ├── engine.sh                # `andrax` command dispatcher
│   ├── scripts/
│   │   ├── run_tool_by_id.sh
│   │   ├── run_workflow_by_id.sh
│   │   ├── list_tools.sh
│   │   ├── list_workflows.sh
│   │   └── ...
│   └── README.md
│
├── termux-backend/              # Install scripts, env config, wrappers
│   ├── setup/
│   │   ├── install_termux_packages.sh
│   │   ├── install_python_tools.sh
│   │   ├── install_go_tools.sh (optional)
│   │   ├── install_rust_tools.sh (optional)
│   │   ├── setup_proot_kali.sh
│   │   └── README.md
│   ├── config/
│   │   ├── env.sh              # ANDRAX_HOME, ANDRAX_LOG_DIR, etc.
│   │   ├── paths.sh
│   │   └── README.md
│   ├── tools/
│   └── README.md
│
├── workflow-engine/             # Shell & YAML workflow orchestration
│   ├── workflows/
│   │   ├── recon/
│   │   ├── exploitation/
│   │   ├── post/
│   │   └── custom/
│   ├── libs/
│   │   ├── workflow_runner.sh
│   │   ├── common.sh
│   │   └── ...
│   ├── workflow_registry.json
│   └── README.md
│
├── bin/                         # Low-level wrappers & adapters
│   ├── andrax-tool-wrapper.sh
│   ├── andrax-workflow-run.sh
│   ├── adapters/
│   │   ├── adapter-termux.sh
│   │   └── adapter-magisk.sh
│   └── README.md
│
├── docs/                        # User & developer documentation
│   ├── README.md
│   ├── TOOLS.md                 # Auto-generated tool catalog
│   ├── WORKFLOWS.md             # Auto-generated workflow catalog
│   └── dev/                     # Developer documentation
│       ├── 01-architecture-overview.md
│       ├── 02-backend-structure.md
│       ├── 03-android-app-structure.md
│       ├── 04-cicd-pipeline.md
│       ├── 05-signing-pipeline.md
│       ├── 06-versioning-system.md
│       ├── 07-release-lifecycle.md
│       ├── 08-tool-registry.md
│       ├── 09-workflow-registry.md
│       ├── 10-contribution-guide.md
│       ├── 11-build-instructions.md
│       ├── 12-release-instructions.md
│       ├── 13-repository-settings.md
│       └── README.md
│
├── tools/                       # Build & automation utilities
│   ├── build_docs.sh
│   ├── audit.sh
│   └── ...
│
├── .github/
│   └── workflows/
│       ├── ci.yml
│       ├── release.yml
│       └── pages.yml
│
├── magisk-module/               # (Optional) Magisk module wrapper
├── workflows/                   # Runtime workflows (populated at runtime)
└── .gitignore
```

---

## Quick Start

### 1. Extract & Setup Permissions

```sh
cd ~
tar -xzf ANDRAX-2.0.tar.gz
cd ANDRAX-2.0

# Make scripts executable
find . -name '*.sh' -exec chmod +x {} \;
chmod +x scripting-engine/engine.sh launcher-system/*.sh
```

### 2. Install the Backend

```sh
# Core packages & tools (required)
bash termux-backend/setup/install_termux_packages.sh

# Python-based tools
bash termux-backend/setup/install_python_tools.sh

# Optional: Go tools
bash termux-backend/setup/install_go_tools.sh

# Optional: Rust tools
bash termux-backend/setup/install_rust_tools.sh

# Optional: proot Kali userland (for tools not in Termux)
bash termux-backend/setup/setup_proot_kali.sh
```

### 3. Load the Environment

```sh
source termux-backend/config/env.sh

# Add to shell profile for auto-load
echo "source ~/ANDRAX-2.0/termux-backend/config/env.sh" >> ~/.bashrc
```

This exports:
- `ANDRAX_HOME` — installation root
- `ANDRAX_LOG_DIR` — log directory (`~/.andrax/logs/`)
- `ANDRAX_LOOT_DIR` — loot directory (`~/.andrax/loot/`)
- `ANDRAX_REGISTRY` — tool registry JSON path
- Adds `andrax` to `PATH`

### 4. Verify Installation

```sh
andrax doctor            # environment self-check
andrax list-tools
andrax list-tools recon  # filter by category
andrax list-workflows
andrax info nmap         # show tool details
```

### 5. Run Your First Tool

```sh
# Syntax: andrax run-tool <tool-id> -- <tool-args...>

andrax run-tool nmap -- -sV scanme.nmap.org
andrax run-tool whois -- google.com
andrax run-tool sqlmap -- --help
```

Logs: `~/.andrax/logs/`  
Loot: `~/.andrax/loot/`

---

## Running Workflows

```sh
# List available workflows
andrax list-workflows

# Run a workflow with arguments
andrax run-workflow recon_basic -- example.com
andrax run-workflow web_scan -- 192.168.1.100

# See docs/WORKFLOWS.md for full catalog
```

---

## Building the Android App

The Kotlin app under `android-app/` is a complete Gradle project (targets API 26–34) that dispatches to the Termux backend via `RUN_COMMAND`.

**Prerequisites:** Android Studio (Giraffe+), JDK 11+

**Build:**
```sh
cd android-app/
./gradlew build           # debug APK
./gradlew bundleRelease   # release APK (requires signing)
```

**Deploy:**
1. Copy `launcher-system/tool_registry.json` to `android-app/src/main/assets/`
2. Open in Android Studio → Sync → Build & Run

See `INSTALL.md` and `docs/dev/03-android-app-structure.md` for full details.

---

## Capabilities & Limitations

ANDRAX 2.0 works **without root**, but some capabilities are reduced:

| Capability | Non-root Behavior |
|:-----------|:------------------|
| TCP/UDP scanning (nmap) | ✅ Works (connect scans) |
| SYN / raw-socket scans | ❌ Needs root; falls back to `-sT` |
| Wi-Fi monitor mode / injection | ❌ Not possible on stock Android |
| Wi-Fi scanning / info | ✅ Via `termux-wifi-scaninfo` |
| HTTP(S) MITM proxy | ✅ Works (as user-configured proxy) |
| ARP spoofing / ettercap | ❌ Needs raw sockets |
| Metasploit Framework | ✅ Runs; some modules need proot Kali |

---

## Useful Commands

```sh
andrax help              # show help
andrax doctor            # environment check
andrax categories        # browse categories
andrax info nmap         # show tool details
andrax list-tools | jq . # list all tools (JSON)
andrax run-tool hydra -- -h  # run tool with args
andrax run-workflow recon_basic -- example.com
tail -f ~/.andrax/logs/*.log  # view logs
ls -la ~/.andrax/loot/   # view captured loot
```

---

## Development & Contribution

See `docs/dev/` for comprehensive developer documentation:

- **[Architecture Overview](docs/dev/01-architecture-overview.md)** — design principles, layers, data flow
- **[Tool Registry](docs/dev/08-tool-registry.md)** — how to add new tools
- **[Workflow Registry](docs/dev/09-workflow-registry.md)** — how to create workflows
- **[Contribution Guide](docs/dev/10-contribution-guide.md)** — coding conventions, PR checklist
- **[Build Instructions](docs/dev/11-build-instructions.md)** — building docs, APK, registries

**Quick add-a-tool:**
1. Edit `launcher-system/tool_registry.json`
2. Place script in `termux-backend/tools/` or reference installed tool
3. Run `tools/build_docs.sh`
4. Test: `andrax run-tool <new-id> -- <args>`

---

## Uninstall & Cleanup

```sh
rm -rf ~/.andrax          # logs & loot
rm -rf ~/ANDRAX-2.0       # toolkit
proot-distro remove kali  # (optional) proot userland
```

---

## Legal & Support

- **License:** See `LICENSE.md` — authorized testing only
- **Documentation:** Full docs in `docs/` and `INSTALL.md`
- **Issues & Contributions:** See GitHub repository

---

## Version

Current: **2.0**

See `VERSION` file and `docs/dev/06-versioning-system.md` for details.

---

## References

- [Installation & Build Guide](INSTALL.md)
- [Legal Notice](LICENSE.md)
- [Developer Documentation](docs/dev/README.md)
- [Tool Catalog](docs/TOOLS.md) (auto-generated)
- [Workflow Catalog](docs/WORKFLOWS.md) (auto-generated)
