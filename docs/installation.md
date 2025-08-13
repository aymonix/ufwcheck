# Manual Installation Guide for ufwcheck

This guide is for advanced users who prefer to install the tool suite manually without using the `install.sh` script.

## Step 1: Fulfill Prerequisites

Before you begin, you need to ensure your system is ready.

#### Required Tools
While most standard utilities (`grep`, `sort`, etc.) are pre-installed, you must ensure the following are present:
*   `curl` (or `wget`) for downloading.
*   `column` (usually in the `util-linux` package).
*   `jq` for JSON processing.
*   `cron` if you plan to use automated updates.
*   **`mmdblookup`**: This is the core utility for reading the GeoIP database. It is **not** installed by default and is typically provided by the `mmdb-bin` package.

On Debian/Ubuntu, you can install all of them with:
```bash
sudo apt-get update && sudo apt-get install curl util-linux jq cron mmdb-bin
```

#### Required Data: The GeoLite2-City Database

1.  Sign up for a free account on the [MaxMind website](https://www.maxmind.com/en/geolite2/signup).
2.  Download the `GeoLite2-City` database archive and extract the `GeoLite2-City.mmdb` file.

You can place this `.mmdb` file anywhere you like, but you **must** specify the correct path in the configuration file later.

**Pro Tip:** We strongly recommend placing it in `~/.local/share/geoip/`. This path follows the XDG standard, does not require `sudo` permissions, and helps keep your home directory clean. The default configuration file is already set up to use this path.

## Step 2: Create Directories

Create the required XDG-compliant directories with a single command:
```bash
mkdir -p ~/.local/bin ~/.local/share/geoip ~/.local/state ~/.config/ufwcheck ~/.config/maxmind
```

## Step 3: Install the Scripts

Download the latest versions of the scripts from the repository and place them in your local bin directory.

1.  Download the scripts:
    ```bash
    curl -Lfs https://raw.githubusercontent.com/aymonix/ufwcheck/main/ufwcheck.sh -o ~/.local/bin/ufwcheck
    curl -Lfs https://raw.githubusercontent.com/aymonix/ufwcheck/main/geoupdate.sh -o ~/.local/bin/geoupdate
    ```
2.  Make them executable:
    ```bash
    chmod +x ~/.local/bin/ufwcheck.sh ~/.local/bin/geoupdate.sh
    ```

## Step 4: Create Configuration Files

You need to create three configuration files.

**A. MaxMind Secrets File**
Create `~/.config/maxmind/secrets` and add your credentials. This file must be kept private.
```bash
# Contents for ~/.config/maxmind/secrets
export MAXMIND_ID="YOUR_ACCOUNT_ID"
export MAXMIND_TOKEN="YOUR_LICENSE_KEY"
```
Set its permissions to `600`:
```bash
chmod 600 ~/.config/maxmind/secrets
```

**B. MaxMind Config Loader**
Create `~/.config/maxmind/config.sh` to load the secrets.
```bash
# Contents for ~/.config/maxmind/config.sh
#!/usr/bin/env bash
source "$HOME/.config/maxmind/secrets"
```

**C. ufwcheck Config File**
Create the main configuration file `~/.config/ufwcheck/config.sh`.
```bash
# Contents for ~/.config/ufwcheck/config.sh
#!/usr/bin/env bash
LOG_FILE="/var/log/ufw.log"
MMDB_FILE="$HOME/.local/share/geoip/GeoLite2-City.mmdb"
STATE_DIR="$HOME/.local/state"
OUTPUT_LOG="$STATE_DIR/ufwcheck.log"
```

## Step 5: Set Up Shell Environment

Create the environment file `~/.config/ufwcheck/env.sh` to enable aliases and PATH access.
```bash
# Contents for ~/.config/ufwcheck/env.sh
#!/usr/bin/env bash
export PATH="$HOME/.local/bin:$PATH"
alias ufwcheck='ufwcheck.sh'
alias geoupdate='geoupdate.sh'
```

## Step 6: Final Steps

1.  **Activate the Environment:** Add the following line to your `~/.bashrc` or `~/.zshrc`:
    ```bash
    source "$HOME/.config/ufwcheck/env.sh"
    ```
    Restart your terminal or run `source ~/.bashrc` to apply the changes.

2.  **Initial Database Download:** Run `geoupdate` for the first time to download the GeoLite2-City database.
    ```bash
    geoupdate
    ```

The installation is now complete.
