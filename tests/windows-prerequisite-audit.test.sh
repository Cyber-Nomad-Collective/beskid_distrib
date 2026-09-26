#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

[[ -f "${root}/windows/audit-prerequisites.sh" ]] || {
  echo 'FAIL: release-audit command is missing' >&2
  exit 1
}

# An audit with no independently verified vendor files cannot pass.
if bash "${root}/windows/audit-prerequisites.sh" "${tmp}" >"${tmp}/audit.log" 2>&1; then
  echo 'FAIL: release audit accepted missing vendor payloads' >&2
  exit 1
fi

# Supply complete, hash-matching small fixtures to reach the provenance gate.
node - "${root}/windows/prerequisites.lock.json" "${tmp}/fixture-lock.json" "${tmp}" <<'NODE'
const fs = require('node:fs');
const crypto = require('node:crypto');
const path = require('node:path');
const lock = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
for (const item of lock.packages) {
  const bytes = Buffer.from(`audit fixture ${item.id}`);
  fs.writeFileSync(path.join(process.argv[4], item.name), bytes);
  item.size = bytes.length;
  item.sha512 = crypto.createHash('sha512').update(bytes).digest('hex');
}
fs.writeFileSync(process.argv[3], JSON.stringify(lock));
NODE
if BESKID_PREREQUISITES_LOCK="${tmp}/fixture-lock.json" \
  bash "${root}/windows/audit-prerequisites.sh" "${tmp}" >"${tmp}/audit.log" 2>&1; then
  echo 'FAIL: release audit accepted an EXE without signed provenance' >&2
  exit 1
fi
grep -Fq 'Missing LLVM signed attestation' "${tmp}/audit.log" || {
  echo 'FAIL: release audit did not reach the signed-provenance gate' >&2
  exit 1
}

# No Windows signature verifier is available in this deliberately restricted PATH.
# Even if the hash phase is satisfied in a future fixture, the audit must refuse
# a signature-free release rather than accepting unsigned vendor bytes.
if PATH='/usr/bin:/bin' bash -c 'source "$1"; verify_microsoft_exe_signature "$2"' bash \
  "${root}/windows/vc-redist.sh" "${tmp}/unsigned.exe" >"${tmp}/signature.log" 2>&1; then
  echo 'FAIL: Authenticode helper accepted an unverifiable EXE' >&2
  exit 1
fi

printf 'Windows prerequisite audit fail-closed tests OK\n'
