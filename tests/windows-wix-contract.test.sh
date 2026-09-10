#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
msi_builder="${root}/windows/build-msi.sh"
msi_source="${root}/windows/beskid.wxs"
bundle_source="${root}/windows/beskid.bundle.wxs"

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

printf 'Windows WiX contract tests OK\n'
