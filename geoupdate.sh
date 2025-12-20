#!/usr/bin/env bash
# ==============================================================================
# SCRIPT: geoupdate.sh
# AUTHOR: Aymon
# DATE:   2025-12-12
# VERSION: 1.2.0
#
# DESCRIPTION
#   Downloads and verifies the latest GeoLite2-City.mmdb database from MaxMind.
#   It uses credentials sourced via a configuration loader, verifies the
#   archive's checksum, unpacks the database to the user's local share
#   directory, and logs all operations with timestamps.
#
# DEPENDENCIES
#   curl, awk, sha256sum, tar
#   A valid MaxMind account and credentials configured in ~/.config/maxmind/
#
# USAGE
#   geoupdate.sh
# ==============================================================================

set -euo pipefail

# ==============================================================================
# GLOBAL VARIABLES & CONSTANTS
# ==============================================================================
readonly UFWCHECK_CONFIG_FILE="$HOME/.config/ufwcheck/config.sh"
readonly MAXMIND_CONFIG_FILE="$HOME/.config/maxmind/config.sh"


# ==============================================================================
# FUNCTIONS
# ==============================================================================

# ==============================================================================
# DESCRIPTION
#   Checks if all required command-line tools are installed.
#
# OUTPUTS
#   Writes error messages to STDERR if tools are missing.
#
# RETURNS
#   Exits the script with code 1 if dependencies are missing.
# ==============================================================================
check_dependencies() {
  local missing_deps=0
  for cmd in curl awk sha256sum tar; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "ERROR: Required command not found: '$cmd'. Please install it." >&2
      ((missing_deps++))
    fi
  done
  if ((missing_deps > 0)); then
    exit 1
  fi
}

# ==============================================================================
# DESCRIPTION
#   Encapsulates the core update logic: download, verification, and unpacking.
#
# GLOBAL VARIABLES
#   MAXMIND_ID, MAXMIND_TOKEN, MMDB_FILE, STATE_DIR, DOWNLOAD_URL, SHA_URL
#   tmp_dir (modified)
#
# OUTPUTS
#   Writes status messages to STDOUT and error messages to STDERR.
#
# RETURNS
#   Exits the script with code 1 on network, checksum, or security errors.
# ==============================================================================
run_update() {
  if [[ -z "${MAXMIND_ID:-}" ]]; then
    echo "ERROR: MAXMIND_ID is not set or is empty in your secrets file." >&2
    exit 1
  fi
  if [[ -z "${MAXMIND_TOKEN:-}" ]]; then
    echo "ERROR: MAXMIND_TOKEN is not set or is empty in your secrets file." >&2
    exit 1
  fi

  local geoip_data_dir
  geoip_data_dir=$(dirname "$MMDB_FILE")

  mkdir -p "$geoip_data_dir"

  # Variable must be global to survive function scope for the EXIT trap
  tmp_dir="$(mktemp -d "$STATE_DIR/geoupdate.XXXXXX")"
  trap 'rm -rf "$tmp_dir"' EXIT

  local tmp_archive="$tmp_dir/GeoLite2-City.tar.gz"
  local tmp_sha256="$tmp_dir/GeoLite2-City.tar.gz.sha256"

  echo "Downloading GeoLite2-City database..."
  curl -s -f -u "$MAXMIND_ID:$MAXMIND_TOKEN" -L "$DOWNLOAD_URL" -o "$tmp_archive"

  echo "Downloading checksum..."
  curl -s -f -u "$MAXMIND_ID:$MAXMIND_TOKEN" -L "$SHA_URL" -o "$tmp_sha256"

  echo "Verifying checksum..."
  # Extract hash to ignore upstream filename mismatches.
  local expected_hash
  expected_hash=$(awk '{print $1}' "$tmp_sha256")

  # Validate local file via constructed stdin input.
  if ! (cd "$tmp_dir" && echo "$expected_hash  GeoLite2-City.tar.gz" | sha256sum -c --status); then
    echo "ERROR: SHA256 mismatch! The downloaded file may be corrupt." >&2
    exit 1
  fi
  echo "Checksum OK."

  echo "Verifying archive content for unsafe file paths..."
  # Security: Check for unsafe paths (e.g., / or ../) to prevent "Tar Slip".
  if tar -tf "$tmp_archive" | grep -q -e '^/' -e '\.\./'; then
    echo "ERROR: Archive contains potentially unsafe file paths. Aborting." >&2
    exit 1
  fi
  echo "Archive content is safe."

  echo "Unpacking archive to $geoip_data_dir..."
  tar -xzf "$tmp_archive" -C "$geoip_data_dir" --strip-components=1

  echo "GeoLite2-City database updated successfully."
}

# ==============================================================================
# DESCRIPTION
#   Loads configuration, sets up logging, and orchestrates the script execution.
#
# GLOBAL VARIABLES
#   UFWCHECK_CONFIG_FILE, MAXMIND_CONFIG_FILE
#
# OUTPUTS
#   Writes formatted log entries to the log file and STDOUT.
#
# RETURNS
#   Exits the script with code 1 if configuration files are missing.
# ==============================================================================
main() {
  check_dependencies

  # Load project paths from the ufwcheck config.
  if [[ ! -r "$UFWCHECK_CONFIG_FILE" ]]; then
    echo "ERROR: Cannot read ufwcheck config file: $UFWCHECK_CONFIG_FILE" >&2
    exit 1
  fi
  # shellcheck source=/dev/null
  source "$UFWCHECK_CONFIG_FILE"

  # Load credentials and URLs from the MaxMind config.
  if [[ ! -r "$MAXMIND_CONFIG_FILE" ]]; then
    echo "ERROR: Cannot read MaxMind config file: $MAXMIND_CONFIG_FILE" >&2
    exit 1
  fi
  # shellcheck source=/dev/null
  source "$MAXMIND_CONFIG_FILE"

  local GEO_LOG_FILE="${STATE_DIR}/geoupdate.log"
  mkdir -p "$STATE_DIR"

  {
    run_update
  } 2>&1 | awk '{
      if ($0 ~ /^ERROR:/) {
          print "[ERROR] " strftime("[%Y-%m-%d %H:%M:%S]") " " $0
      } else {
          print "[INFO ] " strftime("[%Y-%m-%d %H:%M:%S]") " " $0
      }
      fflush()
  }' | tee -a "$GEO_LOG_FILE"
}


# ==============================================================================
# MAIN EXECUTION
# ==============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
