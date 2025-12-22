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

# BASIC FUNCTIONALITY

@test "ufwcheck.unit: print_help() - when called - should display usage and exit 0" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../ufwcheck.sh"
    print_help
  '

  assert_success
  assert_output --partial "Usage: ufwcheck.sh"
}

@test "ufwcheck.unit: validate_positive_integer() - with valid input - should exit 0" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../ufwcheck.sh"
    validate_positive_integer "10" "--top"
  '

  assert_success
  assert_output ""
}

@test "ufwcheck.unit: validate_positive_integer() - with invalid input - should print error and exit 2" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../ufwcheck.sh"
    validate_positive_integer "abc" "--top"
  '

  assert_failure 2
  assert_output --partial "must be a positive integer"
}

@test "ufwcheck.unit: check_dependencies() - when all dependencies exist - should exit 0" {
  run bash -c '
    # Mock command to always succeed, simulating installed tools.
    command() { return 0; }
    source "'"$BATS_TEST_DIRNAME"'/../ufwcheck.sh"
    check_dependencies
  '

  assert_success
}

@test "ufwcheck.unit: check_dependencies() - when a dependency is missing - should print error and exit 1" {
  run bash -c '
    # Mock command to fail specifically for "jq".
    command() {
      if [[ "$2" == "jq" ]]; then
        return 1
      fi
      return 0
    }
    source "'"$BATS_TEST_DIRNAME"'/../ufwcheck.sh"
    check_dependencies
  '

  assert_failure 1
  assert_output --partial "Required command not found: 'jq'"
}

@test "ufwcheck.unit: check_environment() - when log dir is inaccessible - should exit 1" {
  # Create a directory with no permissions (000) to trigger -r/-x checks.
  local restricted_dir="$HOME/restricted_logs"
  mkdir -p "$restricted_dir"
  chmod 000 "$restricted_dir"

  # Pass dummy script name ($0) and directory ($1) to avoid basename errors.
  run bash -c '
    target_dir="$1"

    source "'"$BATS_TEST_DIRNAME"'/../ufwcheck.sh"
    
    # Mock dependencies to bypass that check.
    check_dependencies() { return 0; }
    
    # Ensure config dir exists before creating file (config path is internal to script).
    mkdir -p "$(dirname "$UFWCHECK_CONFIG_FILE")"

    cat > "$UFWCHECK_CONFIG_FILE" <<EOF
LOG_FILE="$target_dir/ufw.log"
MMDB_FILE="$HOME/db.mmdb"
EOF
    
    check_environment
  ' "ufwcheck_mock" "$restricted_dir"
  
  # Cleanup permissions so teardown can remove it.
  chmod 700 "$restricted_dir"

  assert_failure 1
  assert_output --partial "directory not found or not readable"
}

# ARGUMENT PARSING

@test "ufwcheck.unit: parse_arguments() - with combined flags - should set all variables correctly and exit 0" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../ufwcheck.sh"
    parse_arguments -d 7 --json -t 20 --no-private
    
    # Dump internal state to stdout for verification.
    echo "mode=$mode"
    echo "value=$value"
    echo "json_mode=$json_mode"
    echo "top_limit=$top_limit"
    echo "filter_private=$filter_private"
  '

  assert_success
  assert_line "mode=days"
  assert_line "value=7"
  assert_line "json_mode=true"
  assert_line "top_limit=20"
  assert_line "filter_private=true"
}

@test "ufwcheck.unit: parse_arguments() - with flag missing argument - should print error and exit 2" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../ufwcheck.sh"
    parse_arguments --days
  '

  assert_failure 2
  assert_output --partial "Option '--days' requires an argument."
}

@test "ufwcheck.unit: parse_arguments() - with unknown flag - should print error and exit 2" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../ufwcheck.sh"
    parse_arguments --nonexistent-flag
  '

  assert_failure 2
  assert_output --partial "Error: Unknown option '--nonexistent-flag'"
}

