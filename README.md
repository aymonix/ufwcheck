# ufwcheck

**ufwcheck** is a suite of `bash` utilities for analyzing UFW (Uncomplicated Firewall) logs, designed for Debian and Ubuntu environments. It helps identify IP addresses exhibiting suspicious activity by scanning both real-time logs and historical archives, enriches them with geolocation data, and presents the findings in clear, ranked reports.

## Features

#### Core Functionality
*   ⚡ **Fast Log Analysis**: Finds and aggregates all `UFW BLOCK` events.
*   🌍 **IP Geolocation**: Automatically determines the country and city for each IP.
*   🕰️ **Deep History Analysis**: The Omni-Reader architecture seamlessly reads compressed and rotated logs (`.gz`), enabling analysis of long-term trends.
*   🌀 **Rotation Agnostic**: Works correctly regardless of your system's log rotation strategy (daily, weekly, or monthly).
*   🚀 **Smart Optimization**: Automatically detects the query scope to read only necessary files, ensuring instant results for daily reports.
*   🔍 **Flexible Filtering**: Analyze logs for today, a specific date, the last N days, or a specific month.
*   📋 **Customizable Reporting**: Allows limiting the output to the top N most active IPs or filtering by the minimum number of blocked attempts.

#### Convenience & Usability
*   🛡️ **Safe & Read-Only**: `ufwcheck` operates in a non-destructive mode, ensuring your system logs are never modified.
*   ⚙️ **Guided Installer**: `install.sh` automatically checks for dependencies and assists with setup.
*   🔒 **Secure by Design**: The installer verifies script integrity, and the update process is hardened against common threats.
*   🔄 **Easy Updates**: `geoupdate.sh` makes it easy to keep your GeoIP database up to date.

## Prerequisites

The `install.sh` script will automatically check for all required utilities. For it to run, you will need:
*   `curl`
*   `python3` (usually pre-installed)
*   `python3-maxminddb` library (for fast GeoIP lookups)
*   `zcat` (provided by the standard `gzip` package)
*   `column` from the `util-linux` package
*   `jq` for JSON processing
*   `sha256sum` from the `coreutils` package
*   `cron` for optional automatic updates

> [!IMPORTANT]
> A free **MaxMind** account is required to download the GeoLite2-City database. Registration is needed so MaxMind can notify users of important database updates or changes to their service.

## Installation

We provide an automated installer script to make setup as quick and easy as possible.

1.  **Download the installer:**
    ```bash
    curl -O https://raw.githubusercontent.com/aymonix/ufwcheck/main/install.sh
    ```
2.  **Verify Installer Integrity**
    To ensure the installer is authentic, verify its SHA256 checksum. The command should output `install.sh: OK`.
    ```bash
    echo "f431658816cc63bf08e1cc26c05898d045f3ec03a83e0b6b8c7d95bc6861d8c1  install.sh" | sha256sum -c -
    ```

3.  **Make it executable:**
    ```bash
    chmod +x install.sh
    ```
4.  **Run the installer and follow the on-screen instructions:**
    ```bash
    ./install.sh
    ```

