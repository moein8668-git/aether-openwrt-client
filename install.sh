#!/bin/sh
# install.sh — Install Aether OpenWrt Client
#
# Auto-detects architecture, downloads the latest official Aether binary
# from CluvexStudio/Aether releases, and installs the LuCI web interface.
#
# Usage (on the router):
#   wget -O /tmp/install.sh https://raw.githubusercontent.com/moein8668-git/aether-openwrt-client/main/install.sh
#   chmod +x /tmp/install.sh
#   /tmp/install.sh
#
# Options:
#   --start          Install and start immediately
#   --force-config   Overwrite existing /etc/config/aether
#   --no-curl        Skip curl installation

# No set -e — we handle errors explicitly with || blocks and error() calls.

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

info()    { printf "${BLUE}[*]${RESET} %s\n" "$*"; }
success() { printf "${GREEN}[+]${RESET} %s\n" "$*"; }
warn()    { printf "${YELLOW}[!]${RESET} %s\n" "$*"; }
error()   { printf "${RED}[-]${RESET} %s\n" "$*" >&2; }

# --- Parse arguments ---
START_NOW=0
FORCE_CONFIG=0
SKIP_CURL=0
for arg in "$@"; do
    case "$arg" in
        --start) START_NOW=1 ;;
        --force-config) FORCE_CONFIG=1 ;;
        --no-curl) SKIP_CURL=1 ;;
        -h|--help)
            echo "Usage: $0 [--start] [--force-config] [--no-curl]"
            exit 0
            ;;
    esac
done

# --- Preflight ---
if [ "$(id -u)" -ne 0 ]; then
    error "Run as root on the OpenWrt device (ssh root@router, then $0)"
    exit 1
fi

[ -x /sbin/uci ] || [ -x /usr/sbin/uci ] || { error "This does not look like OpenWrt"; exit 1; }

# --- Detect architecture ---
ARCH=$(uname -m 2>/dev/null || echo unknown)
case "$ARCH" in
    x86_64|amd64)   ASSET_ARCH="x86_64" ;;
    aarch64|arm64)  ASSET_ARCH="arm64" ;;
    armv7*|armv8l)  ASSET_ARCH="armv7" ;;
    *)
        error "Unsupported architecture: $ARCH"
        error "Supported: x86_64, aarch64, armv7"
        exit 1
        ;;
esac

# --- Map to release archive name ---
case "$ASSET_ARCH" in
    x86_64)  ARCHIVE="aether-linux-x86_64-musl.tar.gz" ;;
    arm64)   ARCHIVE="aether-linux-aarch64-musl.tar.gz" ;;
    armv7)   ARCHIVE="aether-linux-armv7-musl.tar.gz" ;;
esac

REPO="CluvexStudio/Aether"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"

echo ""
echo "========================================="
echo " Aether OpenWrt Client Installer"
echo " Arch: $ARCH -> $ARCHIVE"
echo "========================================="
echo ""

# --- Check dependencies (wget is built-in on OpenWrt) ---
for cmd in wget tar grep sed; do
    command -v "$cmd" >/dev/null 2>&1 || { error "Missing: $cmd"; exit 1; }
done

# --- Fetch latest release info ---
info "Fetching latest release from GitHub..."
RELEASE_JSON=$(wget -qO- "$API_URL" 2>/dev/null) || {
    error "Failed to reach GitHub API. Check internet connection."
    exit 1
}

