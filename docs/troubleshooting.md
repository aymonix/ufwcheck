# Troubleshooting

## Installation Errors

*   **Error:** `install.sh: FAILED`
    *   **Cause:** The SHA256 checksum of the downloaded `install.sh` script does not match the official checksum. This means the file is either incomplete or has been altered. This ensures that you do not run a corrupt or altered file.
    *   **Solution:** Delete the file (`rm install.sh`) and try downloading it again. If the error persists, please let us know by creating an **[Issue](https://github.com/aymonix/ufwcheck/issues)**.

*   **Error:** `ERROR: Checksum mismatch!` (during the execution of `./install.sh`)
    *   **Cause:** The SHA256 checksum of the downloaded scripts (`ufwcheck.sh` or `geoupdate.sh`) does not match the official checksums. This indicates that the files are incomplete or have been altered during download. This ensures that you do not run a corrupt or altered file.
    *   **Solution:** Please run `./install.sh` again. If the error persists, please let us know by creating an **[Issue](https://github.com/aymonix/ufwcheck/issues)**.

## General Issues

*   **Error:** `bash: ufwcheck: command not found`
    *   **Cause:** Your shell has not yet loaded the new environment settings.
    *   **Solution:** Ensure you have added the `source "$HOME/.config/ufwcheck/env.sh"` line to your `~/.bashrc` (or `~/.zshrc`) and then **restarted your terminal** or run `source ~/.bashrc`.

## ufwcheck Errors

*   **Error:** `[✘] Error: Required command not found: '...'. Please install it.`
    *   **Cause:** A required system utility is missing from your environment.
    *   **Solution:** Install the missing package. For Debian/Ubuntu, the package list is in the **[Prerequisites](../README.md#prerequisites)** section.

*   **Error:** `[✘] Error: Configuration file not found at '~/.config/ufwcheck/config.sh'`
    *   **Cause:** The main configuration file is missing or in the wrong location.
    *   **Solution:** Ensure the installation was successful. If you performed a manual installation, create this file at the specified path.

*   **Error:** `[✘] Error: UFW log directory not found or not readable...`
    *   **Cause:** The path to the UFW log is incorrect, or your user lacks permission to read it.
    *   **Solution:** Check the `LOG_FILE` path in your config. The system log `/var/log/ufw.log` often requires administrator privileges (`root`) or membership in the `adm` group. Ensure your user is in the `adm` group (`sudo usermod -aG adm $USER`) or consult your system administrator.

*   **Error:** `[✘] Error: GeoIP database not found or not readable...`
    *   **Cause:** The `GeoLite2-City.mmdb` database has not been downloaded yet or the path is incorrect.
    *   **Solution:**
        *   **If using automated management:** Run `geoupdate.sh` to download the database.
        *   **If using manual placement:** Ensure your `.mmdb` file is located at the path specified in the `MMDB_FILE` variable in your configuration.

*   **Error:** `[✘] Error: Maximum allowed value for '--days' is 366. Got: '...'`
    *   **Cause:** The provided value exceeds the maximum supported history depth.
    *   **Solution:** Provide a value less than or equal to 366.

*   **Error:** `[✘] Error: The value for '...' must be a positive integer...`
    *   **Cause:** You provided a non-numeric or negative value to an option (`--top`, `--days`, `--attempts`).
    *   **Solution:** Use only positive integers (e.g., `1`, `10`, `100`).
	
*   **Error:** `[✘] Error: Invalid month abbreviation...` or `...Date must be in YYYY-MM-DD format...`
    *   **Cause:** The date or month format is incorrect.
    *   **Solution:** Use three-letter English abbreviations (`Jan`, `Feb`, etc.) for the month or the `YYYY-MM-DD` format for the date.

## geoupdate Errors

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
