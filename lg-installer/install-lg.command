#!/bin/bash
# macOS launcher: double-click in Finder to run the LG TV installer.
# First time only: right-click > Open (macOS blocks downloaded scripts by default).
cd "$(dirname "$0")" || exit 1
bash ./install-lg.sh "$@"
echo
read -r -p "Press Enter to close this window..." _
