#!/usr/bin/env bash
# ==============================================================================
# SCRIPT: install.sh
# AUTHOR: Aymon
# DATE:   2025-09-26
# VERSION: 1.1.0
#
# DESCRIPTION
#   Automates the installation of the ufwcheck tool suite. It follows the XDG
#   Base Directory Specification to keep the user's home directory clean.
#   The script operates with user permissions and does not require sudo,
#   except for prompting the user to install missing system dependencies.
#
#   Installation Steps:
#   1. Checks for required command-line tools.
#   2. Creates necessary directories and configuration, then downloads and verifies
#      the core scripts (ufwcheck.sh, geoupdate.sh).
#   3. Interactively configures MaxMind API credentials.
#   4. Sets up a shell environment file for easy command access.
#   5. Optionally configures a cron job for automatic database updates.
#   6. Displays the final manual step required to complete the installation.
#
# USAGE
#   ./install.sh
# ==============================================================================

set -euo pipefail

# ==============================================================================
# GLOBAL VARIABLES & CONSTANTS
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
readonly UFWCHECK_CONFIG_DIR="${HOME}/.config/ufwcheck"
readonly MAXMIND_CONFIG_DIR="${HOME}/.config/maxmind"
readonly GEOIP_DATA_DIR="${HOME}/.local/share/geoip"
readonly BIN_DIR="${HOME}/.local/bin"
readonly STATE_DIR="${HOME}/.local/state"

# Project Files.
readonly UFWCHECK_SCRIPT_PATH="${BIN_DIR}/ufwcheck.sh"
readonly GEOUPDATE_SCRIPT_PATH="${BIN_DIR}/geoupdate.sh"
readonly SHA_SUM_PATH="${BIN_DIR}/SHA256SUMS"
readonly MAXMIND_SECRETS_FILE="${MAXMIND_CONFIG_DIR}/secrets"
readonly MAXMIND_CONFIG_FILE="${MAXMIND_CONFIG_DIR}/config.sh"
readonly UFWCHECK_CONFIG_FILE="${UFWCHECK_CONFIG_DIR}/config.sh"
readonly UFWCHECK_ENV_FILE="${UFWCHECK_CONFIG_DIR}/env.sh"

# ==============================================================================
# FUNCTIONS
# ==============================================================================

# ==============================================================================
# DESCRIPTION
#   Prints a formatted header message to the console.
#
# ARGUMENTS
#   $1 - The text to display in the header.
#
# GLOBAL VARIABLES
#   THEME_HEADER
#   THEME_RESET
# ==============================================================================
print_header() {
  echo -e "\n${THEME_HEADER}--- $1 ---${THEME_RESET}"
}

# ==============================================================================
# DESCRIPTION
#   Checks if a command exists in the system's PATH.
#
# ARGUMENTS
#   $1 - The name of the command to check.
#
# RETURNS
#   0 if the command exists, 1 otherwise.
# ==============================================================================
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# ==============================================================================
# DESCRIPTION
#   Checks for required system dependencies. If any are missing, it provides
#   the user with a command to install them and exits.
#
# ARGUMENTS
#   None
#
# GLOBAL VARIABLES
#   THEME_WARN, THEME_SUCCESS, THEME_INFO, THEME_RESET, C_BOLD
# ==============================================================================
check_dependencies() {
  print_header "Welcome to the ufwcheck Installer"
  echo "This script will guide you through the installation process."

  print_header "Checking for Required Tools"

  declare -A CMD_TO_PKG=(
    [curl]="curl"
    [mmdblookup]="mmdb-bin"
    [column]="util-linux"
    [crontab]="cron"
    [jq]="jq"
    [sha256sum]="coreutils"
  )

  local missing_pkgs=()
  local all_deps_found=true

  for cmd in "${!CMD_TO_PKG[@]}"; do
    if ! command_exists "$cmd"; then
      all_deps_found=false
      echo -e "Checking for '${cmd}'... ${THEME_WARN}Not found.${THEME_RESET} (package: ${CMD_TO_PKG[$cmd]})"
      if [[ ! " ${missing_pkgs[*]} " =~ " ${CMD_TO_PKG[$cmd]} " ]]; then
        missing_pkgs+=("${CMD_TO_PKG[$cmd]}")
      fi
    else
      echo -e "Checking for '${cmd}'... ${THEME_SUCCESS}Found.${THEME_RESET}"
    fi
  done

  if ! $all_deps_found; then
    echo -e "\n${C_BOLD}${THEME_WARN}ACTION REQUIRED: One or more dependencies are missing.${THEME_RESET}"
    echo "To install the required packages for Debian/Ubuntu, please run:"
    echo -e "  ${THEME_INFO}sudo apt-get update && sudo apt-get install ${missing_pkgs[@]}${THEME_RESET}"
    echo "After installation, please run this script again."
    exit 1
  fi
  echo "All required tools are present."
}