@test "ufwcheck.unit: parse_arguments() - with --days > 366 - should print error and exit 2" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../ufwcheck.sh"
    parse_arguments --days 400
  '

  assert_failure 2
  assert_output --partial "Maximum allowed value for '--days' is 366"
}

# LOG STREAMING

@test "ufwcheck.unit: ufw_log_stream() - mode=today - should read only current logs" {
  local mock_dir="$HOME/logs"
  mkdir -p "$mock_dir"
  
  # Create files with specific markers.
  echo "DATA_CURRENT" > "$mock_dir/ufw.log"
  echo "DATA_YESTERDAY" > "$mock_dir/ufw.log.1"
  echo "DATA_OLD" | gzip > "$mock_dir/ufw.log.2.gz"

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../ufwcheck.sh"
    export LOG_FILE="'"$mock_dir"'/ufw.log"
    mode="today"
    
    ufw_log_stream
  '

  assert_success
  assert_output --partial "DATA_CURRENT"
  assert_output --partial "DATA_YESTERDAY"
  # Should NOT read archived files in "today" mode.
  refute_output --partial "DATA_OLD"
}

@test "ufwcheck.unit: ufw_log_stream() - mode=days - should read ALL logs" {
  local mock_dir="$HOME/logs"
  mkdir -p "$mock_dir"
  
  echo "DATA_CURRENT" > "$mock_dir/ufw.log"
  echo "DATA_YESTERDAY" > "$mock_dir/ufw.log.1"
  echo "DATA_OLD" | gzip > "$mock_dir/ufw.log.2.gz"

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../ufwcheck.sh"
    export LOG_FILE="'"$mock_dir"'/ufw.log"
    mode="days"
    
    ufw_log_stream
  '

  assert_success
  assert_output --partial "DATA_CURRENT"
  assert_output --partial "DATA_YESTERDAY"
  assert_output --partial "DATA_OLD"
}

# LOG PROCESSING (AWK LOGIC)

@test "ufwcheck.unit: process_logs()(awk) - with standard log lines - should correctly count IPs and exit 0" {
  local awk_script='
    /UFW BLOCK/ {
        for(i=1; i<=NF; i++) {
            if ($i ~ /^SRC=/) {
                ip = $i;
                sub("SRC=", "", ip);
                if (filter_private == "true" && ip ~ private_ip_regex) {
                    next;
                }
                counts[ip]++;
                break;
            }
        }
    }
    END {
        for (ip in counts) {
            if (counts[ip] >= min_attempts) {
                print counts[ip], ip;
            }
        }
    }
  '
  
  local log_input
  log_input=$(cat <<LOG
[UFW BLOCK] IN=eth0 OUT= MAC=... SRC=8.8.8.8 DST=...
[UFW ALLOW] IN=eth0 OUT= MAC=... SRC=1.2.3.4 DST=...
[UFW BLOCK] IN=eth0 OUT= MAC=... SRC=8.8.8.8 DST=...
[UFW BLOCK] IN=eth0 OUT= MAC=... SRC=1.1.1.1 DST=...
[UFW BLOCK] IN=eth0 OUT= MAC=... SRC=8.8.8.8 DST=...
LOG
)

  run bash -c '
    awk \
      -v min_attempts="2" \
      -v filter_private="false" \
      -v private_ip_regex="^192[.]168[.]|^10[.]|^172[.](1[6-9]|2[0-9]|3[0-1])[.]|^127[.]" \
      "$1" 2>/dev/null
  ' "bash" "$awk_script" <<< "$log_input"

  assert_success
  assert_output "3 8.8.8.8"
}

