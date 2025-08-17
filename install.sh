#!/usr/bin/env bash
# ==============================================================================
# SCRIPT: install.sh
# AUTHOR: Aymon
# DATE:   2025-08-06
# VERSION: 1.0.0
#
# DESCRIPTION
#   Automates the installation of the ufwcheck tool suite. It follows the XDG
#   Base Directory Specification to keep the user's home directory clean.
#   The script operates with user permissions and does not require sudo,
#   except for prompting the user to install missing system dependencies.
#
#   Installation Steps:
#   1. Checks for required command-line tools.
#   2. Interactively configures MaxMind API credentials.
#   3. Creates all necessary configuration and data directories.
#   4. Downloads the latest versions of ufwcheck.sh and geoupdate.sh.
#   5. Sets up a shell environment file for easy command access.
#   6. Optionally configures a cron job for automatic database updates.
#
# USAGE
#   ./install.sh
# ==============================================================================

set -euo pipefail

# ==============================================================================
# GLOBAL VARIABLES & CONSTANTS
# ==============================================================================

# Color definitions (ANSI 8/16 colors for maximum compatibility).
C_RESET='\e[0m'
C_BOLD='\e[1m'
C_BLUE='\e[34m'
C_GREEN='\e[32m'
C_YELLOW='\e[33m'
C_CYAN='\e[36m'

# Themed variables for colored output.
HEADER_COLOR="${C_BOLD}${C_BLUE}"
SUCCESS_COLOR="${C_GREEN}"
WARN_COLOR="${C_YELLOW}"
INFO_COLOR="${C_CYAN}"
CMD_COLOR="${C_GREEN}"

# Script Configuration.
GITHUB_USER="aymonix"
GITHUB_REPO="ufwcheck"
GITHUB_BRANCH="main"

# ==============================================================================
# FUNCTIONS
# ==============================================================================

# ------------------------------------------------------------------------------
# DESCRIPTION
#   Prints a formatted header message to the console.
#
# ARGUMENTS
#   $1 - The text to display in the header.
# ------------------------------------------------------------------------------
print_header() {
  echo -e "\n${HEADER_COLOR}--- $1 ---${C_RESET}"
}

# ------------------------------------------------------------------------------
# DESCRIPTION
#   Checks if a command exists in the system's PATH.
#
# ARGUMENTS
#   $1 - The name of the command to check.
#
# RETURNS
#   0 if the command exists, 1 otherwise.
# ------------------------------------------------------------------------------
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# ------------------------------------------------------------------------------
# DESCRIPTION
#   Checks for required system dependencies. If any are missing, it provides
#   the user with a command to install them and exits.
#
# ARGUMENTS
#   None
# ------------------------------------------------------------------------------
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
  )

  local missing_pkgs=()
  local all_deps_found=true

  for cmd in "${!CMD_TO_PKG[@]}"; do
    if ! command_exists "$cmd"; then
      all_deps_found=false
      echo -e "• Checking for '${cmd}'... ${WARN_COLOR}Not found.${C_RESET} (package: ${CMD_TO_PKG[$cmd]})"
      if [[ ! " ${missing_pkgs[*]} " =~ " ${CMD_TO_PKG[$cmd]} " ]]; then
        missing_pkgs+=("${CMD_TO_PKG[$cmd]}")
      fi
    else
      echo -e "• Checking for '${cmd}'... ${SUCCESS_COLOR}Found.${C_RESET}"
    fi
  done

  if ! $all_deps_found; then
    echo -e "\n${C_BOLD}${WARN_COLOR}ACTION REQUIRED: One or more dependencies are missing.${C_RESET}"
    echo "To install the required packages for Debian/Ubuntu, please run:"
    echo -e "  ${INFO_COLOR}sudo apt-get update && sudo apt-get install ${missing_pkgs[*]}${C_RESET}"
    echo "After installation, please run this script again."
    exit 1
  fi
  echo "All required tools are present."
}

# ------------------------------------------------------------------------------
# DESCRIPTION
#   Interactively configures MaxMind API credentials, giving the user the
#   choice between automatic setup and manual configuration. It creates both
#   the 'secrets' file and the configuration loader.
#
# ARGUMENTS
#   None
# ------------------------------------------------------------------------------
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
        echo -e "${WARN_COLOR}WARN: Input was empty. Skipping API setup. Please configure manually later.${C_RESET}"
      else
        mkdir -p "$HOME/.config/maxmind"
        cat > "$HOME/.config/maxmind/secrets" <<EOF
# MaxMind Credentials (permissions: 600)
export MAXMIND_ID="$maxmind_id"
export MAXMIND_TOKEN="$maxmind_token"
EOF
        chmod 600 "$HOME/.config/maxmind/secrets"
        echo -e "${SUCCESS_COLOR}Successfully created and secured '~/.config/maxmind/secrets'.${C_RESET}"
      fi
      ;;
    2)
      echo "Manual setup selected."
      echo "After installation, create '~/.config/maxmind/secrets' with this content:"
      echo -e "---"
      echo -e "${INFO_COLOR}export MAXMIND_ID=\"YOUR_ACCOUNT_ID\""
      echo -e "export MAXMIND_TOKEN=\"YOUR_LICENSE_KEY\"${C_RESET}"
      echo -e "---"
      echo "And set permissions: ${INFO_COLOR}chmod 600 ~/.config/maxmind/secrets${C_RESET}"
      ;;
    *)
      echo -e "${WARN_COLOR}WARN: Invalid choice. Skipping API setup. Please configure manually later.${C_RESET}"
      ;;
  esac

  # Create the configuration loader for MaxMind tools.
  mkdir -p "$HOME/.config/maxmind"
  cat > "$HOME/.config/maxmind/config.sh" << 'EOF'
