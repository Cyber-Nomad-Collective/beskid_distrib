# Windows Guide — obtaining CI secrets for the MSI and EXE pipeline

The Windows packaging job (`windows-msi` in the superrepo's `distribute.yml`)
builds an MSI with WiX v4, wraps it in a WiX Burn EXE bootstrapper, and uploads
both to the `cli-latest` / `cli-v<version>` release on `beskid_compiler`. It
needs **one** secret.

## Secret required

| Secret | Purpose |
|---|---|
| `DISTRIB_GH_PAT` | Download immutable `cli-v<version>` / `lsp-v<version>` binaries from `beskid_compiler`, and upload the built `.msi` and bootstrapper `.exe`. |

## Obtaining `DISTRIB_GH_PAT`

1. As an owner of `Cyber-Nomad-Collective`, open
   https://github.com/settings/tokens/new (classic PAT).
2. **Note:** `Beskid distrib pipeline`.
3. **Expiration:** 365 days (rotate before expiry).
4. **Scopes:** select `repo` (full). This grants read on `beskid_compiler`
   releases and write to upload `.msi` assets. If `beskid_compiler` is in a
   private org, `repo` is required; fine-grained PATs scoped to just
   `beskid_compiler` also work and are preferred where feasible.
5. Generate, copy the `ghp_...` token immediately (shown once).
6. Add it to the **superrepo** (`Cyber-Nomad-Collective/beskid`) under
   **Settings → Secrets and variables → Actions → New repository secret**:
   - Name: `DISTRIB_GH_PAT`
   - Value: the `ghp_...` token.

## What the MSI does (no secrets needed for this)

The MSI itself is built from `beskid_distrib/windows/beskid.wxs`:

- Installs `beskid.exe` + `beskid_lsp.exe` into `C:\Program Files\Beskid\`
  (directory picker shown — user can change the path).
- Adds that directory to the **system PATH** via the MSI Environment table
  (`<Environment ... System='yes' Part='last' />`). This survives reboot and
  applies to all users (per-machine install, `ALLUSERS=1`).
- Registers an uninstall entry in Add/Remove Programs with the version +
  publisher + Beskid icon.
- Upgrades in place (major upgrade via `UpgradeCode`); installing a newer MSI
  supersedes the older one.

## No code signing (v1)

The MSI is **unsigned**. Windows SmartScreen will show an "unrecognized app"
warning the first time a user runs it. This is expected for v1. Users click
**More info → Run anyway**. When a code-signing certificate is later obtained
(Authenticode OV/EV), add a `signtool sign` step to the `windows-msi` job and
add secrets `WINDOWS_CERT_PFX` (base64) + `WINDOWS_CERT_PASSWORD`; the WiX
source already separates build from signing so this is additive.
