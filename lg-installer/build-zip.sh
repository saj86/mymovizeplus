#!/usr/bin/env bash
# Builds ../moviz-lg-installer.zip from the files in this folder plus ../moviz-webos.ipk
# (the install scripts use the bundled .ipk, never a download).
# Also copies ../lg-guide.html into the package as LG-install-guide.html,
# rewriting its relative links to absolute server URLs (they would be broken inside the zip).
set -euo pipefail

SERVER_URL="http://10.0.0.70:8000"
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(dirname "$HERE")"
OUT="$REPO/moviz-lg-installer.zip"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

[ -f "$REPO/moviz-webos.ipk" ] || { echo "Missing $REPO/moviz-webos.ipk" >&2; exit 1; }
cp "$REPO/moviz-webos.ipk" "$STAGE"/
cp "$HERE"/install-lg.bat "$HERE"/install-lg.ps1 "$HERE"/install-lg.sh "$HERE"/install-lg.command "$HERE"/README.txt "$STAGE"/
chmod +x "$STAGE"/install-lg.sh "$STAGE"/install-lg.command

# Packaged guide: point relative links at the server; the zip download button
# becomes a note, since the user already has the package.
python3 - "$REPO/lg-guide.html" "$STAGE/LG-install-guide.html" "$SERVER_URL" <<'PY'
import sys
src, dst, server = sys.argv[1:4]
s = open(src, encoding="utf-8").read()
for name in ("index.html", "moviz-webos.ipk"):
    s = s.replace(f'href="{name}"', f'href="{server}/{name}"')
old = s[s.index('<a class="dl" href="moviz-lg-installer.zip">'):]
old = old[:old.index('</a>') + 4]
s = s.replace(old, '<div class="note" style="margin:0 0 16px"><span class="dot">✔</span><div>'
              'این راهنما داخل پکیج نصب است؛ اسکریپت‌ها (<span class="kbd">install-lg.bat</span> و '
              '<span class="kbd">install-lg.command</span>) و فایل اپ (<span class="kbd">moviz-webos.ipk</span>) کنار همین فایل هستند.</div></div>')
assert 'href="moviz-lg-installer.zip"' not in s
open(dst, "w", encoding="utf-8").write(s)
PY

rm -f "$OUT"
(cd "$STAGE" && zip -X -q "$OUT" LG-install-guide.html README.txt install-lg.bat install-lg.command install-lg.ps1 install-lg.sh moviz-webos.ipk)
echo "Built $OUT"
zipinfo "$OUT"
