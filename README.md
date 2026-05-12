# Klipper Backup & Restore Tool

Back up your Klipper config — or your entire printer data — to GitHub, GitLab, or Gitea and restore it onto any printer with a single command.

---

## Prerequisites

- Klipper installed and running
- SSH access to your printer (Raspberry Pi or similar)
- A GitHub, GitLab, or Gitea account with a repository created for your config
- `git` and `wget` installed on the printer:

```bash
sudo apt install git wget -y
```

---

## Installation

SSH into your printer and run:

```bash
wget -q -O menu.sh https://raw.githubusercontent.com/m00seee/Klipper-Backup-Restore-tool/main/menu.sh
chmod +x menu.sh
./menu.sh
```

The first run gives you two options:

```
  1) Full Setup    — configure backups and install Klipper macros
  2) Quick Restore — just pull my config files from a repo, nothing else
```

Choose **Full Setup** to configure everything. The wizard will:

1. Ask which Git provider you're using (GitHub, GitLab, or Gitea)
2. Ask for your username, email, personal access token, and repository path
3. Test the connection before saving anything
4. Ask what you want to back up (config only, or full printer data)
5. Set up the backup and restore scripts
6. Install the `BACKUP_TO_GITHUB` / `RESTORE_FROM_GITHUB` macros into Klipper
7. Push an initial backup

**A reboot is recommended after setup so Klipper loads the new macros.**

---

## Backup Scope

During setup you can choose what to back up:

| Option | What's included |
|--------|----------------|
| **Config only** *(recommended)* | `printer_data/config` — all your Klipper config files |
| **Full printer data** | `printer_data` — config, Moonraker database, print history, and optionally gcodes |

If you choose **Full printer data**, you'll be asked separately whether to include g-code files. G-codes can be very large — GitHub recommends keeping repos under 1GB. The following are always excluded regardless of scope:

- `logs/` — not useful to restore
- `comms/` — runtime socket files
- `tmp/`
- `.moonraker.db-journal` — rebuilt automatically on startup

> **Note:** Moonraker database files may be briefly locked during backup. This is normal.

---

## Creating a Personal Access Token

You need a token so the tool can push to your repository without storing your password.

### GitHub
**Classic token** *(recommended)*
1. Go to **Settings → Developer settings → Personal access tokens → Tokens (classic)**
2. Click **Generate new token (classic)**
3. Give it a name (e.g. `klipper-backup`) and tick the **`repo`** scope
4. Copy the token — you won't be able to see it again

**Fine-grained token**
1. Go to **Settings → Developer settings → Fine-grained tokens**
2. Under **Repository permissions**, set **Contents** to **Read and Write**
3. Copy the token

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
  3) Quick Restore (clone only, no setup)
  4) Reconfigure
  5) Exit
```

---

## Quick Restore

Use **Quick Restore** (option 3) when you need to get your config onto a fresh printer fast — no git setup, no macros, just your files copied across.

- For **public repos**: only needs the repo path and branch, no token required
- For **private repos**: will prompt for a token automatically if the clone fails

Once you're back up and running, use **Reconfigure** to set up automatic backups properly.

---

## Klipper Macros

After setup, two macros are available in Mainsail or Fluidd named after your provider:

| Macro | What it does |
|-------|-------------|
| `BACKUP_TO_GITHUB` | Commits and pushes your current config to your repository |
| `RESTORE_FROM_GITHUB` | Pulls the latest config from your repository (overwrites local files) |

*(Replace `GITHUB` with `GITLAB` or `GITEA` depending on your provider)*

You can call these from the macro panel, or add `BACKUP_TO_GITHUB` to the end of your `END_PRINT` gcode to back up automatically after every print.

> **Warning:** Running `RESTORE_FROM_GITHUB` will overwrite your current Klipper config. A Klipper restart is required afterwards for changes to take effect.

---

## Reconfiguring

If you change your token, switch providers, change backup scope, or move to a new repository, choose **option 4 (Reconfigure)** from the menu. It re-runs the full wizard and tests the connection before saving.

---

## Credentials & Security

Your credentials are stored in `~/.klipper_backup.conf` with permissions set to `600` (readable only by your user). The token is never written into the git history or exposed in `.git/config`.
