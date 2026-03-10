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
  assert_output --partial "sudo apt install -y jq"
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
  assert_output --partial "sudo apt install -y python3-maxminddb"
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

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../install.sh"
    install_files
  '

  assert_success

  assert [ -f "${HOME}/.local/bin/ufwcheck" ]
  assert [ -f "${HOME}/.local/bin/geoupdate" ]
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
  assert [ ! -f "${HOME}/.local/bin/ufwcheck" ]
}

# CONFIGURATION

@test "install.unit: configure_maxmind() - when user provides valid input - should create secrets file and exit 0" {
  run_isolated '
    read() {
      case "$*" in
        *"Account ID"*) eval "${!#}=\"MY_ACCOUNT_ID\"" ;;
        *"License Key"*) eval "${!#}=\"MY_LICENSE_KEY\"" ;;
        *) eval "${!#}=\"1\"" ;;
      esac
    }
    source "'"$BATS_TEST_DIRNAME"'/../install.sh"
    configure_maxmind
  '

  assert_success

  local secrets_file="$HOME/.config/maxmind/secrets"
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
}

@test "install.unit: configure_maxmind() - when user provides empty input - should skip creation and exit 0" {
  run_isolated '
    read() {
      case "$*" in
        *"Account ID"*) eval "${!#}=\"\"" ;;
        *"License Key"*) eval "${!#}=\"\"" ;;
        *) eval "${!#}=\"1\"" ;;
      esac
    }
    source "'"$BATS_TEST_DIRNAME"'/../install.sh"
    configure_maxmind
  '

  assert_success

  local secrets_file="$HOME/.config/maxmind/secrets"
  assert [ ! -f "$secrets_file" ]
  assert_output --partial "WARN: Input was empty. Skipping API setup."
}

@test "install.unit: configure_maxmind() - when user chooses manual setup - should print instructions and exit 0" {
  run_isolated '
    read() { eval "${!#}=\"2\""; }
    source "'"$BATS_TEST_DIRNAME"'/../install.sh"
    configure_maxmind
  '

  assert_success

  local secrets_file="$HOME/.config/maxmind/secrets"
  assert [ ! -f "$secrets_file" ]
  assert_output --partial "Manual setup selected"
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
  echo "$content" | grep -q "geoupdate"
  assert_equal "$?" "0"
  
  rm "$crontab_capture_file"
}

@test "install.unit: configure_cron() - when user declines - should skip setup and exit 0" {
  run_isolated '
    read() { eval "${!#}=\"n\""; }
    source "'"$BATS_TEST_DIRNAME"'/../install.sh"
    configure_cron
  '

  assert_success
  assert_output --partial "Skipping cron job setup"
}

@test "install.unit: setup_environment() - when called - should create a valid env file and exit 0" {
  run_isolated '
    source "'"$BATS_TEST_DIRNAME"'/../install.sh"
    mkdir -p "$(dirname "$UFWCHECK_ENV_FILE")"
    setup_environment
  '

  assert_success

  local env_file="$HOME/.config/ufwcheck/env"
  assert [ -f "$env_file" ]

  local env_content
  env_content=$(cat "$env_file")

  echo "$env_content" | grep -Fq "export PATH=\"${HOME}/.local/bin:\$PATH\""
  assert_equal "$?" "0"

  echo "$env_content" | grep -q "alias ufc='ufwcheck'"
  assert_equal "$?" "0"
}

@test "install.unit: final_instructions() - when called - should display correct instructions and exit 0" {
  run_isolated '
    source "'"$BATS_TEST_DIRNAME"'/../install.sh"
    final_instructions
  '

  assert_success
  assert_output --partial "source \"${HOME}/.config/ufwcheck/env\""
  assert_output --partial "geoupdate"
}

# MAIN

@test "install.unit: main() - when existing installation detected and user confirms - should proceed" {
  run_isolated '
    read() { eval "${!#}=\"y\""; }
    source "'"$BATS_TEST_DIRNAME"'/../install.sh"
    check_dependencies() { return 0; }
    install_files() { return 0; }
    configure_maxmind() { return 0; }
    setup_environment() { return 0; }
    configure_cron() { return 0; }
    final_instructions() { echo "final_instructions called"; }
    mkdir -p "$(dirname "$UFWCHECK_CONFIG_FILE")"
    touch "$UFWCHECK_CONFIG_FILE"
    main
  '

  assert_success
  assert_output --partial "final_instructions called"
}

@test "install.unit: main() - when existing installation detected and user declines - should abort" {
  run_isolated '
    read() { eval "${!#}=\"n\""; }
    source "'"$BATS_TEST_DIRNAME"'/../install.sh"
    mkdir -p "$(dirname "$UFWCHECK_CONFIG_FILE")"
    touch "$UFWCHECK_CONFIG_FILE"
    main
  '

  assert_success
  assert_output --partial "Aborted."
}
