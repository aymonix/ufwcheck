# ufwcheck

![GitHub release](https://img.shields.io/github/v/release/aymonix/ufwcheck)
![GitHub license](https://img.shields.io/github/license/aymonix/ufwcheck)

**ufwcheck** is a suite of `bash` utilities for analyzing UFW (Uncomplicated Firewall) logs, designed for Debian and Ubuntu environments. It identifies IP addresses with suspicious activity by scanning real-time logs and historical archives, enriches them with geolocation data, and presents the findings in ranked reports.

## Features

#### Core Functionality
- **Fast Log Analysis**: Finds and aggregates all `UFW BLOCK` events.
- **IP Geolocation**: Determines the country and city for each IP using the MaxMind GeoLite2-City database.
- **Deep History Analysis**: Reads compressed and rotated logs (`.gz`) transparently, enabling analysis of long-term trends.
- **Rotation Agnostic**: Works correctly regardless of the system's log rotation strategy (daily, weekly, or monthly).
- **Smart Optimization**: Detects the query scope and reads only the necessary log files.
- **Flexible Filtering**: Analyze logs for today, a specific date, the last N days, or a specific month.
- **Customizable Reporting**: Limit output to the top N IPs or filter by minimum blocked attempt count.

#### Convenience & Usability
- **Safe & Read-Only**: Operates in non-destructive mode, system logs are never modified.
- **Guided Installer**: `install.sh` checks dependencies and assists with the full setup.
- **Easy Updates**: `geoupdate` keeps the GeoIP database current.

## Prerequisites

The `install.sh` script will automatically check for all required utilities. For it to run, you will need:
- `curl`
- `python3` (usually pre-installed)
- `python3-maxminddb` library (for fast GeoIP lookups)
- `zcat` (provided by the standard `gzip` package)
- `column` from the `bsdextrautils` package
- `jq` for JSON processing
- `cron` for optional automatic updates

> [!IMPORTANT]
> A free [**MaxMind**](https://www.maxmind.com/en/geolite2/signup) account is required to download the GeoLite2-City database. Registration is needed so MaxMind can notify users of important database updates or changes to their service.

## Installation

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

> [!CAUTION]
> Re-running `install.sh` will detect an existing installation and ask for confirmation before proceeding. All configuration files will be overwritten with default versions. Back up any custom changes before confirming.

For a completely manual installation, see the **[Manual Installation Guide](docs/installation.md)**.

## Usage

After installation, `ufwcheck` is available system-wide via the `ufc` alias or by calling `ufwcheck` directly. By default, the command analyzes today's logs for IP addresses with two or more blocked attempts. Each report is prefixed with a timestamp.

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

**`--no-private`**
Excludes local network IPs (`192.168.*.*`, `10.*.*.*`, etc.) to focus solely on external threats.

**`--json`**
Outputs results in JSON format to `stdout`. To save to a file: `ufwcheck --json > report.json`

#### Examples

**Basic Usage**
```bash
# Today's logs, IPs with 2 or more blocked attempts (default)
ufwcheck

# Top 10 most active IPs for today
ufwcheck -t 10

# External IPs with more than 50 blocked attempts
ufwcheck --no-private -a 50

# Report for a specific date in JSON format
ufwcheck --date 2025-07-26 --json > report.json
```

**Combined Options**
```bash
# Last 7 days, IPs with 5+ attempts, top 20 results
ufwcheck -d 7 -a 5 -t 20

# July report, top 30, 100+ attempts, JSON output
ufwcheck -m Jul -t 30 -a 100 --json > report.json
```

## Log Rotation & Retention

`ufwcheck` is rotation-agnostic and correctly processes the full log history chain regardless of rotation strategy (daily, weekly, or monthly). By default, Debian and Ubuntu retain approximately **28 days** of UFW logs, but `ufwcheck` supports analysis of up to **1 year** of history to detect persistent low-frequency attacks that are invisible in daily or weekly reports and only reveal themselves across months of data.

> [!NOTE]
> The tool enforces a hard limit of 366 days for the `--days` flag.

For logrotate setup and performance reference, see **[Log Retention & Performance](docs/log-retention.md)**.

## Output Format

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

Automated Reports with Cron

```cron
0 8 * * * ufwcheck --no-private -t 20 | mail -s "Daily Ufwcheck Report" your.email@example.com
```

## Updating the GeoIP Database

```bash
geoupdate
```

`geoupdate` is also available via the short alias `gup`. The installer can optionally configure a weekly cron job to run it automatically.

## Troubleshooting

See the **[Troubleshooting Guide](docs/troubleshooting.md)**. If your issue is not listed, please **[open an issue](https://github.com/aymonix/ufwcheck/issues)**.

## Uninstall

See the **[Uninstall Guide](docs/uninstall.md)**.

## Changelog

See **[CHANGELOG.md](CHANGELOG.md)**.

## Contributing

Issues and pull requests are welcome at **[github.com/aymonix/ufwcheck](https://github.com/aymonix/ufwcheck/issues)**.

## License

MIT License. See the [LICENSE](LICENSE) file for details.
