#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
msi_builder="${root}/windows/build-msi.sh"
msi_source="${root}/windows/beskid.wxs"
bundle_source="${root}/windows/beskid.bundle.wxs"
bundle_builder="${root}/windows/build-exe.sh"
redist_helper="${root}/windows/vc-redist.sh"
prerequisites_lock="${root}/windows/prerequisites.lock.json"
prerequisites_renderer="${root}/windows/render-prerequisites.mjs"
theme="${root}/windows/beskid-theme.xml"
theme_strings="${root}/windows/beskid-theme.wxl"
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
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
node "${prerequisites_renderer}" "${prerequisites_lock}" "${tmp}/prerequisites.wxs" || \
  fail 'locked prerequisite fragment did not render'
node - "${prerequisites_lock}" <<'NODE' || fail 'LLVM payload URL is replaceable or not directly downloadable'
const fs = require('node:fs');
const lock = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const llvm = lock.packages.find(packageItem => packageItem.id === 'LlvmX64');
if (!/^https:\/\/release-assets\.githubusercontent\.com\/github-production-release-asset\/75821432\/[0-9a-f-]{36}$/.test(llvm.url)) process.exit(1);
NODE
node - "${prerequisites_lock}" "${tmp}/replaceable.json" <<'NODE'
const fs = require('node:fs');
const lock = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
lock.packages[2].url = 'https://github.com/llvm/llvm-project/releases/download/llvmorg-22.1.8/LLVM-22.1.8-win64.exe';
fs.writeFileSync(process.argv[3], JSON.stringify(lock));
NODE
if node "${prerequisites_renderer}" "${tmp}/replaceable.json" "${tmp}/replaceable.wxs" 2>/dev/null; then
  fail 'prerequisite renderer accepted a replaceable LLVM release-tag URL'
fi
for field in url sha512 size; do
  node - "${prerequisites_lock}" "${tmp}/bad-${field}.json" "${field}" <<'NODE'
const fs = require('node:fs');
const lock = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
delete lock.packages[0][process.argv[4]];
fs.writeFileSync(process.argv[3], JSON.stringify(lock));
NODE
  if node "${prerequisites_renderer}" "${tmp}/bad-${field}.json" "${tmp}/bad.wxs" 2>/dev/null; then
    fail "prerequisite renderer accepted missing ${field}"
  fi
done
for invalid in 'url=http://example.com/payload.exe' 'sha512=deadbeef' 'size=0'; do
  field="${invalid%%=*}"
  value="${invalid#*=}"
  node - "${prerequisites_lock}" "${tmp}/invalid-${field}.json" "${field}" "${value}" <<'NODE'
const fs = require('node:fs');
const lock = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
lock.packages[0][process.argv[4]] = process.argv[4] === 'size' ? Number(process.argv[5]) : process.argv[5];
fs.writeFileSync(process.argv[3], JSON.stringify(lock));
NODE
  if node "${prerequisites_renderer}" "${tmp}/invalid-${field}.json" "${tmp}/invalid.wxs" 2>/dev/null; then
    fail "prerequisite renderer accepted malformed ${field}"
  fi
done
node - "${prerequisites_lock}" "${tmp}/moving.json" <<'NODE'
const fs = require('node:fs');
const lock = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
lock.packages[0].url = 'https://aka.ms/vs/17/release/vc_redist.x64.exe';
fs.writeFileSync(process.argv[3], JSON.stringify(lock));
NODE
if node "${prerequisites_renderer}" "${tmp}/moving.json" "${tmp}/moving.wxs" 2>/dev/null; then
  fail 'prerequisite renderer accepted a moving Microsoft permalink'
fi
mkdir -p "${tmp}/audit"
printf 'wrong vendor bytes' >"${tmp}/audit/vc_redist.x64.exe"
if BESKID_PREREQUISITES_AUDIT_DIR="${tmp}/audit" \
  node "${prerequisites_renderer}" "${prerequisites_lock}" "${tmp}/bad-audit.wxs" 2>/dev/null; then
  fail 'prerequisite renderer accepted a mismatched audit copy'
