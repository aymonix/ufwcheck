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

# DEPENDENCY CHECKS

@test "install.unit: check_dependencies() - when all dependencies exist - should return 0" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../install.sh"
    
    python3() { return 0; }
    command() { return 0; }
    
    check_dependencies
  '

  assert_success
  assert_output --partial "All required tools are present."
}

@test "install.unit: check_dependencies() - when binary tool is missing - should return 1" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../install.sh"
    
    command() {
      [[ "$2" == "jq" ]] && return 1
      return 0
    }
    
    check_dependencies
  '

  assert_failure 1
  assert_output --partial "sudo apt-get install jq"
}

@test "install.unit: check_dependencies() - when python library is missing - should return 1" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../install.sh"
    
    command() { return 0; }
    
    python3() {
      return 1
    }
    
    check_dependencies
  '

  assert_failure 1
  assert_output --partial "sudo apt-get install python3-maxminddb"
}

# FILE INSTALLATION

@test "install.unit: install_files() - when download and verification succeed - should exit 0" {
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
  
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../install.sh"
    install_files
  '

  assert_success
  
  assert [ -f "${HOME}/.local/bin/ufwcheck.sh" ]
  assert [ -f "${HOME}/.local/bin/geoupdate.sh" ]

  assert [ ! -f "${HOME}/.local/bin/SHA256SUMS" ]
}

@test "install.unit: install_files() - when checksum mismatches - should exit 1 and clean up" {
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
exit 1
EOF
  chmod +x "$STUB_DIR/sha256sum"
  
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../install.sh"
    install_files
  '

  assert_failure 1
  assert_output --partial "ERROR: Checksum mismatch!"
  
  assert [ ! -f "${HOME}/.local/bin/ufwcheck.sh" ]
  assert [ ! -f "${HOME}/.local/bin/geoupdate.sh" ]
  assert [ ! -f "${HOME}/.local/bin/SHA256SUMS" ]
}

@test "install.unit: install_files() - when download fails - should exit 22" {
  cat > "$STUB_DIR/curl" <<EOF
#!/usr/bin/env bash
exit 22
EOF
  chmod +x "$STUB_DIR/curl"
  
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../install.sh"
    install_files
  '

  assert_failure 22
  assert [ ! -f "${HOME}/.local/bin/ufwcheck.sh" ]
}

# CONFIGURATION

@test "install.unit: configure_maxmind() - when user provides valid input - should create secrets file and exit 0" {
  local input_file
  input_file=$(mktemp)
  # Simulate user input: Choice "1", User ID, License Key
  echo -e "1\nMY_ACCOUNT_ID\nMY_LICENSE_KEY\n" > "$input_file"

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../install.sh"
    configure_maxmind
  ' < "$input_file"

  assert_success
  
  local secrets_file="${HOME}/.config/maxmind/secrets"
  assert [ -f "$secrets_file" ]
  
  local secrets_content
  secrets_content=$(cat "$secrets_file")
  
  echo "$secrets_content" | grep -q 'export MAXMIND_ID="MY_ACCOUNT_ID"'
  assert_equal "$?" "0"

  echo "$secrets_content" | grep -q 'export MAXMIND_TOKEN="MY_LICENSE_KEY"'
  assert_equal "$?" "0"
  
  local permissions
  permissions=$(stat -c %a "$secrets_file")
  assert_equal "$permissions" "600"

  rm "$input_file"
}

@test "install.unit: configure_maxmind() - when user provides empty input - should skip creation and exit 0" {
  local input_file
  input_file=$(mktemp)
  # Simulate input: Choice "1", Empty ID, Empty Key
  echo -e "1\n\n\n" > "$input_file"

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../install.sh"
    configure_maxmind
  ' < "$input_file"

  assert_success
  
  local secrets_file="${HOME}/.config/maxmind/secrets"
  assert [ ! -f "$secrets_file" ]
  assert_output --partial "WARN: Input was empty. Skipping API setup."

  rm "$input_file"
}

@test "install.unit: configure_maxmind() - when user chooses manual setup - should print instructions and exit 0" {
  local input_file
  input_file=$(mktemp)
  # Simulate input: Choice "2"
  echo -e "2\n" > "$input_file"

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../install.sh"
    configure_maxmind
  ' < "$input_file"

  assert_success
  
  local secrets_file="${HOME}/.config/maxmind/secrets"
  assert [ ! -f "$secrets_file" ]
  assert_output --partial "Manual setup selected"

  rm "$input_file"
}

# CRON & ENV

@test "install.unit: configure_cron() - when user agrees - should add cron job and exit 0" {
  local crontab_capture_file=$(mktemp)

  cat > "$STUB_DIR/crontab" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "-l" ]]; then
  exit 0
else
  cat > "$crontab_capture_file"
fi
EOF
  chmod +x "$STUB_DIR/crontab"

  # Mock grep to ensure pipeline success even if crontab -l is empty.
  cat > "$STUB_DIR/grep" <<EOF
#!/usr/bin/env bash
cat
EOF
  chmod +x "$STUB_DIR/grep"

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../install.sh"
    echo "y" | configure_cron
  '

  assert_success
  assert_output --partial "Cron job successfully added"
  
  local content=$(cat "$crontab_capture_file")
  echo "$content" | grep -q "geoupdate.sh"
  assert_equal "$?" "0"
  
  rm "$crontab_capture_file"
}

@test "install.unit: configure_cron() - when user declines - should skip setup and exit 0" {
  local crontab_marker_file="${HOME}/crontab_was_called"

  cat > "$STUB_DIR/crontab" <<EOF
#!/usr/bin/env bash
touch "$crontab_marker_file"
EOF
  chmod +x "$STUB_DIR/crontab"

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../install.sh"
    echo "n" | configure_cron
  '

  assert_success
  assert_output --partial "Skipping cron job setup"

  assert [ ! -f "$crontab_marker_file" ]
}

@test "install.unit: setup_environment() - when called - should create a valid env file and exit 0" {
  # The function writes to this directory, so it must exist beforehand.
  mkdir -p "${HOME}/.config/ufwcheck"

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../install.sh"
    setup_environment
  '

  assert_success
  
  local env_file="${HOME}/.config/ufwcheck/env.sh"
  assert [ -f "$env_file" ]

  local env_content
  env_content=$(cat "$env_file")

  # Verify the PATH export preserves the literal '$PATH' variable using Fixed-string grep.
  echo "$env_content" | grep -Fq "export PATH=\"${HOME}/.local/bin:\$PATH\""
  assert_equal "$?" "0"

  echo "$env_content" | grep -q "alias ufwcheck='ufwcheck.sh'"
  assert_equal "$?" "0"
}

@test "install.unit: final_instructions() - when called - should display correct instructions and exit 0" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../install.sh"
    final_instructions
  '

  assert_success
  
  assert_output --partial "source \"${HOME}/.config/ufwcheck/env.sh\""
  assert_output --partial "geoupdate.sh"
}
