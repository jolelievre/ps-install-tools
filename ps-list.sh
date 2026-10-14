#!/bin/sh
#
# Usage: ps-list [--json]
#
# Runs ps-infos on every instance: one line each and an HTML report in ~/www/instances.html,
# or a JSON array of ps-infos --json objects with --json.

BASEDIR=$(dirname "$0")
source $BASEDIR/tools/tools.sh
load_config

json=0
if test "$1" = "--json"; then
    json=1
fi

# Extracts the value after "label:" from a ps-infos text report
field() {
    sed -n "s/^$2:[[:space:]]*//p" "$1" | head -n1
}

suffixes=""
for dir in ${baseFolder}*/; do
    test -d "$dir" || continue
    dir=${dir%/}
    suffixes="$suffixes ${dir#$baseFolder}"
done

if test "$json" = 1; then
    printf '['
    first=1
    for suffix in $suffixes; do
        test "$first" = 1 || printf ','
        first=0
        "$BASEDIR/ps-infos.sh" --json "$suffix"
    done
    printf ']\n'
    exit 0
fi

rows=""
count=0
for suffix in $suffixes; do
    out=$(mktemp)
    if ! "$BASEDIR/ps-infos.sh" "$suffix" > "$out" 2>/dev/null; then
        rm -f "$out"
        continue
    fi
    count=$((count + 1))

    branch=$(field "$out" "Git branch")
    version=$(field "$out" "PrestaShop version")
    url=$(field "$out" "Project url")
    adminUrl=$(field "$out" "Project admin url")
    http=$(field "$out" "HTTP status (FO)")
    # mod_php version, when httpd.conf loads it
    phpGlobal=$(field "$out" "PHP (web)" | sed -n 's/.*(mod_php \([0-9.]*\)).*/\1/p')
    folder=$(field "$out" "Project folder")
    rm -f "$out"

    set_target_instance "$suffix"
    phpClass="ok"
    if test "$instancePhpVersion" = ""; then
        php="global${phpGlobal:+ ($phpGlobal)}"
        phpClass="muted"
    elif test "$instancePhp" = ""; then
        php="$instancePhpVersion (not installed)"
        phpClass="bad"
    elif test "$(fpm_pool_version "$suffix")" != "$instancePhpVersion"; then
        php="$instancePhpVersion (no PHP-FPM pool)"
        phpClass="bad"
    else
        php=$instancePhpVersion
    fi

    printf "%-14s %-30s %-10s %-6s %-14s %s\n" "$suffix" "$branch" "$version" "$http" "$php" "$url"

    rows="$rows<tr><td><strong>$suffix</strong></td><td>$branch</td><td>$version</td><td><a href=\"$url\" target=\"_blank\">front</a> &middot; <a href=\"$adminUrl\" target=\"_blank\">admin</a></td><td class=\"$phpClass\">$php</td><td><code>$folder</code></td></tr>"
done

if test "$count" = 0; then
    echo "No instance found under ${baseFolder}*"
    rows="<tr><td colspan=\"6\" class=\"muted\">No instance found under ${baseFolder}*</td></tr>"
fi

htmlOut="$HOME/www/instances.html"
mkdir -p "$HOME/www"
generatedAt=$(date "+%Y-%m-%d %H:%M:%S")

cat > "$htmlOut" <<HTML
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>PrestaShop instances</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; background: #f7f7f8; color: #1c1c1e; margin: 2rem; }
  h1 { font-size: 1.3rem; margin-bottom: 0.25rem; }
  .meta { color: #666; font-size: 0.85rem; margin-bottom: 1.5rem; }
  table { border-collapse: collapse; width: 100%; background: #fff; box-shadow: 0 1px 3px rgba(0,0,0,.08); }
  th, td { padding: 0.5rem 0.75rem; text-align: left; border-bottom: 1px solid #eee; font-size: 0.9rem; }
  th { background: #fafafa; font-weight: 600; }
  code { font-size: 0.8rem; color: #555; }
  .ok { color: #1a7f37; font-weight: 600; }
  .bad { color: #cf222e; font-weight: 600; }
  .muted { color: #999; }
  a { color: #0969da; text-decoration: none; }
  a:hover { text-decoration: underline; }
</style>
</head>
<body>
<h1>PrestaShop instances</h1>
<div class="meta">$count instance(s) under $baseFolder* &middot; generated $generatedAt</div>
<table>
<thead><tr><th>Suffix</th><th>Branch</th><th>Version</th><th>Links</th><th>PHP</th><th>Folder</th></tr></thead>
<tbody>
$rows
</tbody>
</table>
</body>
</html>
HTML

echo
echo "HTML report: $htmlOut"
echo "Open: http://localhost/instances.html"
