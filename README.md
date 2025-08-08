# ufwcheck

**ufwcheck** is a suite of `bash` utilities for analyzing UFW (Uncomplicated Firewall) logs. It helps identify IP addresses exhibiting suspicious activity, enriches them with geolocation data, and presents the findings in clear, ranked reports.

## Features

*   ⚡ **Fast Log Analysis**: Finds and aggregates all `[UFW BLOCK]` events.
*   🌍 **IP Geolocation**: Automatically determines the country and city for each IP.
*   🔍 **Flexible Filtering**: Analyze logs for today, a specific date, the last N days, or a specific month.
*   📊 **Customizable Reporting**: Allows limiting the output to the top N most active IPs or filtering by the minimum number of blocked attempts.
*   🛡️ **Safe & Read-Only**: `ufwcheck` operates in a non-destructive mode, ensuring your system logs are never modified.
*   ⚙️ **Smart Installer**: `install.sh` automatically checks for dependencies and assists with setup.
*   🔄 **Automatic Updates**: `geoupdate.sh` makes it easy to keep your GeoIP database up to date.

## Prerequisites

The `install.sh` script will automatically check for all required utilities. For it to run, you will need:
*   `curl` (or `wget`)
*   `mmdblookup` (from the `mmdb-bin` package)
*   `column` (from the `util-linux` package)
*   `jq`
*   `cron` (for optional automatic updates)

You will also need a free **MaxMind** account to download the GeoLite2-City database.

## Installation

We provide an automated installer script to make setup as quick and easy as possible.

1.  **Download the installer:**
    ```bash
    curl -O https://raw.githubusercontent.com/aymonix/ufwcheck/main/install.sh
    ```
2.  **Make it executable:**
    ```bash
    chmod +x install.sh
    ```
3.  **Run the installer and follow the on-screen instructions:**
    ```bash
    ./install.sh
    ```

> For advanced users who prefer a completely manual installation, we have prepared a **[Manual Installation Guide](docs/MANUAL_INSTALLATION.md)**.

> *Note: `install.sh` is intended for initial installation. Please read the FAQ for details on re-running the script.*

## Usage

The primary analysis tool is `ufwcheck.sh` (available via the `ufwcheck` alias after installation).

#### Options

| Option | Argument | Short Description | Default |
| :--- | :--- | :--- | :--- |
| **Data Filtering** |
| `--today` | — | Analyze today's logs. | **Yes** |
| `--date` | `YYYY-MM-DD` | Filter by a specific date. | - |
| `--days`, `-d` | `N` | Filter logs for the last N days. | - |
| `--month`, `-m`| `NAME` | Filter by month (e.g., `Jan`). | - |
| `--no-private` | — | Exclude private/local IPs. | - |
| **Output Control** |
| `--top`, `-t` | `N` | Show only the top N IPs. | All |
| `--attempts`, `-a`| `N` | Filter by min number of attempts. | `2` |
| `--json` | — | Output in JSON format. | - |
| **Other Options** |
| `--help`, `-h` | — | Show this help message. | - |

#### Explanations for Select Options

*   **`--no-private`**
    This option cleans up the report from local network "noise" (IPs like `192.168.*.*`, `10.*.*.*`, etc.). Use it to focus solely on real external threats from the internet.

*   **`--json`**
    This mode outputs the results in a machine-readable JSON format, ideal for integrating with other scripts, monitoring systems, or web frontends. The output is directed to standard output (`stdout`), allowing you to easily redirect it:
    *   **To a file:** `ufwcheck --json > report.json`
    *   **To another program:** `ufwcheck --json | jq '.[] | .ip'`

#### Examples

*   **Basic Usage**
    *Analyze today's logs for IPs with 2 or more blocked attempts (default behavior):*
    ```bash
    ufwcheck
    ```
    *Show the top 10 most active IPs for today:*
    ```bash
    ufwcheck -t 10
    ```
    *Show external IPs with more than 50 blocked attempts for today:*
    ```bash
    ufwcheck --no-private -a 50
    ```
    *Get a report for a specific date in JSON format and save it to a file:*
    ```bash
    ufwcheck --date 2025-07-26 --json > report.json
    ```

