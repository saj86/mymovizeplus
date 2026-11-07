#!/usr/bin/env bash
# MyMoviz Plus - one-click installer for LG webOS TVs (macOS / Linux)
# Usage: bash install-lg.sh [--ip 10.0.0.55] [--passphrase AB12CD] [--ipk path/to/app.ipk]
#
# Same steps as install-lg.ps1:
#   Node.js (>=20, private portable copy if missing) -> @webos-tools/cli ->
#   .ipk shipped next to this script -> ask TV IP + passphrase -> fetch key -> install + launch.

set -u

IPK_NAME="moviz-webos.ipk"
APP_ID="com.movizplus.moviztv"
DEVICE_NAME="moviz-tv"
NODE_MAJOR=22
ROOT="$HOME/.moviz-lg"
CLI_DIR="$ROOT/cli"
STATE_FILE="$ROOT/last-ip.txt"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

IP=""; PASSPHRASE=""; IPK=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ip) IP="$2"; shift 2 ;;
    --passphrase) PASSPHRASE="$2"; shift 2 ;;
    --ipk) IPK="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

c_cyan=$'\e[36m'; c_green=$'\e[32m'; c_yellow=$'\e[33m'; c_red=$'\e[31m'; c_off=$'\e[0m'
step() { printf '\n%s[%s/5] %s%s\n' "$c_cyan" "$1" "$2" "$c_off"; }
ok()   { printf '  %sOK%s  %s\n' "$c_green" "$c_off" "$1"; }
warn() { printf '  %s!!%s  %s\n' "$c_yellow" "$c_off" "$1"; }
fail() { printf '\n  %sXX  %s%s\n' "$c_red" "$1" "$c_off"; exit 1; }

mkdir -p "$ROOT"

printf '%s==============================================\n   MyMoviz Plus  -  LG webOS TV installer\n==============================================%s\n' "$c_red" "$c_off"
echo "Before starting, on the TV: open the 'Developer Mode' app,"
echo "make sure Dev Mode Status is ON and Key Server is ON."

# ---------------------------------------------------------------- 1. Node.js
step 1 "Checking Node.js"
NODE=""; NPM=""
if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
  v="$(node -v 2>/dev/null)"; major="${v#v}"; major="${major%%.*}"
  if [ "${major:-0}" -ge 20 ] 2>/dev/null; then
    NODE="$(command -v node)"; NPM="$(command -v npm)"; ok "Using installed Node.js $v"
  else
    warn "Installed Node.js ($v) is too old - using a private copy instead"
  fi
fi

if [ -z "$NODE" ]; then
  existing="$(ls -d "$ROOT"/node-v"$NODE_MAJOR".* 2>/dev/null | sort | tail -1)"
  if [ -n "$existing" ] && [ -x "$existing/bin/node" ]; then
    node_dir="$existing"; ok "Using private Node.js ($(basename "$existing"))"
  else
    case "$(uname -s)" in Darwin) os=darwin ;; Linux) os=linux ;; *) fail "Unsupported OS: $(uname -s)" ;; esac
    case "$(uname -m)" in x86_64|amd64) arch=x64 ;; arm64|aarch64) arch=arm64 ;; armv7l) arch=armv7l ;; *) fail "Unsupported CPU: $(uname -m)" ;; esac
    command -v curl >/dev/null || fail "curl is required"
    node_ver="$(curl -fsSL https://nodejs.org/dist/index.json 2>/dev/null \
      | grep -o "\"version\":\"v$NODE_MAJOR\.[0-9.]*\"[^}]*\"lts\":\"[^\"]*\"" | head -1 \
      | sed -E 's/.*"version":"([^"]+)".*/\1/')"
    [ -n "$node_ver" ] || { node_ver="v22.12.0"; warn "Could not read the Node.js version list, using $node_ver"; }
    name="node-$node_ver-$os-$arch"
    echo "  Downloading Node.js $node_ver ($os-$arch)..."
    curl -fL --progress-bar "https://nodejs.org/dist/$node_ver/$name.tar.gz" -o "$ROOT/$name.tar.gz" \
      || fail "Download of Node.js failed. Check the internet connection and run again."
    tar -xzf "$ROOT/$name.tar.gz" -C "$ROOT" || fail "Node.js extraction failed."
    rm -f "$ROOT/$name.tar.gz"
    node_dir="$ROOT/$name"
    ok "Node.js $node_ver ready"
  fi
  NODE="$node_dir/bin/node"; NPM="$node_dir/bin/npm"
  export PATH="$node_dir/bin:$PATH"
fi

