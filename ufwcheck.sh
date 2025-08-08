#!/usr/bin/env bash
# ==============================================================================
# SCRIPT: ufwcheck.sh
# AUTHOR: Aymon
# DATE:   2025-08-06
# VERSION: 1.0.0
#
# DESCRIPTION
#   Analyzes UFW (Uncomplicated Firewall) logs to identify and report on IP
#   addresses with multiple block events. It offers flexible filtering by date,
#   excludes private networks, and can output results as a formatted table
#   or in JSON format. Geo-location data (country, city) is added for each IP.
#
# DEPENDENCIES
#   - Standard UNIX utils: grep, awk, sort, uniq, head, column
#   - mmdblookup (from mmdb-bin): For querying the GeoLite2-City database.
#   - jq: For generating JSON output.
#
# USAGE
#   ./ufwcheck.sh [OPTIONS]
#   Example: ./ufwcheck.sh -d 7 -t 20 --no-private
# ==============================================================================

set -euo pipefail

# ==============================================================================
# GLOBAL VARIABLES & CONSTANTS
# ==============================================================================
readonly CMD_NAME=$(basename "$0")
readonly CMD_ARGS="$CMD_NAME $*"
readonly declare -A MONTH_MAP=(
  [Jan]=01 [Feb]=02 [Mar]=03 [Apr]=04 [May]=05 [Jun]=06
  [Jul]=07 [Aug]=08 [Sep]=09 [Oct]=10 [Nov]=11 [Dec]=12
)


# ==============================================================================
# FUNCTIONS
# ==============================================================================

# ------------------------------------------------------------------------------
# DESCRIPTION
#   Prints the help message and usage examples, then exits.
#
# ARGUMENTS
#   None
# ------------------------------------------------------------------------------
print_help() {
  cat << EOF
Usage: ufwcheck.sh [OPTIONS]

Analyzes UFW logs to identify and report on IPs with multiple block events.

Filtering Options:
  --today                Analyze today's log entries (default).
  --date YYYY-MM-DD      Filter by a specific date.
  --days N, -d N         Filter logs for the last N days.
  --month NAME, -m NAME  Filter by month abbreviation (e.g., Jan, Feb, etc.).
  --no-private           Exclude private/local network IP addresses from analysis.

Output Options:
  --top N, -t N          Show only the top N IPs by attempt count.
  --attempts N, -a N     Show only IPs with at least N blocked attempts (default: 2).
  --json                 Output results in JSON format instead of a table.

Other Options:
  --help, -h             Display this help message and exit.

Examples:
  ufwcheck.sh                                  # Today's logs, IPs with >= 2 attempts.
  ufwcheck.sh -t 10                            # Today's logs, top 10 IPs.
  ufwcheck.sh -a 50                            # Today's logs, >= 50 attempts.
  ufwcheck.sh --no-private                     # Today's logs, external IPs only (no private networks).
  ufwcheck.sh -m Jul -t 30                     # All IPs for July, top 30 IPs.
  ufwcheck.sh -d 7 -a 5 -t 20                  # Last 7 days, >= 5 attempts, top 20 IPs.
  ufwcheck.sh --date 2025-07-26                # All IPs for a specific date.
  ufwcheck.sh --date 2025-07-26 --json         # All IPs for a specific date in JSON format.
  ufwcheck.sh --date 2025-07-26 -t 10 -a 100   # IPs for a specific date, top 10 IPs, >= 100 attempts.
EOF
  exit 0
}

# ------------------------------------------------------------------------------
# DESCRIPTION
#   Validates if the provided argument is a positive integer.
#
# ARGUMENTS
#   $1 - The value to check (string).
#   $2 - The name of the flag for the error message (string).
# ------------------------------------------------------------------------------
validate_positive_integer() {
  local value="$1"
  local flag_name="$2"
  if ! [[ "$value" =~ ^[1-9][0-9]*$ ]]; then
    echo "[✘] Error: The value for '$flag_name' must be a positive integer. Got: '$value'" >&2
    exit 1
  fi
}

