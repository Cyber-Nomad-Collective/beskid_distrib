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
node - "${prerequisites_lock}" <<'NODE' || fail 'LLVM payload URL is not the pinned official release download'
const fs = require('node:fs');
const lock = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const llvm = lock.packages.find(packageItem => packageItem.id === 'LlvmX64');
if (llvm.url !== `https://github.com/llvm/llvm-project/releases/download/llvmorg-${llvm.version}/${llvm.name}`) process.exit(1);
NODE
node - "${prerequisites_lock}" "${tmp}/replaceable.json" <<'NODE'
const fs = require('node:fs');
const lock = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
lock.packages[2].url = 'https://github.com/llvm/llvm-project/releases/download/llvmorg-22.1.7/LLVM-22.1.8-win64.exe';
fs.writeFileSync(process.argv[3], JSON.stringify(lock));
NODE
if node "${prerequisites_renderer}" "${tmp}/replaceable.json" "${tmp}/replaceable.wxs" 2>/dev/null; then
  fail 'prerequisite renderer accepted an LLVM URL with the wrong release tag'
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

# A clean install offers developer tools but leaves them unchecked. Burn
# chooses Visual Studio install versus modify for a standard-path instance,
# and skips an existing standard-path LLVM installation.
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
const buildTools = fragment.match(/<ExePackage\b[^>]*Id="VsBuildTools2022"[\s\S]*?<\/ExePackage>/)?.[0];
if (!buildTools) throw Error('Build Tools package missing');
if (/DetectCondition="VsBuildToolsInstalled"/.test(buildTools)) throw Error('Build Tools presence alone must not skip missing components');
if (!buildTools.includes('Condition="VsBuildToolsInstalled"') || !buildTools.includes('InstallArgument="modify --installPath')) throw Error('existing Build Tools must be modified to complete missing components');
if (!buildTools.includes('Condition="NOT VsBuildToolsInstalled"') || !buildTools.includes('InstallArgument="--quiet')) throw Error('new Build Tools must use the install command');
if (!fragment.match(/Id="LlvmX64"[^>]*DetectCondition="LlvmX64Installed"/)) throw Error('LLVM installed-product detection missing');
if (!bundle.includes("Variable='VsBuildToolsInstalled'") || !bundle.includes("Path='[ProgramFilesFolder]Microsoft Visual Studio\\2022\\BuildTools\\Common7\\Tools\\VsDevCmd.bat'")) throw Error('standard Build Tools path search missing');
if (!bundle.includes("Variable='LlvmX64Installed'") || !bundle.includes("Path='[ProgramFiles64Folder]LLVM\\bin\\lld-link.exe'")) throw Error('standard LLVM path search missing');
for (const attr of ["IconSourceFile='$(var.AssetsDir)\\icons\\beskid.ico'", "ThemeFile='$(var.DistribRoot)\\windows\\beskid-theme.xml'", "LocalizationFile='$(var.DistribRoot)\\windows\\beskid-theme.wxl'", "LogoFile='$(var.AssetsDir)\\icons\\beskid-512.png'"]) {
  if (!bundle.includes(attr)) throw Error(`bundle lacks ${attr}`);
}
for (const id of ['WixUIBannerBmp', 'WixUIDialogBmp']) {
  if (!msi.includes(`Id='${id}'`)) throw Error(`MSI lacks ${id}`);
}
if (!msi.includes("Property Id='ARPPRODUCTICON' Value='beskid.ico'")) throw Error('MSI ARP icon missing');
NODE

# Exercise the Burn-to-MSI directory flow from parsed WiX authoring. The two
# installer outcomes below model the formatted Burn variable resolution and
# the MSI property handoff used by the real bundle.
python3 - "${bundle_source}" "${theme}" "${theme_strings}" <<'PY' || fail 'Burn install-folder behavior contract failed'
import re
import sys
import xml.etree.ElementTree as ET

