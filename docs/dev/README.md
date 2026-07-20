# ANDRAX 2.0 — Developer Documentation

This directory is the developer-facing documentation set for ANDRAX 2.0. It
describes how the project is put together, how the pieces talk to each other,
and how to build, extend, and release it. End-user / operator docs live in the
repository root (`README.md`, `INSTALL.md`) and in `docs/TOOLS.md` /
`docs/WORKFLOWS.md` (both auto-generated — see the registry docs below).

> **Authorized-use only.** ANDRAX 2.0 orchestrates dual-use offensive-security
> tools. Everything in this documentation assumes you are building/testing
> against systems you own or are explicitly authorized to test. See
> [`../../LICENSE.md`](../../LICENSE.md).

## Contents

| # | Document | What it covers |
|---|----------|----------------|
| 1 | [Architecture overview](01-architecture-overview.md) | The five layers, data flow, execution paths, design principles |
| 2 | [Backend structure](02-backend-structure.md) | `termux-backend/`, `launcher-system/`, `scripting-engine/`, `workflow-engine/`, `bin/`, the shared libraries |
| 3 | [Android app structure](03-android-app-structure.md) | Kotlin skeleton, activities, `ToolRepository`, `TermuxLauncher`, the RUN_COMMAND bridge |
| 4 | [CI/CD pipeline](04-cicd-pipeline.md) | Current (local) build pipeline, and a recommended GitHub Actions design |
| 5 | [Signing pipeline](05-signing-pipeline.md) | APK signing model, keystore handling, recommended release-signing flow |
| 6 | [Versioning system](06-versioning-system.md) | Where versions live (`VERSION`, registry, Gradle), the scheme, how to bump |
| 7 | [Release lifecycle](07-release-lifecycle.md) | Branching, stages, gates, artifacts, from commit to tagged release |
| 8 | [Tool registry](08-tool-registry.md) | `tool_registry.json` schema, canonical vs. generated copies, sync rules |
| 9 | [Workflow registry](09-workflow-registry.md) | Shell vs. YAML workflows, `workflow_registry.json`, the runner |
| 10 | [Contribution guide](10-contribution-guide.md) | How to add tools/workflows, coding conventions, the audit tooling, PR checklist |
| 11 | [Build instructions](11-build-instructions.md) | Building the backend, the registries, the docs, and the APK |
| 12 | [Release instructions](12-release-instructions.md) | Step-by-step cutting a release + tarball + APK |

## The 30-second model

ANDRAX 2.0 is a **user-space** penetration-testing workbench for non-rooted
modern Android. It has five cooperating layers:

```
Android app  ──RUN_COMMAND intent──►  scripting-engine (engine.sh)
(thin UI)                                     │
                                              ├─► launcher-system  (registry lookup → tool script)
                                              ├─► workflow-engine   (chained shell/YAML workflows)
                                              └─► termux-backend    (one launcher script per tool)
```

The **tool registry** (`launcher-system/tool_registry.json`) is the single
source of truth that both the CLI and the app read, so tool ids and script
paths never drift.

## Reading order for new contributors

1. [Architecture overview](01-architecture-overview.md) — the mental model.
2. [Backend structure](02-backend-structure.md) — where the real work happens.
3. [Tool registry](08-tool-registry.md) + [Workflow registry](09-workflow-registry.md) — the data contracts.
4. [Contribution guide](10-contribution-guide.md) — how to add your own.
5. [Build](11-build-instructions.md) / [Release](12-release-instructions.md) — shipping it.

## A note on current state vs. recommendations

This project is at an early, skeleton stage. Some subsystems the documentation
below describes — a CI system, an APK signing pipeline, a formal release
process — **do not yet exist as automation in the repository.** Where that is
the case, the document says so explicitly and clearly separates:

* **Current state** — what the repo actually does today, and
* **Recommended** — a concrete, ready-to-adopt design you can drop in.

See [Known gaps](01-architecture-overview.md#known-gaps--inconsistencies) for a
consolidated list of the rough edges a contributor should be aware of.
