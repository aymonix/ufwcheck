# Manual Installation Guide for ufwcheck

This guide is for advanced users who prefer to install the tool suite manually without using the `install.sh` script.

## Step 1: Fulfill Prerequisites

Before you begin, you need to ensure your system is ready.

### Required Tools
While most standard utilities (`grep`, `sort`, etc.) are pre-installed, you must ensure the following are present:
*   `curl` for downloading.
*   `python3` (usually pre-installed).
*   `python3-maxminddb`: Python library for fast GeoIP lookups.
*   `zcat`: Provided by the `gzip` package (for reading compressed logs).
*   `column` in the `bsdextrautils` package.
*   `jq` for JSON processing.
*   `cron` if you plan to use automated updates.

On Debian/Ubuntu, you can install all of them with:
```bash
sudo apt update && sudo apt install -y curl python3 python3-maxminddb gzip bsdextrautils jq cron
```

### Required Data: MaxMind Account & GeoIP Database

`ufwcheck` relies on the `GeoLite2-City.mmdb` database for geolocation. For the system to function correctly, this file should be placed at the recommended location: `~/.local/share/geoip/GeoLite2-City.mmdb`. This path follows the XDG standard, does not require `sudo` permissions. The default configuration file is already set up to use this path.

To obtain and manage this database, you will need a free MaxMind account.

1.  Sign up for a free account on the [MaxMind](https://www.maxmind.com/en/geolite2/signup) website.
2.  Obtain your Account ID and License Key. These credentials should be configured as described in Step 4.

There are two ways to place the database file in the required location:

&nbsp;
**Automated Management (Recommended)**

The `geoupdate` script is designed to handle the initial download, and can be scheduled with cron for fully automated subsequent updates. This is the most convenient and reliable method. After configuring your credentials, you will simply run the script as shown in the final step of this guide.

&nbsp;
**Manual Placement**

If you already have a `GeoLite2-City.mmdb` file and prefer to manage it manually, simply place your `.mmdb` file at the recommended path: `~/.local/share/geoip/`.

> [!NOTE]
> If you choose to store the database in a custom location, ensure the `MMDB_FILE` variable in `~/.config/ufwcheck/config` is updated to reflect the correct path.

## Step 2: Create Directories

Create the required XDG-compliant directories with a single command:
```bash
mkdir -p ~/.local/bin ~/.local/share/geoip ~/.local/state ~/.config/ufwcheck ~/.config/maxmind
```

## Step 3: Install the Scripts

Download the latest versions of the scripts from the repository and place them in your local bin directory.

&nbsp;
**A. Download the scripts:**

```bash
curl -Lfs "https://raw.githubusercontent.com/aymonix/ufwcheck/main/ufwcheck" -o ~/.local/bin/ufwcheck
curl -Lfs "https://raw.githubusercontent.com/aymonix/ufwcheck/main/geoupdate" -o ~/.local/bin/geoupdate
```

&nbsp;
**B. Make them executable:**

```bash
chmod +x ~/.local/bin/ufwcheck ~/.local/bin/geoupdate
```

## Step 4: Create Configuration Files

You need to create three configuration files.

&nbsp;
**A. MaxMind Secrets File:**

Create `~/.config/maxmind/secrets` and add your credentials. This file must be kept private.
```bash
export MAXMIND_ID="YOUR_ACCOUNT_ID"
export MAXMIND_TOKEN="YOUR_LICENSE_KEY"
```
Set its permissions to `600`:
```bash
chmod 600 ~/.config/maxmind/secrets
```

&nbsp;
**B. MaxMind Config Loader:**

Create `~/.config/maxmind/config` with the following content:
```bash
source "$HOME/.config/maxmind/secrets"

DOWNLOAD_URL="https://download.maxmind.com/geoip/databases/GeoLite2-City/download?suffix=tar.gz"
SHA_URL="https://download.maxmind.com/geoip/databases/GeoLite2-City/download?suffix=tar.gz.sha256"
```

&nbsp;
**C. ufwcheck Config File:**

Create the main configuration file `~/.config/ufwcheck/config`:
```bash
LOG_FILE="/var/log/ufw.log"
MMDB_FILE="$HOME/.local/share/geoip/GeoLite2-City.mmdb"
STATE_DIR="$HOME/.local/state"
OUTPUT_LOG="$STATE_DIR/ufwcheck.log"
```

## Step 5: Set Up Shell Environment

Create the environment file `~/.config/ufwcheck/env` to enable PATH access and aliases.
```bash
export PATH="$HOME/.local/bin:$PATH"
alias ufc='ufwcheck'
alias gup='geoupdate'
```

Once the environment is loaded, `ufwcheck` and `geoupdate` can be called directly by name, or via the short aliases `ufc` and `gup`.

## Step 6: Configure Log Retention (Optional)

To utilize the deep history analysis features of `ufwcheck`, you may want to extend the default log retention period. For setup instructions and performance reference, see **[Log Retention & Performance](log-retention.md)**.

## Step 7: Final Steps

**A. Activate the Environment:**

Add the following line to your `~/.bashrc` or `~/.zshrc`:
```bash
source "$HOME/.config/ufwcheck/env"
```
Restart your terminal or run `source ~/.bashrc` to apply the changes.

&nbsp;
**B. Initial Database Download:**

Run `gup` or `geoupdate` for the first time to download the GeoLite2-City database.
```bash
geoupdate
```

The installation is now complete!
