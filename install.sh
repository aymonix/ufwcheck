#!/usr/bin/env bash
# ==============================================================================
# SCRIPT: install.sh
# VERSION: 1.0.1
#
# Description:
#   Automates the installation of the ufwcheck tool suite. It follows the XDG
#   Base Directory Specification to keep the user's home directory clean.
#   The script operates with user permissions and does not require sudo,
#   except for prompting the user to install missing system dependencies.
#
# Dependencies:
#   curl, python3, python3-maxminddb, column, jq, crontab
#
# Installation Steps:
#   1. Checks for required command-line tools and Python libraries.
#   2. Creates necessary directories and configuration, then downloads
#      the core scripts (ufwcheck, geoupdate).
#   3. Interactively configures MaxMind API credentials.
#   4. Sets up a shell environment file for easy command access.
#   5. Optionally configures a cron job for automatic database updates.
#   6. Displays the final manual step required to complete the installation.
# ==============================================================================

set -euo pipefail

# ==============================================================================
# GLOBALS & CONSTANTS
# ==============================================================================

# Color definitions (ANSI 8/16 colors).
readonly C_BOLD='\e[1m'
readonly C_BLUE='\e[34m'
readonly C_GREEN='\e[32m'
readonly C_YELLOW='\e[33m'
readonly C_CYAN='\e[36m'

# Themed variables.
readonly THEME_HEADER="${C_BOLD}${C_BLUE}"
readonly THEME_SUCCESS="${C_GREEN}"
readonly THEME_WARN="${C_YELLOW}"
readonly THEME_INFO="${C_CYAN}"
readonly THEME_CMD="${C_GREEN}"
readonly THEME_RESET='\e[0m'

# Script Configuration.
readonly GITHUB_USER="aymonix"
readonly GITHUB_REPO="ufwcheck"
readonly GITHUB_BRANCH="main"

# Project Paths.
readonly UFWCHECK_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ufwcheck"
readonly MAXMIND_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/maxmind"
readonly GEOIP_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/geoip"
readonly BIN_DIR="${HOME}/.local/bin"
readonly STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"

# Project Files.
readonly UFWCHECK_SCRIPT_PATH="${BIN_DIR}/ufwcheck"
readonly GEOUPDATE_SCRIPT_PATH="${BIN_DIR}/geoupdate"
readonly MAXMIND_SECRETS_FILE="${MAXMIND_CONFIG_DIR}/secrets"
readonly MAXMIND_CONFIG_FILE="${MAXMIND_CONFIG_DIR}/config"
readonly UFWCHECK_CONFIG_FILE="${UFWCHECK_CONFIG_DIR}/config"
readonly UFWCHECK_ENV_FILE="${UFWCHECK_CONFIG_DIR}/env"

# ==============================================================================
# FUNCTIONS
# ==============================================================================

# ==============================================================================
# Description:
#   Prints a formatted section header to the console.
#
# Args:
#   $1 - The header text to display.
# ==============================================================================
print_header() {
  echo -e "\n${THEME_HEADER}--- $1 ---${THEME_RESET}"
}

# ==============================================================================
# Description:
#   Checks if a command exists in the system's PATH.
#
# Args:
#   $1 - The command name to check.
#
# Returns:
#   0 if found, 1 otherwise.
# ==============================================================================
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# ==============================================================================
# Description:
#   Checks for all required system dependencies including the python3-maxminddb
#   library. If anything is missing, prints the install command and exits.
# ==============================================================================
check_dependencies() {
  print_header "Welcome to the ufwcheck Installer"
  echo "This script will guide you through the installation process."

  print_header "Checking for Required Tools"

  declare -A CMD_TO_PKG=(
    [curl]="curl"
    [python3]="python3"
    [column]="bsdextrautils"
    [crontab]="cron"
    [jq]="jq"
  )

  local missing_pkgs=()
  local all_deps_found="true"

  # 1. Check binary tools
  for cmd in "${!CMD_TO_PKG[@]}"; do
    if ! command_exists "$cmd"; then
      all_deps_found="false"
      echo -e "Checking for '${cmd}'... ${THEME_WARN}Not found.${THEME_RESET} (package: ${CMD_TO_PKG[$cmd]})"
      if ! printf '%s\n' "${missing_pkgs[@]}" | grep -qx "${CMD_TO_PKG[$cmd]}"; then
        missing_pkgs+=("${CMD_TO_PKG[$cmd]}")
      fi
    else
      echo -e "Checking for '${cmd}'... ${THEME_SUCCESS}Found.${THEME_RESET}"
    fi
  done

  # 2. Check Python library (maxminddb)
  if command_exists "python3"; then
    echo -n "Checking for Python library 'maxminddb'... "
    if python3 -c "import maxminddb" 2>/dev/null; then
      echo -e "${THEME_SUCCESS}Found.${THEME_RESET}"
    else
      echo -e "${THEME_WARN}Not found.${THEME_RESET}"
      all_deps_found="false"
      # Check if package is already in list to avoid duplicates
      if [[ ! " ${missing_pkgs[*]} " =~ " python3-maxminddb " ]]; then
        missing_pkgs+=("python3-maxminddb")
      fi
    fi
  fi

  if [[ "$all_deps_found" == "false" ]]; then
    echo -e "\n${C_BOLD}${THEME_WARN}ACTION REQUIRED: One or more dependencies are missing.${THEME_RESET}"
    echo "To install the required packages for Debian/Ubuntu, please run:"
    echo -e "  ${THEME_INFO}sudo apt update && sudo apt install -y ${missing_pkgs[*]}${THEME_RESET}"
    echo "After installation, please run this script again."
    return 1
  fi
  echo "All required tools are present."
}

