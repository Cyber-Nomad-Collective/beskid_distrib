# Distribution Pipeline Secrets

All secrets are configured on the **superrepo**
(`Cyber-Nomad-Collective/beskid`) under **Settings → Secrets and variables →
Actions**. Per-platform setup instructions live in `docs/<Platform>_Guide.md`.

| Secret | Required by | Scope / Notes |
|---|---|---|
| `DISTRIB_GH_PAT` | all platform jobs | Classic PAT, `repo` scope. Used to download `cli-latest`/`lsp-latest` assets from `beskid_compiler` and upload `.msi`/`.deb` back to those releases. If `beskid_compiler` is private, this PAT must have access to `Cyber-Nomad-Collective`. |
| `HOMEBREW_TAP_GIT_TOKEN` | `macos-brew` | Classic PAT, `repo` scope on `Cyber-Nomad-Collective/beskid_homebrew`. Cross-repo formula push; the default `GITHUB_TOKEN` cannot do this. Optional — if absent the `macos-brew` job is skipped. |
| `SNAPCRAFT_STORE_CREDENTIALS` | `linux-snap` | Snap Store login credentials. Generate via `snapcraft export-login` (or the Snap Store dashboard). The legacy `SNAPCRAFT_TOKEN` is deprecated. Optional — if absent the `linux-snap` job is skipped. |

## Minimum viable set

Only `DISTRIB_GH_PAT` is required. `HOMEBREW_TAP_GIT_TOKEN` and
`SNAPCRAFT_STORE_CREDENTIALS` are optional — the corresponding platform jobs
(`macos-brew`, `linux-snap`) are skipped with a warning if their secret is
absent, allowing the remaining platform jobs to proceed.

## Rotation

- PATs (`DISTRIB_GH_PAT`, `HOMEBREW_TAP_GIT_TOKEN`): rotate before GitHub's
  365-day expiry. Prefer fine-grained PATs scoped to the single required repo
  where possible.
- `SNAPCRAFT_STORE_CREDENTIALS`: re-export via `snapcraft export-login` and
  update the secret.
