# PrestaShop local instances (ps-install-tools)

Imported from `~/.claude/CLAUDE.md` on machines used for PrestaShop development. Describes the local environment driven by the scripts in `~/dev/ps-install-tools`.

## Layout: one suffix per instance

| Element | Value for suffix `<s>` |
| --- | --- |
| Folder | `~/www/prestashop-<s>` (git clone of PrestaShop, any branch or version) |
| Front office | `http://prestashop.<s>.localhost/` |
| Back office | `http://prestashop.<s>.localhost/admin-dev/` |
| Admin API | `http://prestashop.<s>.localhost/admin-api/` |
| Database | `prestashop-<s>` (MySQL on 127.0.0.1, user `root`, no password, table prefix `ps_`) |
| Test database | `test_prestashop-<s>` (rebuilt with `composer create-test-db` inside the instance) |
| Apache vhost | `/opt/homebrew/etc/httpd/extra/sites-{available,enabled}/prestashop.<s>.localhost.conf` |
| Apache logs | `~/www/var/logs/prestashop-<s>.error.log` and `.access.log` |
| BO login | `email` / `password` of `ps-install-tools/config.yml`, printed by `ps-infos` |
| Admin API client | `apiClientId` / `apiClientSecret` of `config.yml` (defaults `test` / `18c7b983c2eaa22a111609ce2b1c435e`), all scopes, printed by `ps-infos` |

Web stack: Homebrew Apache (`httpd`) on port 80 with mod_php (`sphp <version>` switches the PHP version), MySQL via brew services. opcache revalidates file timestamps, so code changes are live without restarting Apache; only a new vhost needs a restart. Other folders under `~/www` that do not follow the `prestashop-<s>` pattern are not driven by the tools.

## Detect the current instance

- A SessionStart hook runs `ps-infos` when a session opens inside `~/www/prestashop-<s>`; its report at the top of the context is authoritative (branch, version, DBs, vhost, HTTP status, login).
- Otherwise: cwd under `~/www/prestashop-<s>/...` means suffix `<s>`. Run `ps-infos <s>`, or `ps-infos` with no argument from inside the folder. `ps-infos --json <s>` gives the same data as JSON (URLs, paths, DB names, booleans) for scripts.
- Never infer a version from the suffix: `develop`, `92`, `sheriff` only name the instance, `ps-infos` gives the branch and version.

## Tools

Aliases from `ps-install-tools/aliases.sh`, also callable by full path `~/dev/ps-install-tools/<name>.sh`. `<s>` is always the suffix.

| Command | What it does | Notes |
| --- | --- | --- |
| `ps-infos [--json] <s>` | Report on an instance, JSON with `--json` | read-only, safe anytime |
| `ps-install <s> [branch \| user:branch]` | Create or update an instance: clone, checkout, `composer install`, assets build, `tests/UI/.env`, vhost, `/etc/hosts`, DB install, dump, cache warmup | On an existing instance the DB is dropped and reinstalled. sudo only when the vhost or hosts entry is new |
| `ps-install-multi-shop <s> [branch]` | `ps-install` then multistore data | |
| `ps-install-classic <s> [version]` | Build the Classic Edition `<version>` with `~/dev/smb_edition_builder` (`_dev/classic-config/fr-FR/config_classic_<version>.yml`), uninstall the instance if it exists (in the background while the build runs), move the release to the instance folder, `ps-install` | Always pass the version: without a terminal a missing or unknown version lists the available ones and aborts (in a terminal an arrow-key menu is shown). Long: the build takes many minutes. sudo when an instance is replaced or the vhost is new. Addons credentials and GitHub token come from `config.yml` |
| `ps-install-data <s>` | Drop and reinstall the DB with fixtures, then dump it | DB only |
| `ps-install-multi-shop-data <s>` | Add multistore data through the BO (Playwright) | |
| `ps-backup <s>` | `mysqldump` the DB to `<folder>/var/dump.sql` | |
| `ps-reset <s>` | Drop the DB, reload `<folder>/var/dump.sql`, clear cache | fastest way back to a clean state |
| `ps-install-module <s> <folder\|zip>` | Copy a module into the instance and install it | |
| `ps-upgrade <s>` | Run the upgrade module from the BO (Playwright) | |
| `ps-ngrok <s>` | Expose the instance through ngrok (rewrites vhost, `.htaccess`, shop domain in DB) | sudo, changes the shop domain |
| `ps-uninstall <s> [<s2> ...]` | Delete folder, DB, test DB, vhost, hosts entry of every listed instance | Accepts several suffixes separated by spaces, uninstalled one after the other (one confirmation, one Apache stop/restart, one `/etc/hosts` cleanup, so at most two sudo dialogs). DESTRUCTIVE: removes the working copies and any uncommitted work. Always confirm with the developer first |

Behaviour when an agent runs them (no terminal, stdin is `/dev/null`):

- `[Y/n]` confirmation prompts read EOF and proceed, so the tools run unattended. Always pass the suffix explicitly, an empty suffix aborts.
- `sudo` inside the tools opens a macOS password dialog (`tools/askpass.sh`) that only the developer can answer, one dialog per script run. Never prepend `sudo` to a tool and never run the wrapped commands (Apache restart, `/etc/hosts` edits) yourself.
- `composer install` and `make assets` take minutes: run in background and poll.
- `ps-install-classic` runs an edition build (many minutes): run in background and poll.
- `PS_LANGUAGE` and `PS_COUNTRY` environment variables override the install language (`en`) and country (`fr`).

## Data policy

- Databases and test databases are disposable: rebuilt by `ps-install-data`, `ps-reset`, `composer create-test-db`. No need to ask before touching them.
- Folders are not disposable: they hold branches and uncommitted work. Ask before `ps-uninstall` or anything that discards git state.
- Never copy `ps-install-tools/config.yml` anywhere: it is gitignored and holds SMTP credentials.

## Tests inside an instance

- `composer create-test-db` (rebuild the test DB), `composer integration-tests`, `composer integration-behaviour-tests` (Behat), `composer phpstan`, `composer php-cs-fixer`.
- Playwright UI tests: `tests/UI/.env` is generated by `ps-install` with the instance URLs and the BO/API credentials above.

## QA of a pull request (prestashop-pr-qa skill)

- The shop is not in Docker: the served directory is the instance folder (third argument of `pick-run-dir.sh`). FO and BO URLs as above.
- Switching between the code before and after the PR: `git checkout` in the instance, then `bin/console cache:clear`; no Apache restart needed (opcache revalidates). For a PR that changes the DB: `ps-backup` before, `ps-reset` to go back.
- To QA without disturbing a working instance, spawn a dedicated one: `ps-install qa-<pr> <contributor>:<branch>`, then `ps-uninstall qa-<pr>` at the end (with confirmation).
- `gh` is authenticated, node comes from nvm and is on PATH in the agent shell. Run directories go under `~/prestashop-pr-qa/`.