@test "ufwcheck.unit: process_logs()(awk) - with private IP filter enabled - should exclude private IPs and exit 0" {
  local awk_script='
    /UFW BLOCK/ {
        for(i=1; i<=NF; i++) {
            if ($i ~ /^SRC=/) {
                ip = $i;
                sub("SRC=", "", ip);
                if (filter_private == "true" && ip ~ private_ip_regex) {
                    next;
                }
                counts[ip]++;
                break;
            }
        }
    }
    END {
        for (ip in counts) {
            if (counts[ip] >= min_attempts) {
                print counts[ip], ip;
            }
        }
    }
  '
  
  local log_input
  log_input=$(cat <<LOG
[UFW BLOCK] IN=eth0 OUT= MAC=... SRC=8.8.8.8 DST=...
[UFW BLOCK] IN=eth0 OUT= MAC=... SRC=192.168.1.10 DST=...
[UFW BLOCK] IN=eth0 OUT= MAC=... SRC=8.8.8.8 DST=...
[UFW BLOCK] IN=eth0 OUT= MAC=... SRC=192.168.1.10 DST=...
[UFW BLOCK] IN=eth0 OUT= MAC=... SRC=192.168.1.10 DST=...
LOG
)

  run bash -c '
    awk \
      -v min_attempts="2" \
      -v filter_private="true" \
      -v private_ip_regex="^192[.]168[.]|^10[.]|^172[.](1[6-9]|2[0-9]|3[0-1])[.]|^127[.]" \
      "$1" 2>/dev/null
  ' "bash" "$awk_script" <<< "$log_input"

  assert_success
  assert_output "2 8.8.8.8"
}

@test "ufwcheck.unit: process_logs()(awk) - when attempts < min_attempts - should return empty and exit 0" {
  local awk_script='
    /UFW BLOCK/ {
        for(i=1; i<=NF; i++) {
            if ($i ~ /^SRC=/) {
                ip = $i;
                sub("SRC=", "", ip);
                if (filter_private == "true" && ip ~ private_ip_regex) {
                    next;
                }
                counts[ip]++;
                break;
            }
        }
    }
    END {
        for (ip in counts) {
            if (counts[ip] >= min_attempts) {
                print counts[ip], ip;
            }
        }
    }
  '
  
  local log_input
  log_input=$(cat <<LOG
[UFW BLOCK] IN=eth0 OUT= MAC=... SRC=8.8.8.8 DST=...
[UFW BLOCK] IN=eth0 OUT= MAC=... SRC=8.8.8.8 DST=...
[UFW BLOCK] IN=eth0 OUT= MAC=... SRC=8.8.8.8 DST=...
LOG
)

  run bash -c '
    awk \
      -v min_attempts="4" \
      -v filter_private="false" \
      -v private_ip_regex="^192[.]168[.]|^10[.]|^172[.](1[6-9]|2[0-9]|3[0-1])[.]|^127[.]" \
      "$1" 2>/dev/null
  ' "bash" "$awk_script" <<< "$log_input"

  assert_success
  assert_output ""
}

# FORMATTING

@test "ufwcheck.unit: format_json() - with valid input - should produce correct JSON and exit 0" {
  local geo_data_override
  geo_data_override=$(cat <<'EOF'
geo_data() {
  echo $'8.8.8.8\t123\tUnited States\tMountain View'
}
EOF
)

  local tmp_ips_file
  tmp_ips_file=$(mktemp)

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../ufwcheck.sh"
    eval "$1"
    format_json "'"$tmp_ips_file"'"
  ' -- "$geo_data_override"
  
  rm "$tmp_ips_file"

  assert_success
  
  local expected_json
  expected_json=$(cat <<'JSON'
[
  {
    "ip": "8.8.8.8",
    "attempts": 123,
    "country": "United States",
    "city": "Mountain View"
  }
]
JSON
)
  assert_output --partial "$expected_json"
}

@test "ufwcheck.unit: format_json() - with empty input - should produce an empty JSON array and exit 0" {
  local geo_data_override
  geo_data_override=$(cat <<'EOF'
geo_data() {
  : # No output
}
EOF
)
  local tmp_ips_file
  tmp_ips_file=$(mktemp)

  run bash -c '
    {
      source "'"$BATS_TEST_DIRNAME"'/../ufwcheck.sh"
      eval "$1"
      format_json "'"$tmp_ips_file"'"
    } 2>/dev/null
  ' -- "$geo_data_override"
  
  rm "$tmp_ips_file"

  assert_success
  assert_output "[]"
}