fi
node - "${tmp}/prerequisites.wxs" "${bundle_source}" <<'NODE' || fail 'remote prerequisite contract failed'
const fs = require('node:fs');
const fragment = fs.readFileSync(process.argv[2], 'utf8');
const bundle = fs.readFileSync(process.argv[3], 'utf8');
const ids = ['VcRedistX64', 'VsBuildTools2022', 'LlvmX64'];
for (const id of ids) {
  const packageXml = fragment.match(new RegExp(`<ExePackage\\b[^>]*Id="${id}"[\\s\\S]*?<\\/ExePackage>`));
  if (!packageXml) throw Error(`missing ${id}`);
  if (!/<ExePackagePayload\b[^>]*Name="[^"]+"[^>]*DownloadUrl="https:\/\/[^\"]+"[^>]*Hash="[A-Fa-f0-9]{128}"[^>]*Size="[1-9][0-9]*"/.test(packageXml[0])) throw Error(`unpinned ${id}`);
  if (/SourceFile=|Compressed="yes"/.test(packageXml[0])) throw Error(`embedded ${id}`);
  for (const attr of ['Permanent="yes"', 'PerMachine="yes"', 'Vital="yes"']) {
    if (!packageXml[0].includes(attr)) throw Error(`${id} lacks ${attr}`);
  }
}
if (!fragment.includes('DetectCondition="VcRedistX64Installed = 1 AND VcRedistX64Minor &gt;= 40"')) throw Error('VC++ floor lost');
if (!fragment.includes('<ExitCode Value="1638" Behavior="success" />')) throw Error('VC++ exit code mapping lost');
if (!bundle.includes("<Variable Name='InstallDeveloperTools' Type='numeric' Value='0'")) throw Error('developer tools must default off');
for (const id of ['VsBuildTools2022', 'LlvmX64']) {
  if (!fragment.match(new RegExp(`Id="${id}"[^>]*InstallCondition="InstallDeveloperTools = 1"`))) throw Error(`${id} is not opt-in`);
}
const refs = ['VcRedistX64Group', 'VsBuildTools2022Group', 'LlvmX64Group'];
let previous = -1;
for (const ref of refs) {
  const position = bundle.indexOf(`<PackageGroupRef Id='${ref}' />`);
  if (position <= previous) throw Error(`package order invalid at ${ref}`);
  previous = position;
}
if (bundle.indexOf('<MsiPackage', previous) < 0) throw Error('MSI must follow prerequisites');
if (/vc_redist\.x64\.exe|vs_BuildTools\.exe|LLVM-[^'\"]+\.exe/.test(bundle)) throw Error('static bundle names embedded vendor payload');
NODE
if grep -Eq '<RemotePayload|RemotePayload ' "${bundle_source}"; then
  fail 'bundle uses the WiX v3 RemotePayload element'
fi
grep -Fq 'load_wix_extension WixToolset.Util.wixext' "${bundle_builder}" || \
  fail 'bundle builder does not load the WiX util extension'
if grep -Fq -- '-d VcRedistPath=' "${bundle_builder}"; then
  fail 'bundle builder still passes an embedded redistributable'
fi

# A clean install offers developer tools but leaves them unchecked. The LLVM
# NSIS product key detects an existing installation; VS vendor behavior is a
# separate VM acceptance gate because Burn cannot enumerate VS instances.
node - "${bundle_source}" "${tmp}/prerequisites.wxs" "${theme}" "${theme_strings}" "${msi_source}" <<'NODE' || fail 'branding and developer option contract failed'
const fs = require('node:fs');
const [bundlePath, fragmentPath, themePath, stringsPath, msiPath] = process.argv.slice(2);
const bundle = fs.readFileSync(bundlePath, 'utf8');
const fragment = fs.readFileSync(fragmentPath, 'utf8');
const theme = fs.readFileSync(themePath, 'utf8');
const strings = fs.readFileSync(stringsPath, 'utf8');
const msi = fs.readFileSync(msiPath, 'utf8');
if (!/Name='InstallDeveloperTools' Type='numeric' Value='0' bal:Overridable='yes'/.test(bundle)) throw Error('option must default off and allow command-line override');
if (!/Checkbox\b[^>]*Name="InstallDeveloperTools"/.test(theme)) throw Error('theme lacks bound checkbox');
if (!/Install developer tools/.test(strings) || !/download/i.test(strings)) throw Error('option or large-download warning missing');
for (const name of ['VsBuildTools2022', 'LlvmX64']) {
  const pkg = fragment.match(new RegExp(`<ExePackage\\b[^>]*Id="${name}"[^>]*>`))?.[0];
  if (!pkg || !pkg.includes('InstallCondition="InstallDeveloperTools = 1"') || !pkg.includes('Permanent="yes"')) throw Error(`${name} is not permanent and opt-in`);
}
if (!fragment.match(/Id="LlvmX64"[^>]*DetectCondition="LlvmX64Installed"/)) throw Error('LLVM installed-product detection missing');
if (!bundle.includes("Key='SOFTWARE\\LLVM'")) throw Error('LLVM NSIS registry key search missing');
for (const attr of ["IconSourceFile='$(var.AssetsDir)\\icons\\beskid.ico'", "ThemeFile='$(var.DistribRoot)\\windows\\beskid-theme.xml'", "LocalizationFile='$(var.DistribRoot)\\windows\\beskid-theme.wxl'", "LogoFile='$(var.AssetsDir)\\icons\\beskid-512.png'"]) {
  if (!bundle.includes(attr)) throw Error(`bundle lacks ${attr}`);
}
for (const id of ['WixUIBannerBmp', 'WixUIDialogBmp']) {
  if (!msi.includes(`Id='${id}'`)) throw Error(`MSI lacks ${id}`);
}
if (!msi.includes("Property Id='ARPPRODUCTICON' Value='beskid.ico'")) throw Error('MSI ARP icon missing');
NODE

# A standalone MSI requires the same 14.40+ runtime as Burn; repair/uninstall stay open.
grep -Fq "Key='SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64'" "${msi_source}" || \
  fail 'MSI does not search for the x64 Visual C++ runtime'
grep -Fq "Property Id='VCREDISTX64MINOR'" "${msi_source}" || \
  fail 'MSI does not search for the Visual C++ runtime minor version'
grep -Fq "Name='Minor'" "${msi_source}" || \
  fail 'MSI does not read the Visual C++ runtime minor version'
[[ "$(grep -c "Bitness='always64'" "${msi_source}")" -ge 2 ]] || \
  fail 'MSI registry searches do not both read the 64-bit registry view'
grep -Fq "Condition='Installed OR (VCREDISTX64INSTALLED = \"#1\" AND VCREDISTX64MINOR &gt;= 40)'" "${msi_source}" || \
  fail 'MSI does not block installation without the 14.40+ Visual C++ runtime'

# The MSVC Build Tools and the Windows SDK are not redistributable. Neither
# package may carry them; the guide documents them for `beskid build`/`run`.
if grep -Eq 'SourceFile=.*(vc_redist|vs_BuildTools|LLVM-)' "${tmp}/prerequisites.wxs"; then
  fail 'vendor bytes are embedded in the prerequisite fragment'
fi
for phrase in 'VCRUNTIME140.dll' 'Desktop development with C++' 'Windows SDK' \
  'x64 Native Tools Command Prompt' 'beskid test' 'beskid build' 'llvm-ml'; do
  grep -Fq "${phrase}" "${guide}" || fail "Windows guide does not document: ${phrase}"
done

printf 'Windows WiX contract tests OK\n'