TAG_NAME=$(echo "$RELEASE_JSON" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name":\s*"([^"]+)".*/\1/')
if [ -z "$TAG_NAME" ]; then
    error "Could not resolve latest release tag."
    exit 1
fi
success "Latest release: $TAG_NAME"

# --- Find download URL ---
ASSET_URL=$(echo "$RELEASE_JSON" | grep -o "\"browser_download_url\": *\"[^\"]*${ARCHIVE}\"" | sed -E 's/.*"(https[^"]+)"/\1/' | head -n1)
if [ -z "$ASSET_URL" ]; then
    error "No asset found: $ARCHIVE"
    error "This architecture may not have a prebuilt binary."
    exit 1
fi

# --- Find SHA256 checksum URL ---
SHA256_FILE="${ARCHIVE}.sha256"
SHA256_URL=$(echo "$RELEASE_JSON" | grep -o "\"browser_download_url\": *\"[^\"]*${SHA256_FILE}\"" | sed -E 's/.*"(https[^"]+)"/\1/' | head -n1)

# --- Download ---
TMP_DIR=$(mktemp -d /tmp/aether-install.XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT

info "Downloading $ARCHIVE..."
wget -q -O "$TMP_DIR/$ARCHIVE" "$ASSET_URL" || {
    error "Download failed."
    exit 1
}

# --- Verify checksum ---
if [ -n "$SHA256_URL" ]; then
    info "Verifying checksum..."
    wget -q -O "$TMP_DIR/$SHA256_FILE" "$SHA256_URL" || {
        warn "Could not download checksum file. Skipping verification."
    }
    if [ -f "$TMP_DIR/$SHA256_FILE" ]; then
        EXPECTED_HASH=$(cat "$TMP_DIR/$SHA256_FILE" | awk '{print $1}' | tr -d '[:space:]')
        ACTUAL_HASH=$(sha256sum "$TMP_DIR/$ARCHIVE" | awk '{print $1}')
        if [ "$EXPECTED_HASH" = "$ACTUAL_HASH" ]; then
            success "Checksum verified"
        else
            error "Checksum mismatch!"
            error "Expected: $EXPECTED_HASH"
            error "Actual:   $ACTUAL_HASH"
            error "The download may be corrupted or tampered with. Aborting."
            exit 1
        fi
    fi
else
    warn "No checksum file found for $ARCHIVE. Skipping verification."
fi

# --- Extract ---
info "Extracting..."
tar -xzf "$TMP_DIR/$ARCHIVE" -C "$TMP_DIR" 2>/dev/null

# Find the binary
BINARY=$(find "$TMP_DIR" -maxdepth 2 -type f -name "aether" | head -n1)
if [ -z "$BINARY" ] || [ ! -f "$BINARY" ]; then
    error "Could not find aether binary in the archive."
    exit 1
fi

chmod +x "$BINARY"
success "Binary: $($BINARY --version 2>&1)"

# --- Ask about curl ---
if [ "$SKIP_CURL" -eq 0 ] && ! command -v curl >/dev/null 2>&1; then
    echo ""
    printf "${YELLOW}Install curl?${RESET} (needed for connection tests in LuCI) [y/N]: "
    read -r answer
    case "$answer" in
        y|Y|yes|YES)
            info "Installing curl..."
            if command -v apk >/dev/null 2>&1; then
                apk add curl 2>/dev/null || warn "Could not install curl"
            elif command -v opkg >/dev/null 2>&1; then
                opkg update >/dev/null 2>&1
                opkg install curl 2>/dev/null || warn "Could not install curl"
            fi
            ;;
        *)
            warn "Skipping curl. Connection tests will not work."
            ;;
    esac
fi

# --- Install binary ---
SCRIPT_DIR=$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")
cp -f "$BINARY" /usr/bin/aether
chmod 755 /usr/bin/aether
success "Installed /usr/bin/aether"

# --- Stop previous instance ---
/etc/init.d/aether stop 2>/dev/null || true
killall aether 2>/dev/null || true
sleep 1

# --- Remote file helper ---
# When install.sh is run standalone (downloaded to /tmp), the files/ directory
# isn't available locally.  Fall back to fetching each file from GitHub Raw.
RAW_BASE="https://raw.githubusercontent.com/moein8668-git/aether-openwrt-client/main/files"

fetch_file() {
    # fetch_file <repo-relative-path-under-files/> <destination> <mode>
    local rel="$1" dst="$2" mode="$3"
    local src_local="$SCRIPT_DIR/files/$rel"
    mkdir -p "$(dirname "$dst")"
    if [ -f "$src_local" ]; then
        cp -f "$src_local" "$dst"
    else
        wget -q -O "$dst" "$RAW_BASE/$rel" || {
            error "Failed to download $rel"
            rm -f "$dst"
            return 1
        }
    fi
    [ -n "$mode" ] && chmod "$mode" "$dst"
    success "Installed $dst"
}

# --- Install config ---
FILE_ERRORS=0
if [ -f /etc/config/aether ] && [ "$FORCE_CONFIG" -eq 0 ]; then
    warn "Keeping existing /etc/config/aether"
else
    fetch_file "etc/config/aether" /etc/config/aether 644 || FILE_ERRORS=$((FILE_ERRORS + 1))
fi

# --- Install files ---
fetch_file "etc/init.d/aether" /etc/init.d/aether 755 || FILE_ERRORS=$((FILE_ERRORS + 1))
fetch_file "usr/bin/aether-ctl" /usr/bin/aether-ctl 755 || FILE_ERRORS=$((FILE_ERRORS + 1))
fetch_file "usr/libexec/rpcd/luci-app-aether" /usr/libexec/rpcd/luci-app-aether 755 || FILE_ERRORS=$((FILE_ERRORS + 1))
fetch_file "usr/share/rpcd/acl.d/luci-app-aether.json" /usr/share/rpcd/acl.d/luci-app-aether.json 644 || FILE_ERRORS=$((FILE_ERRORS + 1))
fetch_file "usr/share/luci/menu.d/luci-app-aether.json" /usr/share/luci/menu.d/luci-app-aether.json 644 || FILE_ERRORS=$((FILE_ERRORS + 1))
fetch_file "www/luci-static/resources/view/aether.js" /www/luci-static/resources/view/aether.js 644 || FILE_ERRORS=$((FILE_ERRORS + 1))

# --- Check for file errors ---
if [ "$FILE_ERRORS" -gt 0 ]; then
    warn "$FILE_ERRORS file(s) failed to install. Check network connection and re-run."
fi

# --- Identity storage ---
mkdir -p /etc/aether 2>/dev/null
chmod 700 /etc/aether 2>/dev/null || true
[ -f /etc/aether/aether.toml ] || touch /etc/aether/aether.toml

# --- Register service ---
/etc/init.d/aether enable 2>/dev/null || true

# --- Restart rpcd ---
/etc/init.d/rpcd restart 2>/dev/null || true

# --- Start if requested ---
if [ "$START_NOW" -eq 1 ]; then
    info "Starting Aether..."
    aether-ctl start 2>/dev/null || /etc/init.d/aether start
fi

echo ""
success "========================================="
success " Installation complete!"
success "========================================="
echo ""
echo "  Binary:     /usr/bin/aether ($TAG_NAME)"
echo "  CLI:        aether-ctl start | stop | status | log"
echo "  LuCI:       Services -> Aether (Ctrl+F5 to refresh)"
echo "  Config:     /etc/config/aether"
echo ""
