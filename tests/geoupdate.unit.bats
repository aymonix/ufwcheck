#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/test_helper/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/test_helper/bats-assert/load.bash"

setup() {
  export HOME="$(mktemp -d)"
  STUB_DIR=$(mktemp -d)
  export PATH="$STUB_DIR:$PATH"
}

teardown() {
  export PATH=$(echo "$PATH" | sed "s|$STUB_DIR:||")
  rm -rf "$HOME" "$STUB_DIR"
}

# --- TESTS ---

@test "geoupdate.unit: run_update() - with missing credentials - should fail and exit 1" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../geoupdate.sh"
    
    # Initialize globals to satisfy set -u.
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
EOF
  chmod +x "$STUB_DIR/curl"

  cat > "$STUB_DIR/sha256sum" <<EOF
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$STUB_DIR/sha256sum"

  # Output safe filename to pass security validation.
  cat > "$STUB_DIR/tar" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "-tf" ]]; then
  echo "GeoLite2-City.mmdb"
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
    
    # Define global tmp_dir to satisfy "set -u" during EXIT trap execution.
    tmp_dir=""
    
    run_update
  '

  assert_success
  assert_output --partial "GeoLite2-City database updated successfully."
}

@test "geoupdate.unit: run_update() - when download fails - should exit 22" {
  # Mock curl to simulate a specific HTTP/Network failure (code 22).
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

  # Verify that the specific curl error code propagated through the script.
  assert_failure 22
}

@test "geoupdate.unit: run_update() - when checksum mismatches - should exit 1" {
  # Mock curl: Must succeed and create files to reach the validation step.
  cat > "$STUB_DIR/curl" <<EOF
#!/usr/bin/env bash
while [[ \$# -gt 0 ]]; do
  if [[ "\$1" == "-o" ]]; then touch "\$2"; fi
  shift
done
EOF
  chmod +x "$STUB_DIR/curl"

  # Mock sha256sum: Fail to simulate data corruption.
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
  assert_output --partial "Archive contains potentially unsafe file paths"
  refute_output --partial "SECURITY FAIL"
}

@test "geoupdate.unit: main() - with missing config files - should exit 1" {
  # Run main in the clean sandbox where config files do not exist.
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../geoupdate.sh"
    main
  '

  assert_failure 1
  assert_output --partial "Cannot read ufwcheck config file"
}
