# Manual Installation Guide for ufwcheck

This guide is for advanced users who prefer to install the tool suite manually without using the `install.sh` script.

## Step 1: Fulfill Prerequisites

Before you begin, you need to ensure your system is ready.

### Required Tools
While most standard utilities (`grep`, `sort`, etc.) are pre-installed, you must ensure the following are present:
*   `curl` for downloading.
*   `python3` (usually pre-installed).
*   **`python3-maxminddb`**: Python library for fast GeoIP lookups.
*   **`zcat`**: Provided by the `gzip` package (for reading compressed logs).
*   `column` usually in the `util-linux` package.
*   `jq` for JSON processing.
*   `cron` if you plan to use automated updates.
*   **`sha256sum`**: For verifying script integrity. Part of the `coreutils` package.

On Debian/Ubuntu, you can install all of them with:
```bash
sudo apt-get update && sudo apt-get install curl python3 python3-maxminddb gzip util-linux jq cron coreutils
```

### Required Data: MaxMind Account & GeoIP Database

`ufwcheck` relies on the `GeoLite2-City.mmdb` database for geolocation. For the system to function correctly, this file should be placed at the recommended location: `~/.local/share/geoip/GeoLite2-City.mmdb`. This path follows the XDG standard, does not require `sudo` permissions. The default configuration file is already set up to use this path.

To obtain and manage this database, you will need a free MaxMind account.

1.  Sign up for a free account on the [MaxMind](https://www.maxmind.com/en/geolite2/signup) website.
2.  Obtain your Account ID and License Key. These credentials should be configured as described in Step 4.

There are two ways to place the database file in the required location:

&nbsp;
**Automated Management (Recommended)**

The `geoupdate.sh` script is designed to handle the initial download, and can be scheduled with cron for fully automated subsequent updates. This is the most convenient and reliable method. After configuring your credentials, you will simply run the script as shown in the final step of this guide.

&nbsp;
**Manual Placement**

If you already have a `GeoLite2-City.mmdb` file and prefer to manage it manually, simply place your `.mmdb` file at the recommended path: `~/.local/share/geoip/`.

> [!NOTE]
> If you choose to store the database in a custom location, ensure the `MMDB_FILE` variable in `~/.config/ufwcheck/config.sh` is updated to reflect the correct path.

## Step 2: Create Directories

Create the required XDG-compliant directories with a single command:
```bash
mkdir -p ~/.local/bin ~/.local/share/geoip ~/.local/state ~/.config/ufwcheck ~/.config/maxmind
```

## Step 3: Install the Scripts

Download the latest versions of the scripts from the repository and place them in your local bin directory.

&nbsp;
**A. Download the scripts and their checksums:**

```bash
curl -Lfs "https://raw.githubusercontent.com/aymonix/ufwcheck/main/ufwcheck.sh" -o ~/.local/bin/ufwcheck.sh
curl -Lfs "https://raw.githubusercontent.com/aymonix/ufwcheck/main/geoupdate.sh" -o ~/.local/bin/geoupdate.sh
curl -Lfs "https://raw.githubusercontent.com/aymonix/ufwcheck/main/SHA256SUMS" -o ~/.local/bin/SHA256SUMS
```

&nbsp;
**B. Verify Integrity (Security Check):**

This step ensures the downloaded scripts are authentic and have not been altered.
```bash
cd ~/.local/bin && sha256sum -c --ignore-missing SHA256SUMS
```

If the command completes successfully (you should see `OK` for each script), you can safely remove the checksum file:
```bash
rm ~/.local/bin/SHA256SUMS
```

> [!NOTE]
> If you see a `FAILED` message, it might be due to an incomplete download. Please delete all downloaded files and try the download step again.
> ```bash
> rm ~/.local/bin/ufwcheck.sh ~/.local/bin/geoupdate.sh ~/.local/bin/SHA256SUMS
> ```
> If the error persists, please try again later or let us know by creating an **[Issue](https://github.com/aymonix/ufwcheck/issues)**.

&nbsp;
**C. Make them executable:**

```bash
chmod +x ~/.local/bin/ufwcheck.sh ~/.local/bin/geoupdate.sh
```

## Step 4: Create Configuration Files

You need to create three configuration files.

&nbsp;
**A. MaxMind Secrets File:**

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

&nbsp;
**B. MaxMind Config Loader:**

Create `~/.config/maxmind/config.sh` to load the secrets.
```bash
# Contents for ~/.config/maxmind/config.sh
#!/usr/bin/env bash
source "$HOME/.config/maxmind/secrets"
export DOWNLOAD_URL="https://download.maxmind.com/geoip/databases/GeoLite2-City/download?suffix=tar.gz"
export SHA_URL="https://download.maxmind.com/geoip/databases/GeoLite2-City/download?suffix=tar.gz.sha256"
```

&nbsp;
**C. ufwcheck Config File:**

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

## Step 6: Configure Log Retention (Optional)

To utilize the deep history analysis features of `ufwcheck` (extending back months or a year), you must adjust the system's log rotation settings.

&nbsp;
**A. Open the Configuration:**

Open the `logrotate` configuration file for UFW:
```bash
sudo nano /etc/logrotate.d/ufw
```

&nbsp;
**B. Modify Retention Settings:**

Locate the line starting with `rotate` (usually `rotate 4`). Change its value based on your desired retention period:

*   **`rotate 13`**: ~3 months.
*   **`rotate 26`**: ~6 months.
*   **`rotate 52`**: ~1 year.

Note that the `postrotate` section contains default system-specific commands. It is recommended to keep these defaults unchanged while adjusting the retention settings.

**Example of a modified configuration (set for 1 year):**
```text
/var/log/ufw.log
{
        rotate 52
        weekly
        missingok
        notifempty
        compress
        delaycompress
        sharedscripts
        postrotate
                # System-specific reload command (leave unchanged)...
        endscript
}
```

&nbsp;
**C. Save and Apply:**

Save the file and exit the editor. The changes will take effect automatically during the next scheduled system rotation.

## Step 7: Final Steps

**A. Activate the Environment:**

Add the following line to your `~/.bashrc` or `~/.zshrc`:
```bash
source "$HOME/.config/ufwcheck/env.sh"
```
Restart your terminal or run `source ~/.bashrc` to apply the changes.

&nbsp;
**B. Initial Database Download:**

Run `geoupdate` for the first time to download the GeoLite2-City database.
```bash
geoupdate
```

The installation is now complete :tada:
