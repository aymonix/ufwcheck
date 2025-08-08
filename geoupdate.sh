#!/usr/bin/env bash
# ==============================================================================
# SCRIPT: geoupdate.sh
# AUTHOR: Aymon
# DATE:   2025-08-06
# VERSION: 1.0.0
#
# DESCRIPTION
#   Downloads and verifies the latest GeoLite2-City.mmdb database from MaxMind.
#   It uses credentials sourced via a configuration loader, verifies the
#   archive's checksum, unpacks the database to the user's local share
#   directory, and logs all operations with timestamps.
#
# DEPENDENCIES
#   - curl, awk, sha256sum, tar
#   - A valid MaxMind account and credentials configured in ~/.config/maxmind/
#
# USAGE
#   geoupdate.sh
# ==============================================================================

set -euo pipefail

# ==============================================================================
# GLOBAL VARIABLES & CONSTANTS
# ==============================================================================
readonly STATE_DIR="$HOME/.local/state"
readonly LOG_FILE="$STATE_DIR/geoupdate.log"


# ==============================================================================
# FUNCTIONS
# ==============================================================================

# ------------------------------------------------------------------------------
# DESCRIPTION
#   Encapsulates the entire update logic to ensure all output is captured by
#   the logging mechanism.
#
# ARGUMENTS
#   None
# ------------------------------------------------------------------------------
run_update() {
  # Load credentials via the central config loader.
  local CONFIG_FILE="$HOME/.config/maxmind/config.sh"
  if [[ ! -r "$CONFIG_FILE" ]]; then
    echo "ERROR: Cannot read config file: $CONFIG_FILE" >&2
    exit 1
  fi
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"

  if [[ -z "${MAXMIND_ID:-}" || -z "${MAXMIND_TOKEN:-}" ]]; then
    echo "ERROR: MAXMIND_ID or MAXMIND_TOKEN is not exported by $CONFIG_FILE" >&2
    exit 1
  fi

  local DEST_DIR="$HOME/.local/share/geoip"
  local DOWNLOAD_URL="https://download.maxmind.com/geoip/databases/GeoLite2-City/download?suffix=tar.gz"
  local SHA_URL="https://download.maxmind.com/geoip/databases/GeoLite2-City/download?suffix=tar.gz.sha256"

  mkdir -p "$DEST_DIR"

  # Create a temporary directory within our state folder for cleanliness.
  local tmp_dir
  tmp_dir="$(mktemp -d "$STATE_DIR/geoupdate.XXXXXX")"
  trap 'rm -rf "$tmp_dir"' EXIT

  local tmp_archive="$tmp_dir/GeoLite2-City.tar.gz"
  local tmp_sha256="$tmp_dir/GeoLite2-City.tar.gz.sha256"

  echo "Downloading GeoLite2-City database..."
  curl -s -f -u "$MAXMIND_ID:$MAXMIND_TOKEN" -L "$DOWNLOAD_URL" -o "$tmp_archive"

  echo "Downloading checksum..."
  curl -s -f -u "$MAXMIND_ID:$MAXMIND_TOKEN" -L "$SHA_URL" -o "$tmp_sha256"

  echo "Verifying checksum..."
  local expected_sum
  expected_sum=$(awk '{print $1}' "$tmp_sha256")

  local actual_sum
  actual_sum=$(sha256sum "$tmp_archive" | awk '{print $1}')

  if [[ "$expected_sum" != "$actual_sum" ]]; then
    echo "ERROR: SHA256 mismatch!" >&2
    echo "Expected: $expected_sum" >&2
    echo "Actual:   $actual_sum" >&2
    exit 1
  fi
  echo "Checksum OK."

  echo "Unpacking archive to $DEST_DIR..."
  tar -xzf "$tmp_archive" -C "$DEST_DIR" --strip-components=1

  echo "GeoLite2-City database updated successfully."
}

# ------------------------------------------------------------------------------
# DESCRIPTION
#   Main function to set up logging and orchestrate the script execution.
#
# ARGUMENTS
#   All script arguments are passed here (currently none).
# ------------------------------------------------------------------------------
main() {
  mkdir -p "$STATE_DIR"

  # Redirect all output of the main logic to the log file and terminal.
  {
    run_update
  } > >(while read -r line; do echo "[INFO ] $(date '+%Y-%m-%d %H:%M:%S') $line"; done | tee -a "$LOG_FILE") \
    2> >(while read -r line; do echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $line"; done | tee -a "$LOG_FILE")
}


# ==============================================================================
# MAIN EXECUTION
# ==============================================================================
main "$@"