@test "ufwcheck.unit: format_table() - with valid input - should call column with correct arguments and exit 0" {
  local geo_data_override
  geo_data_override=$(cat <<'EOF'
geo_data() {
  echo $'8.8.8.8\t123\tUnited States\tMountain View'
}
EOF
)
  local column_capture_file
  column_capture_file=$(mktemp)
  
  cat > "$STUB_DIR/column" <<EOF
#!/usr/bin/env bash
printf "%s\n" "\$@" > "$column_capture_file"
cat
EOF
  chmod +x "$STUB_DIR/column"

  local tmp_out_file
  tmp_out_file=$(mktemp)

  run bash -c '
    {
      source "'"$BATS_TEST_DIRNAME"'/../ufwcheck.sh"
      eval "$1"
      export OUTPUT_LOG="/dev/null"
      
      format_table "/dev/null" "$2"
    } 2>/dev/null
  ' "bash" "$geo_data_override" "$tmp_out_file"

  rm "$tmp_out_file"

  assert_success
  assert_output --partial "IP Address"
  assert_output --partial "Attempts"

  run cat "$column_capture_file"
  rm "$column_capture_file"

  assert_line --index 0 "-t"
  assert_line --index 1 "-s"
  assert_line --index 2 $'\t'
  assert_line --index 3 "-o"
  assert_line --index 4 "  "
}

@test "ufwcheck.unit: format_table() - with empty input - should print 'No IPs found' and exit 0" {
  local geo_data_override
  geo_data_override=$(cat <<'EOF'
geo_data() {
  : # No output
}
EOF
)
  local tmp_out_file
  tmp_out_file=$(mktemp)

  run bash -c '
    {
      source "'"$BATS_TEST_DIRNAME"'/../ufwcheck.sh"
      eval "$1"
      export OUTPUT_LOG="/dev/null"
      format_table "/dev/null" "$2"
    } 2>/dev/null
  ' "bash" "$geo_data_override" "$tmp_out_file"

  rm "$tmp_out_file"

  assert_success
  assert_output --partial "No IPs found matching the specified criteria."
}

# DATA EXTRACTION (ORCHESTRATOR)

@test "ufwcheck.unit: extract_data() - with --today filter - should call grep with correct date and exit 0" {
  local date_override
  date_override=$(cat <<'EOF'
date() {
  echo "2025-01-01"
}
EOF
)

  local grep_capture_file
  grep_capture_file=$(mktemp)
  cat > "$STUB_DIR/grep" <<EOF
#!/usr/bin/env bash
echo "\$@" > "$grep_capture_file"
echo "mock_log_line"
EOF
  chmod +x "$STUB_DIR/grep"

  # Mock ufw_log_stream to avoid filesystem operations during pipeline test.
  local ufw_stream_mock
  ufw_stream_mock=$(cat <<'EOF'
ufw_log_stream() {
  echo "mock_log_line"
}
EOF
)

  cat > "$STUB_DIR/sort" <<EOF
#!/usr/bin/env bash
cat
EOF
  chmod +x "$STUB_DIR/sort"

  cat > "$STUB_DIR/process_logs" <<EOF
#!/usr/bin/env bash
cat
EOF
  chmod +x "$STUB_DIR/process_logs"

  local tmp_ips_file
  tmp_ips_file=$(mktemp)

  run bash -c '
    {
      source "'"$BATS_TEST_DIRNAME"'/../ufwcheck.sh"
      eval "$1" # Apply date mock
      eval "$2" # Apply ufw_stream mock
      unset -f process_logs

      export LOG_FILE="/dev/null"
      export top_limit=""
      export filter_private="false"
      export min_attempts="1"

      mode="today"

      extract_data "$3"
    } 2>/dev/null
  ' "bash" "$date_override" "$ufw_stream_mock" "$tmp_ips_file"

  rm "$tmp_ips_file"

  assert_success

  local captured_grep_args
  captured_grep_args=$(cat "$grep_capture_file")
  rm "$grep_capture_file"

  assert [ "${captured_grep_args#*^2025-01-01T}" != "$captured_grep_args" ]
}

