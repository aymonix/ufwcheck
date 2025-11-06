#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/test_helper/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/test_helper/bats-assert/load.bash"

# Runs before each test to create an isolated sandbox environment.
setup() {
  export HOME="$(mktemp -d)"

  # Copy the script-under-test into the sandbox to avoid modifying the original.
  local source_script="${BATS_TEST_DIRNAME}/../install.sh"
  local target_script="${HOME}/install.sh"
  cp "$source_script" "$target_script"
  chmod +x "$target_script"

  # Create a sandbox bin directory and mock external dependencies.
  mkdir -p "${HOME}/bin"
  local BASH_PATH
  BASH_PATH=$(command -v bash)

  for cmd in mmdblookup column crontab jq; do
    echo "#!${BASH_PATH}" > "${HOME}/bin/${cmd}"
    echo "exit 0" >> "${HOME}/bin/${cmd}"
    chmod +x "${HOME}/bin/${cmd}"
  done
  export PATH="${HOME}/bin:${PATH}"
}

# Runs after each test to clean up the sandbox environment.
teardown() {
  rm -rf "$HOME"
}

# --- TESTS ---

@test "install.e2e: creates all required files on a default run" {
  local BASH_PATH
  BASH_PATH=$(command -v bash)

  # Mock curl to simulate successful file creation.
  cat > "${HOME}/bin/curl" <<EOF
#!${BASH_PATH}
while [[ \$# -gt 0 ]]; do
  case "\$1" in -o|--output) touch "\$2"; exit 0 ;; esac
  shift
done
exit 0
EOF
  # Mock sha256sum to simulate a successful integrity check.
  echo "#!${BASH_PATH}" > "${HOME}/bin/sha256sum"
  echo "exit 0" >> "${HOME}/bin/sha256sum"
  chmod +x "${HOME}/bin/curl" "${HOME}/bin/sha256sum"

  local target_script="${HOME}/install.sh"
  run bash -c "yes '' | $target_script"

  assert_success
  assert [ -d "${HOME}/.local/bin" ]
  assert [ -d "${HOME}/.config/ufwcheck" ]
  assert [ -d "${HOME}/.config/maxmind" ]
  assert [ -f "${HOME}/.local/bin/ufwcheck.sh" ]
  assert [ -f "${HOME}/.local/bin/geoupdate.sh" ]
  assert [ -f "${HOME}/.config/ufwcheck/config.sh" ]
  assert [ -f "${HOME}/.config/ufwcheck/env.sh" ]
  assert [ -f "${HOME}/.config/maxmind/config.sh" ]
  assert [ ! -f "${HOME}/.local/bin/SHA256SUMS" ]
}

@test "install.e2e: skips secrets and cron creation on user refusal" {
  local BASH_PATH
  BASH_PATH=$(command -v bash)

  # Mock curl and sha256sum for a successful file download.
  cat > "${HOME}/bin/curl" <<EOF
#!${BASH_PATH}
while [[ \$# -gt 0 ]]; do
  case "\$1" in -o|--output) touch "\$2"; exit 0 ;; esac
  shift
done
exit 0
EOF
  echo "#!${BASH_PATH}" > "${HOME}/bin/sha256sum"
  echo "exit 0" >> "${HOME}/bin/sha256sum"
  chmod +x "${HOME}/bin/curl" "${HOME}/bin/sha256sum"

  # Simulate user input: '2' for manual MaxMind, 'n' for cron.
  local target_script="${HOME}/install.sh"
  local user_input="2\nn"
  run bash -c "echo -e '$user_input' | $target_script"

  assert_success
  assert [ -f "${HOME}/.local/bin/ufwcheck.sh" ]
  assert [ ! -f "${HOME}/.config/maxmind/secrets" ]
  assert_output --partial "Skipping cron job setup."
}

@test "install.e2e: aborts and cleans up on checksum mismatch" {
  local BASH_PATH
  BASH_PATH=$(command -v bash)

  # Mock curl to successfully create files.
  cat > "${HOME}/bin/curl" <<EOF
#!${BASH_PATH}
while [[ \$# -gt 0 ]]; do
  case "\$1" in -o|--output) touch "\$2"; exit 0 ;; esac
  shift
done
exit 0
EOF
  # Mock sha256sum to fail the integrity check.
  echo "#!${BASH_PATH}" > "${HOME}/bin/sha256sum"
  echo "exit 1" >> "${HOME}/bin/sha256sum"
  chmod +x "${HOME}/bin/curl" "${HOME}/bin/sha256sum"

  local target_script="${HOME}/install.sh"
  run bash -c "$target_script"

  assert_failure
  assert_output --partial "ERROR: Checksum mismatch!"
  assert [ ! -f "${HOME}/.local/bin/ufwcheck.sh" ]
  assert [ ! -f "${HOME}/.local/bin/geoupdate.sh" ]
  assert [ ! -f "${HOME}/.local/bin/SHA256SUMS" ]
}