bundle_path, theme_path, strings_path = sys.argv[1:]
bundle = ET.parse(bundle_path).getroot().find('w:Bundle', {'w': 'http://wixtoolset.org/schemas/v4/wxs'})
theme = ET.parse(theme_path).getroot()
strings = ET.parse(strings_path).getroot()
ns = {'w': 'http://wixtoolset.org/schemas/v4/wxs', 'bal': 'http://wixtoolset.org/schemas/v4/wxs/bal', 'thm': 'http://wixtoolset.org/schemas/v4/thmutil', 'wxl': 'http://wixtoolset.org/schemas/v4/wxl'}

install_folder = bundle.find("w:Variable[@Name='InstallFolder']", ns)
assert install_folder is not None, 'Burn must initialize the folder variable edited by the Options page'
assert install_folder.get('Type') == 'formatted', 'default folder must expand Burn folder variables'
assert install_folder.get('Value') == '[ProgramFiles64Folder]\\Beskid', 'default must resolve under 64-bit Program Files'

options = theme.find(".//thm:Page[@Name='Options']", ns)
editbox = options.find("thm:Editbox[@Name='InstallFolder']", ns) if options is not None else None
browse = options.find(".//thm:BrowseDirectoryAction[@VariableName='InstallFolder']", ns) if options is not None else None
assert editbox is not None and browse is not None, 'Options edit and Browse must change the same Burn variable'
options_ok = options.find("thm:Button[@Name='OptionsOkButton']/thm:ChangePageAction", ns) if options is not None else None
assert options_ok is not None and options_ok.get('Page') == 'InstallFolderCheck', 'Options must save its editbox value before validating it'
options_cancel = options.find("thm:Button[@Name='OptionsCancelButton']/thm:ChangePageAction", ns) if options is not None else None
assert options_cancel is not None and options_cancel.get('Page') == 'InstallFolderCheck' and options_cancel.get('Cancel') == 'yes', 'Options Cancel must discard pending edits and return through the folder gate'
folder_check = theme.find(".//thm:Page[@Name='InstallFolderCheck']", ns)
continue_action = folder_check.find("thm:Button[@Name='FolderCheckContinueButton']/thm:ChangePageAction", ns) if folder_check is not None else None
empty_message = folder_check.find("thm:Label[@Name='FolderCheckEmptyMessage']", ns) if folder_check is not None else None
back_action = folder_check.find("thm:Button[@Name='FolderCheckBackButton']/thm:ChangePageAction", ns) if folder_check is not None else None
assert continue_action is not None and continue_action.get('Page') == 'Install' and continue_action.get('Condition') == 'InstallFolder <> ""', 'post-Options transition must require a non-empty folder'
assert empty_message is not None and empty_message.get('VisibleCondition') == 'InstallFolder = ""', 'empty-folder validation page must explain why setup cannot continue'
assert back_action is not None and back_action.get('Page') == 'Options', 'user must be able to return and correct an empty folder'
install_transitions = [action for action in theme.findall('.//thm:ChangePageAction', ns) if action.get('Page') == 'Install']
assert install_transitions == [continue_action], 'every theme transition to the Install page must pass through the guarded folder action'

chain = bundle.find('w:Chain', ns)
msi = chain.find('w:MsiPackage', ns) if chain is not None else None
msi_property = msi.find("w:MsiProperty[@Name='INSTALLDIR']", ns) if msi is not None else None
assert msi_property is not None and msi_property.get('Value') == '[InstallFolder]', 'MSI INSTALLDIR must receive the Burn folder value'

def formatted_default(value):
    return value.replace('[ProgramFiles64Folder]', r'C:\Program Files')

def msi_install_dir(folder_value):
    return msi_property.get('Value').replace('[InstallFolder]', folder_value)

default_path = msi_install_dir(formatted_default(install_folder.get('Value')))
custom_path = msi_install_dir(r'D:\Beskid Tools\Beskid')
assert default_path == r'C:\Program Files\Beskid', f'default path resolved to {default_path!r}'
assert custom_path == r'D:\Beskid Tools\Beskid', f'custom path resolved to {custom_path!r}'

