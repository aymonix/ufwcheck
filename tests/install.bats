#!/usr/bin/env bats

# Load bats-support and bats-assert helper libraries.
# Provides functions for stubbing commands and making assertions.
load 'test_helper/bats-support'
load 'test_helper/bats-assert'

# --- SANDBOX SETUP ---
# Runs before/after each test to ensure a clean, isolated environment.

setup() {
  # Create a temporary directory to act as $HOME for the test.
  export HOME="$(mktemp -d)"
  # Source the script to make its functions available for testing.
  source ../install.sh
}

teardown() {
  # Clean up the temporary directory after the test.
  rm -rf "$HOME"
}

# --- TESTS ---

# === Static Analysis ===

@test "Static Analysis: install.sh passes shellcheck" {
  # Validates the script for common bugs and syntax errors.
  run shellcheck ../install.sh
  assert_success
}


# === Dependency Checks ===

@test "Dependencies: exits 0 if all dependencies are present" {
  # Test the "happy path" for the check_dependencies() function.
  # Stub `command_exists` to always report success (exit 0).
  stub command_exists { return 0; }

  run check_dependencies

  # Expect the script to exit successfully.
  assert_success
  assert_output --partial "All required tools are present."
}

@test "Dependencies: exits 1 if a dependency is missing" {
  # Test the failure scenario for the check_dependencies() function.
  # Stub `command_exists` to report 'jq' as missing (exit 1).
  stub command_exists {
    if [[ "$1" == "jq" ]]; then
      return 1 # Simulate "not found"
    else
      return 0 # Simulate "found" for all other tools
    fi
  }

  run check_dependencies

  # Expect the script to exit with a failure code.
  assert_failure
  assert_output --partial "sudo apt-get install jq"
}
