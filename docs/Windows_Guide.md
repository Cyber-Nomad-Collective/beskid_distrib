# Windows installation guide

Beskid supports x64 Windows 10 or later. The downloadable
`beskid-<version>-windows-amd64.exe` is the recommended installer. It needs
administrator approval and an internet connection to fetch missing vendor
prerequisites. Allow space for the Beskid installation and, when selected,
several GB for Visual Studio Build Tools, Windows SDK, and LLVM. Setup may
request a restart; complete it before opening a new shell.

The superrepo's Woodpecker Windows packaging step runs
`windows/build-msi.sh` and `windows/build-exe.sh` using WiX v4 to build
checksummed MSI and Burn setup EXE artifacts. Publication to the
`beskid_compiler` release is a separate reviewed manual operation.

## Choose what to install

The setup offers an unchecked **Install developer tools (MSVC, Windows SDK,
LLVM)** option:

| Choice | Installs | Commands after setup |
| --- | --- | --- |
| Default, runtime only | Beskid CLI, LSP, updater, ABI-v5 runtime kit, corelib, bundled packages, and Visual C++ x64 Redistributable 14.40 or newer when needed | `beskid check`, formatting, documentation and package inspection |
| Developer tools selected | Everything above, plus Visual Studio 2022 Build Tools with the Desktop development with C++ workload and Windows SDK, and LLVM with `lld-link` | `beskid build`, `beskid run`, and `beskid test` from a fresh ordinary shell |

`beskid run` and `beskid test` link native executables, so they require the
native tools too. Tests use one compiled object with a fresh process for each
selected test; assertion failure does not stop later tests. The
compiler discovers the installed x64 toolchain for its child processes; you
do not need to open the Visual Studio Native Tools prompt or set global
`LIB`/`INCLUDE` variables. An existing standard-path Build Tools installation
is modified to add any missing selected x64 compiler and SDK components;
re-running that modification on a complete installation is harmless. Selecting
developer tools still downloads the pinned Visual Studio bootstrapper for this
check, even when the installed components are complete. The
installer retains shared Microsoft and LLVM prerequisites
when you repair or remove Beskid.

The redistributable supplies `VCRUNTIME140.dll` to Beskid and programs built
with it. Release engineers building the native runtime kit also need LLVM's
`llvm-ml` assembler and `clang`; that is separate from ordinary end-user use.

