#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/test_helper/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/test_helper/bats-assert/load.bash"

setup() {
  export HOME="$(mktemp -d)"
  export XDG_CONFIG_HOME="$HOME/.config"
  export XDG_DATA_HOME="$HOME/.local/share"
  export XDG_STATE_HOME="$HOME/.local/state"
  export STUB_DIR="$(mktemp -d)"
  export PATH="$STUB_DIR:$PATH"
}

teardown() {
  export PATH=$(echo "$PATH" | sed "s|$STUB_DIR:||")
  rm -rf "$HOME" "$STUB_DIR"
}

run_isolated() {
  run env -i \
      HOME="$HOME" \
      XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
      XDG_DATA_HOME="$XDG_DATA_HOME" \
      XDG_STATE_HOME="$XDG_STATE_HOME" \
      PATH="$PATH" \
      bash -c "$@"
}

# --- TESTS ---

@test "geoupdate.unit: check_dependencies() - when all dependencies exist - should exit 0" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../geoupdate"
    command() { return 0; }
    check_dependencies
  '

  assert_success
}

@test "geoupdate.unit: check_dependencies() - when a dependency is missing - should print error and exit 1" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../geoupdate"
    
    # Mock failure specifically for "curl" to verify error handling logic.
    command() {
      [[ "$2" == "curl" ]] && return 1
      return 0
    }
    
    check_dependencies
  '

  assert_failure 1
  assert_output --partial "ERROR: Required command not found: 'curl'"
}

@test "geoupdate.unit: run_update() - with missing credentials - should print error and exit 1" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../geoupdate"
    
    # Initialize required globals to satisfy set -u, but leave credentials unset.
    export MMDB_FILE="${HOME}/.local/share/geoip/GeoLite2-City.mmdb"
    export STATE_DIR="${HOME}/.local/state"
    
    run_update
  '

  assert_failure 1
  assert_output --partial "ERROR: MAXMIND_ID is not set"
}

