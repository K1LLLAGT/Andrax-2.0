# 12. Release Instructions

The concrete, copy-pasteable procedure for cutting an ANDRAX 2.0 release. It
implements the [Release lifecycle](07-release-lifecycle.md) and depends on the
[Versioning](06-versioning-system.md) and [Signing](05-signing-pipeline.md)
rules. Read those first.

> **Current state:** releases are **manual** (no CI yet). Follow § A below. Once
> the recommended `release.yml` is in place, § B reduces the whole thing to
> pushing a tag.

## Pre-release gate

Confirm the tree is releasable before you touch version numbers:

```sh
git checkout main && git pull

# 1. Lint & audit
find . -name '*.sh' -not -path './.git/*' -print0 | xargs -0 shellcheck -S warning
bash tools/backend_consistency_auditor.sh
bash tools/broken_script_locator.sh
bash tools/privileged_tool_detector.sh      # expect: none

# 2. Regenerate artifacts and confirm no drift
bash tools/build_registry.sh
bash tools/build_workflow_registry.sh
bash tools/build_docs.sh
cp launcher-system/tool_registry.json android-app/src/main/assets/tool_registry.json
git diff --exit-code || { echo "Commit regenerated artifacts first."; exit 1; }

# 3. Integration test
bash tools/test_pipeline.sh
```

## A. Manual release

### A.1 Bump the version

Pick the new `X.Y.Z` per [Versioning § 6.2](06-versioning-system.md#62-the-scheme).
Update **every** location in one commit (a `tools/bump_version.sh` should own
this — see [Versioning § 6.4](06-versioning-system.md#64-bumping-a-version-the-rule)):

```sh
# if you added tools/bump_version.sh:
bash tools/bump_version.sh 2.1.0

# otherwise, by hand:
echo "2.1" > VERSION
jq '.version="2.1.0" | .generated="'"$(date +%F)"'"' \
   launcher-system/tool_registry.json > reg.tmp && mv reg.tmp launcher-system/tool_registry.json
# android-app/build.gradle.kts: versionName="2.1.0", versionCode=20100
# magisk-module/andrax-bridge/module.prop: only if it changed
```

Regenerate artifacts again (the registry stamp + docs changed):

```sh
bash tools/build_registry.sh
bash tools/build_workflow_registry.sh
bash tools/build_docs.sh
cp launcher-system/tool_registry.json android-app/src/main/assets/tool_registry.json
```

### A.2 Write release notes

Summarize highlights + a full changelog since the previous tag:

```sh
git log --pretty='* %s' "$(git describe --tags --abbrev=0)"..HEAD > /tmp/changelog.md
```

### A.3 Commit, verify consistency, tag

```sh
git add -A
git commit -m "Release 2.1.0"

# consistency assertions (also done by CI)
test "$(jq -r .version launcher-system/tool_registry.json)" = "2.1.0"
test "$(cat VERSION)" = "2.1"

git tag -a v2.1.0 -m "ANDRAX 2.0 — v2.1.0"
git push origin main
git push origin v2.1.0
```

### A.4 Build the artifacts

**Source tarball** (what `INSTALL.md` extracts):

```sh
git archive --format=tar.gz --prefix=ANDRAX-2.0/ -o ANDRAX-2.0.tar.gz v2.1.0
sha256sum ANDRAX-2.0.tar.gz > ANDRAX-2.0.tar.gz.sha256
gpg --armor --detach-sign ANDRAX-2.0.tar.gz         # → ANDRAX-2.0.tar.gz.asc
```

**Signed release APK** (needs the keystore + Gradle signing config —
[Signing § 5.2](05-signing-pipeline.md#52-apk-signing-model)):

```sh
cd android-app
./gradlew assembleRelease
apksigner verify --print-certs build/outputs/apk/release/app-release.apk
sha256sum build/outputs/apk/release/app-release.apk > app-release.apk.sha256
cd ..
```

**Magisk module** (optional, only if it changed):

```sh
( cd magisk-module && zip -r ../andrax-bridge.zip andrax-bridge )
sha256sum andrax-bridge.zip > andrax-bridge.zip.sha256
```

### A.5 Verify before publishing

```sh
sha256sum -c ANDRAX-2.0.tar.gz.sha256
gpg --verify ANDRAX-2.0.tar.gz.asc ANDRAX-2.0.tar.gz
apksigner verify --print-certs android-app/build/outputs/apk/release/app-release.apk
# Confirm the APK signing cert SHA-256 matches your published release cert.
```

### A.6 Publish the GitHub Release

Create a release for tag `v2.1.0` and attach:

* `ANDRAX-2.0.tar.gz` + `.sha256` + `.asc`
* `app-release.apk` + `.sha256`
* `andrax-bridge.zip` + `.sha256` (if built)
* the release notes from A.2

If the GitHub CLI is available:

```sh
gh release create v2.1.0 \
  --title "ANDRAX 2.0 — v2.1.0" \
  --notes-file /tmp/changelog.md \
  ANDRAX-2.0.tar.gz ANDRAX-2.0.tar.gz.sha256 ANDRAX-2.0.tar.gz.asc \
  android-app/build/outputs/apk/release/app-release.apk app-release.apk.sha256
```

### A.7 Post-release

* Confirm the assets download and verify from a clean machine.
* Announce, updating any install docs that pin a version.
* If this was a hotfix, ensure the fix is also on `main`
  ([Release lifecycle § 7.5](07-release-lifecycle.md#75-hotfix-flow)).

## B. Automated release (once CI exists)

With the recommended `release.yml`
([CI/CD § B.2](04-cicd-pipeline.md#b2-releaseyml--build--publish-on-a-tag)) and
the signing secrets configured
([Signing § 5.4](05-signing-pipeline.md#54-signing-in-ci)), the entire release is:

```sh
# after the version-bump commit is on main:
git tag -a v2.1.0 -m "ANDRAX 2.0 — v2.1.0"
git push origin v2.1.0
```

CI then builds the tarball, builds + signs the APK, and publishes the GitHub
Release with checksums. You only need to do the post-release verification (A.5)
and announcement (A.7).

## Release checklist

- [ ] Pre-release gate green (lint, audits, no drift, `test_pipeline.sh`).
- [ ] Version bumped in **all** locations; `VERSION`/registry/tag agree.
- [ ] Registries + docs regenerated and committed.
- [ ] Release notes written.
- [ ] Annotated tag `vX.Y.Z` pushed.
- [ ] Source tarball built, checksummed, GPG-signed.
- [ ] Release APK built and **signed**; signature verified.
- [ ] Checksums/signatures verified from a clean environment.
- [ ] GitHub Release created with all artifacts + notes.
- [ ] Hotfix (if any) also merged to `main`.