# ==============================================================================
# DESCRIPTION
#   Interactively configures MaxMind API credentials, giving the user the
#   choice between automatic setup and manual configuration. It creates both
#   the 'secrets' file and the configuration loader.
#
# ARGUMENTS
#   None
#
# GLOBAL VARIABLES
#   MAXMIND_CONFIG_DIR, MAXMIND_SECRETS_FILE, MAXMIND_CONFIG_FILE
#   THEME_WARN, THEME_SUCCESS, THEME_INFO, THEME_RESET
# ==============================================================================
configure_maxmind() {
  print_header "MaxMind API Configuration"
  echo "The update script requires a MaxMind Account ID and License Key."

  local choice
  read -p "How would you like to configure access? [1] Interactive (Recommended) [2] Manual: " choice
  choice=${choice:-1}

  case "$choice" in
    1)
      echo "Entering interactive setup..."
      local maxmind_id maxmind_token
      read -p "Please enter your MaxMind Account ID: " maxmind_id
      read -s -p "Please enter your MaxMind License Key: " maxmind_token
      echo

      if [[ -z "$maxmind_id" || -z "$maxmind_token" ]]; then
        echo -e "${THEME_WARN}WARN: Input was empty. Skipping API setup. Please configure manually later.${THEME_RESET}"
      else
        mkdir -p "$MAXMIND_CONFIG_DIR"
        cat > "$MAXMIND_SECRETS_FILE" <<EOF
# MaxMind Credentials (permissions: 600)
export MAXMIND_ID="$maxmind_id"
export MAXMIND_TOKEN="$maxmind_token"
EOF
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
#!/usr/bin/env bash
# === Config for MaxMind ===

# This file sources credentials from a separate, private file.
source "$MAXMIND_SECRETS_FILE"

# Public URLs for GeoLite2-City database downloads
export DOWNLOAD_URL="https://download.maxmind.com/geoip/databases/GeoLite2-City/download?suffix=tar.gz"
export SHA_URL="https://download.maxmind.com/geoip/databases/GeoLite2-City/download?suffix=tar.gz.sha256"
EOF
  echo "MaxMind configuration loader created at ${MAXMIND_CONFIG_FILE}."
}

# ==============================================================================
# DESCRIPTION
#   Creates XDG-compliant directories, downloads and verifies the main scripts
#   from GitHub, and creates the default ufwcheck configuration file.
#
# ARGUMENTS
#   None
#
# GLOBAL VARIABLES
#   BIN_DIR, GEOIP_DATA_DIR, STATE_DIR, UFWCHECK_CONFIG_DIR
#   UFWCHECK_CONFIG_FILE, UFWCHECK_SCRIPT_PATH, GEOUPDATE_SCRIPT_PATH
#   SHA_SUM_PATH, GITHUB_USER, GITHUB_REPO, GITHUB_BRANCH
#   THEME_SUCCESS, THEME_WARN, THEME_RESET
# ==============================================================================
install_files() {
  print_header "Installing Scripts and Configuration"

  # Step 1: Create all necessary XDG-compliant directories.
  echo "Creating standard XDG directories..."
  mkdir -p "$BIN_DIR" "$GEOIP_DATA_DIR" "$STATE_DIR" "$UFWCHECK_CONFIG_DIR"

  # Step 2: Create the default configuration file for ufwcheck.
  echo "Creating default configuration file for ufwcheck..."
  cat > "$UFWCHECK_CONFIG_FILE" << EOF
#!/usr/bin/env bash
# === Config for ufwcheck ===

# Path to the UFW log file.
LOG_FILE="/var/log/ufw.log"

# Path to the GeoIP database.
MMDB_FILE="${GEOIP_DATA_DIR}/GeoLite2-City.mmdb"

# Directory for state files (temporary files and report log).
STATE_DIR="${STATE_DIR}"

# Path to the report log file.
OUTPUT_LOG="$STATE_DIR/ufwcheck.log"
EOF
  echo -e "${THEME_SUCCESS}Successfully created ${UFWCHECK_CONFIG_FILE}.${THEME_RESET}"

  # Step 3: Download the main scripts and checksum file from GitHub.
  local base_url="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}"
  local ufwcheck_url="${base_url}/ufwcheck.sh"
  local geoupdate_url="${base_url}/geoupdate.sh"
  local sha_url="${base_url}/SHA256SUMS"

  echo "Downloading main scripts and checksum file..."
  curl -Lfs "$ufwcheck_url" -o "$UFWCHECK_SCRIPT_PATH"
  curl -Lfs "$geoupdate_url" -o "$GEOUPDATE_SCRIPT_PATH"
  curl -Lfs "$sha_url" -o "$SHA_SUM_PATH"

  # Step 4: Verify the integrity of the downloaded scripts using sha256sum.
  echo "Verifying script integrity..."
  if ! (cd "$BIN_DIR" && sha256sum -c --ignore-missing --status SHA256SUMS); then
    echo -e "${THEME_WARN}ERROR: Checksum mismatch! The downloaded scripts may be compromised.${THEME_RESET}" >&2
    echo "Aborting installation to ensure system safety." >&2
    
    # Clean up potentially compromised or incomplete files.
    rm -f "$UFWCHECK_SCRIPT_PATH" "$GEOUPDATE_SCRIPT_PATH" "$SHA_SUM_PATH"
    exit 1
  fi
  
  # Clean up the checksum file after successful verification.
  rm -f "$SHA_SUM_PATH"
  echo -e "${THEME_SUCCESS}Scripts verified successfully.${THEME_RESET}"

  # Step 5: Set executable permissions for the scripts.
  echo "Setting executable permissions..."
  chmod +x "$UFWCHECK_SCRIPT_PATH" "$GEOUPDATE_SCRIPT_PATH"
  echo -e "${THEME_SUCCESS}Scripts installed successfully to ${BIN_DIR}.${THEME_RESET}"
}

