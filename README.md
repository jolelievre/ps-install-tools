# ps-install-tools

Scripts to create, reinstall, reset and remove local PrestaShop instances on macOS (Homebrew Apache + MySQL). Every instance is identified by a **suffix**:

| Element | Value for suffix `<s>` |
| --- | --- |
| Folder | `~/www/prestashop-<s>` |
| URL | `http://prestashop.<s>.localhost/` (BO at `/admin-dev/`) |
| Database | `prestashop-<s>` (test DB `test_prestashop-<s>`) |
| Apache vhost | `/opt/homebrew/etc/httpd/extra/sites-{available,enabled}/prestashop.<s>.localhost.conf` |

Folder, domain and database prefixes come from `config.yml` (created from `config.yml.dist` on first run, gitignored).

## Setup

```bash
npm install
npx playwright install
```

Source `aliases.sh` from your shell profile to get the `ps-*` aliases, or call the scripts by full path.

## Commands

| Command | What it does |
| --- | --- |
| `ps-infos <s>` | Read-only report: URLs, DBs (existence), folder, git branch, PrestaShop version, dump, vhost, hosts entry, HTTP status, PHP versions, BO login |
| `ps-install <s> [branch \| user:branch]` | Create or update an instance: clone, checkout, composer install, assets build, `tests/UI/.env`, vhost, `/etc/hosts`, DB install, dump, cache warmup |
| `ps-install-multi-shop <s> [branch]` | `ps-install` then multistore data |
| `ps-install-data <s>` | Drop and reinstall the DB with fixtures, then dump it |
| `ps-install-multi-shop-data <s>` | Add multistore data through the BO (Playwright) |
| `ps-backup <s>` | `mysqldump` the DB to `<folder>/var/dump.sql` |
| `ps-reset <s>` | Drop the DB, reload `<folder>/var/dump.sql`, clear cache |
| `ps-install-module <s> <folder\|zip>` | Copy a module into the instance and install it |
| `ps-upgrade <s>` | Run the upgrade module from the BO (Playwright) |
| `ps-ngrok <s>` | Expose the instance through ngrok |
| `ps-uninstall <s>` | Delete folder, DB, test DB, vhost and hosts entry (destructive) |

When no suffix is given, the scripts detect it from the current folder if it is inside an instance (`~/www/prestashop-<s>/...`), otherwise they ask for it. Without a terminal an empty suffix aborts.

`PS_LANGUAGE` and `PS_COUNTRY` override the install language (`en`) and country (`fr`).

## sudo

Only Apache restarts and `/etc/hosts` edits need `sudo` (`ps-install` on a new instance, `ps-uninstall`, `ps-ngrok`). In a terminal the password is asked as usual. Without a terminal (scripts driven by an AI agent) `run_sudo` in `tools/tools.sh` uses `tools/askpass.sh`: a macOS dialog titled "PrestaShop install tools" asks for the password and states which script needs it and why. Cancelling makes the step fail and prints the command to run manually.

## AI agent integration (`claude/`)

- `claude/CLAUDE.md`: always-on knowledge of the environment and the tools for Claude Code. Import it from `~/.claude/CLAUDE.md` with one line:
  ```
  @~/dev/ps-install-tools/claude/CLAUDE.md
  ```
- `claude/session-start.sh`: Claude Code SessionStart hook that prints `ps-infos` when a session opens inside an instance folder. Wire it in `~/.claude/settings.json`:
  ```json
  { "hooks": { "SessionStart": [ { "hooks": [ { "type": "command", "command": "\"$HOME/dev/ps-install-tools/claude/session-start.sh\"" } ] } ] } }
  ```

Both are wired automatically by the optional `install/17-prestashop-claude.sh` step of the mac-config repository.
