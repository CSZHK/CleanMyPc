#!/bin/bash

atlas_local_signing_keychain_path() {
  printf '%s\n' "${ATLAS_LOCAL_SIGNING_KEYCHAIN_PATH:-$HOME/Library/Keychains/AtlasLocalSigning.keychain-db}"
}

atlas_local_signing_keychain_password() {
  printf '%s\n' "${ATLAS_LOCAL_SIGNING_KEYCHAIN_PASSWORD:-atlas-local-signing}"
}

atlas_local_signing_identity_name() {
  printf '%s\n' "${ATLAS_LOCAL_SIGNING_IDENTITY_NAME:-Atlas Local Development}"
}

atlas_detect_release_app_identity() {
  security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' \
    | head -1
}

atlas_detect_development_app_identity() {
  local output
  output="$(security find-identity -v -p codesigning 2>/dev/null || true)"

  local identity
  identity="$(printf '%s\n' "$output" | sed -n 's/.*"\(Apple Development:.*\)"/\1/p' | head -1)"
  if [[ -n "$identity" ]]; then
    printf '%s\n' "$identity"
    return 0
  fi

  printf '%s\n' "$output" | sed -n 's/.*"\(Mac Developer:.*\)"/\1/p' | head -1
}

atlas_detect_installer_identity() {
  security find-identity -v -p basic 2>/dev/null \
    | sed -n 's/.*"\(Developer ID Installer:.*\)"/\1/p' \
    | head -1
}

atlas_local_identity_exists() {
  local keychain_path identity_name
  keychain_path="$(atlas_local_signing_keychain_path)"
  identity_name="$(atlas_local_signing_identity_name)"

  [[ -f "$keychain_path" ]] || return 1
  security find-certificate -a -c "$identity_name" "$keychain_path" >/dev/null 2>&1
}

atlas_unlock_local_signing_keychain() {
  local keychain_path keychain_password
  keychain_path="$(atlas_local_signing_keychain_path)"
  keychain_password="$(atlas_local_signing_keychain_password)"

  [[ -f "$keychain_path" ]] || return 0
  security unlock-keychain -p "$keychain_password" "$keychain_path" >/dev/null 2>&1 || true
  security set-keychain-settings -lut 21600 "$keychain_path" >/dev/null 2>&1 || true
  atlas_add_local_signing_keychain_to_search_list
}

atlas_add_local_signing_keychain_to_search_list() {
  local keychain_path
  keychain_path="$(atlas_local_signing_keychain_path)"

  [[ -f "$keychain_path" ]] || return 0

  local current_keychains=()
  while IFS= read -r line; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%\"}"
    line="${line#\"}"
    [[ -n "$line" ]] && current_keychains+=("$line")
  done < <(security list-keychains -d user 2>/dev/null || true)

  if printf '%s\n' "${current_keychains[@]}" | grep -Fx "$keychain_path" >/dev/null 2>&1; then
    return 0
  fi

  security list-keychains -d user -s "$keychain_path" "${current_keychains[@]}" >/dev/null 2>&1 || true
}

atlas_local_identity_usable() {
  atlas_local_identity_exists || return 1

  local keychain_path identity_name sample_file
  keychain_path="$(atlas_local_signing_keychain_path)"
  identity_name="$(atlas_local_signing_identity_name)"

  atlas_unlock_local_signing_keychain

  sample_file="$(mktemp "${TMPDIR:-/tmp}/atlas-local-signing-check.XXXXXX")"
  printf 'atlas local signing check\n' > "$sample_file"
  if ! /usr/bin/codesign --force --sign "$identity_name" --keychain "$keychain_path" "$sample_file" >/dev/null 2>&1; then
    rm -f "$sample_file"
    return 1
  fi

  rm -f "$sample_file"
  return 0
}

atlas_signing_mode_for_identity() {
  local identity="${1:-}"
  local local_identity_name
  local_identity_name="$(atlas_local_signing_identity_name)"

  if [[ -z "$identity" || "$identity" == "-" ]]; then
    printf '%s\n' "adhoc"
  elif [[ "$identity" == Developer\ ID\ Application:* ]]; then
    printf '%s\n' "developer-id"
  elif [[ "$identity" == "$local_identity_name" ]]; then
    printf '%s\n' "local-stable"
  else
    printf '%s\n' "local-stable"
  fi
}

atlas_resolve_app_signing_identity() {
  if [[ -n "${ATLAS_CODESIGN_IDENTITY:-}" ]]; then
    printf '%s\n' "$ATLAS_CODESIGN_IDENTITY"
    return 0
  fi

  local identity
  identity="$(atlas_detect_release_app_identity)"
  if [[ -n "$identity" ]]; then
    printf '%s\n' "$identity"
    return 0
  fi

  identity="$(atlas_detect_development_app_identity)"
  if [[ -n "$identity" ]]; then
    printf '%s\n' "$identity"
    return 0
  fi

  if atlas_local_identity_usable; then
    printf '%s\n' "$(atlas_local_signing_identity_name)"
    return 0
  fi

  printf '%s\n' "-"
}

atlas_resolve_app_signing_keychain() {
  local identity="${1:-}"

  if [[ -n "${ATLAS_CODESIGN_KEYCHAIN:-}" ]]; then
    printf '%s\n' "$ATLAS_CODESIGN_KEYCHAIN"
    return 0
  fi

  if [[ "$identity" == "$(atlas_local_signing_identity_name)" ]] && atlas_local_identity_exists; then
    printf '%s\n' "$(atlas_local_signing_keychain_path)"
    return 0
  fi

  printf '%s\n' ""
}

atlas_resolve_installer_signing_identity() {
  if [[ -n "${ATLAS_INSTALLER_SIGN_IDENTITY:-}" ]]; then
    printf '%s\n' "$ATLAS_INSTALLER_SIGN_IDENTITY"
    return 0
  fi

  atlas_detect_installer_identity
}
