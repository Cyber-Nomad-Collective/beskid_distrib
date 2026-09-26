#!/usr/bin/env bash
# Verify release-audit copies of Microsoft prerequisite EXEs on Windows.
# The setup EXE references remote payloads; it never embeds these files.

verify_microsoft_exe_signature() {
  local file="${1:?Microsoft EXE path}"
  local shell=''
  if command -v powershell.exe >/dev/null 2>&1; then shell=powershell.exe
  elif command -v pwsh >/dev/null 2>&1; then shell=pwsh
  else
    echo 'PowerShell is required to verify Microsoft Authenticode signatures.' >&2
    return 1
  fi
  local native="${file}"
  command -v cygpath >/dev/null 2>&1 && native="$(cygpath -w "${file}")"
  # shellcheck disable=SC2016 # PowerShell expands the script.
  BESKID_VC_REDIST_VERIFY_PATH="${native}" "${shell}" -NoProfile -NonInteractive -Command '
    $s = Get-AuthenticodeSignature -LiteralPath $env:BESKID_VC_REDIST_VERIFY_PATH
    if ($s.Status -ne "Valid") { Write-Error "signature status: $($s.Status)"; exit 1 }
    if ($s.SignerCertificate.Subject -notmatch "O=Microsoft Corporation") {
      Write-Error "unexpected signer: $($s.SignerCertificate.Subject)"; exit 1
    }
  '
}
