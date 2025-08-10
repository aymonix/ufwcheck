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

> For advanced users who prefer a completely manual installation, we have prepared a **[Manual Installation Guide](docs/installation.md)**.

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

If you encounter any issues during installation or usage, we have prepared a comprehensive troubleshooting guide.

➡️ Click here to view the **[Troubleshooting Guide](docs/troubleshooting.md)**

If your issue is not listed there, please feel free to **[open an issue](https://github.com/aymonix/ufwcheck/issues)**.

## FAQ

**Q: What happens if I run `install.sh` again?**
**A:** The installer is designed for the initial setup. Running `install.sh` again **will overwrite** your existing scripts and configuration files (`~/.config/ufwcheck/config.sh`) with the default versions. Be careful, as **this will erase any custom changes** you have made to the configuration.

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

To completely remove `ufwcheck` from your system, please refer to the **[Uninstall Guide](docs/uninstall.md)**.

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
