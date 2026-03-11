# Uninstalling ufwcheck

This guide provides the steps to completely and cleanly remove all components of `ufwcheck` from your system.

## Step 1: Remove the Cron Job (If Configured)

If you set up an automatic update job, remove it with a single command:
```bash
crontab -l | grep -Fv "geoupdate" | crontab -
```

## Step 2: Clean Up Your Shell Configuration

Open your shell configuration file (`~/.bashrc` or `~/.zshrc`) and remove the following line:
```bash
source "$HOME/.config/ufwcheck/env"
```
Save the file. The changes will take effect when you start a new terminal session.

## Step 3: Remove All Files and Directories

The following command will permanently delete all scripts, configuration files, and data associated with the tool suite.
```bash
rm -rf ~/.local/bin/ufwcheck \
       ~/.local/bin/geoupdate \
       ~/.config/ufwcheck/ \
       ~/.config/maxmind/ \
       ~/.local/share/geoip/ \
       ~/.local/state/ufwcheck.log \
       ~/.local/state/geoupdate.log
```

After these steps, `ufwcheck` will be completely removed from your system.
