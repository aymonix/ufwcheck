#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/test_helper/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/test_helper/bats-assert/load.bash"

# Run target function with mocked dependencies in an isolated subshell.
run_with_stub() {
  local function_to_run="$1"
  local stub_definition="$2"

  (
    source "${BATS_TEST_DIRNAME}/../install.sh"
    eval "$stub_definition"
    "$function_to_run"
  )
}

setup() {
  export HOME="$(mktemp -d)"
}

teardown() {
  rm -rf "$HOME"
}

# --- TESTS ---

@test "install.unit: check_dependencies() - when all dependencies exist - should exit 0" {
  local stub="command_exists() { return 0; }"
  
  run run_with_stub check_dependencies "$stub"

  assert_success
  assert_output --partial "All required tools are present."
}

@test "install.unit: check_dependencies() - when a dependency is missing - should exit 1" {
  # Mock failure only for 'jq'.
  local stub='
    command_exists() {
      if [[ "$1" == "jq" ]]; then
        return 1
      else
        return 0
      fi
    }
  '
  
  run run_with_stub check_dependencies "$stub"

  assert_failure 1
  assert_output --partial "sudo apt-get install jq"
}

@test "install.unit: install_files() - when download and verification succeed - should exit 0" {
  # Mock curl to simulate file creation.
  local curl_stub='
    curl() {
      while [[ $# -gt 0 ]]; do
        if [[ "$1" == "-o" || "$1" == "--output" ]]; then
          touch "$2"
        fi
        shift
      done
      return 0
    }
  '
  local sha256sum_stub='sha256sum() { return 0; }'
  local combined_stubs="${curl_stub}${sha256sum_stub}"
  
  run run_with_stub install_files "$combined_stubs"

  assert_success
  
  assert [ -f "${HOME}/.local/bin/ufwcheck.sh" ]
  assert [ -x "${HOME}/.local/bin/ufwcheck.sh" ]
  
  assert [ -f "${HOME}/.local/bin/geoupdate.sh" ]
  assert [ -x "${HOME}/.local/bin/geoupdate.sh" ]

  assert [ ! -f "${HOME}/.local/bin/SHA256SUMS" ]
}

@test "install.unit: install_files() - when checksum mismatches - should exit 1 and clean up" {
  # Mock curl success, but sha256sum failure.
  local curl_stub='
    curl() {
      while [[ $# -gt 0 ]]; do
        if [[ "$1" == "-o" || "$1" == "--output" ]]; then
          touch "$2"
        fi
        shift
      done
      return 0
    }
  '
  local sha256sum_stub='sha256sum() { return 1; }'
  local combined_stubs="${curl_stub}${sha256sum_stub}"
  
  run run_with_stub install_files "$combined_stubs"

  assert_failure 1
  assert_output --partial "ERROR: Checksum mismatch!"
  
  assert [ ! -f "${HOME}/.local/bin/ufwcheck.sh" ]
  assert [ ! -f "${HOME}/.local/bin/geoupdate.sh" ]
  assert [ ! -f "${HOME}/.local/bin/SHA256SUMS" ]
}

@test "install.unit: install_files() - when download fails - should exit 1" {
  local curl_stub='curl() { return 22; }'
  
  run run_with_stub install_files "$curl_stub"

  assert_failure
  assert [ ! -f "${HOME}/.local/bin/ufwcheck.sh" ]
}

@test "install.unit: configure_maxmind() - when user provides valid input - should create secrets file and exit 0" {
  local input_file
  input_file=$(mktemp)
  echo -e "1\nMY_ACCOUNT_ID\nMY_LICENSE_KEY\n" > "$input_file"

  # Run in background to avoid stdin deadlock between read and heredoc.
  run_with_stub configure_maxmind "" < "$input_file" &
  local func_pid=$!

  local secrets_file="${HOME}/.config/maxmind/secrets"
  local counter=0
  while [ ! -f "$secrets_file" ] && [ "$counter" -lt 20 ]; do
    sleep 0.1
    counter=$((counter + 1))
  done

  kill "$func_pid" 2>/dev/null || true
  wait "$func_pid" 2>/dev/null || true

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
  echo -e "1\n\n\n" > "$input_file"

  local output_file
  output_file=$(mktemp)
  
  # Run in background to avoid stdin deadlock.
  run_with_stub configure_maxmind "" < "$input_file" > "$output_file" 2>&1 &
  local func_pid=$!

  local config_file="${HOME}/.config/maxmind/config.sh"
  local counter=0
  while [ ! -f "$config_file" ] && [ "$counter" -lt 20 ]; do
    sleep 0.1
    counter=$((counter + 1))
  done

  kill "$func_pid" 2>/dev/null || true
  wait "$func_pid" 2>/dev/null || true

  local secrets_file="${HOME}/.config/maxmind/secrets"
  assert [ ! -f "$secrets_file" ]
  
  local output_content
  output_content=$(cat "$output_file")
  echo "$output_content" | grep -q 'Input was empty. Skipping API setup.'
  assert_equal "$?" "0"

  rm "$input_file" "$output_file"
}

@test "install.unit: configure_maxmind() - when user chooses manual setup - should print instructions and exit 0" {
  local input_file
  input_file=$(mktemp)
  echo -e "2\n" > "$input_file"

  local output_file
  output_file=$(mktemp)
  
  # Run in background to avoid stdin deadlock.
  run_with_stub configure_maxmind "" < "$input_file" > "$output_file" 2>&1 &
  local func_pid=$!

  local config_file="${HOME}/.config/maxmind/config.sh"
  local counter=0
  while [ ! -f "$config_file" ] && [ "$counter" -lt 20 ]; do
    sleep 0.1
    counter=$((counter + 1))
  done

  kill "$func_pid" 2>/dev/null || true
  wait "$func_pid" 2>/dev/null || true

  local secrets_file="${HOME}/.config/maxmind/secrets"
  assert [ ! -f "$secrets_file" ]
  
  local output_content
  output_content=$(cat "$output_file")
  echo "$output_content" | grep -q 'Manual setup selected'
  assert_equal "$?" "0"

  rm "$input_file" "$output_file"
}

@test "install.unit: configure_cron() - when user agrees - should add cron job and exit 0" {
    local crontab_capture_file=$(mktemp)
    
    local stub='
        crontab() {
            if [[ "$1" == "-l" ]]; then
                return 0
            else
                cat > "'"$crontab_capture_file"'"
            fi
        }
    '

    run run_with_stub configure_cron "$stub" <<< "y"

    sleep 0.1

    assert_success
    assert_output --partial "Cron job successfully added"
    
    local content=$(cat "$crontab_capture_file")
    echo "$content" | grep -q "geoupdate.sh"
    assert_equal "$?" "0"
    
    rm "$crontab_capture_file"
}

@test "install.unit: configure_cron() - when user declines - should skip setup and exit 0" {
  local crontab_marker_file="${HOME}/crontab_was_called"
  local crontab_stub='
    crontab() {
      touch "'"$crontab_marker_file"'"
    }
  '
  
  local user_input="n"
  run run_with_stub configure_cron "$crontab_stub" <<< "$user_input"

  assert_success
  assert_output --partial "Skipping cron job setup"
  
  assert [ ! -f "$crontab_marker_file" ]
}

@test "install.unit: setup_environment() - when called - should create a valid env file and exit 0" {
  mkdir -p "${HOME}/.config/ufwcheck"

  run run_with_stub setup_environment ""

  assert_success
  
  local env_file="${HOME}/.config/ufwcheck/env.sh"
  assert [ -f "$env_file" ]

  local env_content
  env_content=$(cat "$env_file")

  echo "$env_content" | grep -q "export PATH=\"${HOME}/.local/bin:"
  assert_equal "$?" "0"

  echo "$env_content" | grep -q "alias ufwcheck='ufwcheck.sh'"
  assert_equal "$?" "0"

  echo "$env_content" | grep -q "alias geoupdate='geoupdate.sh'"
  assert_equal "$?" "0"
}

@test "install.unit: final_instructions() - when called - should display correct instructions and exit 0" {
  run run_with_stub final_instructions ""

  assert_success
  
  assert_output --partial "source \"${HOME}/.config/ufwcheck/env.sh\""
  assert_output --partial "geoupdate.sh"
}
