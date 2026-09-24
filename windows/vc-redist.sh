#!/usr/bin/env bash
# Resolve the Microsoft Visual C++ 2015-2022 Redistributable (x64) that the
# Burn bootstrapper embeds and chains before the Beskid MSI.
#
# beskid.exe, beskid_lsp.exe, beskid-up.exe, the ABI-v5 runtime DLL, and every
# executable that `beskid build` links import VCRUNTIME140.dll. The UCRT
# (api-ms-win-crt-*) is part of Windows 10 and later. Microsoft licenses
# vc_redist.x64.exe as distributable code, so the bundle carries it.
#
# The redistributable is embedded rather than referenced as a remote payload:
# the official URL always serves the newest build, so a payload hash recorded
# at bundle build time would stop matching after Microsoft updates the file.
#
# Source of the file, in order:
#   BESKID_VC_REDIST_X64  path to a vc_redist.x64.exe that the caller vouches
#                         for (offline builds, pinned mirrors, tests)
#   otherwise             download from BESKID_VC_REDIST_X64_URL (default: the
#                         official Microsoft permalink) and require a valid
#                         Authenticode signature from Microsoft Corporation.
#                         Verification needs Windows PowerShell or pwsh and
#                         fails closed without one.

BESKID_VC_REDIST_X64_OFFICIAL_URL='https://aka.ms/vs/17/release/vc_redist.x64.exe'

verify_vc_redist_signature() {
  local file="${1:?vc_redist path}"
  local shell=''
  if command -v powershell.exe >/dev/null 2>&1; then shell=powershell.exe
  elif command -v pwsh >/dev/null 2>&1; then shell=pwsh
  else
    echo "Cannot verify the Authenticode signature of ${file}: PowerShell is unavailable." >&2
    echo "Set BESKID_VC_REDIST_X64 to a vc_redist.x64.exe you have verified." >&2
    return 1
  fi
  local native="${file}"
  command -v cygpath >/dev/null 2>&1 && native="$(cygpath -w "${file}")"
  # shellcheck disable=SC2016 # PowerShell, not bash, expands this script.
  BESKID_VC_REDIST_VERIFY_PATH="${native}" "${shell}" -NoProfile -NonInteractive -Command '
    $s = Get-AuthenticodeSignature -LiteralPath $env:BESKID_VC_REDIST_VERIFY_PATH
    if ($s.Status -ne "Valid") { Write-Error "signature status: $($s.Status)"; exit 1 }
    if ($s.SignerCertificate.Subject -notmatch "O=Microsoft Corporation") {
      Write-Error "unexpected signer: $($s.SignerCertificate.Subject)"; exit 1
    }
  ' || {
    echo "Rejected ${file}: not a valid Microsoft-signed redistributable." >&2
    return 1
  }
}

# Print the path of a verified vc_redist.x64.exe. Downloads land in <work-dir>.
resolve_vc_redist_x64() {
  local work_dir="${1:?work directory}"
  if [[ -n "${BESKID_VC_REDIST_X64:-}" ]]; then
    [[ -s "${BESKID_VC_REDIST_X64}" ]] || {
      echo "BESKID_VC_REDIST_X64 does not name a file: ${BESKID_VC_REDIST_X64}" >&2
      return 1
    }
    printf '%s\n' "${BESKID_VC_REDIST_X64}"
    return 0
  fi

  local url="${BESKID_VC_REDIST_X64_URL:-${BESKID_VC_REDIST_X64_OFFICIAL_URL}}"
  local file="${work_dir}/vc_redist.x64.exe"
  command -v curl >/dev/null 2>&1 || { echo "curl is required to download ${url}" >&2; return 1; }
  curl --fail --location --silent --show-error --proto '=https' --proto-redir '=https' --tlsv1.2 -o "${file}" "${url}" || {
    echo "Failed to download the Visual C++ Redistributable from ${url}" >&2
    return 1
  }
  verify_vc_redist_signature "${file}" || return 1
  printf '%s\n' "${file}"
}
