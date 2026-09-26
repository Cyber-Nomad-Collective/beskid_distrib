# Distribution Pipeline Secrets

Distribution runs in the superrepo's Woodpecker pipelines
(`.woodpecker/release.yml` and `scripts/ci/`). The GitHub Actions secrets that
earlier versions of this file described (`DISTRIB_GH_PAT`,
`HOMEBREW_TAP_GIT_TOKEN`) are not used by any pipeline and should not be
created.

| Woodpecker secret | Exposed as | Used for |
|---|---|---|
| `compiler_release_token` | `GH_TOKEN` | Everything the release job does against GitHub: downloading the verified `v<version>` bundle, uploading the `.msi`, `.exe`, `.dmg`, `.deb`, and `beskid.rb` assets to `cli-v<version>` and the rolling `cli-stable` / `cli-unstable` releases on `beskid_compiler`, and committing `Formula/beskid.rb` to `Cyber-Nomad-Collective/beskid_homebrew` for stable `X.Y.Z` releases. |

The token therefore needs release write access on `beskid_compiler` and
contents write access on `beskid_homebrew`. A fine-grained token limited to
those two repositories is enough.

Other Woodpecker secrets (`open_vsx_token`, `pckg_release_publisher_key`,
`registry_username`, `registry_password`) belong to the editor, package
registry, and platform-image pipelines, not to distribution.

## Not configured

- No code-signing or notarization secrets exist. The MSI, the setup `.exe`, and
  the DMG are unsigned, and Homebrew does not require signing.
- No apt repository or GPG key exists. The `.deb` is a release asset only.

## Rotation

Rotate `compiler_release_token` before its expiry and update it in the
Woodpecker repository settings. Prefer a fine-grained token scoped to the two
repositories above.