# ==============================================================================
# DESCRIPTION
#   Creates the shell environment file with PATH adjustments and aliases.
#
# ARGUMENTS
#   None
#
# GLOBAL VARIABLES
#   UFWCHECK_ENV_FILE
#   BIN_DIR
# ==============================================================================
setup_environment() {
  print_header "Setting up Shell Environment"

  cat > "$UFWCHECK_ENV_FILE" << EOF
#!/usr/bin/env bash
# === Environment settings for ufwcheck ===
# This file is sourced by your shell profile (e.g., .bashrc).

# Add the user's local binary directory to the PATH.
export PATH="${BIN_DIR}:$PATH"

# Convenient aliases.
alias ufwcheck='ufwcheck.sh'
alias geoupdate='geoupdate.sh'
EOF
  echo "Environment file created at ${UFWCHECK_ENV_FILE}."
}

# ==============================================================================
# DESCRIPTION
#   Interactively offers to set up a weekly cron job for database updates.
#
# ARGUMENTS
#   None
#
# GLOBAL VARIABLES
#   GEOUPDATE_SCRIPT_PATH
#   THEME_SUCCESS, THEME_INFO, THEME_RESET
# ==============================================================================
configure_cron() {
  print_header "Automatic Database Updates (Optional)"

  local choice
  read -p "Set up a weekly cron job to update the GeoLite2-City database? [y/N]: " choice

  if [[ "$choice" =~ ^[Yy]$ ]]; then
    local cron_job="0 3 * * 6 ${GEOUPDATE_SCRIPT_PATH} >/dev/null 2>&1"
    # Safely add the cron job without overwriting existing ones.
    (crontab -l 2>/dev/null | grep -Fv "geoupdate.sh"; echo "$cron_job") | crontab -
    echo -e "${THEME_SUCCESS}Cron job successfully added.${THEME_RESET}"
  else
    echo "Skipping cron job setup."
    echo "If you wish to set it up manually later, the recommended command is:"
    echo -e "  ${THEME_INFO}0 3 * * 6 ${GEOUPDATE_SCRIPT_PATH} >/dev/null 2>&1${THEME_RESET}"
    echo "(This will run every Saturday at 3 AM, the optimal time after MaxMind's final weekly update.)"
  fi
}

# ==============================================================================
# DESCRIPTION
#   Prints the final, mandatory manual steps for the user to complete.
#
# ARGUMENTS
#   None
#
# GLOBAL VARIABLES
#   UFWCHECK_ENV_FILE
#   THEME_CMD, C_BOLD, THEME_RESET
# ==============================================================================
final_instructions() {
  print_header "Installation Complete!"
  echo -e "${C_BOLD}To finish the setup, one manual step is required.${THEME_RESET}"
  echo "Add the following line to your shell configuration file (e.g., ~/.bashrc or ~/.zshrc):"
  echo -e "\n  ${THEME_CMD}source \"${UFWCHECK_ENV_FILE}\"${THEME_RESET}\n"
  echo "After adding the line, restart your terminal or run 'source ~/.bashrc' to apply the changes."
  echo "You can then download the GeoLite2-City database for the first time by running:"
  echo -e "  ${THEME_CMD}geoupdate.sh${THEME_RESET}"
}


# ==============================================================================
# MAIN EXECUTION
# ==============================================================================
main() {
  check_dependencies
  install_files
  configure_maxmind
  setup_environment
  configure_cron
  final_instructions
}

main "$@"