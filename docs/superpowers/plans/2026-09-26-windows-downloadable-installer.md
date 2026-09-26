# Branded Windows Downloadable Installer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship one branded Windows setup EXE that downloads verified prerequisites, offers an opt-in native developer toolchain, and leaves `beskid build` usable from a fresh ordinary shell.

**Architecture:** WiX v4 Burn uses a custom WixStdBA theme, a default-off bundle variable, and SHA-512-pinned remote EXE payloads. A checked-in lock and renderer own vendor metadata; the compiler separately discovers the installed VS native environment for child tools. The standalone MSI remains valid and branded.

**Tech Stack:** WiX 4.0.6, Bash, Node.js, ImageMagick, Rust, PowerShell, Windows Server test VM.

**Spec:** `docs/superpowers/specs/2026-09-26-windows-downloadable-prerequisites-design.md`

## Global Constraints

- Windows target: x64 Windows 10 or later; Visual C++ Redistributable x64 version 14.40 or later.
- The default `InstallDeveloperTools` value is numeric `0`; unattended setup is also runtime-only unless explicitly overridden.
- VC++ is mandatory; MSVC x64 Build Tools, Windows SDK, and LLVM `lld-link` are opt-in downloads, not embedded payloads.
- Vendor EXE bytes are selected from official immutable HTTPS URLs and pinned by SHA-512 and byte size; a failed download or hash check fails closed.
- Shared vendor prerequisites remain installed when Beskid is removed or the option is deselected during repair.
- `beskid build` and `beskid run` must work from a fresh ordinary shell after opt-in setup without changing the user's global `PATH`, `LIB`, or `INCLUDE`.
- Use the existing `assets/icons/beskid-512.png`/`beskid-logo.svg` branding; no generic WiX icon or dialog artwork in the published setup.
- Work in isolated `codex/` branches. Do not push or publish. The user authorized merge to `main` only after the complete real-WiX and Windows gates pass.

## Review Focus

- A vendor URL serves new bytes under the same name: Task 1's lock/renderer test and Task 4's hash-failure VM test require rejection before execution.
- A machine has VS Community but no Build Tools product: Task 4 verifies the opt-in path installs the required Build Tools product without modifying the Community instance.
- Setup is cancelled mid-download: Task 4 verifies no Beskid MSI is installed and retained shared prerequisites are not removed.
- Repair runs with `InstallDeveloperTools=0` after an earlier opt-in install: Task 2's contract and Task 4's VM test verify no vendor tool is uninstalled.
- The SDK/tool binaries exist but an ordinary shell lacks `LIB`/`INCLUDE`: Task 3's regression test and Task 4's fresh-shell smoke require successful `beskid build` and `run`.

---

### Task 1: Pin remote prerequisites and replace the embedded VC++ payload

**Files (in `beskid_distrib`):**
- Create: `windows/prerequisites.lock.json` — vendor URLs, versions, SHA-512, sizes, source/license links.
- Create: `windows/render-prerequisites.mjs` — validate the lock and render a WiX v4 `PackageGroup` fragment.
- Modify: `windows/build-exe.sh`, `windows/beskid.bundle.wxs`, `windows/vc-redist.sh` — consume the fragment, retain VC++ registry/version detection, and stop embedding the redistributable.
- Test: `tests/windows-wix-contract.test.sh`, `tests/distribution-scripts.test.sh` — reject unpinned, malformed, or embedded payloads.

**Interfaces:** `node windows/render-prerequisites.mjs <lock.json> <fragment.wxs>` emits ordered `ExePackage` entries `VcRedistX64`, `VsBuildTools2022`, and `LlvmX64` with child `ExePackagePayload` `Name`/`DownloadUrl`/`Hash`/`Size`. `windows/build-exe.sh` passes both the static bundle and generated fragment to `wix build`; the static bundle's `Chain` references the package groups before the MSI.

- [ ] **Step 1: Write red tests** asserting VC++ and developer EXEs have remote payload metadata, the lock parser rejects missing/invalid URL/hash/size, the package order is VC++ → VS → LLVM → MSI, and no vendor bytes are embedded.
- [ ] **Step 2: Run** `bash tests/windows-wix-contract.test.sh && bash tests/distribution-scripts.test.sh` from `beskid_distrib`; confirm the new assertions fail on the current embedded-VC++ flow.
- [ ] **Step 3: Implement** the lock, renderer, and build-script/WiX wiring. Pin actual official versioned artifacts and verify their bytes/signatures during release preparation; use `wix burn remotepayload` to cross-check generated metadata where supported. Keep VC++ 14.40 detection and exit-code mapping.
- [ ] **Step 4: Rerun** both tests and `git diff --check`; confirm zero failures and inspect the rendered fragment for correct WiX v4 `ExePackagePayload` syntax.
- [ ] **Step 5: Commit** only this slice on the distribution branch, without staging unrelated work.

### Task 2: Offer and brand the developer-tools choice

**Files (in `beskid_distrib`, unless noted):**
- Create: `windows/beskid-theme.xml`, `windows/beskid-theme.wxl` — customized WixStdBA layout/localized text based on WiX v4's shipped theme.
- Modify: `windows/beskid.bundle.wxs` — `InstallDeveloperTools` variable, `ThemeFile`, `LogoFile`, `Bundle/@IconSourceFile`, package conditions, and permanent maintenance policy.
- Modify: `windows/beskid.wxs` — retain `ARPPRODUCTICON`, override `WixUIBannerBmp`/`WixUIDialogBmp`.
- Modify: `windows/build-msi.sh`, `windows/build-exe.sh`, superrepo `scripts/ci/woodpecker-package-platform.mjs` — derive and validate one multi-size ICO plus MSI artwork from the existing Beskid PNG.
- Test: `tests/windows-wix-contract.test.sh`, `tests/distribution-scripts.test.sh`, `tests/distribution-static.test.sh`.

