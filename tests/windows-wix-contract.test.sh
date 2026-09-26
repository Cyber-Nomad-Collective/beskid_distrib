#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
msi_builder="${root}/windows/build-msi.sh"
msi_source="${root}/windows/beskid.wxs"
bundle_source="${root}/windows/beskid.bundle.wxs"
bundle_builder="${root}/windows/build-exe.sh"
redist_helper="${root}/windows/vc-redist.sh"
guide="${root}/docs/Windows_Guide.md"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Fq -- '-arch x64' "${msi_builder}" || \
  fail 'MSI builder does not select the x64 package architecture'

grep -Fq '<SummaryInformation' "${msi_source}" || \
  fail 'MSI source does not use the WiX v4 SummaryInformation element'

if grep -Fq "Property Id='ALLUSERS'" "${msi_source}"; then
  fail 'MSI source duplicates the Package per-machine ALLUSERS property'
fi

if grep -Eq "DowngradeErrorMessage=.*\[[0-9]+\]" "${msi_source}"; then
  fail 'MSI downgrade message contains an invalid numeric format token'
fi

for source in "${msi_source}" "${bundle_source}"; do
  grep -Fq "encoding='utf-8'" "${source}" || \
    fail "$(basename "${source}") does not use the WiX-compatible UTF-8 declaration"
done

# End-user prerequisites. The CLI, LSP, updater, runtime DLL, and linked
# programs import VCRUNTIME140.dll: the bundle chains Microsoft's x64
# redistributable before the MSI, detected through the 64-bit registry view.
grep -Fq "xmlns:util='http://wixtoolset.org/schemas/v4/wxs/util'" "${bundle_source}" || \
  fail 'bundle does not declare the WiX v4 util namespace for registry detection'
grep -Fq "Key='SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64'" "${bundle_source}" || \
  fail 'bundle does not detect the x64 Visual C++ runtime registry key'
[[ "$(grep -c "Bitness='always64'" "${bundle_source}")" -ge 2 ]] || \
  fail 'bundle registry searches do not read the 64-bit registry view'
grep -Fq "DetectCondition='VcRedistX64Installed = 1 AND VcRedistX64Minor &gt;= 40'" "${bundle_source}" || \
  fail 'bundle does not require an installed 14.40+ Visual C++ runtime'
for attribute in "Id='VcRedistX64'" "SourceFile='\$(var.VcRedistPath)'" "Compressed='yes'" \
  "Permanent='yes'" "PerMachine='yes'" "Vital='yes'" "InstallArguments='/install /quiet /norestart'"; do
  grep -Fq "${attribute}" "${bundle_source}" || fail "VC++ redistributable package lacks ${attribute}"
done
grep -Fq "<ExitCode Value='1638' Behavior='success' />" "${bundle_source}" || \
  fail 'bundle treats an already newer Visual C++ runtime as a failure'
redist_line="$(grep -n "<ExePackage" "${bundle_source}" | head -1 | cut -d: -f1)"
msi_line="$(grep -n "<MsiPackage" "${bundle_source}" | head -1 | cut -d: -f1)"
[[ -n "${redist_line}" && -n "${msi_line}" && "${redist_line}" -lt "${msi_line}" ]] || \
  fail 'bundle must install the Visual C++ runtime before the Beskid MSI'
if grep -Eq '<RemotePayload|RemotePayload ' "${bundle_source}"; then
  fail 'bundle uses the WiX v3 RemotePayload element'
fi
grep -Fq 'load_wix_extension WixToolset.Util.wixext' "${bundle_builder}" || \
  fail 'bundle builder does not load the WiX util extension'
grep -Fq -- '-d VcRedistPath=' "${bundle_builder}" || \
  fail 'bundle builder does not pass the redistributable payload'
grep -Fq "https://aka.ms/vs/17/release/vc_redist.x64.exe" "${redist_helper}" || \
  fail 'redistributable helper does not use the official Microsoft permalink'
grep -Fq 'Get-AuthenticodeSignature' "${redist_helper}" || \
  fail 'downloaded redistributable is not verified by Authenticode'

# A standalone MSI fails closed without the runtime; repair/uninstall stay open.
grep -Fq "Key='SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64'" "${msi_source}" || \
  fail 'MSI does not search for the x64 Visual C++ runtime'
grep -Fq "Condition='Installed OR VCREDISTX64INSTALLED = \"#1\"'" "${msi_source}" || \
  fail 'MSI does not block installation without the Visual C++ runtime'

# The MSVC Build Tools and the Windows SDK are not redistributable. Neither
# package may carry them; the guide documents them for `beskid build`/`run`.
for source in "${msi_source}" "${bundle_source}" "${bundle_builder}" "${msi_builder}"; do
  if grep -Eiq 'vs_buildtools|vs_BuildTools|winsdksetup|Windows Kits|link\.exe|lld-link' "${source}"; then
    fail "$(basename "${source}") ships or fetches a non-redistributable or undecided native toolchain"
  fi
done
for phrase in 'VCRUNTIME140.dll' 'Desktop development with C++' 'Windows SDK' \
  'x64 Native Tools Command Prompt' 'beskid test' 'beskid build' 'llvm-ml'; do
  grep -Fq "${phrase}" "${guide}" || fail "Windows guide does not document: ${phrase}"
done

printf 'Windows WiX contract tests OK\n'
