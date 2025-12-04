#!/usr/bin/env bash
# ==============================================================================
# SCRIPT: ufwcheck.sh
# AUTHOR: Aymon
# DATE:   2025-09-26
# VERSION: 1.1.0
#
# DESCRIPTION
#   Analyzes UFW (Uncomplicated Firewall) logs to identify and report on IP
#   addresses with multiple block events. It offers flexible filtering by date,
#   excludes private networks, and can output results as a formatted table
#   or in JSON format. Geo-location data (country, city) is added for each IP.
#
# DEPENDENCIES
#   - Standard UNIX utils: grep, awk, sort, head, column
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
declare -r -A MONTH_MAP=(
  [Jan]=01 [Feb]=02 [Mar]=03 [Apr]=04 [May]=05 [Jun]=06
  [Jul]=07 [Aug]=08 [Sep]=09 [Oct]=10 [Nov]=11 [Dec]=12
)
readonly PRIVATE_IP_REGEX="^192\.168\.|^10\.|^172\.(1[6-9]|2[0-9]|3[0-1])\.|^127\."

# Fixed path to the configuration file sourced on startup.
readonly UFWCHECK_CONFIG_FILE="${HOME}/.config/ufwcheck/config.sh"


# ==============================================================================
# FUNCTIONS
# ==============================================================================

# ==============================================================================
# DESCRIPTION
#   Prints the help message and usage examples, then exits.
#
# OUTPUTS
#   Writes the full help text to STDOUT.
# ==============================================================================
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

# ==============================================================================
# DESCRIPTION
#   Validates if the provided argument is a positive integer.
#
# ARGUMENTS
#   $1 - The value to check (string).
#   $2 - The name of the flag for the error message (string).
#
# RETURNS
#   Exits with code 2 if validation fails.
# ==============================================================================
validate_positive_integer() {
  local value="$1"
  local flag_name="$2"
  if ! [[ "$value" =~ ^[1-9][0-9]*$ ]]; then
    echo "[✘] Error: The value for '$flag_name' must be a positive integer. Got: '$value'" >&2
    exit 2
  fi
}

# ==============================================================================
# DESCRIPTION
#   Checks if all required command-line tools are installed.
# ==============================================================================
check_dependencies() {
  local missing_deps=0
  for cmd in grep awk sort head column mmdblookup jq; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "[✘] Error: Required command not found: '$cmd'. Please install it." >&2
      ((missing_deps++))
    fi
  done
  if ((missing_deps > 0)); then
    exit 1
  fi
}

# ==============================================================================
# DESCRIPTION
#   Filters log entries from stdin, optionally removes private IPs, counts
#   their occurrences, and outputs a list of "count ip".
#
# ARGUMENTS
#   $1 - Flag to filter private IPs ("true" or "false").
#   $2 - Minimum number of attempts for an IP to be included.
#
# OUTPUTS
#   Writes an unsorted list of "count ip" lines to STDOUT.
# ==============================================================================
process_logs() {
  local filter_private="$1"; shift
  local min_attempts="$1"; shift

  awk -v filter_private="$filter_private" \
      -v min_attempts="$min_attempts" \
      -v private_ip_regex="$PRIVATE_IP_REGEX" '
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
}

# ==============================================================================
# DESCRIPTION
#   Checks all system dependencies and configuration files. Exits if any
#   checks fail.
#
# GLOBAL VARIABLES
#   UFWCHECK_CONFIG_FILE, LOG_FILE, MMDB_FILE, STATE_DIR
# ==============================================================================
check_environment() {
  check_dependencies

  if [[ ! -f "$UFWCHECK_CONFIG_FILE" || ! -r "$UFWCHECK_CONFIG_FILE" ]]; then
    echo "[✘] Error: Configuration file not found or not readable at '$UFWCHECK_CONFIG_FILE'." >&2
    echo "    Please create it based on the example in the README file." >&2
    exit 1
  fi

  # shellcheck source=/dev/null
  source "$UFWCHECK_CONFIG_FILE"

  if [[ ! -r "$LOG_FILE" ]]; then
      echo "[✘] Error: UFW log file not found or not readable at '$LOG_FILE'." >&2
      exit 1
  fi
  if [[ ! -r "$MMDB_FILE" ]]; then
      echo "[✘] Error: GeoIP database not found or not readable at '$MMDB_FILE'." >&2
      exit 1
  fi

  mkdir -p "$STATE_DIR"
}

