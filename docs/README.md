# ANDRAX 2.0 — Documentation

A user-space, ANDRAX-style penetration-testing workbench for modern non-rooted
Android, built on **Termux** + **proot-distro**. This is the documentation site;
the project itself lives one level up.

> **Authorized-use only.** ANDRAX 2.0 orchestrates dual-use offensive-security
> tools. Use it only against systems you own or are explicitly authorized to
> test. See the project `LICENSE.md`.

## Catalogs (auto-generated)

- [Tool catalog](TOOLS.md) — every tool in the arsenal, by category.
- [Workflow catalog](WORKFLOWS.md) — the chained shell/YAML workflows.

Both are regenerated from the registries by `tools/build_docs.sh`.

## Developer documentation

The full developer documentation set lives in [`dev/`](dev/) — architecture,
backend and app internals, CI/CD, signing, versioning, the release lifecycle,
the tool/workflow registries, and the contribution/build/release guides.

Start with:

- [Architecture overview](dev/01-architecture-overview.md)
- [Backend structure](dev/02-backend-structure.md)
- [Contribution guide](dev/10-contribution-guide.md)
- [Build instructions](dev/11-build-instructions.md)
- [Repository settings](dev/13-repository-settings.md)