condition = bundle.find("bal:Condition[@Condition='InstallFolder <> \"\"']", ns)
message_ref = condition.get('Message', '') if condition is not None else ''
assert message_ref == '$(loc.InstallFolderRequired)', 'Burn must reject an empty install folder with a localized message'
message_id = message_ref[len('$(loc.'):-1]
localized_message = strings.find(f"wxl:String[@Id='{message_id}']", ns)
assert localized_message is not None and localized_message.get('Value'), 'blank-folder rejection message must resolve in the theme localization'
def permits_install(expression, folder_value):
    match = re.fullmatch(r'InstallFolder\s*<>\s*""', expression)
    assert match, 'unexpected blank-folder guard expression'
    return folder_value != ''

assert not permits_install(condition.get('Condition', ''), ''), 'empty initial folder must fail the Burn condition'
assert permits_install(condition.get('Condition', ''), default_path)
assert permits_install(condition.get('Condition', ''), custom_path)

def leave_options(edited_value):
    # WixStdBA writes the editbox variable while leaving Options. The following
    # page condition must evaluate the committed value, not the earlier default.
    committed_folder = edited_value
    next_action = continue_action.get('Condition')
    assert next_action == condition.get('Condition'), 'post-Options and startup guards must reject the same empty value'
    return 'Install' if permits_install(next_action, committed_folder) else 'InstallFolderCheck'

assert leave_options('') == 'InstallFolderCheck', 'clearing Options must not reach the MSI install page'
assert leave_options(default_path) == 'Install', 'default folder must continue to installation'
assert leave_options(custom_path) == 'Install', 'custom folder must continue to installation'

def cancel_after_back(committed_value, pending_edit):
    page_after_back = back_action.get('Page')
    assert page_after_back == 'Options', 'validation Back must return to Options'
    # Cancel=yes discards the current Options edits, preserving the value that
    # was committed when Options was first left for the validation page.
    restored_value = committed_value
    return options_cancel.get('Page'), restored_value

page_after_cancel, value_after_cancel = cancel_after_back('', default_path)
assert page_after_cancel == 'InstallFolderCheck', 'Cancel after Back must revisit the guard page'
cancel_result = 'Install' if permits_install(continue_action.get('Condition', ''), value_after_cancel) else 'InstallFolderCheck'
assert cancel_result == 'InstallFolderCheck', 'blank committed value must remain blocked after Back and Cancel'
PY

# A standalone MSI requires the same 14.40+ runtime as Burn; repair/uninstall stay open.
grep -Fq "Key='SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64'" "${msi_source}" || \
  fail 'MSI does not search for the x64 Visual C++ runtime'
grep -Fq "Property Id='VCREDISTX64DLL'" "${msi_source}" || \
  fail 'MSI does not search for the versioned Visual C++ runtime DLL'
grep -Fq "Name='vcruntime140.dll' MinVersion='14.40.0.0'" "${msi_source}" || \
  fail 'MSI does not require Visual C++ runtime file version 14.40+'
grep -Fq "Path='[System64Folder]'" "${msi_source}" || \
  fail 'MSI does not search the 64-bit system folder'
grep -Fq "Bitness='always64'" "${msi_source}" || \
  fail 'MSI registry search does not read the 64-bit registry view'
grep -Fq "Condition='Installed OR (VCREDISTX64INSTALLED = \"#1\" AND VCREDISTX64DLL)'" "${msi_source}" || \
  fail 'MSI does not block installation without the 14.40+ Visual C++ runtime'

# The MSVC Build Tools and the Windows SDK are not redistributable. Neither
# package may carry them; the guide documents them for `beskid build`/`run`.
if grep -Eq 'SourceFile=.*(vc_redist|vs_BuildTools|LLVM-)' "${tmp}/prerequisites.wxs"; then
  fail 'vendor bytes are embedded in the prerequisite fragment'
fi
for phrase in 'VCRUNTIME140.dll' 'Desktop development with C++' 'Windows SDK' \
  'fresh ordinary shell' 'InstallDeveloperTools=1' 'SHA-512' \
  'beskid test' 'beskid build' 'llvm-ml'; do
  grep -Fq "${phrase}" "${guide}" || fail "Windows guide does not document: ${phrase}"
done

printf 'Windows WiX contract tests OK\n'