> [!NOTE]
> `install.sh` is intended for initial installation. Please see the **[FAQ](#FAQ)** for important details about re-running the script.

For advanced users who prefer a completely manual installation, we have prepared a **[Manual Installation Guide](docs/installation.md)**.

## Usage

The primary analysis tool is `ufwcheck.sh`, which becomes available system-wide via the `ufwcheck` alias after installation. By default, running the command without any options will analyze today's logs for IP addresses with two or more blocked attempts. Each report is prefixed with a timestamp indicating the exact date and time the script was executed.

#### Options

| Option | Argument | Short Description | Default |
| :--- | :--- | :--- | :--- |
| **Data Filtering** |
| `--today` | - | Analyze today's logs. | **Yes** |
| `--date` | `YYYY-MM-DD` | Filter by a specific date. | - |
| `--days`, `-d` | `N` | Filter logs for the last N days. | - |
| `--month`, `-m`| `NAME` | Filter by month (e.g., `Jan`, `Feb`, ... `Dec`). | - |
| `--no-private` | - | Exclude private/local IPs. | - |
| **Output Control** |
| `--top`, `-t` | `N` | Show only the top N IPs. | All |
| `--attempts`, `-a`| `N` | Filter by min number of attempts. | `2` |
| `--json` | - | Output in JSON format. | - |
| **Other Options** |
| `--help`, `-h` | - | Show help message. | - |

#### Explanations for Select Options

*   **`--no-private`**
    This option cleans up the report from local network "noise" (IPs like `192.168.*.*`, `10.*.*.*`, etc.). Use it to focus solely on real external threats from the internet.

*   **`--json`**
    This mode outputs the results in a machine-readable JSON format, ideal for integrating with other scripts, monitoring systems, or web frontends. The output is directed to standard output (`stdout`), allowing you to easily redirect it:
    *   **To a file:** `ufwcheck --json > report.json`
    *   **To another program:** `ufwcheck --json | jq '.[] | .ip'`
    This command extracts just the IP addresses from the JSON report, providing a clean list for use in other scripts or for piping into tools like `whois`.

#### Examples

**Basic Usage**
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
\
**Combined Options**
*Last 7 days, IPs with 5+ blocked attempts, top 20 results:*
```bash
ufwcheck -d 7 -a 5 -t 20
```
*Get a report for July, top 30, with over 100 blocked attempts, in JSON format, and save to a file:*
```bash
ufwcheck -m Jul -t 30 -a 100 --json > report.json
```

## Log Rotation & Retention

`ufwcheck` is Rotation-Agnostic. Whether your system rotates logs daily, weekly, or monthly, the Omni-Reader engine will correctly identify and process the entire history chain.

By default, Debian and Ubuntu systems rotate UFW logs weekly and retain only 4 archives. This provides approximately **28 days** of history. However, `ufwcheck` is capable of analyzing up to **1 year** of data to detect persistent low-frequency attacks.

> [!NOTE]
> **Limits:** The tool enforces a hard limit of 366 days for the `--days` flag. This duration represents the optimal operating range for efficient text-based log analysis, balancing deep historical insight with query performance.

#### Storage & Performance Impact (1 Year History)
The following estimates are based on typical server activity profiles when analyzing a full year of logs (`--days 366`).

| Server Profile | Activity Level | Storage (Year) | Analysis Time | RAM Usage |
| :--- | :--- | :--- | :--- | :--- |
| **Personal / Dev** | Low noise, port scanners. | ~75 MB | ~25 sec | < 20 MB |
| **Small Business** | Public web server, constant bots. | ~350 MB | ~1 - 3 min | ~50 MB |
| **High Exposure** | Popular service, aggressive attacks. | ~3 GB | ~10 - 20 min | ~150 MB |

Performance depends on your CPU speed. Analysis is optimized to stream data, ensuring minimal memory footprint even on low-end VPS.

#### Configuration
For detailed instructions on how to configure `logrotate` to store 1 year of history, please refer to **Step 6** in the **[Manual Installation Guide](docs/installation.md#step-6-configure-log-retention-optional)**.

## Output Format

The script generates a formatted table for easy analysis. The example uses IP addresses reserved for documentation (RFC 5737).

```bash
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
You can easily set up automatic reports. Open your crontab for editing with `crontab -e` and add an entry like the following example.

*Send a daily report of the top 20 external IPs to your email at 8:00 AM:*
```cron
0 8 * * * ufwcheck --no-private -t 20 | mail -s "Daily Ufwcheck Report" your.email@example.com
```

#### Convenient Aliases
You can add your own convenient aliases to the environment file created by the installer. Open `~/.config/ufwcheck/env.sh` and add your custom aliases, for example.

*Create a custom "ufwclean" alias that shows only external IPs with 5 or more blocked attempts:*
```bash
alias ufwclean='ufwcheck.sh --no-private -a 5'
```

*Create a "ufwtop" alias for a weekly summary of the top 30 IPs with over 100 blocked attempts:*
```bash
alias ufwtop='ufwcheck.sh -d 7 -a 100 -t 30'
```

## Updating the GeoIP Database

To update the GeoLite2-City database to the latest version, simply run:
```bash
geoupdate
```

> [!TIP]
> For your convenience, the installer can set up a weekly `cron` job to run the `geoupdate` command automatically. This ensures your geolocation data always stays current.

## Troubleshooting

If you encounter any issues during installation or usage, we have prepared a comprehensive troubleshooting guide.

Click here to view the **[Troubleshooting Guide](docs/troubleshooting.md)**

If your issue is not listed there, please feel free to **[open an issue](https://github.com/aymonix/ufwcheck/issues)**.

## FAQ

**Q: What happens if I run `install.sh` again?**
**A:**
> [!CAUTION]
> Re-running `install.sh` will prompt you to re-enter your MaxMind credentials and **will overwrite** all related configuration files (`~/.config/ufwcheck/config.sh`, `~/.config/ufwcheck/env.sh`, `~/.config/maxmind/*`) with default versions.
>
> To prevent data loss, we strongly recommend backing up any custom changes first. You can use these commands:
> ```bash
> cp ~/.config/ufwcheck/config.sh ~/.config/ufwcheck/config.sh.bak-$(date +%F)
> cp ~/.config/ufwcheck/env.sh ~/.config/ufwcheck/env.sh.bak-$(date +%F)
> cp ~/.config/maxmind/secrets ~/.config/maxmind/secrets.bak-$(date +%F)
> cp ~/.config/maxmind/config.sh ~/.config/maxmind/config.sh.bak-$(date +%F)
> ```

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

**v1.0.0** (2025-12-25)
*   🎉 **Initial Public Release**: Comprehensive launch of the `ufwcheck` suite.
*   🚀 **Core Architecture**: Features Omni-Reader logic for transparent analysis of current, rotated, and compressed logs.
*   ⚡ **Performance**: Powered by an embedded Python engine for high-speed IP batch processing.
*   ⚙️ **Ecosystem**: Includes smart installer (`install.sh`) and auto-updater (`geoupdate.sh`).
*   🛡️ **Security**: Built with strict permission checks, input sanitization, and SHA256 integrity verification.

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

GitHub: [@aymonix](https://github.com/aymonix)

## License

This project is distributed under the MIT License. See the [LICENSE](LICENSE) file for details.