# ==============================================================================
# Description:
#   Interactively configures MaxMind API credentials. Offers a choice between
#   guided setup and manual configuration. Creates both the secrets file and
#   the configuration loader.
#
# Globals:
#   MAXMIND_CONFIG_DIR, MAXMIND_SECRETS_FILE, MAXMIND_CONFIG_FILE
# ==============================================================================
configure_maxmind() {
  print_header "MaxMind API Configuration"
  echo "The update script requires a MaxMind Account ID and License Key."

  local choice
  read -r -p "How would you like to configure access? [1] Interactive (Recommended) [2] Manual: " choice
  choice=${choice:-1}

  case "$choice" in
    1)
      echo "Entering interactive setup..."
      local maxmind_id maxmind_token
      read -r -p "Please enter your MaxMind Account ID: " maxmind_id
      read -r -s -p "Please enter your MaxMind License Key: " maxmind_token || true
      echo

      if [[ -z "$maxmind_id" || -z "$maxmind_token" ]]; then
        echo -e "${THEME_WARN}WARN: Input was empty. Skipping API setup. Please configure manually later.${THEME_RESET}"
      else
        mkdir -p "$MAXMIND_CONFIG_DIR"
        printf '# MaxMind Credentials (permissions: 600)\nexport MAXMIND_ID="%s"\nexport MAXMIND_TOKEN="%s"\n' \
          "$maxmind_id" "$maxmind_token" > "$MAXMIND_SECRETS_FILE"
        chmod 600 "$MAXMIND_SECRETS_FILE"
        echo -e "${THEME_SUCCESS}Successfully created and secured ${MAXMIND_SECRETS_FILE}.${THEME_RESET}"
      fi
      ;;
    2)
      echo "Manual setup selected."
      echo "After installation, create ${MAXMIND_SECRETS_FILE} with this content:"
      echo -e "---"
      echo -e "${THEME_INFO}export MAXMIND_ID=\"YOUR_ACCOUNT_ID\""
      echo -e "export MAXMIND_TOKEN=\"YOUR_LICENSE_KEY\"${THEME_RESET}"
      echo -e "---"
      echo "And set permissions: ${THEME_INFO}chmod 600 ${MAXMIND_SECRETS_FILE}${THEME_RESET}"
      ;;
    *)
      echo -e "${THEME_WARN}WARN: Invalid choice. Skipping API setup. Please configure manually later.${THEME_RESET}"
      ;;
  esac

  # Create the configuration loader for MaxMind tools.
  mkdir -p "$MAXMIND_CONFIG_DIR"
  cat > "$MAXMIND_CONFIG_FILE" << EOF
# ==============================================================================
# MaxMind configuration
# Location: ${MAXMIND_CONFIG_FILE}
# Description: Sources credentials and defines GeoLite2-City download URLs.
# ==============================================================================

# Abort if secrets file is not readable
if [[ ! -r "${MAXMIND_SECRETS_FILE}" ]]; then
    echo "Error: MaxMind secrets not found at ${MAXMIND_SECRETS_FILE}" >&2
    exit 1
fi

# Authentication credentials
source "${MAXMIND_SECRETS_FILE}"

# GeoLite2-City download URLs
DOWNLOAD_URL="https://download.maxmind.com/geoip/databases/GeoLite2-City/download?suffix=tar.gz"
SHA_URL="https://download.maxmind.com/geoip/databases/GeoLite2-City/download?suffix=tar.gz.sha256"
EOF
  echo "MaxMind configuration loader created at ${MAXMIND_CONFIG_FILE}."
}