*   **Combined Options**
    *Last 7 days, IPs with 5+ blocked attempts, top 20 results:*
    ```bash
    ufwcheck -d 7 -a 5 -t 20
    ```
    *Get a report for July, top 30, with over 100 blocked attempts, in JSON format, and save to a file:*
    ```bash
    ufwcheck -m Jul -t 30 -a 100 --json > report.json
    ```
	
## Output Format

The script generates a formatted table for easy analysis. The example uses IP addresses reserved for documentation (RFC 5737).

```text
[2025-07-26 12:20]
IP Address         Attempts  Country          City
--------------     --------  ---------------  -----------
203.0.113.5        1603      Russia           Moscow
192.0.2.10         699       India            New Delhi
203.0.113.22       316       The Netherlands  Amsterdam
198.51.100.88      118       Germany          Berlin
```

## Advanced Usage

#### Automated Reports with Cron
You can easily set up automatic reports. Open your crontab for editing (`crontab -e`) and add one of the following lines:

*   **Send a daily report (top 20 IPs) via Email:**
    ```cron
    0 8 * * * ufwcheck --no-private -t 20 | mail -s "Daily Ufwcheck Report" your.email@example.com
    ```

#### Convenient Aliases
Create an alias in your `~/.bash_aliases` (or `~/.bashrc`) for frequently used command sets:

*   **Example "ufwclean" alias:**
    *Shows only external IPs with 5 or more blocked attempts.*
    ```bash
    alias ufwclean='ufwcheck.sh --no-private -a 5'
    ```

## Updating the GeoIP Database

To update the GeoLite2-City database to the latest version, simply run:
```bash
geoupdate
```
The installer offers to set up a weekly `cron` job to run this command automatically, ensuring your database remains current.

## Troubleshooting

#### General Issues
*   **Error:** `bash: ufwcheck: command not found`
    *   **Cause:** Your shell has not yet loaded the new environment settings.
    *   **Solution:** Ensure you have added the `source "$HOME/.config/ufwcheck/env.sh"` line to your `~/.bashrc` (or `~/.zshrc`) and then **restarted your terminal** or run `source ~/.bashrc`.

#### `ufwcheck` Errors

*   **Error:** `[✘] Error: Required command not found: 'jq'. Please install it.`
    *   **Cause:** A required utility (e.g., `jq`) is missing from the system.
    *   **Solution:** Install the missing package. For Debian/Ubuntu, the package list is in the `## Prerequisites` section.

*   **Error:** `[✘] Error: Configuration file not found at '~/.config/ufwcheck/config.sh'`
    *   **Cause:** The main configuration file is missing or in the wrong location.
    *   **Solution:** Ensure the installation was successful. If you performed a manual installation, create this file at the specified path.

*   **Error:** `[✘] Error: UFW log file not found or not readable...`
    *   **Cause:** The path to the UFW log is incorrect, or your user lacks permission to read it.
    *   **Solution:** Check the `LOG_FILE` path in your config. The system log `/var/log/ufw.log` often requires administrator privileges (`root`) or membership in the `adm` group. Ensure your user is in the `adm` group (`sudo usermod -aG adm $USER`) or consult your system administrator.

*   **Error:** `[✘] Error: GeoIP database not found or not readable...`
    *   **Cause:** The `GeoLite2-City.mmdb` database has not been downloaded yet. The `install.sh` script only prepares for the download.
    *   **Solution:** You need to run `geoupdate` for the first time to download the database. If you installed manually, ensure you have downloaded the database and placed it at the path specified in `MMDB_FILE`.

*   **Error:** `[✘] Error: The value for '...' must be a positive integer...`
    *   **Cause:** You provided a non-numeric or negative value to an option (`--top`, `--days`, `--attempts`).
    *   **Solution:** Use only positive integers (e.g., `1`, `10`, `100`).

