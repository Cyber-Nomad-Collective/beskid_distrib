#!/usr/bin/env bash
# Deterministic WiX CLI/extension setup shared by the MSI and Burn builders.

BESKID_WIX_VERSION=4.0.6

ensure_wix_toolchain() {
  export PATH="${PATH}:${HOME}/.dotnet/tools"

  local installed_version=''
  if command -v wix >/dev/null 2>&1; then
    installed_version="$(wix --version 2>/dev/null | tr -d '\r[:space:]' || true)"
  fi

  if [[ -z "${installed_version}" ]]; then
    dotnet tool install --global wix --version "${BESKID_WIX_VERSION}"
  elif [[ "${installed_version}" != "${BESKID_WIX_VERSION}" ]]; then
    dotnet tool update --global wix --version "${BESKID_WIX_VERSION}"
  fi
}

load_wix_extension() {
  local extension="${1:?WiX extension package}"
  ensure_wix_toolchain
  wix extension add -g "${extension}/${BESKID_WIX_VERSION}"
}