# ==============================================================================
# Description:
#   Creates XDG-compliant directories, generates the default ufwcheck config,
#   downloads scripts from GitHub, and sets executable permissions.
#
# Globals:
#   BIN_DIR, GEOIP_DATA_DIR, STATE_DIR, UFWCHECK_CONFIG_DIR
#   UFWCHECK_CONFIG_FILE, UFWCHECK_SCRIPT_PATH, GEOUPDATE_SCRIPT_PATH
#   GITHUB_USER, GITHUB_REPO, GITHUB_BRANCH
# ==============================================================================
install_files() {
  print_header "Installing Scripts and Configuration"

  echo "Creating standard XDG directories..."
  mkdir -p "$BIN_DIR" "$GEOIP_DATA_DIR" "$STATE_DIR" "$UFWCHECK_CONFIG_DIR"

  echo "Creating default configuration file for ufwcheck..."
  cat > "$UFWCHECK_CONFIG_FILE" << EOF
# ==============================================================================
# ufwcheck configuration
# Location: ${UFWCHECK_CONFIG_FILE}
# Description: Defines log paths, GeoIP database, and state directory.
# ==============================================================================

# UFW log file
LOG_FILE="/var/log/ufw.log"

# GeoIP database file
MMDB_FILE="${GEOIP_DATA_DIR}/GeoLite2-City.mmdb"

# Directory for temporary and state files
STATE_DIR="${STATE_DIR}"

# Report log file
OUTPUT_LOG="${STATE_DIR}/ufwcheck.log"
EOF
  echo -e "${THEME_SUCCESS}Successfully created ${UFWCHECK_CONFIG_FILE}.${THEME_RESET}"

  local base_url="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}"
  local ufwcheck_url="${base_url}/ufwcheck"
  local geoupdate_url="${base_url}/geoupdate"

  echo "Downloading main scripts..."
  curl -Lfs "$ufwcheck_url" -o "$UFWCHECK_SCRIPT_PATH"
  curl -Lfs "$geoupdate_url" -o "$GEOUPDATE_SCRIPT_PATH"

  echo "Setting executable permissions..."
  chmod +x "$UFWCHECK_SCRIPT_PATH" "$GEOUPDATE_SCRIPT_PATH"
  echo -e "${THEME_SUCCESS}Scripts installed successfully to ${BIN_DIR}.${THEME_RESET}"
}

# ==============================================================================
# Description:
#   Creates the shell environment file with PATH adjustments and aliases
#   for ufwcheck and geoupdate commands.
#
# Globals:
#   UFWCHECK_ENV_FILE, BIN_DIR
# ==============================================================================
setup_environment() {
  print_header "Setting up Shell Environment"

  cat > "$UFWCHECK_ENV_FILE" << EOF
# ==============================================================================
# ufwcheck Environment Settings
# Location: ${UFWCHECK_ENV_FILE}
# Description: The file is sourced from the shell profile (e.g., .bashrc).
# ==============================================================================

# Add the user's local binary directory to the PATH.
export PATH="${BIN_DIR}:\$PATH"

# Aliases.
alias ufc='ufwcheck'
alias gup='geoupdate'
EOF
  echo "Environment file created at ${UFWCHECK_ENV_FILE}."
}

# ==============================================================================
# Description:
#   Interactively offers to configure a weekly cron job for automatic
#   GeoLite2-City database updates.
#
# Globals:
#   GEOUPDATE_SCRIPT_PATH
# ==============================================================================
configure_cron() {
  print_header "Automatic Database Updates (Optional)"

  local choice
  read -r -p "Set up a weekly cron job to update the GeoLite2-City database? [y/N]: " choice

  if [[ "$choice" =~ ^[Yy]$ ]]; then
    local cron_job="0 3 * * 6 ${GEOUPDATE_SCRIPT_PATH} >/dev/null 2>&1"
    # Safely add the cron job without overwriting existing ones.
    (crontab -l 2>/dev/null | grep -Fv "${GEOUPDATE_SCRIPT_PATH}"; echo "$cron_job") | crontab -
    echo -e "${THEME_SUCCESS}Cron job successfully added.${THEME_RESET}"
  else
    echo "Skipping cron job setup."
    echo "If you wish to set it up manually later, the recommended command is:"
    echo -e "  ${THEME_INFO}0 3 * * 6 ${GEOUPDATE_SCRIPT_PATH} >/dev/null 2>&1${THEME_RESET}"
    echo "(This will run every Saturday at 3 AM, the optimal time after MaxMind's final weekly update.)"
  fi
}

# ==============================================================================
# Description:
#   Prints the final manual step required to complete the installation.
#
# Globals:
#   UFWCHECK_ENV_FILE
# ==============================================================================
final_instructions() {
  print_header "Installation Complete!"
  echo -e "${C_BOLD}To finish the setup, one manual step is required.${THEME_RESET}"
  echo "Add the following line to your shell configuration file (e.g., ~/.bashrc or ~/.zshrc):"
  echo -e "\n  ${THEME_CMD}source \"${UFWCHECK_ENV_FILE}\"${THEME_RESET}\n"
  echo "After adding the line, restart your terminal or run 'source ~/.bashrc' to apply the changes."
  echo "You can then download the GeoLite2-City database for the first time by running:"
  echo -e "  ${THEME_CMD}geoupdate${THEME_RESET}"
}

# ==============================================================================
# Description:
#   Main entry point. Runs all installation steps in sequence.
# ==============================================================================
main() {
  if [[ -f "${UFWCHECK_CONFIG_FILE}" ]]; then
    echo -e "${THEME_WARN}Existing installation detected.${THEME_RESET}"
    read -r -p "Proceed with reinstall? This will overwrite all config files. [y/N]: " choice
    [[ "$choice" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
  fi
  check_dependencies
  install_files
  configure_maxmind
  setup_environment
  configure_cron
  final_instructions
}


# ==============================================================================
# MAIN EXECUTION
# ==============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