*   **Error:** `[✘] Error: Invalid month abbreviation...` or `...Date must be in YYYY-MM-DD format...`
    *   **Cause:** The date or month format is incorrect.
    *   **Solution:** Use three-letter English abbreviations (`Jan`, `Feb`, etc.) for the month or the `YYYY-MM-DD` format for the date.

#### `geoupdate` Errors

*   **Error:** `ERROR: Cannot read config file: '~/.config/maxmind/config.sh'`
    *   **Cause:** The MaxMind configuration loader is missing.
    *   **Solution:** Ensure the installation was successful and the file exists.

*   **Error:** `source: ~/.config/maxmind/secrets: No such file or directory`
    *   **Cause:** You chose the manual setup option and did not create the credentials file.
    *   **Solution:** Create the `~/.config/maxmind/secrets` file and place your **MaxMind Account ID** and **License Key** in it, as shown during the installation.

*   **Error:** `ERROR: MAXMIND_ID or MAXMIND_TOKEN is not exported...`
    *   **Cause:** The `secrets` file exists, but the variables are defined incorrectly.
    *   **Solution:** Check `~/.config/maxmind/secrets`. Make sure the lines begin with `export`.

*   **Error:** `curl: (22) The requested URL returned error: 401 Unauthorized`
    *   **Cause:** Your **Account ID** or **License Key** is incorrect.
    *   **Solution:** Verify the credentials in your `~/.config/maxmind/secrets` file.

*   **Error:** `ERROR: SHA256 mismatch!`
    *   **Cause:** The downloaded archive is corrupt.
    *   **Solution:** Run `geoupdate` again. This is usually a temporary network issue.

## FAQ

**Q: What happens if I run `install.sh` again?**
**A:** Be careful. The `install.sh` script is designed for a "clean" installation and **will overwrite** existing scripts and configuration files with each run. **This will erase your custom edits to the configs.** To update to a new version, it is recommended to **first completely uninstall** the old version (see `## Uninstall`) and then run the new `install.sh`.

**Q: Why do I need a MaxMind account to download GeoLite2?**
**A:** MaxMind requires registration to download their free GeoLite2 databases to comply with privacy regulations (like CCPA and GDPR) and to notify users of important updates.

**Q: Can I use this with `iptables` or `firewalld`?**
**A:** No. The tool is specifically designed to parse the standard `ufw` log format. Adapting it for other firewalls would require changing the parsing logic.

**Q: Why do I see IPs from well-known companies (Cloudflare, Google) in my report?**
**A:** This is normal. Large internet companies constantly scan the entire IP address space for research purposes. Your firewall correctly blocks these requests, and they are generally not considered malicious activity.

## Contributing

We welcome any contributions to the `ufwcheck` project! If you have ideas for improvements, new features, or have found a bug, please feel free to:
*   ⭐ **Star the repository** - it helps other users discover the tool.
*   🐛 **Open an Issue** - if you've found a bug or have a suggestion.
*   💡 **Submit a Pull Request** - if you'd like to contribute your own fixes or improvements.

## Changelog

*   **v1.0.0** (2025-08-06)
    *   🎉 Initial public release of `ufwcheck`.
    *   ⚙️ Added the smart installer `install.sh`.
    *   ✨ Implemented `ufwcheck` with flexible filters and JSON output.
    *   🔄 Added `geoupdate` for automatic GeoIP database updates.

## Uninstall

To completely remove `ufwcheck` from your system, please refer to the **[Uninstall Guide](docs/UNINSTALL.md)**.

## Security Notice

This tool is intended for **defensive security monitoring only**. Always:
*   Comply with all applicable laws and privacy regulations.
*   Only analyze logs from systems you own or have explicit permission to monitor.
*   Keep your GeoIP databases updated for accurate results.
*   Protect your configuration files, as they may contain sensitive paths.

## Author

**Aymon**

*   GitHub: [@aymonix](https://github.com/aymonix)

## License

This project is distributed under the MIT License. See the `LICENSE` file for details.