#!/usr/bin/env bash
# Configuration loader for MaxMind tools.
# This file sources credentials from a separate, private file.
source "$HOME/.config/maxmind/secrets"
EOF
  echo "MaxMind configuration loader created at '~/.config/maxmind/config.sh'."
}

# ------------------------------------------------------------------------------
# DESCRIPTION
#   Creates XDG-compliant directories, downloads the main scripts from GitHub,
#   and creates the default ufwcheck configuration file.
#
# ARGUMENTS
#   None
# ------------------------------------------------------------------------------
install_files() {
  print_header "Installing Scripts and Configuration"

  echo "Creating standard XDG directories..."
  mkdir -p "$HOME/.local/bin" "$HOME/.local/share/geoip" "$HOME/.local/state" "$HOME/.config/ufwcheck"

  # Create the default configuration file for ufwcheck.sh
  echo "Creating default configuration file for ufwcheck..."
  cat > "$HOME/.config/ufwcheck/config.sh" << 'EOF'
#!/usr/bin/env bash
# === Config for ufwcheck ===

# Path to the UFW log file.
LOG_FILE="/var/log/ufw.log"

# Path to the GeoIP database.
MMDB_FILE="$HOME/.local/share/geoip/GeoLite2-City.mmdb"

# Directory for state files (temporary files and report log).
STATE_DIR="$HOME/.local/state"

# Path to the report log file.
OUTPUT_LOG="$STATE_DIR/ufwcheck.log"
EOF
  echo -e "${SUCCESS_COLOR}Successfully created '~/.config/ufwcheck/config.sh'.${C_RESET}"

  # Download the main scripts from the repository.
  local ufwcheck_url="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}/ufwcheck.sh"
  local geoupdate_url="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}/geoupdate.sh"

  echo "Downloading ufwcheck.sh..."
  curl -Lfs "$ufwcheck_url" -o "$HOME/.local/bin/ufwcheck.sh"

  echo "Downloading geoupdate.sh..."
  curl -Lfs "$geoupdate_url" -o "$HOME/.local/bin/geoupdate.sh"

  echo "Setting executable permissions..."
  chmod +x "$HOME/.local/bin/ufwcheck.sh" "$HOME/.local/bin/geoupdate.sh"
  echo -e "${SUCCESS_COLOR}Scripts installed successfully to '~/.local/bin'.${C_RESET}"
}

# ------------------------------------------------------------------------------
# DESCRIPTION
#   Creates the shell environment file with PATH adjustments and aliases.
#
# ARGUMENTS
#   None
# ------------------------------------------------------------------------------
setup_environment() {
  print_header "Setting up Shell Environment"

  cat > "$HOME/.config/ufwcheck/env.sh" << 'EOF'
#!/usr/bin/env bash
# Environment settings for ufwcheck tools.
# This file is sourced by your shell profile (e.g., .bashrc).

# Add the user's local binary directory to the PATH.
export PATH="$HOME/.local/bin:$PATH"

# Convenient aliases.
alias ufwcheck='ufwcheck.sh'
alias geoupdate='geoupdate.sh'
EOF
  echo "Environment file created at '~/.config/ufwcheck/env.sh'."
}

# ------------------------------------------------------------------------------
# DESCRIPTION
#   Interactively offers to set up a weekly cron job for database updates.
#
# ARGUMENTS
#   None
# ------------------------------------------------------------------------------
configure_cron() {
  print_header "Automatic Database Updates (Optional)"

  local choice
  read -p "Set up a weekly cron job to update the GeoLite2-City database? [y/N]: " choice

  if [[ "$choice" =~ ^[Yy]$ ]]; then
    local cron_job="0 3 * * 6 $HOME/.local/bin/geoupdate.sh >/dev/null 2>&1"
    # Safely add the cron job without overwriting existing ones.
    (crontab -l 2>/dev/null | grep -Fv "geoupdate.sh"; echo "$cron_job") | crontab -
    echo -e "${SUCCESS_COLOR}Cron job successfully added.${C_RESET}"
  else
    echo "Skipping cron job setup."
    echo "If you wish to set it up manually later, the recommended command is:"
    echo -e "  ${INFO_COLOR}0 3 * * 6 $HOME/.local/bin/geoupdate.sh >/dev/null 2>&1${C_RESET}"
    echo "(This will run every Saturday at 3 AM, the optimal time after MaxMind's final weekly update.)"
  fi
}

# ------------------------------------------------------------------------------
# DESCRIPTION
#   Prints the final, mandatory manual steps for the user to complete.
#
# ARGUMENTS
#   None
# ------------------------------------------------------------------------------
final_instructions() {
  print_header "Installation Complete!"
  echo -e "${C_BOLD}To finish the setup, one manual step is required.${C_RESET}"
  echo "Add the following line to your shell configuration file (e.g., ~/.bashrc or ~/.zshrc):"
  echo -e "\n  ${CMD_COLOR}source \"\$HOME/.config/ufwcheck/env.sh\"${C_RESET}\n"
  echo "After adding the line, restart your terminal or run 'source ~/.bashrc' to apply the changes."
  echo "You can then download the GeoLite2-City database for the first time by running:"
  echo -e "  ${CMD_COLOR}geoupdate.sh${C_RESET}"
}


# ==============================================================================
# MAIN EXECUTION
# ==============================================================================
main() {
  check_dependencies
  configure_maxmind
  install_files
  setup_environment
  configure_cron
  final_instructions
}

main
