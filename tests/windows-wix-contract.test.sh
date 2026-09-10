#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
msi_builder="${root}/windows/build-msi.sh"
msi_source="${root}/windows/beskid.wxs"
bundle_source="${root}/windows/beskid.bundle.wxs"

grep -Fq -- '-arch x64' "${msi_builder}" || {
  echo 'Windows MSI builds must explicitly target x64.' >&2
  exit 1
}
grep -Fq '<SummaryInformation' "${msi_source}" || {
  echo 'Windows MSI metadata must use the WiX v4 SummaryInformation element.' >&2
  exit 1
}
grep -Fq "Scope='perMachine'" "${msi_source}" || {
  echo 'Windows MSI package scope must be per-machine.' >&2
  exit 1
}
for source in "${msi_source}" "${bundle_source}"; do
  grep -Fq "encoding='utf-8'" "${source}" || {
    echo "Windows installer XML must declare UTF-8: ${source}" >&2
    exit 1
  }
done
if grep -Fq "Id='ALLUSERS'" "${msi_source}"; then
  echo 'Package Scope already owns ALLUSERS; an explicit duplicate is forbidden.' >&2
  exit 1
fi
if grep -Eq 'DowngradeErrorMessage=.*\[[0-9]+\]' "${msi_source}"; then
  echo 'DowngradeErrorMessage must not contain an unresolved numeric MSI token.' >&2
  exit 1
fi

printf 'Windows WiX contract tests OK\n'
