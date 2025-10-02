# Uninstalling ufwcheck

This guide provides the steps to completely and cleanly remove all components of `ufwcheck` from your system.

## Step 1: Remove the Cron Job (If Configured)

If you set up an automatic update job, you need to remove it from your user's crontab.

1.  Open the crontab editor:
    ```bash
    crontab -e
    ```
2.  Find the line containing `geoupdate.sh` and delete it. Save and exit the editor.

## Step 2: Clean Up Your Shell Configuration

You need to remove the line that sources the environment settings.

1.  Open your shell's configuration file (e.g., `~/.bashrc` or `~/.zshrc`) in a text editor.
2.  Find and delete the following line:
    ```bash
    source "$HOME/.config/ufwcheck/env.sh"
    ```
3.  Save the file. The changes will take effect when you start a new terminal session.

## Step 3: Remove All Files and Directories

The following command will permanently delete all scripts, configuration files, data, and temporary files associated with the tool suite.

```bash
rm -rf ~/.local/bin/ufwcheck.sh \
       ~/.local/bin/geoupdate.sh \
       ~/.config/ufwcheck/ \
       ~/.config/maxmind/ \
       ~/.local/share/geoip/ \
       ~/.local/state/ufwcheck.log \
       ~/.local/state/geoupdate.log \
       ~/.local/state/ufw_*.XXXXXX \
       ~/.local/state/geoupdate.XXXXXX
```

After these steps, `ufwcheck` will be completely removed from your system.