The setup downloads official vendor packages using the reviewed URLs, sizes,
and SHA-512 hashes in
[`windows/prerequisites.lock.json`](../windows/prerequisites.lock.json). The
setup fails if a download or hash differs; it does not run unverified bytes.
Visual Studio's bootstrapper downloads the selected C++ workload components
from Microsoft. Vendor sources and terms are available from
[Microsoft Visual C++](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist?view=msvc-170),
[Visual Studio Build Tools](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022),
[Microsoft license terms](https://visualstudio.microsoft.com/license-terms/),
[LLVM releases](https://github.com/llvm/llvm-project/releases), and
[LLVM license terms](https://llvm.org/docs/DeveloperPolicy.html#license).

For unattended runtime-only setup, use `beskid-<version>-windows-amd64.exe
/quiet /norestart /log setup.log`. Add `InstallDeveloperTools=1` to select the
developer tools explicitly. The default is `0`, including unattended installs.
Use the setup EXE rather than the standalone MSI when Visual C++ is missing.

## Standalone MSI

The `beskid-<version>-windows-amd64.msi` installs the same Beskid files and
shows a branded directory picker, but it does not fetch prerequisites. It
stops with an actionable message unless Visual C++ x64 Redistributable 14.40
or newer is already installed. It does not install Build Tools, Windows SDK,
or LLVM. Beskid's `bin` directory is added to the system `PATH` by the MSI;
open a new shell after installation.

## If setup stops

- Check the path supplied with `/log` or the setup log linked on the failure
  page. Find the failed vendor package name and its companion log before
  retrying.
- For a network or hash failure, restore connectivity and rerun the same setup
  EXE. Do not substitute an unverified installer. For a pending restart,
  restart Windows, then rerun setup if it did not finish.
- If `beskid build` reports a missing MSVC or SDK component after an opt-in
  install, inspect the Visual Studio Installer for the C++ workload, x64/x86
  MSVC tools, and a supported Windows SDK. Confirm LLVM's `lld-link` is
  installed, then retry from a new ordinary shell.

## Release verification

Woodpecker packages the MSI and EXE from a qualified, checksummed compiler
bundle. The Windows packaging job derives the ICO and MSI artwork from the
checked-in Beskid logo and records the resulting installer SHA-256 hashes in
`package-result.json`. Packaging does not publish installers. Before a
release, run the disposable-VM installer matrix from the implementation plan
for both setup choices, failure/cancel/repair/upgrade paths, and fresh-shell
CLI/JIT/build/run; record installed MSVC/SDK versions and 100%/150% UI
screenshots. A passing package job alone does not establish those behaviors.

Run `scripts/ci/windows-installer-smoke.ps1` from an elevated PowerShell on
approved disposable Windows VMs, once per scenario: `runtime`, `developer`,
`community`, `preexisting`, `offline`, `hash-failure`, `cancel`,
`repair-deselect`, `upgrade`, and `uninstall`. Supply the exact packaged EXE,
MSI, `windows/prerequisites.lock.json`, a directory containing all three
locked vendor EXEs, separate test and app project fixtures, and one shared
evidence directory. The script hashes the setup/MSI and all vendor files,
records VC++/MSVC/SDK/LLVM versions, executes `lld-link`, and runs
`beskid test`, `build`, and `run` with a new ordinary process environment
when installed. Each case exits nonzero if its expected machine state fails.
If Burn returns `3010`, the recorder writes a pending continuation, then
stops. Reboot Windows and rerun the same case with `-ResumeAfterReboot`; it
checks that the machine actually rebooted before checking installed tools and
running CLI smoke.
For example, from the superrepo checkout on a clean VM:

```powershell
powershell.exe -NoProfile -File scripts/ci/windows-installer-smoke.ps1 `
  -Scenario developer -SetupExe C:\release\beskid-0.5.0-windows-amd64.exe `
  -Msi C:\release\beskid-0.5.0-windows-amd64.msi `
  -LockFile beskid_distrib\windows\prerequisites.lock.json `
  -VendorAuditDir C:\vendor-audit `
  -TestProject C:\fixtures\test_harness\TestHarness.bproj `
  -ProgramProject C:\fixtures\smoke_project\SmokeProject.bproj `
  -OutputDir C:\installer-evidence
```

Use a fresh snapshot or a controlled predecessor state for each case:

| Case | Required starting state / action |
| --- | --- |
| `runtime`, `developer` | Clean VM with no Beskid or developer tools; leave the option off/on respectively. |
| `community` | VS Community installed, no Build Tools product; verify Community remains and Build Tools is added. |
| `preexisting` | Complete Build Tools, SDK, and LLVM already installed. |
| Partial Build Tools | On a disposable clone, remove the selected Windows SDK component while retaining Build Tools and `VsDevCmd.bat`; verify the opt-in setup restores the component and `beskid build`/`beskid run` pass. |
| `offline` | Clean VM with vendor network access disabled; capture the failed setup log and exit code. |
| `hash-failure` | Clean VM with a deliberately mismatched remote-payload hash test bundle; capture its failed log and exit code. Keep the released setup EXE separately for release-hash comparison. |
| `cancel` | Clean VM; cancel through the UI during a vendor download. The recorder verifies that cancellation followed the download start and preceded payload acquisition. |
| `repair-deselect` | Prior opt-in install; repair with `InstallDeveloperTools=0`. |
| `upgrade` | Prior Beskid version installed; pass `-PriorVersion`. |
| `uninstall` | Current Beskid installed with shared prerequisites present. |

For `offline`, the recorder runs the released setup EXE on a prepared offline
VM. For `hash-failure`, pass `-ObservedSetupExe` with a deliberately altered
test bundle; the recorder runs it and checks the failure log, absent Beskid
install, and retained preexisting vendor tools. For `cancel`, the recorder
starts passive setup, closes its progress window during a vendor download,
and checks Burn's ordered cancellation log. Collect actual screenshots named
`welcome-100.png`, `welcome-150.png`, `options-100.png`, `options-150.png`,
`progress-100.png`, `progress-150.png`, `success-100.png`,
`success-150.png`, `failure-100.png`, `failure-150.png`,
`msi-directory-100.png`, and `msi-directory-150.png`. A human must inspect
the images for correct Beskid branding and legibility; the automated gate
checks their presence.

After transferring this evidence to a directory visible to the Woodpecker
release worker, run `node scripts/ci/windows-installer-smoke-gate.mjs
<evidence-dir> <setup-sha256> <msi-sha256>
<checked-in-prerequisites.lock.json>`. This checks scenario records and the
vendor hashes against the reviewed lock. It reports structural validity only:
the evidence is not yet authenticated as coming from a disposable VM.
Manual publication is explicitly blocked, even when
`BESKID_WINDOWS_INSTALLER_SMOKE_DIR` is set, until a trusted VM provenance and
evidence-transfer path is integrated. The persistent Windows build agent is
not a disposable install target.

The standalone MSI and setup EXE are currently unsigned, so Windows may show
an unrecognized-app warning. Release engineering must review that warning and
the pinned vendor signatures before publishing.

## Installation ownership and updates

The MSI records Windows Installer ownership of the complete private installation
prefix. `beskid toolchain status` validates that payload and reports the running
executable. `beskid toolchain update` directs you to the qualified replacement MSI
or setup EXE, which preserves Windows Installer ownership; it does not activate
an unrelated direct-download installation.