# ------------------------------------------------------------------------------
# DESCRIPTION
#   Checks if all required command-line tools are installed.
#
# ARGUMENTS
#   None
# ------------------------------------------------------------------------------
check_dependencies() {
  local missing_deps=0
  for cmd in grep awk sort uniq head column mmdblookup jq; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "[✘] Error: Required command not found: '$cmd'. Please install it." >&2
      ((missing_deps++))
    fi
  done
  if ((missing_deps > 0)); then
    exit 1
  fi
}

# ------------------------------------------------------------------------------
# DESCRIPTION
#   Processes a temporary file of IPs and their counts, enriches the data
#   with Geo-location information, and prints a final JSON array.
#
# ARGUMENTS
#   $1 - Path to the temporary file containing "count ip" lines.
#   $2 - Path to the GeoLite2-City .mmdb database file.
# ------------------------------------------------------------------------------
generate_json_output() {
  local tmp_ips_file="$1"
  local geo_db_file="$2"

  local json_input=""
  while read -r count ip; do
    json_input+="${ip}\t${count}\n"
  done < "$tmp_ips_file"

  echo -n "$json_input" | jq -R '
    [
      inputs |
      split("\t") |
      {
        ip: .[0],
        attempts: .[1] | tonumber
      }
    ]
  ' | jq --slurp --arg geo_db_file "$geo_db_file" '
    .[] | .[] | . as $item |
    ("mmdblookup --file \"\($geo_db_file)\" --ip \"\(.ip)\"") |
    (
        bash -c "eval $(.)" 2>/dev/null |
        jq -r "
          (.. | .country.names.en? // \"-\") as \$country |
          (.. | .city.names.en? // \"-\") as \$city |
          {country: \$country, city: \$city}
        "
    ) as $geo |
    $item + {
      country: (if $geo.country == "-" then null else $geo.country end),
      city: (if $geo.city == "-" then null else $geo.city end)
    }
  ' | jq -s 'sort_by(-.attempts)'
}

# ------------------------------------------------------------------------------
# DESCRIPTION
#   Main function to orchestrate the entire script execution.
#
# ARGUMENTS
#   All script arguments are passed here.
# ------------------------------------------------------------------------------
main() {
  # Initial Setup & Pre-flight Checks
  check_dependencies

  local CONFIG_FILE="$HOME/.config/ufwcheck/config.sh"
  if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
  else
    echo "[✘] Error: Configuration file not found at '$CONFIG_FILE'." >&2
    echo "    Please create it based on the example in the README file." >&2
    exit 1
  fi

  if [[ ! -r "$LOG_FILE" ]]; then
      echo "[✘] Error: UFW log file not found or not readable at '$LOG_FILE'." >&2
      exit 1
  fi

  if [[ ! -r "$MMDB_FILE" ]]; then
      echo "[✘] Error: GeoIP database not found or not readable at '$MMDB_FILE'." >&2
      exit 1
  fi

  # Argument Parsing
  local mode="today"
  local value=""
  local top_limit=""
  local min_attempts=2
  local json_mode="false"
  local filter_private="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --today)
        mode="today"
        shift
        ;;
      --date)
        mode="date"
        value="$2"
        shift 2
        ;;
      --days|-d)
        mode="days"
        value="$2"
        shift 2
        ;;
      --month|-m)
        mode="month"
        value="$2"
        shift 2
        ;;
      --top|-t)
        top_limit="$2"
        shift 2
        ;;
      --attempts|-a)
        min_attempts="$2"
        shift 2
        ;;
      --json)
        json_mode="true"
        shift
        ;;
      --no-private)
        filter_private="true"
        shift
        ;;
      --help|-h)
        print_help
        ;;
      *)
        echo "[✘] Error: Unknown option '$1'. Use --help for usage." >&2
        exit 1
        ;;
    esac
  done

  # Validate numerical arguments
  if [[ "$mode" == "days" ]]; then
    validate_positive_integer "$value" "--days"
  fi
  if [[ -n "$top_limit" ]]; then
    validate_positive_integer "$top_limit" "--top"
  fi
  validate_positive_integer "$min_attempts" "--attempts"

  # Data Extraction
  mkdir -p "$STATE_DIR"
  local tmp_ips
  tmp_ips=$(mktemp "$STATE_DIR/ufw_ips.XXXXXX")
  trap 'rm -f "$tmp_ips"' EXIT

  local regex=""
  case "$mode" in
    today) regex="^$(date '+%Y-%m-%d')T";;
    date)
      if ! [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo "[✘] Error: Date must be in YYYY-MM-DD format. Got: '$value'" >&2
        exit 1
      fi
      regex="^${value}T";;
    days)
      local dates=()
      for ((i=0; i<value; i++)); do dates+=("$(date -d "-$i day" '+%Y-%m-%d')"); done
      regex=$(printf '^%sT|' "${dates[@]}"); regex=${regex%|};;
    month)
      local month_num="${MONTH_MAP[$value]}"
      if [[ -z "$month_num" ]]; then
        echo "[✘] Error: Invalid month abbreviation '$value'. Use Jan, Feb, etc." >&2
        exit 1
      fi
      regex="^....-${month_num}-[0-9][0-9]T";;
  esac

  local log_pipeline="grep -E \"$regex.*UFW BLOCK\" \"$LOG_FILE\""

  if [[ "$filter_private" == "true" ]]; then
    local private_ip_regex='SRC=(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|127\.)'
    log_pipeline+=" | grep -vE \"$private_ip_regex\""
  fi

  eval "$log_pipeline" |
    awk '{for(i=1;i<=NF;i++) if ($i ~ /^SRC=/) {sub("SRC=", "", $i); print $i}}' |
    sort | uniq -c |
    awk -v min_attempts="$min_attempts" '$1 >= min_attempts {print $1, $2}' |
    sort -nr > "$TMP_IPS.sorted"

  if [[ -n "$top_limit" ]]; then
    head -n "$top_limit" "$TMP_IPS.sorted" > "$tmp_ips"
    rm -f "$TMP_IPS.sorted"
  else
    mv "$TMP_IPS.sorted" "$tmp_ips"
  fi

  # Output Generation
  if [[ "$json_mode" == "true" ]]; then
    # JSON Mode
    generate_json_output "$tmp_ips" "$MMDB_FILE"
    echo "JSON output generated successfully." >&2
  else
    # Table Mode
    local tmp_out
    tmp_out=$(mktemp "$STATE_DIR/ufw_out.XXXXXX")
    trap 'rm -f "$tmp_ips" "$tmp_out"' EXIT

    while read -r count ip; do
      local geo_output
      geo_output=$(mmdblookup --file "$MMDB_FILE" --ip "$ip" 2>/dev/null || true)

      local country city
      IFS='|' read -r country city <<< "$(echo "$geo_output" | awk -F'"' '
        /"country"/ {in_country=1}; in_country && /"en"/ {getline; c=$2; in_country=0}
        /"city"/ {in_city=1}; in_city && /"en"/ {getline; ci=$2; in_city=0}
        END {print c "|" ci}
      ')"

      [[ -z "$country" ]] && country="-"
      [[ -z "$city" ]] && city="-"

      echo -e "${ip}\t${count}\t${country}\t${city}" >> "$tmp_out"
    done < "$tmp_ips"

    local date_label="[$(date '+%Y-%m-%d %H:%M')]"
    echo
    echo "$date_label"
    echo -e "\n[COMMAND] $CMD_ARGS" >> "$OUTPUT_LOG"
    echo "$date_label" >> "$OUTPUT_LOG"

    if [[ -s "$tmp_out" ]]; then
        (
          echo -e "IP Address\tAttempts\tCountry\tCity"
          echo -e "--------------\t----------\t--------------\t----------"
          cat "$tmp_out"
        ) | column -t -s $'\t' -o "  " | tee -a "$OUTPUT_LOG"
    else
        echo "No IPs found matching the specified criteria." | tee -a "$OUTPUT_LOG"
    fi

    echo "-------------------------------------------------------" | tee -a "$OUTPUT_LOG"
    echo
  fi
}


# ==============================================================================
# MAIN EXECUTION
# ==============================================================================
main "$@"
