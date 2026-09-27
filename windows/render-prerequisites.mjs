#!/usr/bin/env node
import { createReadStream, readFileSync, statSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join } from 'node:path';

const [lockPath, outputPath] = process.argv.slice(2);
if (!lockPath || !outputPath) {
  console.error('Usage: render-prerequisites.mjs <lock.json> <fragment.wxs>');
  process.exit(2);
}

function ValidateUrl(value, field, artifact = false) {
  if (typeof value !== 'string') throw new Error(`${field} must be an HTTPS URL`);
  const url = new URL(value);
  if (url.protocol !== 'https:' || url.username || url.password || (artifact && (url.search || url.hash))) {
    throw new Error(`${field} must be an HTTPS URL without credentials or a mutable artifact query`);
  }
  return url;
}

function EscapeXml(value) {
  return String(value).replace(/[&"'<>]/g, char => ({ '&': '&amp;', '"': '&quot;', "'": '&apos;', '<': '&lt;', '>': '&gt;' })[char]);
}

const lock = JSON.parse(readFileSync(lockPath, 'utf8'));
const expectedIds = ['VcRedistX64', 'VsBuildTools2022', 'LlvmX64'];
if (lock.schemaVersion !== 1 || !Array.isArray(lock.packages) || lock.packages.length !== expectedIds.length) {
  throw new Error('prerequisite lock must contain the three ordered packages');
}
for (const [index, item] of lock.packages.entries()) {
  if (item.id !== expectedIds[index]) throw new Error(`unexpected package at position ${index}`);
  for (const field of ['vendor', 'product', 'version', 'name']) {
    if (typeof item[field] !== 'string' || !item[field].trim()) throw new Error(`${item.id}.${field} is required`);
  }
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]*\.exe$/i.test(item.name)) throw new Error(`${item.id}.name is invalid`);
  if (!/^[a-fA-F0-9]{128}$/.test(item.sha512 ?? '')) throw new Error(`${item.id}.sha512 must be SHA-512 hex`);
  if (!Number.isSafeInteger(item.size) || item.size <= 0) throw new Error(`${item.id}.size must be positive bytes`);
  const url = ValidateUrl(item.url, `${item.id}.url`, true);
  ValidateUrl(item.sourceUrl, `${item.id}.sourceUrl`);
  ValidateUrl(item.licenseUrl, `${item.id}.licenseUrl`);
  if (item.id === 'LlvmX64') {
    // The CDN asset URL expires. Use LLVM's official release permalink; the
    // locked size/hash and signed attestation still bind the exact bytes.
    if (url.href !== `https://github.com/llvm/llvm-project/releases/download/llvmorg-${item.version}/${item.name}`) {
      throw new Error('LLVM URL must identify the locked official release installer');
    }
    const attestation = ValidateUrl(item.attestationUrl, `${item.id}.attestationUrl`, true);
    if (attestation.hostname !== 'github.com' || attestation.pathname !== `/llvm/llvm-project/releases/download/llvmorg-${item.version}/${item.name}.jsonl` ||
      !/^[a-fA-F0-9]{40}$/.test(item.sourceCommit ?? '')) throw new Error('LLVM signed attestation provenance is required');
  } else if (url.hostname !== 'download.visualstudio.microsoft.com' ||
    !/^\/download\/pr\/[0-9a-f-]{36}\/[0-9a-f]{64}\/[^/]+\.exe$/i.test(url.pathname)) {
    throw new Error(`${item.id} URL must identify a content-addressed Microsoft artifact`);
  }
}

if (process.env.BESKID_PREREQUISITES_AUDIT_DIR) {
  for (const item of lock.packages) {
    const copy = join(process.env.BESKID_PREREQUISITES_AUDIT_DIR, item.name);
    if (statSync(copy).size !== item.size) throw new Error(`${item.id} audit size mismatch`);
    const digest = createHash('sha512');
    for await (const chunk of createReadStream(copy)) digest.update(chunk);
    if (digest.digest('hex').toLowerCase() !== item.sha512.toLowerCase()) {
      throw new Error(`${item.id} audit SHA-512 mismatch`);
    }
  }
}

const packages = lock.packages.map(item => {
  const common = `Id="${item.id}" DisplayName="${EscapeXml(item.product)} ${EscapeXml(item.version)}" PerMachine="yes" Permanent="yes" Vital="yes" Cache="remove"`;
  const payload = `<ExePackagePayload Name="${EscapeXml(item.name)}" DownloadUrl="${EscapeXml(item.url)}" Hash="${item.sha512.toUpperCase()}" Size="${item.size}" />`;
  if (item.id === 'VcRedistX64') return `  <PackageGroup Id="VcRedistX64Group">
    <ExePackage ${common} DetectCondition="VcRedistX64Installed = 1 AND VcRedistX64Minor &gt;= 40" InstallArguments="/install /quiet /norestart" RepairArguments="/repair /quiet /norestart">
      ${payload}
      <ExitCode Value="1638" Behavior="success" />
      <ExitCode Value="3010" Behavior="scheduleReboot" />
    </ExePackage>
  </PackageGroup>`;
  if (item.id === 'VsBuildTools2022') {
    // VsDevCmd.bat proves only that an instance exists, not that it has the
    // requested x64 compiler and SDK. The same signed bootstrapper supports
    // Microsoft's modify verb; running it on an existing instance completes
    // missing components and is a no-op when they are already present.
    const components = '--add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.26100';
    return `  <PackageGroup Id="VsBuildTools2022Group">
    <ExePackage ${common} InstallCondition="InstallDeveloperTools = 1">
      ${payload}
      <CommandLine Condition="VsBuildToolsInstalled" InstallArgument="modify --installPath &quot;[ProgramFilesFolder]Microsoft Visual Studio\\2022\\BuildTools&quot; --quiet --wait --norestart ${components}" />
      <CommandLine Condition="NOT VsBuildToolsInstalled" InstallArgument="--quiet --wait --norestart ${components}" />
      <ExitCode Value="3010" Behavior="scheduleReboot" />
    </ExePackage>
  </PackageGroup>`;
  }
  return `  <PackageGroup Id="${item.id}Group">
    <ExePackage ${common} DetectCondition="LlvmX64Installed" InstallCondition="InstallDeveloperTools = 1" InstallArguments="/S">
      ${payload}
      <ExitCode Value="3010" Behavior="scheduleReboot" />
    </ExePackage>
  </PackageGroup>`;
});

writeFileSync(outputPath, `<?xml version="1.0" encoding="utf-8"?>
<Wix xmlns="http://wixtoolset.org/schemas/v4/wxs">
<Fragment>
${packages.join('\n')}
</Fragment>
</Wix>
`);
