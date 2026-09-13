# ps-install-tools

Scripts to create, reinstall, reset and remove local PrestaShop instances on macOS (Homebrew Apache + MySQL). Every instance is identified by a **suffix**:

| Element | Value for suffix `<s>` |
| --- | --- |
| Folder | `~/www/prestashop-<s>` |
| URL | `http://prestashop.<s>.localhost/` (BO at `/admin-dev/`) |
| Database | `prestashop-<s>` (test DB `test_prestashop-<s>`) |
| Apache vhost | `/opt/homebrew/etc/httpd/extra/sites-{available,enabled}/prestashop.<s>.localhost.conf` |

Folder, domain and database prefixes, BO account, SMTP settings and the default Admin API client (`apiClientId` / `apiClientSecret`) come from `config.yml`, created from `config.yml.dist` on first run and gitignored. New keys added to `config.yml.dist` are asked once on the next run (default kept without a terminal).

## Setup

```bash
npm install
npx playwright install
```

Source `aliases.sh` from your shell profile to get the `ps-*` aliases, or call the scripts by full path.

## Commands

| Command | What it does |
| --- | --- |
| `ps-infos [--json] <s>` | Read-only report: URLs, DBs (existence), folder, git branch, PrestaShop version, dump, vhost, hosts entry, HTTP status, PHP versions, BO login. `--json` prints the same data as JSON for scripts and agents |
| `ps-install <s> [branch \| user:branch]` | Create or update an instance: clone, checkout, composer install, assets build, `tests/UI/.env`, vhost, `/etc/hosts`, DB install, dump, cache warmup |
| `ps-install-multi-shop <s> [branch]` | `ps-install` then multistore data |
| `ps-install-classic <s> [version]` | Build the Classic Edition `<version>` with `smb_edition_builder` (menu of the available versions when omitted or unknown), uninstall the instance if it exists (in the background while the build runs), move the release to the instance folder and `ps-install` it (see below) |
| `ps-install-data <s>` | Drop and reinstall the DB with fixtures, then dump it |
| `ps-install-multi-shop-data <s>` | Add multistore data through the BO (Playwright) |
| `ps-backup <s>` | `mysqldump` the DB to `<folder>/var/dump.sql` |
| `ps-reset <s>` | Drop the DB, reload `<folder>/var/dump.sql`, clear cache |
| `ps-install-module <s> <folder\|zip>` | Copy a module into the instance and install it |
| `ps-upgrade <s>` | Run the upgrade module from the BO (Playwright) |
| `ps-ngrok <s>` | Expose the instance through ngrok |
| `ps-uninstall <s> [<s2> ...]` | Delete folder, DB, test DB, vhost and hosts entry of every listed instance (destructive) |

`ps-uninstall` is the only command that takes several suffixes: they are uninstalled one after the other, with a single confirmation listing them all, a single Apache stop/restart around the whole list and a single `/etc/hosts` cleanup, so `sudo` is asked at most twice whatever the number of instances.

```bash
ps-uninstall qa-1234                      # one instance
ps-uninstall qa-1234 qa-5678 classic      # three instances, one confirmation
```

When no suffix is given, the scripts detect it from the current folder if it is inside an instance (`~/www/prestashop-<s>/...`), otherwise they ask for it. Without a terminal an empty suffix aborts.

`PS_LANGUAGE` and `PS_COUNTRY` override the install language (`en`) and country (`fr`).

## Classic Edition

`ps-install-classic <s> [version]` builds the Classic Edition with a local clone of [smb_edition_builder](https://github.com/PrestaShopCorp/smb_edition_builder) and installs the result as a regular instance:

```bash
ps-install-classic classic                # pick the version in an arrow-key menu (newest first)
ps-install-classic classic 9.2.x          # _dev/classic-config/fr-FR/config_classic_9.2.x.yml
ps-install-classic classic-828 8.2.8
ps-install-classic classic-91 9.1.5-5.0
```

When `<version>` is omitted or has no config file, an arrow-key menu of the available versions (reverse alphabetical order, newest first) is shown in the terminal; without a terminal the versions are listed and the script aborts. It also fails early when the builder folder or its `vendor` is missing, or when a credential is empty. When an instance already matches the suffix it is uninstalled (`ps-uninstall`, one sudo prompt before the build) in the background while the build runs, since a build cannot be replaced in place; its log is written to `<tmpFolder>/ps-install-classic-<s>-uninstall.log`. The release built in `workdir/tools/build/releases/prestashop` is then moved to the instance folder, `admin` and `install` are renamed `admin-dev` and `install-dev`, and `ps-install <s>` finishes the installation.

Keys in `config.yml`:

| Key | Value |
| --- | --- |
| `editionBuilderFolder` | Clone of `smb_edition_builder` with `composer install` done (default `$HOME/dev/smb_edition_builder`) |
| `editionLocale` | Config folder under `_dev/classic-config/` (default `fr-FR`) |
| `addonsUserAgent`, `addonsUser`, `addonsPassword` | Addons credentials passed as `-A` and `-u user:password` to download paid modules |
| `githubToken` | GitHub token passed as `-t` to download corp modules |
| `githubEmail`, `githubName` | Git identity passed as `-E` / `-N`; empty means the local git config, then the builder defaults |

`addonsPassword` and `githubToken` are secrets: they only live in the gitignored `config.yml`, never on the command line nor in the shell history. The build uses the current `node` (the builder README asks for node 14 on 8.x and node 20 on 9.x), switch it before running the command if needed.

## sudo

Only Apache restarts and `/etc/hosts` edits need `sudo` (`ps-install` on a new instance, `ps-uninstall`, `ps-ngrok`). In a terminal the password is asked as usual. Without a terminal (scripts driven by an AI agent) `run_sudo` in `tools/tools.sh` uses `tools/askpass.sh`: a macOS dialog titled "PrestaShop install tools" asks for the password and states which script needs it and why. Cancelling makes the step fail and prints the command to run manually.

## Helpers for script authors (`tools/tools.sh`)

`set_target_instance <s>` sets the variables of an instance from its suffix (`suffix`, `targetFolder`, `targetDomain`, `targetUrl`, `targetDatabase`, `targetName`). `tools/config.sh` calls it for the suffix it resolved; a script working on several instances (`ps-uninstall`) calls it again for each suffix of its list.

`select_option "question" choice...` draws an arrow-key menu on the terminal (Up/Down or k/j, Enter selects, q or Esc cancels, long lists scroll) and prints the chosen value: `value=$(select_option "Which version?" $versions)`. Returns 1 when cancelled and 2 when there is no terminal, so the caller can fall back to a non-interactive behaviour. The caller builds and orders the list.

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
