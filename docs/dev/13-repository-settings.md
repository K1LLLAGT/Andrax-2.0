# 13. Repository Settings

One-time GitHub configuration a maintainer applies so the committed workflows can
build, sign, and publish. None of this lives in the repo (secrets must not) —
it's set in the repository's **Settings**. This document is the checklist.

## 13.1 Actions secrets for APK signing

`.github/workflows/release.yml` signs the release APK using four repository
secrets. Set them under **Settings → Secrets and variables → Actions →
New repository secret**. Without them, a tagged release still succeeds but
publishes an **unsigned** APK.

| Secret | Value | How to produce it |
|--------|-------|-------------------|
| `ANDRAX_KEYSTORE_B64` | The release keystore, base64-encoded | `base64 -w0 andrax-release.keystore` (Linux) / `base64 andrax-release.keystore \| tr -d '\n'` (macOS) |
| `ANDRAX_KEYSTORE_PASS` | Keystore (store) password | Chosen when the keystore was created |
| `ANDRAX_KEY_ALIAS` | Key alias | `andrax` (see [Signing § 5.2](05-signing-pipeline.md#one-time-create-the-release-keystore)) |
| `ANDRAX_KEY_PASS` | Key password | Chosen when the keystore was created |

> The keystore is created once and kept forever — losing it breaks in-place
> updates for all users. See [Signing § 5.5](05-signing-pipeline.md#55-key-management-rules).
> Never commit the keystore or these values; `.gitignore` already blocks
> `*.keystore`, `*.jks`, and `keystore.properties`.

### Set them via the web UI

1. **Settings → Secrets and variables → Actions**.
2. **New repository secret**, name it exactly as in the table, paste the value,
   **Add secret**. Repeat for all four.
3. Values are write-only afterward — GitHub never shows them again. To rotate,
   overwrite the secret.

### Or via the `gh` CLI

Run from the repo root, with the keystore file present locally:

```sh
gh secret set ANDRAX_KEYSTORE_B64  --body "$(base64 -w0 andrax-release.keystore)"
gh secret set ANDRAX_KEYSTORE_PASS --body 'your-store-password'
gh secret set ANDRAX_KEY_ALIAS     --body 'andrax'
gh secret set ANDRAX_KEY_PASS      --body 'your-key-password'

gh secret list        # confirm all four are present (values are not shown)
```

> Passing secrets as `--body` on the command line can leak them into shell
> history. Prefer `gh secret set NAME` with no `--body` (it prompts and reads
> without echoing), or `gh secret set NAME < file`.

### How the workflow consumes them

`release.yml` decodes `ANDRAX_KEYSTORE_B64` to `$RUNNER_TEMP/release.keystore`
and exposes the other three to Gradle as the environment variables
`ANDRAX_KEYSTORE_FILE`, `ANDRAX_KEYSTORE_PASS`, `ANDRAX_KEY_ALIAS`,
`ANDRAX_KEY_PASS`. `android-app/build.gradle.kts` reads exactly those env vars
(falling back to a local `keystore.properties` for developers). The mapping is
therefore: **secret → workflow env → Gradle signing config**. See
[Signing § 5.4](05-signing-pipeline.md#54-signing-in-ci).

### Optional: source-tarball GPG signing

If you also GPG-sign the source tarball ([Signing § 5.3](05-signing-pipeline.md#53-source-tarball--module-integrity)),
add two more secrets and an import step to the release workflow:

| Secret | Value |
|--------|-------|
| `ANDRAX_GPG_PRIVATE_KEY` | ASCII-armored private key (`gpg --armor --export-secret-keys <id>`) |
| `ANDRAX_GPG_PASSPHRASE` | Its passphrase |

## 13.2 GitHub Pages (for `pages.yml`)

`.github/workflows/pages.yml` renders `docs/` to a site. Enable it once:

1. **Settings → Pages**.
2. Under **Build and deployment → Source**, choose **GitHub Actions**.

That's all — the workflow's `deploy-pages` step publishes to the
`github-pages` environment. After the first successful run, the site URL appears
on the **Settings → Pages** panel and on the workflow's `deploy` job. See
[CI/CD § B.3](04-cicd-pipeline.md#b3-pagesyml--publish-docs).

## 13.3 Branch protection (recommended)

Keep `main` releasable by requiring CI to pass. **Settings → Branches →
Add branch ruleset** (or classic **Branch protection rules**) for `main`:

* **Require a pull request before merging.**
* **Require status checks to pass** → select the `ci.yml` jobs (`shell`, `app`).
* **Require branches to be up to date before merging** (so the drift check
  reflects the merge result).

This enforces the [Release lifecycle](07-release-lifecycle.md) gates
automatically.

## 13.4 Actions permissions

`release.yml` needs to create releases; it already declares
`permissions: contents: write` at the workflow level. Ensure the repository
allows it: **Settings → Actions → General → Workflow permissions** should be
**Read and write permissions** (or at least not restrict the token below what the
workflow requests). Pages deployment uses `pages: write` + `id-token: write`,
declared in `pages.yml`.

## 13.5 Settings checklist

- [ ] Four signing secrets set (`ANDRAX_KEYSTORE_B64`, `ANDRAX_KEYSTORE_PASS`,
      `ANDRAX_KEY_ALIAS`, `ANDRAX_KEY_PASS`).
- [ ] (Optional) GPG secrets for tarball signing.
- [ ] Pages source set to **GitHub Actions**.
- [ ] Branch protection on `main` requiring the `ci` checks.
- [ ] Workflow permissions allow release creation.
