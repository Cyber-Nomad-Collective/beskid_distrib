#!/usr/bin/env bash
# Release gate for separately downloaded vendor EXEs and LLVM's signed provenance.
# Usage: audit-prerequisites.sh <directory containing the three locked EXEs and LLVM .jsonl>
set -euo pipefail

audit_dir="${1:?vendor audit directory}"
root="$(cd "$(dirname "$0")/.." && pwd)"
lock="${BESKID_PREREQUISITES_LOCK:-${root}/windows/prerequisites.lock.json}"
[[ -d "${audit_dir}" ]] || { echo "Missing vendor audit directory: ${audit_dir}" >&2; exit 1; }

# The renderer validates lock fields and every local byte before a signature is trusted.
fragment="$(mktemp "${TMPDIR:-/tmp}/beskid-prerequisites-audit.XXXXXX")"
trap 'rm -f "${fragment}"' EXIT
BESKID_PREREQUISITES_AUDIT_DIR="${audit_dir}" \
  node "${root}/windows/render-prerequisites.mjs" "${lock}" "${fragment}"

# shellcheck source=vc-redist.sh
source "${root}/windows/vc-redist.sh"
vc_name="$(node -e 'const l=require(process.argv[1]);process.stdout.write(l.packages[0].name)' "${lock}")"
vs_name="$(node -e 'const l=require(process.argv[1]);process.stdout.write(l.packages[1].name)' "${lock}")"
llvm_name="$(node -e 'const l=require(process.argv[1]);process.stdout.write(l.packages[2].name)' "${lock}")"
source_commit="$(node -e 'const l=require(process.argv[1]);process.stdout.write(l.packages[2].sourceCommit)' "${lock}")"

attestation="${audit_dir}/${llvm_name}.jsonl"
[[ -s "${attestation}" ]] || { echo "Missing LLVM signed attestation: ${attestation}" >&2; exit 1; }
command -v gh >/dev/null 2>&1 || { echo 'GitHub CLI is required for LLVM attestation verification.' >&2; exit 1; }
gh attestation verify "${audit_dir}/${llvm_name}" \
  --repo llvm/llvm-project \
  --bundle "${attestation}" \
  --signer-workflow llvm/llvm-project/.github/workflows/release-binaries.yml \
  --source-digest "${source_commit}"

verify_microsoft_exe_signature "${audit_dir}/${vc_name}"
verify_microsoft_exe_signature "${audit_dir}/${vs_name}"

echo 'Vendor payload hashes, Microsoft Authenticode signatures, and LLVM signed provenance verified.'