@test "ufwcheck.unit: extract_data() - with --date filter - should call grep with correct date and exit 0" {
  local grep_capture_file
  grep_capture_file=$(mktemp)
  cat > "$STUB_DIR/grep" <<EOF
#!/usr/bin/env bash
echo "\$@" > "$grep_capture_file"
EOF
  chmod +x "$STUB_DIR/grep"

  cat > "$STUB_DIR/process_logs" <<EOF
#!/usr/bin/env bash
cat
EOF
  chmod +x "$STUB_DIR/process_logs"

  local ufw_stream_mock
  ufw_stream_mock=$(cat <<'EOF'
ufw_log_stream() { :; }
EOF
)

  local tmp_ips_file
  tmp_ips_file=$(mktemp)

  run bash -c '
    {
      source "'"$BATS_TEST_DIRNAME"'/../ufwcheck.sh"
      eval "$1"
      unset -f process_logs
      
      export LOG_FILE="/dev/null"
      export top_limit=""
      export filter_private="false"
      export min_attempts="1"
      
      mode="date"
      value="2025-07-26"
      
      extract_data "$2"
    } 2>/dev/null
  ' "bash" "$ufw_stream_mock" "$tmp_ips_file"
  
  rm "$tmp_ips_file"

  assert_success
  
  local captured_grep_args
  captured_grep_args=$(cat "$grep_capture_file")
  rm "$grep_capture_file"
  
  assert [ "${captured_grep_args#*^2025-07-26T}" != "$captured_grep_args" ]
}

@test "ufwcheck.unit: extract_data() - with --days filter - should call grep with correct date alternatives and exit 0" {
  local date_override
  date_override=$(cat <<'EOF'
date() {
  case "$2" in
    "-0 day") echo "2025-01-02" ;;
    "-1 day") echo "2025-01-01" ;;
  esac
}
EOF
)
  local grep_capture_file
  grep_capture_file=$(mktemp)
  cat > "$STUB_DIR/grep" <<EOF
#!/usr/bin/env bash
echo "\$@" > "$grep_capture_file"
EOF
  chmod +x "$STUB_DIR/grep"

  cat > "$STUB_DIR/process_logs" <<EOF
#!/usr/bin/env bash
cat
EOF
  chmod +x "$STUB_DIR/process_logs"

  local ufw_stream_mock
  ufw_stream_mock=$(cat <<'EOF'
ufw_log_stream() { :; }
EOF
)

  local tmp_ips_file
  tmp_ips_file=$(mktemp)

  run bash -c '
    {
      source "'"$BATS_TEST_DIRNAME"'/../ufwcheck.sh"
      eval "$1"
      eval "$2"
      unset -f process_logs
      
      export LOG_FILE="/dev/null"
      export top_limit=""
      export filter_private="false"
      export min_attempts="1"
      
      mode="days"
      value="2"
      
      extract_data "$3"
    } 2>/dev/null
  ' "bash" "$date_override" "$ufw_stream_mock" "$tmp_ips_file"
  
  rm "$tmp_ips_file"

  assert_success
  
  local captured_grep_args
  captured_grep_args=$(cat "$grep_capture_file")
  rm "$grep_capture_file"
  
  assert [ "${captured_grep_args#*^2025-01-02T|^2025-01-01T}" != "$captured_grep_args" ]
}

