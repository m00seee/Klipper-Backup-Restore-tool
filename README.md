# Klipper Backup & Restore Tool

Back up your Klipper config to GitHub, GitLab, or Gitea and restore it onto any printer with a single command.

---

## Prerequisites

- Klipper installed and running
- SSH access to your printer (Raspberry Pi or similar)
- A GitHub, GitLab, or Gitea account with a repository created for your config
- `git` and `wget` installed on the printer:

```bash
sudo apt-get install git wget -y
```

---

## Installation

SSH into your printer and run:

```bash
wget -q -O menu.sh https://raw.githubusercontent.com/m00seee/Klipper-Backup-Restore-tool/main/menu.sh
chmod +x menu.sh
./menu.sh
```

The first run launches a setup wizard that will:

1. Ask which Git provider you're using (GitHub, GitLab, or Gitea)
2. Ask for your username, email, personal access token, and repository path
3. Test the connection before saving anything
4. Set up the backup and restore scripts
5. Install the `BACKUP` and `RESTORE` macros into Klipper
6. Push an initial backup

**A reboot is recommended after setup so Klipper loads the new macros.**

---

## Creating a Personal Access Token

You need a token so the tool can push to your repository without storing your password.

### GitHub
1. Go to **Settings → Developer settings → Personal access tokens → Tokens (classic)**
2. Click **Generate new token (classic)**
3. Give it a name (e.g. `klipper-backup`) and tick the **`repo`** scope
4. Copy the token — you won't be able to see it again

### GitLab
1. Go to **User Settings → Access tokens**
2. Give it a name, set an expiry, and tick **`read_repository`** and **`write_repository`**
3. Copy the token

### Gitea
1. Go to **Settings → Applications → Generate token**
2. Give it a name and copy the token

> **Tip:** When the wizard asks for your token, paste it and press Enter. Nothing will appear on screen while you type — this is normal, it's hidden for security.

---

## Repository Path Format

When prompted for the repository path, use the short form **without** `https://` or `.git`:

| Provider | Example |
|----------|---------|
| GitHub | `yourusername/voron-config` |
| GitLab | `yourusername/voron-config` |
| Gitea | `yourusername/voron-config` |

> **Note:** Create the repository on your Git provider before running the wizard. If you initialise it with a README that's fine — the tool handles it automatically.

---

## Daily Use

Run the menu any time to back up or restore:

```bash
./menu.sh
```

```
  ╔══════════════════════════════════════════════╗
  ║     Klipper Backup & Restore Tool            ║
  ║     GitHub · GitLab · Gitea                  ║
  ╚══════════════════════════════════════════════╝

  Provider: github   Repo: yourusername/voron-config   Branch: main

  1) Backup now
  2) Restore from github
  3) Reconfigure
  4) Exit
```

---

## Klipper Macros

After setup, two macros are available in Mainsail or Fluidd:

| Macro | What it does |
|-------|-------------|
| `BACKUP` | Commits and pushes your current config to your repository |
| `RESTORE` | Pulls the latest config from your repository (overwrites local files) |

You can call these from the macro panel, or add `BACKUP` to the end of your `END_PRINT` gcode to back up automatically after every print.

> **Warning:** Running `RESTORE` will overwrite your current Klipper config. A Klipper restart is required afterwards for changes to take effect.

---

## Reconfiguring

If you change your token, switch providers, or move to a new repository, choose **option 3 (Reconfigure)** from the menu. It re-runs the credential wizard and tests the connection before saving.

---

## Credentials & Security

Your credentials are stored in `~/.klipper_backup.conf` with permissions set to `600` (readable only by your user). The token is never written into the git history or exposed in `.git/config`.
