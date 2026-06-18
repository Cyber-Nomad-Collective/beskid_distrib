# macOS Guide — obtaining CI secrets for the Homebrew pipeline

The macOS packaging job (`macos-brew`) renders the formula from
`beskid_distrib/macos/Formula/beskid.rb.tpl` with the rolling version + sha256
of the `aarch64-apple-darwin` asset, then pushes it to the
`Cyber-Nomad-Collective/beskid_homebrew` tap via
`Justintime50/homebrew-releaser@v3`.

## Prerequisites (one-time, manual)

1. **Create the tap repo.** Create an **empty** repo named `beskid_homebrew`
   under `Cyber-Nomad-Collective` (no README/license — homebrew-releaser will
   populate `Formula/beskid.rb`). Homebrew convention: the tap repo must be
   named `homebrew-<something>` to be installable as
   `brew tap <org>/<something>`. We register `beskid_homebrew` and users tap
   it as `cyber-nomad-collective/beskid` (Homebrew strips the `homebrew-`
   prefix from the repo name when matching the tap).

2. **Verify install path.** After the first publish, users run:
   ```sh
   brew tap cyber-nomad-collective/beskid
   brew install beskid
   beskid --version
   ```

## Secrets required

| Secret | Purpose |
|---|---|
| `DISTRIB_GH_PAT` | Read the `aarch64-apple-darwin` asset (sha256) from `beskid_compiler`'s `cli-latest` release. (Shared with Windows/Ubuntu — set once.) |
| `HOMEBREW_TAP_GIT_TOKEN` | PAT that homebrew-releaser uses to commit + push `Formula/beskid.rb` to `beskid_homebrew`. The default `GITHUB_TOKEN` cannot cross-push to another repo, so a dedicated PAT is mandatory. |

## Obtaining `HOMEBREW_TAP_GIT_TOKEN`

1. Open https://github.com/settings/personal-access-tokens/new (**fine-grained
   PAT**, preferred) or https://github.com/settings/tokens/new (classic).
2. **Fine-grained (recommended):**
   - **Resource owner:** `Cyber-Nomad-Collective`.
   - **Repository access:** Only select repositories → `beskid_homebrew`.
   - **Permissions:** Repository permissions → **Contents: Read and write**.
   - **Expiration:** 365 days.
3. **Classic (alternative):** select `repo` scope (full).
4. Copy the token (`github_pat_...` or `ghp_...`).
5. Add to the **superrepo** (`Cyber-Nomad-Collective/beskid`):
   - **Settings → Secrets and variables → Actions → New repository secret.**
   - Name: `HOMEBREW_TAP_GIT_TOKEN`.

## Apple Silicon only (v1)

The compiler workflow builds only `aarch64-apple-darwin`. The formula
declares `on_intel { depends_on arch: :arm }` so `brew install beskid` on an
Intel Mac fails with a clear arch-mismatch message rather than a binary crash.
Adding Intel later requires extending `compiler.yml`'s build matrix with
`x86_64-apple-darwin`, fetching that asset, and adding a second
`on_intel do ... end` block pointing at the Intel URL + sha256.

## No notarization (v1)

The CLI binary is shipped as a bare Mach-O fetched from the GitHub release, not
inside a `.app` bundle or `.pkg`, so macOS Gatekeeper does **not** block it
(Gatekeeper only quarantines apps with a `com.apple.quarantine` extended
attribute that browsers attach to downloaded bundles; Homebrew does not set
quarantine on installed binaries). When a Developer ID is obtained later,
add a notarization step that submits the darwin-arm64 asset to Apple's
notarytool and staples a ticket.
