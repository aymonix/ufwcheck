# Log Retention & Performance

By default, Debian and Ubuntu systems rotate UFW logs weekly and retain only 4 archives, providing approximately **28 days** of history. `ufwcheck` is capable of analyzing up to **1 year** of data to detect persistent low-frequency attacks.

## Prerequisites

Verify that `logrotate` is installed:
```bash
sudo logrotate --version
```

If the command returns nothing, install it:
```bash
sudo apt install logrotate
```

After installation, verify the UFW log rotation config is in place:
```bash
cat /etc/logrotate.d/ufw
```

## Configuring Log Retention

Open the `logrotate` configuration file for UFW:
```bash
sudo nano /etc/logrotate.d/ufw
```

Locate the line starting with `rotate` (usually `rotate 4`) and change its value based on your desired retention period:

*   **`rotate 13`**: ~3 months.
*   **`rotate 26`**: ~6 months.
*   **`rotate 52`**: ~1 year.

The `postrotate` section contains system-specific commands, **leave it unchanged**.

**Example configuration (1 year retention):**
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

Save the file and exit. Changes take effect automatically on the next scheduled rotation.

## Performance Reference

The following estimates are based on a full year of logs (`--days 366`). Actual times scale linearly with log volume and depend on CPU speed and disk I/O.

| Server Profile | Activity Level | Storage (Year) | Analysis Time |
| :--- | :--- | :--- | :--- |
| **Personal / Dev** | Low noise, port scanners. | ~75 MB | ~15 sec |
| **Small Business** | Public web server, constant bots. | ~350 MB | ~1 min |
| **High Exposure** | Popular service, aggressive attacks. | ~3 GB | ~10 min |

Analysis is optimized to stream data, ensuring minimal memory footprint even on low-end VPS.
