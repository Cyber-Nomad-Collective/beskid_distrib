# Distribution Pipeline Secrets

The superrepo's Woodpecker pipelines (`.woodpecker/release.yml` and
`scripts/ci/`) prepare release evidence without publication credentials.
The retired `compiler_release_token`, `DISTRIB_GH_PAT`, and
`HOMEBREW_TAP_GIT_TOKEN` secrets are not used by that pipeline and should
not be configured for it.

After review, a separate manual publisher invokes the superrepo's
`scripts/ci/woodpecker-release.sh` from a clean local `main` checkout with
`BESKID_MANUAL_PUBLISH=1`, `BESKID_PUBLISH_RELEASE=1`, and a temporary
`GH_TOKEN`. That token needs release write access on `beskid_compiler` and
contents write access on `beskid_homebrew`; keep it outside Woodpecker.

Other Woodpecker secrets (`open_vsx_token`, `pckg_release_publisher_key`,
`registry_username`, `registry_password`) belong to the editor, package
registry, and platform-image pipelines, not to distribution.

## Not configured

- No code-signing or notarization secrets exist. The MSI, the setup `.exe`, and
  the DMG are unsigned, and Homebrew does not require signing.
- No apt repository or GPG key exists. The `.deb` is a release asset only.

## Rotation

Rotate the manual publishing token before expiry. Prefer a fine-grained token
scoped to the two repositories above; do not store it in Woodpecker.
