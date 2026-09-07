#!/usr/bin/env bash
# Shared release-version contracts for distribution consumers.

validate_distribution_version() {
  local version="${1:-}"
  if [[ ! "${version}" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-unstable)?$ ]]; then
    echo "version must be X.Y.Z or X.Y.Z-unstable: ${version:-<empty>}" >&2
    return 1
  fi
}

windows_installer_version() {
  local version="${1:-}"
  validate_distribution_version "${version}" || return 1
  printf '%s' "${version%-unstable}"
}
