#!/usr/bin/env bash
# Verify a release-audit copy of the pinned VC++ redistributable on Windows.
# The setup EXE references a remote payload; it never embeds this file.

verify_vc_redist_signature() {
  local file="${1:?vc_redist path}"
  local shell=''
  if command -v powershell.exe >/dev/null 2>&1; then shell=powershell.exe
  elif command -v pwsh >/dev/null 2>&1; then shell=pwsh
  else
    echo 'PowerShell is required to verify the VC++ Authenticode signature.' >&2
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