# ---------------------------------------------------------------- 2. webOS CLI
step 2 "Checking LG webOS CLI"
CLI_BIN="$CLI_DIR/node_modules/@webos-tools/cli/bin"
if [ ! -f "$CLI_BIN/ares-install.js" ]; then
  echo "  Installing @webos-tools/cli (one time, takes a minute)..."
  mkdir -p "$CLI_DIR"
  "$NPM" install --prefix "$CLI_DIR" @webos-tools/cli --no-audit --no-fund --loglevel=error
  [ -f "$CLI_BIN/ares-install.js" ] || fail "Could not install @webos-tools/cli. Check the internet connection and run again."
fi
ok "webOS CLI ready"

ares() { local tool="$1"; shift; "$NODE" "$CLI_BIN/$tool.js" "$@"; }

# ---------------------------------------------------------------- 3. .ipk file
step 3 "Finding the app package"
if [ -n "$IPK" ]; then
  [ -f "$IPK" ] || fail "File not found: $IPK"
else
  # The .ipk ships inside the installer package, next to this script
  IPK="$SCRIPT_DIR/$IPK_NAME"
  [ -f "$IPK" ] || fail "$IPK_NAME not found next to this script. Extract the whole zip into one folder and run again."
fi
ok "Package: $IPK"

# ---------------------------------------------------------------- 4. Connect
step 4 "Connecting to the TV"
port_open() {
  "$NODE" -e '
    const s = require("net").connect({host: process.argv[1], port: +process.argv[2]});
    s.setTimeout(3000);
    s.on("connect", () => { s.destroy(); process.exit(0); });
    s.on("timeout", () => process.exit(1));
    s.on("error", () => process.exit(1));' "$1" "$2"
}

last_ip=""; [ -f "$STATE_FILE" ] && last_ip="$(tr -d '[:space:]' < "$STATE_FILE")"
while true; do
  if [ -z "$IP" ]; then
    prompt="  TV IP address (shown in the Developer Mode app)"; [ -n "$last_ip" ] && prompt="$prompt [$last_ip]"
    read -r -p "$prompt: " IP || fail "No input - run the script in a terminal."
    IP="$(echo "$IP" | tr -d '[:space:]')"; [ -z "$IP" ] && IP="$last_ip"
  fi
  if ! [[ "$IP" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then warn "That is not a valid IP (example: 10.0.0.55)"; IP=""; continue; fi
  echo "  Checking $IP ..."
  if ! port_open "$IP" 9922; then
    warn "TV not reachable on $IP (port 9922). Same WiFi/LAN? Developer Mode ON? Correct IP?"; IP=""; continue
  fi
  if ! port_open "$IP" 9991; then
    warn "Key Server looks OFF. Turn 'Key Server' ON in the Developer Mode app, then press Enter."
    read -r _ || true
    port_open "$IP" 9991 || warn "Key Server still not reachable - trying anyway."
  fi
  break
done
echo "$IP" > "$STATE_FILE"
ok "TV found at $IP"

ares ares-setup-device --remove "$DEVICE_NAME" >/dev/null 2>&1
ares ares-setup-device --add "$DEVICE_NAME" -i "host=$IP" -i "port=9922" -i "username=prisoner" \
  || fail "Could not register the TV in the webOS CLI."

connected=0
for _try in 1 2 3; do
  if [ -z "$PASSPHRASE" ]; then
    read -r -p "  Passphrase (6 characters, shown in the Developer Mode app): " PASSPHRASE || fail "No input - run the script in a terminal."
    PASSPHRASE="$(echo "$PASSPHRASE" | tr -d '[:space:]')"
  fi
  [ -z "$PASSPHRASE" ] && continue
  echo "  Fetching key from the TV..."
  if ares ares-novacom --device "$DEVICE_NAME" --getkey --passphrase "$PASSPHRASE" \
     && ares ares-device --device "$DEVICE_NAME" --system-info; then
    connected=1; break
  fi
  warn "Connection failed. The passphrase may be wrong or expired - check it in the Developer Mode app."
  PASSPHRASE=""
done
[ "$connected" = 1 ] || fail "Could not connect to the TV after 3 attempts."
ok "Connected"

# ---------------------------------------------------------------- 5. Install
step 5 "Installing the app on the TV"
ares ares-install --device "$DEVICE_NAME" "$IPK" || fail "Install failed (see the message above)."
ok "Installed"
ares ares-launch --device "$DEVICE_NAME" "$APP_ID" >/dev/null 2>&1

printf '\n%s==============================================\n  Done! MyMoviz Plus is installed on the TV.\n  To update later, just run this again.\n==============================================%s\n' "$c_green" "$c_off"