@test "ufwcheck.unit: extract_data() - with --month filter - should call grep with correct month regex and exit 0" {
  local grep_capture_file
  grep_capture_file=$(mktemp)
  cat > "$STUB_DIR/grep" <<EOF
#!/usr/bin/env bash
echo "\$@" > "$grep_capture_file"
EOF
  chmod +x "$STUB_DIR/grep"

  cat > "$STUB_DIR/process_logs" <<EOF
#!/usr/bin/env bash
cat
EOF
  chmod +x "$STUB_DIR/process_logs"

  local ufw_stream_mock
  ufw_stream_mock=$(cat <<'EOF'
ufw_log_stream() { :; }
EOF
)

  local tmp_ips_file
  tmp_ips_file=$(mktemp)

  run bash -c '
    {
      source "'"$BATS_TEST_DIRNAME"'/../ufwcheck.sh"
      eval "$1"
      unset -f process_logs

      export LOG_FILE="/dev/null"
      export top_limit=""
      export filter_private="false"
      export min_attempts="1"

      mode="month"
      value="Feb"

      extract_data "$2"
    } 2>/dev/null
  ' "bash" "$ufw_stream_mock" "$tmp_ips_file"

  rm "$tmp_ips_file"

  assert_success

  run cat "$grep_capture_file"
  rm "$grep_capture_file"

  assert_output --partial "^....-02-[0-9][0-9]T"
}

@test "ufwcheck.unit: extract_data() - with --top N filter - should call head with correct limit and exit 0" {
  local head_capture_file
  head_capture_file=$(mktemp)
  
  cat > "$STUB_DIR/head" <<EOF
#!/usr/bin/env bash
printf "%s\n" "\$@" > "$head_capture_file"
cat > /dev/null
EOF
  chmod +x "$STUB_DIR/head"

  cat > "$STUB_DIR/grep" <<EOF
#!/usr/bin/env bash
echo "mock_log_line"
EOF
  chmod +x "$STUB_DIR/grep"

  cat > "$STUB_DIR/sort" <<EOF
#!/usr/bin/env bash
cat
EOF
  chmod +x "$STUB_DIR/sort"

  cat > "$STUB_DIR/process_logs" <<EOF
#!/usr/bin/env bash
cat
EOF
  chmod +x "$STUB_DIR/process_logs"

  local ufw_stream_mock
  ufw_stream_mock=$(cat <<'EOF'
ufw_log_stream() { echo "data"; }
EOF
)

  local tmp_ips_file
  tmp_ips_file=$(mktemp)

  run bash -c '
    {
      source "'"$BATS_TEST_DIRNAME"'/../ufwcheck.sh"
      eval "$1"
      unset -f process_logs
      
      export LOG_FILE="/dev/null"
      export mode="today"
      export value=""
      export top_limit="10"
      export filter_private="false"
      export min_attempts="1"
      
      extract_data "$2"
    } 2>/dev/null
  ' "bash" "$ufw_stream_mock" "$tmp_ips_file"
  
  rm "$tmp_ips_file"

  assert_success
  
  run cat "$head_capture_file"
  rm "$head_capture_file"
  
  [ "${lines[0]}" = "-n" ]
  [ "${lines[1]}" = "10" ]
}

@test "ufwcheck.unit: extract_data() - with invalid date or month - should print error and exit 2" {
  local process_logs_override
  process_logs_override=$(cat <<'EOF'
process_logs() {
  cat > /dev/null
}
EOF
)

  local tmp_ips_file
  tmp_ips_file=$(mktemp)
  local stderr_log
  stderr_log=$(mktemp)

  # CASE 1: Invalid Date Format
  run bash -c '
    exec 2> "$3"
    source <(sed "\$d" "'"$BATS_TEST_DIRNAME"'/../ufwcheck.sh")
    eval "$1"
    
    export LOG_FILE="/dev/null"
    export top_limit=""
    export filter_private="false"
    export min_attempts="1"
    
    mode="date"
    value="2025/07/26"
    
    extract_data "$2"
  ' "bash" "$process_logs_override" "$tmp_ips_file" "$stderr_log"
  
  assert_failure 2

  # CASE 2: Invalid Month Name
  run bash -c '
    exec 2> "$3"
    source <(sed "\$d" "'"$BATS_TEST_DIRNAME"'/../ufwcheck.sh")
    eval "$1"
    
    export LOG_FILE="/dev/null"
    export top_limit=""
    export filter_private="false"
    export min_attempts="1"
    
    mode="month"
    value="January"
    
    extract_data "$2"
  ' "bash" "$process_logs_override" "$tmp_ips_file" "$stderr_log"

  rm "$tmp_ips_file" "$stderr_log"

  assert_failure 2
}
