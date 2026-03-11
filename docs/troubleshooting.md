# Troubleshooting

## Environment Issues

### `bash: ufwcheck: command not found`
**Cause:** Your shell has not yet loaded the environment settings.
**Solution:** Ensure you have added `source "$HOME/.config/ufwcheck/env"` to your `~/.bashrc` (or `~/.zshrc`), then restart your terminal or run `source ~/.bashrc`.

## ufwcheck Errors

### `[✘] Error: Required command not found: '...'`
**Cause:** A required system utility is missing from your environment.
**Solution:** Install the missing package. For Debian/Ubuntu, the package list is in the **[Prerequisites](../README.md#prerequisites)** section.

### `[✘] Error: Configuration file not found or not readable at '...'`
**Cause:** The main configuration file is missing or not readable.
**Solution:** Ensure the installation was successful. If you performed a manual installation, create the file at `~/.config/ufwcheck/config`.

### `[✘] Error: UFW log directory not found or not readable`
**Cause:** The path to the UFW log is incorrect, or your user lacks permission to read it.
**Solution:** Check the `LOG_FILE` path in your config. The system log `/var/log/ufw.log` requires membership in the `adm` group. Ensure your user is in the group (`sudo usermod -aG adm $USER`) or consult your system administrator.

### `[✘] Error: GeoIP database not found or not readable`
**Cause:** The `GeoLite2-City.mmdb` database has not been downloaded yet or the path is incorrect.
**Solution:** If using automated management, run `geoupdate` to download the database. If using manual placement, ensure your `.mmdb` file is located at the path specified in the `MMDB_FILE` variable in your configuration.

### `[✘] Error: Null bytes detected in '...'`
**Cause:** An unclean system shutdown (crash, power loss) interrupted an active write to the log file, leaving null bytes (`\0`) in it. Null bytes cause `grep` to treat the file as binary and produce no output.
**Solution:** Run the following commands to safely clean the log file and restart the logging service:
```bash
sudo cp -a /var/log/ufw.log /var/log/ufw.log.bak.$(date +%F-%H%M%S)
sudo tr -d '\000' < /var/log/ufw.log > /var/log/ufw.log.clean
sudo chown root:adm /var/log/ufw.log.clean
sudo chmod 0640 /var/log/ufw.log.clean
sudo mv /var/log/ufw.log.clean /var/log/ufw.log
sudo systemctl restart rsyslog
```
Verify the fix by running `ufwcheck` again.

### `[✘] Error: Option '...' requires an argument`
**Cause:** A flag that requires a value was provided without one.
**Solution:** Provide the required value. Run `ufwcheck --help` for usage.

### `[✘] Error: Unknown option '...'. Use --help for usage`
**Cause:** An unrecognized flag was passed to `ufwcheck`.
**Solution:** Run `ufwcheck --help` to see all available options.

### `[✘] Error: Maximum allowed value for '--days' is 366. Got: '...'`
**Cause:** The provided value exceeds the maximum supported history depth.
**Solution:** Provide a value less than or equal to 366.

### `[✘] Error: The value for '...' must be a positive integer`
**Cause:** You provided a non-numeric or negative value to an option (`--top`, `--days`, `--attempts`).
**Solution:** Use only positive integers (e.g., `1`, `10`, `100`).

### `[✘] Error: Invalid month abbreviation '...'. Use Jan, Feb, etc.`
**Cause:** The value provided to `--month` is not a valid three-letter English abbreviation.
**Solution:** Use standard three-letter abbreviations: `Jan`, `Feb`, `Mar`, `Apr`, `May`, `Jun`, `Jul`, `Aug`, `Sep`, `Oct`, `Nov`, `Dec`.

### `[✘] Error: Date must be in YYYY-MM-DD format. Got: '...'`
**Cause:** The value provided to `--date` does not match the required format.
**Solution:** Use the `YYYY-MM-DD` format, e.g. `2025-07-26`.

## geoupdate Errors

### `ERROR: Required command not found: '...'`
**Cause:** A required system utility is missing from your environment.
**Solution:** Install the missing package using your system package manager.

### `ERROR: Cannot read ufwcheck config file: '~/.config/ufwcheck/config'`
**Cause:** The ufwcheck configuration file is missing or not readable.
**Solution:** Ensure the installation was successful and the file exists at `~/.config/ufwcheck/config`.

### `ERROR: Cannot read MaxMind config file: '~/.config/maxmind/config'`
**Cause:** The MaxMind configuration loader is missing or not readable.
**Solution:** Ensure the installation was successful and the file exists at `~/.config/maxmind/config`.

### `ERROR: MAXMIND_ID is not set or is empty in your secrets file`
**Cause:** The `secrets` file exists but `MAXMIND_ID` is missing or empty.
**Solution:** Check `~/.config/maxmind/secrets`. Ensure the line `export MAXMIND_ID="YOUR_ACCOUNT_ID"` is present and correct.

### `ERROR: MAXMIND_TOKEN is not set or is empty in your secrets file`
**Cause:** The `secrets` file exists but `MAXMIND_TOKEN` is missing or empty.
**Solution:** Check `~/.config/maxmind/secrets`. Ensure the line `export MAXMIND_TOKEN="YOUR_LICENSE_KEY"` is present and correct.

### `curl: (22) The requested URL returned error: 401 Unauthorized`
**Cause:** Your **Account ID** or **License Key** is incorrect.
**Solution:** Verify the credentials in your `~/.config/maxmind/secrets` file.

### `ERROR: SHA256 mismatch!`
**Cause:** The downloaded archive is corrupt.
**Solution:** Run `geoupdate` again. This is usually a temporary network issue.

### `ERROR: Archive contains potentially unsafe file paths. Aborting`
**Cause:** The downloaded archive contains paths starting with `/` or `../`. This is unexpected for a MaxMind distribution and may indicate a change in their archive structure or a problem during delivery.
**Solution:** Check the [MaxMind GeoIP Release Notes](https://dev.maxmind.com/geoip/release-notes/) for any announced changes to the archive format. If no changes are announced, wait and run `geoupdate` again later.

### `ERROR: Extraction failed. GeoLite2-City.mmdb not found in archive`
**Cause:** The archive was downloaded and verified but did not contain the expected `.mmdb` file. This is typically a temporary issue on the MaxMind distribution side.
**Solution:** Check the [MaxMind GeoIP Release Notes](https://dev.maxmind.com/geoip/release-notes/) for any announced changes, then run `geoupdate` again.

### `ERROR: Unknown option: '...'`
**Cause:** An unrecognized argument was passed to `geoupdate`.
**Solution:** `geoupdate` accepts no arguments. Run `geoupdate --help` for usage.