@test "geoupdate.unit: run_update() - happy path - should download, verify and unpack and exit 0" {
  cat > "$STUB_DIR/curl" <<EOF
#!/usr/bin/env bash
while [[ \$# -gt 0 ]]; do
  if [[ "\$1" == "-o" ]]; then touch "\$2"; fi
  shift
done
exit 0
EOF
  chmod +x "$STUB_DIR/curl"

  cat > "$STUB_DIR/sha256sum" <<EOF
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$STUB_DIR/sha256sum"

  cat > "$STUB_DIR/tar" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "-tf" ]]; then
  echo "GeoLite2-City.mmdb"
elif [[ "\$1" == "-xzf" ]]; then
  extract_dir=""
  while [[ \$# -gt 0 ]]; do
    if [[ "\$1" == "-C" ]]; then extract_dir="\$2"; fi
    shift
  done
  mkdir -p "\$extract_dir"
  touch "\$extract_dir/GeoLite2-City.mmdb"
fi
exit 0
EOF
  chmod +x "$STUB_DIR/tar"

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../geoupdate"

    export MAXMIND_ID="test_user"
    export MAXMIND_TOKEN="test_key"
    export MMDB_FILE="${HOME}/.local/share/geoip/GeoLite2-City.mmdb"
    export STATE_DIR="${HOME}/.local/state"
    export DOWNLOAD_URL="http://mock.url/db"
    export SHA_URL="http://mock.url/sha"

    mkdir -p "$STATE_DIR"
    TMP_DIR=""

    run_update
  '

  assert_success
  assert_output --partial "GeoLite2-City database updated successfully."
}

@test "geoupdate.unit: run_update() - when download fails - should exit 22" {
  # Simulate a specific curl error code (22 = HTTP error).
  cat > "$STUB_DIR/curl" <<EOF
#!/usr/bin/env bash
exit 22
EOF
  chmod +x "$STUB_DIR/curl"

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../geoupdate"
    
    export MAXMIND_ID="test_user"
    export MAXMIND_TOKEN="test_key"
    export MMDB_FILE="${HOME}/.local/share/geoip/GeoLite2-City.mmdb"
    export STATE_DIR="${HOME}/.local/state"
    export DOWNLOAD_URL="http://mock.url/db"
    export SHA_URL="http://mock.url/sha"
    
    mkdir -p "$STATE_DIR"
    TMP_DIR=""
    
    run_update
  '

  assert_failure 22
}

@test "geoupdate.unit: run_update() - when checksum mismatches - should print error and exit 1" {
  # Mock curl to succeed and create dummy files so script proceeds to verification.
  cat > "$STUB_DIR/curl" <<EOF
#!/usr/bin/env bash
while [[ \$# -gt 0 ]]; do
  if [[ "\$1" == "-o" ]]; then touch "\$2"; fi
  shift
done
exit 0
EOF
  chmod +x "$STUB_DIR/curl"

  # Mock sha256sum to fail, simulating data corruption.
  cat > "$STUB_DIR/sha256sum" <<EOF
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "$STUB_DIR/sha256sum"

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../geoupdate"
    
    export MAXMIND_ID="test_user"
    export MAXMIND_TOKEN="test_key"
    export MMDB_FILE="${HOME}/.local/share/geoip/GeoLite2-City.mmdb"
    export STATE_DIR="${HOME}/.local/state"
    export DOWNLOAD_URL="http://mock.url/db"
    export SHA_URL="http://mock.url/sha"
    
    mkdir -p "$STATE_DIR"
    TMP_DIR=""
    
    run_update
  '

  assert_failure 1
  assert_output --partial "ERROR: SHA256 mismatch!"
}

@test "geoupdate.unit: run_update() - security: tar slip attempt - should abort extraction and exit 1" {
  cat > "$STUB_DIR/curl" <<EOF
#!/usr/bin/env bash
while [[ \$# -gt 0 ]]; do
  if [[ "\$1" == "-o" ]]; then touch "\$2"; fi
  shift
done
exit 0
EOF
  chmod +x "$STUB_DIR/curl"

  cat > "$STUB_DIR/sha256sum" <<EOF
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$STUB_DIR/sha256sum"

  # Trap extraction attempt (-xzf) to verify security abort.
  cat > "$STUB_DIR/tar" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "-tf" ]]; then
  echo "safe_file.txt"
  echo "../etc/passwd"
elif [[ "\$1" == "-xzf" ]]; then
  echo "SECURITY FAIL: Extraction attempted!" >&2
  exit 1
fi
EOF
  chmod +x "$STUB_DIR/tar"

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../geoupdate"
    
    export MAXMIND_ID="test_user"
    export MAXMIND_TOKEN="test_key"
    export MMDB_FILE="${HOME}/.local/share/geoip/GeoLite2-City.mmdb"
    export STATE_DIR="${HOME}/.local/state"
    export DOWNLOAD_URL="http://mock.url/db"
    export SHA_URL="http://mock.url/sha"
    
    mkdir -p "$STATE_DIR"
    TMP_DIR=""
    
    run_update
  '

  assert_failure 1
  assert_output --partial "ERROR: Archive contains potentially unsafe file paths"
  refute_output --partial "SECURITY FAIL"
}

@test "geoupdate.unit: run_update() - when mmdb not found after extraction - should print error and exit 1" {
  cat > "$STUB_DIR/curl" <<EOF
#!/usr/bin/env bash
while [[ \$# -gt 0 ]]; do
  if [[ "\$1" == "-o" ]]; then touch "\$2"; fi
  shift
done
exit 0
EOF
  chmod +x "$STUB_DIR/curl"

  cat > "$STUB_DIR/sha256sum" <<EOF
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$STUB_DIR/sha256sum"

  cat > "$STUB_DIR/tar" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "-tf" ]]; then
  echo "GeoLite2-City.mmdb"
elif [[ "\$1" == "-xzf" ]]; then
  extract_dir=""
  while [[ \$# -gt 0 ]]; do
    if [[ "\$1" == "-C" ]]; then extract_dir="\$2"; fi
    shift
  done
  mkdir -p "\$extract_dir"
fi
exit 0
EOF
  chmod +x "$STUB_DIR/tar"

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../geoupdate"

    export MAXMIND_ID="test_user"
    export MAXMIND_TOKEN="test_key"
    export MMDB_FILE="${HOME}/.local/share/geoip/GeoLite2-City.mmdb"
    export STATE_DIR="${HOME}/.local/state"
    export DOWNLOAD_URL="http://mock.url/db"
    export SHA_URL="http://mock.url/sha"

    mkdir -p "$STATE_DIR"
    TMP_DIR=""

    run_update
  '

  assert_failure 1
  assert_output --partial "ERROR: Extraction failed. GeoLite2-City.mmdb not found in archive."
}

@test "geoupdate.unit: main() - with missing config files - should print error and exit 1" {
  run_isolated '
    command() { return 0; }
    source "'"$BATS_TEST_DIRNAME"'/../geoupdate"
    main
  '

  assert_failure 1
  assert_output --partial "ERROR: Cannot read ufwcheck config file"
}