**Interfaces:** a checkbox named `InstallDeveloperTools` binds to a numeric, command-line-overridable Burn variable of the same name; the VS and LLVM packages install only when it is `1`, and `Permanent='yes'` prevents their removal during repair/uninstall. The generated ICO is supplied as `AssetsDir/icons/beskid.ico`; MSI artwork is `AssetsDir/icons/beskid-msi-banner.png` and `AssetsDir/icons/beskid-msi-dialog.png`.

- [ ] **Step 1: Write red tests** for default-off and explicit opt-in conditions, permanent vendor packages, Beskid logo/EXE icon/ARP icons, branded MSI dialog variables, and missing-asset failures.
- [ ] **Step 2: Run** the three distribution test scripts; confirm the new assertions fail on the existing unbranded/default-chain behavior.
- [ ] **Step 3: Implement** the theme, package conditions, and reproducible ImageMagick asset derivation. Keep the options label, large-download warning, vendor-license links, and failure/reboot messaging readable at 100% and 150% scaling.
- [ ] **Step 4: Rerun** the tests; build the bundle with real WiX 4.0.6 and inspect the EXE icon, MSI UI assets, bundle manifest, and option variable binding. If WiX compilation rejects any sourced snippet, correct the source and test before proceeding.
- [ ] **Step 5: Commit** the theme, branding, bundle, build scripts, and tests as this slice.

### Task 3: Discover the native Windows toolchain in the compiler

**Files (in `beskid_compiler`, on a separate isolated branch):**
- Create: `crates/beskid_aot/src/windows_toolchain.rs` — VS instance discovery and child-process environment construction.
- Modify: `crates/beskid_aot/src/lib.rs`, `src/linker/windows.rs`, `src/api/platform_objects.rs` — apply the discovered environment to `cl`, `link`/`lld-link`, and `lib`/`llvm-lib` children.
- Test: unit tests in `windows_toolchain.rs` plus focused Windows AOT/CLI build-and-run fixture tests.

**Interfaces:** `configure_windows_native_command(command: &mut std::process::Command) -> AotResult<()>` preserves a complete explicit native environment; otherwise it locates VS 2022 Build Tools via installed-instance tooling, obtains x64 `PATH`, `INCLUDE`, `LIB`, and SDK values through `VsDevCmd.bat`, and applies them only to `command`. The caller reports `AotError` with a named missing tool/component if discovery fails. For installed LLVM, add its verified `lld-link` directory to that child environment without changing machine/user environment variables.

- [ ] **Step 1: Write red tests** using fake VS-instance and developer-command outputs: ordinary-shell discovery supplies `cl`/linker/SDK libraries, explicit user environment wins, missing SDK yields a named error, and paths with spaces survive parsing. Include an incomplete VS instance and verify discovery selects a complete Build Tools instance instead.
- [ ] **Step 2: Run** focused `beskid_aot` tests on the Linux builder for parser/policy logic and on the Windows VM for process behavior; confirm the new ordinary-shell test fails before integration.
- [ ] **Step 3: Implement** the discovery helper and integrate it at all native process-spawn sites, preserving the existing `link` then `lld-link` fallback and cross-platform behavior.
- [ ] **Step 4: Rerun** focused tests, the Windows AOT/CLI targets, and one `beskid build` plus `beskid run` from a fresh ordinary shell. Recheck Linux and macOS relevant tests for unintended changes.
- [ ] **Step 5: Commit** only the compiler slice; do not merge it ahead of the distribution end-to-end check.

### Task 4: Prove installer behavior on disposable Windows VMs and integrate

**Files:** `beskid_distrib/docs/Windows_Guide.md`, `beskid_distrib/README.md`, and the Windows packaging/smoke scripts under superrepo `scripts/ci/`.

**Interfaces:** release smoke consumes the built `beskid-<version>-windows-amd64.exe` and `.msi`, records bundle/MSI hashes and versions, and returns nonzero unless runtime-only and developer-toolchain installs satisfy the spec. It never uses production credentials or publication endpoints.

- [ ] **Step 1: Add failing smoke assertions** for default runtime-only, opted-in developer tools, preexisting components, offline/hash/cancel failure, repair/modify deselection, upgrade/uninstall, and fresh-shell CLI/JIT/build/run. Require post-install `lld-link` execution and recorded MSVC/SDK versions. Add screenshot checks for each branded installer page at 100% and 150% scaling.
- [ ] **Step 2: Run the smoke against the pre-change bundle** on a disposable VM and record the expected missing-feature failures; do not use the active test VM as a destructive clean-install target.
- [ ] **Step 3: Update guide/README** with the two setup choices, vendor download/license links, internet/elevation/disk/reboot requirements, unattended variable, standalone-MSI behavior, logs, and recovery steps. Wire the smoke into the release checklist/CI where a disposable VM is available.
- [ ] **Step 4: Build with real WiX and run the complete VM matrix**; verify vendor hashes/signatures, no embedded developer EXEs, Beskid logos/icons, no accidental vendor uninstalls, and `beskid test/build/run` from a new ordinary shell. Also run the distribution scripts and relevant compiler/Linux/macOS regressions with exit code zero.
- [ ] **Step 5: Review** the exact distribution, compiler, and root gitlink diffs against the design; update changelogs, then merge the verified branches to their respective `main` branches and update the superrepo gitlinks as the user authorized. Do not push or publish without a separate approval.
