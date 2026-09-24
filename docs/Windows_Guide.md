# Windows Guide — obtaining CI secrets for the MSI and EXE pipeline

The Windows packaging job (`windows-msi` in the superrepo's `distribute.yml`)
builds an MSI with WiX v4, wraps it in a WiX Burn EXE bootstrapper, and uploads
both to the `cli-latest` / `cli-v<version>` release on `beskid_compiler`. It
needs **one** secret.

## End-user prerequisites

Beskid supports Windows 10 and later on x64. The table shows what each
command needs on a clean machine, where it comes from, and how the installer
handles it.

| Need | Used by | Source | Installer |
|---|---|---|---|
| UCRT (`api-ms-win-crt-*.dll`) | all binaries | Part of Windows 10 and later | Not needed |
| `VCRUNTIME140.dll` (Visual C++ 2015-2022 Redistributable, x64, 14.40 or later) | `beskid.exe`, `beskid_lsp.exe`, `beskid-up.exe`, the runtime DLL used by `beskid test`, and every program that `beskid build` links | Microsoft, distributable code | Chained: the setup `.exe` installs it when it is missing. The standalone `.msi` stops with a message if it is missing |
| ABI-v5 runtime kit (`lib\beskid-runtime\abi-5\x86_64-pc-windows-msvc`) | `beskid test` (JIT, loads the kit DLL), `beskid build`, `beskid run` | Release bundle | Shipped in the MSI |
| `kernel32.dll`, `ws2_32.dll` | runtime and linked programs | Windows | Not needed |
| MSVC x64 compiler and linker (`cl.exe`, `link.exe`) and the MSVC CRT import libraries (`msvcrt.lib`, `vcruntime.lib`) | `beskid build`, `beskid run` | Visual Studio Build Tools, `Desktop development with C++` workload | Documented only. Microsoft does not permit redistribution |
| Windows SDK import libraries (`kernel32.lib`, `ucrt.lib`, `ws2_32.lib`) | `beskid build`, `beskid run` | Windows SDK (selected by default in the same workload) | Documented only. Microsoft does not permit redistribution |

`beskid test` runs tests in the JIT and needs only the redistributable and the
bundled runtime kit. `beskid run` is not a JIT command: it links a temporary
executable, so it has the same needs as `beskid build`.

### Set up `beskid build` and `beskid run`

1. Install the Visual Studio 2022 Build Tools (or any Visual Studio 2022
   edition) with the `Desktop development with C++` workload. Keep the MSVC
   x64/x86 build tools and a Windows 11 or Windows 10 SDK selected.
2. Open the `x64 Native Tools Command Prompt for VS 2022` (or run
   `vcvars64.bat` in your shell). Beskid does not locate Visual Studio by
   itself: `cl.exe`, `link.exe`, and the `LIB` and `INCLUDE` variables must
   come from that environment.
3. Run `beskid build` or `beskid run` from that prompt.

If the tools are missing, the compiler reports `[E4020]` and names the missing
tool (for example `cl`) or the linker. Programs that `beskid build` produces
also import `VCRUNTIME140.dll`, so a machine that runs them needs the
redistributable.

A standalone LLVM `lld-link.exe` does not remove the Build Tools requirement:
the linker still needs the MSVC and Windows SDK import libraries, and the
executable bootstrap is compiled with `cl.exe`. The installer does not ship a
linker.

### Build-time only: the runtime kit

End users do not build the runtime kit. Release engineers who run
`beskid runtime-kit build-native-host` need, in addition to the Build Tools,
LLVM for Windows on `PATH`: `llvm-ml` assembles the context-switch and platform
assembly and `clang` compiles the platform C sources.

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

- Installs the verified target bundle (`bin\beskid.exe`, `bin\beskid_lsp.exe`,
  `bin\beskid-up.exe`, the ABI-v5 runtime kit, corelib, and bundled packages)
  into `C:\Program Files\Beskid\` (directory picker shown — user can change
  the path).
- Stops with a message when the Visual C++ Redistributable (x64) is not
  installed. The setup `.exe` (WiX Burn bundle, `beskid.bundle.wxs`) embeds
  Microsoft's `vc_redist.x64.exe` and installs it first when it is missing or
  older than 14.40. The redistributable stays installed when Beskid is
  removed. `windows/build-exe.sh` downloads it from
  `https://aka.ms/vs/17/release/vc_redist.x64.exe` and requires a valid
  Microsoft Authenticode signature, or uses `BESKID_VC_REDIST_X64` when the
  caller supplies a verified copy.
- Adds its `bin` directory to the **system PATH** via the MSI Environment table
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
