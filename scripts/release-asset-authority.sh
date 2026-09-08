#!/usr/bin/env bash
# Verify one GitHub Release asset against the compiler release manifest and
# GitHub's publisher-computed SHA-256 before making it visible to packaging.

release_asset_sha256() {
  local path="${1:?asset path}"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${path}" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "${path}" | awk '{print $1}'
  else
    echo 'A SHA-256 implementation (sha256sum or shasum) is required.' >&2
    return 1
  fi
}

fetch_verified_release_asset() {
  local repo="${1:?repository}"
  local tag="${2:?release tag}"
  local expected_version="${3:-}"
  local asset="${4:?asset name}"
  local destination="${5:?destination path}"
  local staging manifest release_json digest expected actual

  command -v jq >/dev/null 2>&1 || {
    echo 'jq is required to verify compiler release authority.' >&2
    return 1
  }

  staging="$(mktemp -d)"
  manifest="${staging}/release-state.json"
  if ! gh release download "${tag}" --repo "${repo}" --pattern release-state.json --dir "${staging}" --clobber; then
    echo "Release authority is missing for ${repo}@${tag}." >&2
    rm -rf "${staging}"
    return 1
  fi
  if ! jq -e --arg version "${expected_version}" --arg asset "${asset}" '
      .schema_version == 1 and
      .publishable == true and
      (.version | type == "string" and length > 0) and
      ($version == "" or .version == $version) and
      (.available_artifacts | type == "array" and index($asset) != null)
    ' "${manifest}" >/dev/null; then
    echo "Release manifest does not authorize ${asset} for ${tag}." >&2
    rm -rf "${staging}"
    return 1
  fi

  if ! release_json="$(gh api "repos/${repo}/releases/tags/${tag}")"; then
    echo "Release asset metadata is unavailable for ${repo}@${tag}." >&2
    rm -rf "${staging}"
    return 1
  fi
  if ! digest="$(jq -er --arg asset "${asset}" '
      [.assets[]? | select(.name == $asset) | .digest]
      | if length == 1 then .[0] else empty end
    ' <<<"${release_json}")"; then
    echo "Release asset checksum is missing or ambiguous for ${asset}." >&2
    rm -rf "${staging}"
    return 1
  fi
  case "${digest}" in
    sha256:[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*) ;;
    *)
      echo "Release asset checksum is not SHA-256 for ${asset}." >&2
      rm -rf "${staging}"
      return 1
      ;;
  esac
  expected="${digest#sha256:}"
  if [[ ! "${expected}" =~ ^[0-9a-f]{64}$ ]]; then
    echo "Release asset checksum is not SHA-256 for ${asset}." >&2
    rm -rf "${staging}"
    return 1
  fi

  if ! gh release download "${tag}" --repo "${repo}" --pattern "${asset}" --dir "${staging}" --clobber; then
    rm -rf "${staging}"
    return 1
  fi
  actual="$(release_asset_sha256 "${staging}/${asset}")" || {
    rm -rf "${staging}"
    return 1
  }
  if [[ "${actual}" != "${expected}" ]]; then
    echo "Release asset checksum mismatch for ${asset}: expected ${expected}, got ${actual}." >&2
    rm -rf "${staging}"
    return 1
  fi

  mv -f "${staging}/${asset}" "${destination}"
  rm -rf "${staging}"
}