# ==============================================================================
# DESCRIPTION
#   Parses command-line arguments and sets option variables in the caller's scope.
#   Exits with an error code on any parsing failure.
#
# ARGUMENTS
#   $@ - The full list of command-line arguments.
# ==============================================================================
parse_arguments() {
  require_argument() {
    local option="$1"
    local argument="$2"
    if [[ -z "$argument" ]]; then
      echo "[✘] Error: Option '$option' requires an argument." >&2
      exit 2
    fi
  }

  while [[ $# -gt 0 ]]; do
    local current_option="$1"
    case "$current_option" in
      --today)
        mode="today"; shift
        ;;
      --date)
        require_argument "$current_option" "${2-}"
        mode="date"; value="$2"; shift 2
        ;;
      --days|-d)
        require_argument "$current_option" "${2-}"
        mode="days"; value="$2"; shift 2
        ;;
      --month|-m)
        require_argument "$current_option" "${2-}"
        mode="month"; value="$2"; shift 2
        ;;
      --top|-t)
        require_argument "$current_option" "${2-}"
        top_limit="$2"; shift 2
        ;;
      --attempts|-a)
        require_argument "$current_option" "${2-}"
        min_attempts="$2"; shift 2
        ;;
      --json)
        json_mode="true"; shift
        ;;
      --no-private)
        filter_private="true"; shift
        ;;
      --help|-h)
        print_help
        ;;
      *)
        echo "[✘] Error: Unknown option '$current_option'. Use --help for usage." >&2
        exit 2
        ;;
    esac
  done
}

# ==============================================================================
# DESCRIPTION
#   Takes raw IP data, enriches it with GeoIP information using a batch
#   database lookup, and outputs a universal, tab-separated stream of
#   enriched data.
#
# ARGUMENTS
#   $1 - The path to the temporary file containing raw "count ip" data.
#
# GLOBAL VARIABLES
#   MMDB_FILE
#
# OUTPUTS
#   Writes a tab-separated stream of "ip\tcount\tcountry\tcity" to STDOUT.
# ==============================================================================
geo_data() {
  local tmp_ips="$1"
  local mmdb_stream

  # Step 1: Get the raw data stream from mmdblookup in a single batch call.
  mmdb_stream=$(awk '{print $2}' "$tmp_ips" | mmdblookup --file "$MMDB_FILE" --ip - 2>/dev/null)

  # Step 2: Join original "count ip" data with the parsed mmdb_stream.
  paste "$tmp_ips" <(
    echo "$mmdb_stream" | awk '
      BEGIN { RS = "" }
      {
        country = "-"
        city = "-"
        in_country_names = 0
        in_city_names = 0

        for (i = 1; i <= NF; i++) {
          if ($i == "\"country\":") { in_country_names = 1 }
          if ($i == "\"city\":") { in_city_names = 1 }

          if (in_country_names && $i == "\"en\":") {
            value = ""
            for (j = i + 1; j <= NF; j++) {
              if ($(j) ~ /</) { break }
              value = value (value == "" ? "" : " ") $(j)
            }
            country = value
            in_country_names = 0
          }
          if (in_city_names && $i == "\"en\":") {
            value = ""
            for (j = i + 1; j <= NF; j++) {
              if ($(j) ~ /</) { break }
              value = value (value == "" ? "" : " ") $(j)
            }
            city = value
            in_city_names = 0
          }
        }
        gsub(/^"|"/, "", country)
        gsub(/^"|"/, "", city)
        print country "\t" city
      }
    '
  ) | awk '{printf "%s\t%s\t%s\t%s\n", $2, $1, $3, $4}'
}

# ==============================================================================
# DESCRIPTION
#   Takes enriched data and formats it as a JSON object.
#
# ARGUMENTS
#   $1 - The path to the temporary file containing raw IP data.
# ==============================================================================
format_json() {
  local tmp_ips="$1"

  geo_data "$tmp_ips" | jq -R -s '
    split("\n") | .[0:-1] | map(
      split("\t") | {
        ip: .[0],
        attempts: .[1] | tonumber,
        country: .[2],
        city: (if .[3] == "-" then null else .[3] end)
      }
    ) | sort_by(-.attempts)
  '
  echo "JSON output generated successfully." >&2
}

