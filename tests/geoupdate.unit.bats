#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/test_helper/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/test_helper/bats-assert/load.bash"

setup() {
  export HOME="$(mktemp -d)"
  export STUB_DIR="$(mktemp -d)"
  export PATH="$STUB_DIR:$PATH"
}

teardown() {
  export PATH=$(echo "$PATH" | sed "s|$STUB_DIR:||")
  rm -rf "$HOME" "$STUB_DIR"
}

# --- TESTS ---

@test "geoupdate.unit: check_dependencies() - when all dependencies exist - should exit 0" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../geoupdate.sh"
    command() { return 0; }
    check_dependencies
  '

  assert_success
}

@test "geoupdate.unit: check_dependencies() - when a dependency is missing - should print error and exit 1" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../geoupdate.sh"
    
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
    source "'"$BATS_TEST_DIRNAME"'/../geoupdate.sh"
    
    # Initialize required globals to satisfy set -u, but leave credentials unset.
    export MMDB_FILE="${HOME}/GeoLite2-City.mmdb"
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

  # Return a safe filename to pass the "Tar Slip" security check.
  cat > "$STUB_DIR/tar" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "-tf" ]]; then
  echo "GeoLite2-City.mmdb"
fi
exit 0
EOF
  chmod +x "$STUB_DIR/tar"

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../geoupdate.sh"
    
    export MAXMIND_ID="test_user"
    export MAXMIND_TOKEN="test_key"
    export MMDB_FILE="${HOME}/GeoLite2-City.mmdb"
    export STATE_DIR="${HOME}/.local/state"
    export DOWNLOAD_URL="http://mock.url/db"
    export SHA_URL="http://mock.url/sha"
    
    mkdir -p "$STATE_DIR"
    
    # Initialize global variable to prevent "unbound variable" error in EXIT trap.
    tmp_dir=""
    
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
    source "'"$BATS_TEST_DIRNAME"'/../geoupdate.sh"
    
    export MAXMIND_ID="test_user"
    export MAXMIND_TOKEN="test_key"
    export MMDB_FILE="${HOME}/GeoLite2-City.mmdb"
    export STATE_DIR="${HOME}/.local/state"
    export DOWNLOAD_URL="http://mock.url/db"
    export SHA_URL="http://mock.url/sha"
    
    mkdir -p "$STATE_DIR"
    tmp_dir=""
    
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
    source "'"$BATS_TEST_DIRNAME"'/../geoupdate.sh"
    
    export MAXMIND_ID="test_user"
    export MAXMIND_TOKEN="test_key"
    export MMDB_FILE="${HOME}/GeoLite2-City.mmdb"
    export STATE_DIR="${HOME}/.local/state"
    export DOWNLOAD_URL="http://mock.url/db"
    export SHA_URL="http://mock.url/sha"
    
    mkdir -p "$STATE_DIR"
    tmp_dir=""
    
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
    source "'"$BATS_TEST_DIRNAME"'/../geoupdate.sh"
    
    export MAXMIND_ID="test_user"
    export MAXMIND_TOKEN="test_key"
    export MMDB_FILE="${HOME}/GeoLite2-City.mmdb"
    export STATE_DIR="${HOME}/.local/state"
    export DOWNLOAD_URL="http://mock.url/db"
    export SHA_URL="http://mock.url/sha"
    
    mkdir -p "$STATE_DIR"
    tmp_dir=""
    
    run_update
  '

  assert_failure 1
  assert_output --partial "ERROR: Archive contains potentially unsafe file paths"
  refute_output --partial "SECURITY FAIL"
}

@test "geoupdate.unit: main() - with missing config files - should print error and exit 1" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../geoupdate.sh"
    
    # Mock command check to bypass dependency validation and hit config check.
    command() { return 0; }
    
    main
  '

  assert_failure 1
  assert_output --partial "ERROR: Cannot read ufwcheck config file"
}