# ==============================================================================
# DESCRIPTION
#   Takes enriched data and formats it as a table.
#
# ARGUMENTS
#   $1 - The path to the temporary file containing raw IP data.
#   $2 - The path to the temporary file for building the table output.
#
# GLOBAL VARIABLES
#   CMD_ARGS, OUTPUT_LOG
# ==============================================================================
format_table() {
  local tmp_ips="$1"
  local tmp_out="$2"
  local date_label

  geo_data "$tmp_ips" > "$tmp_out"

  date_label="[$(LC_TIME=C date '+%Y-%m-%d %H:%M')]"
  echo
  echo "$date_label"
  printf "\n[COMMAND] %s\n" "$CMD_ARGS" >> "$OUTPUT_LOG"
  echo "$date_label" >> "$OUTPUT_LOG"

  if [[ -s "$tmp_out" ]]; then
      (
        printf "IP Address\tAttempts\tCountry\tCity\n"
        printf -- "--------------\t----------\t--------------\t----------\n"
        cat "$tmp_out"
      ) | column -t -s $'\t' -o "  " | tee -a "$OUTPUT_LOG"
  else
      echo "No IPs found matching the specified criteria." | tee -a "$OUTPUT_LOG"
  fi

  echo "-------------------------------------------------------" | tee -a "$OUTPUT_LOG"
  echo
}

# ==============================================================================
# DESCRIPTION
#   Extracts and processes log data into a temporary file.
#
# ARGUMENTS
#   $1 - The path to the temporary file where processed IP data will be stored.
#
# GLOBAL VARIABLES
#   LOG_FILE, MONTH_MAP
# ==============================================================================
extract_data() {
  local tmp_ips="$1"
  local date_regex
  local final_regex
  local dates
  local month_num
  local limit_pipe=("cat")

  case "$mode" in
    today) date_regex="^$(LC_TIME=C date '+%Y-%m-%d')T";;
    date)
      if ! [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo "[✘] Error: Date must be in YYYY-MM-DD format. Got: '$value'" >&2
        exit 2
      fi
      date_regex="^${value}T";;
    days)
      dates=()
      for ((i=0; i<value; i++)); do dates+=("$(LC_TIME=C date -d "-$i day" '+%Y-%m-%d')"); done
      date_regex=$(printf '^%sT|' "${dates[@]}"); date_regex=${date_regex%|};;
    month)
      month_num="${MONTH_MAP[$value]}"
      if [[ -z "$month_num" ]]; then
        echo "[✘] Error: Invalid month abbreviation '$value'. Use Jan, Feb, etc." >&2
        exit 2
      fi
      date_regex="^....-${month_num}-[0-9][0-9]T";;
  esac

  if [[ -n "$top_limit" ]]; then
    limit_pipe=("head" "-n" "$top_limit")
  fi

  final_regex="${date_regex}.*UFW BLOCK"
  grep -E "$final_regex" "$LOG_FILE" | \
  process_logs "$filter_private" "$min_attempts" | \
  sort -nr | \
  "${limit_pipe[@]}" > "$tmp_ips"
}

# ==============================================================================
# DESCRIPTION
#   Orchestrates the report generation process by calling data extraction and
#   formatting functions.
#
# ARGUMENTS
#   $1 - The path to the temporary file for storing processed IP data.
#   $2 - The path to the temporary file for building the table output.
# ==============================================================================
generate_report() {
  local tmp_ips="$1"
  local tmp_out="$2"

  extract_data "$tmp_ips"

  if [[ "$json_mode" == "true" ]]; then
    format_json "$tmp_ips"
  else
    format_table "$tmp_ips" "$tmp_out"
  fi
}

# ==============================================================================
# DESCRIPTION
#   Main function to orchestrate the entire script execution.
#
# ARGUMENTS
#   $@ - All script arguments are passed here.
# ==============================================================================
main() {
  local mode="today"
  local value=""
  local top_limit=""
  local min_attempts=2
  local json_mode="false"
  local filter_private="false"
  local tmp_ips
  local tmp_out

  check_environment

  tmp_ips=$(mktemp "$STATE_DIR/ufw_ips.XXXXXX")
  tmp_out=$(mktemp "$STATE_DIR/ufw_out.XXXXXX")
  trap 'rm -f "$tmp_ips" "$tmp_out"' EXIT

  parse_arguments "$@"

  if [[ "$mode" == "days" ]]; then
    validate_positive_integer "$value" "--days"
  fi

  if [[ -n "$top_limit" ]]; then
    validate_positive_integer "$top_limit" "--top"
  fi

  validate_positive_integer "$min_attempts" "--attempts"

  generate_report "$tmp_ips" "$tmp_out"
}


# ==============================================================================
# MAIN EXECUTION
# ==============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
