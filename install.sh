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
umask 077

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
        *)
            error "Unknown option: $arg"
            exit 1
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
for cmd in wget tar grep sed find sha256sum; do
    command -v "$cmd" >/dev/null 2>&1 || { error "Missing: $cmd"; exit 1; }
done

# --- Fetch latest release info ---
info "Fetching latest release from GitHub..."
RELEASE_JSON=$(wget -4 -T 30 -qO- "$API_URL" 2>/dev/null) || {
    error "Failed to reach GitHub API. Check internet connection."
    exit 1
}

TAG_NAME=$(echo "$RELEASE_JSON" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name":\s*"([^"]+)".*/\1/')
if [ -z "$TAG_NAME" ]; then
    error "Could not resolve latest release tag."
    exit 1
fi
success "Latest release: $TAG_NAME"

# --- Build canonical download URL ---
# Do not parse browser_download_url from the API response. BusyBox grep/sed
# variants can select or rewrite the URL differently, while GitHub's canonical
# release URL is stable and wget follows its signed redirect correctly.
ASSET_URL="https://github.com/${REPO}/releases/download/${TAG_NAME}/${ARCHIVE}"

# --- Download ---
TMP_DIR=$(mktemp -d /tmp/aether-install.XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT

info "Downloading $ARCHIVE..."
wget -4 -T 120 -O "$TMP_DIR/$ARCHIVE" "$ASSET_URL" || {
    error "Download failed."
    exit 1
}
[ -s "$TMP_DIR/$ARCHIVE" ] || {
    error "Downloaded archive is empty."
    exit 1
}

# --- Verify release checksum ---
CHECKSUM_URL="${ASSET_URL}.sha256"
info "Verifying checksum..."
wget -4 -T 30 -O "$TMP_DIR/$ARCHIVE.sha256" "$CHECKSUM_URL" || {
    error "Could not download the release checksum."
    exit 1
}
if ! (cd "$TMP_DIR" && sha256sum -c "$ARCHIVE.sha256" >/dev/null 2>&1); then
    error "Checksum verification failed. Aborting."
    error "Expected file: $TMP_DIR/$ARCHIVE"
    error "Checksum file: $TMP_DIR/$ARCHIVE.sha256"
    exit 1
fi
success "Checksum verified"

# --- Extract ---
info "Extracting..."
tar -xzf "$TMP_DIR/$ARCHIVE" -C "$TMP_DIR" 2>/dev/null || {
    error "Downloaded archive could not be extracted."
    exit 1
}

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
    printf "${YELLOW}Install curl?${RESET} (needed for LuCI tests and automatic tunnel recovery) [Y/n]: "
    read -r answer
    case "$answer" in
        ''|y|Y|yes|YES)
            info "Installing curl..."
            if command -v apk >/dev/null 2>&1; then
                apk add curl 2>/dev/null || warn "Could not install curl"
            elif command -v opkg >/dev/null 2>&1; then
                opkg update >/dev/null 2>&1
                opkg install curl 2>/dev/null || warn "Could not install curl"
            else
                warn "No supported package manager found; watchdog will remain unavailable"
            fi
            ;;
        *)
            warn "Skipping curl. Connection tests and the data-plane watchdog will not work."
            ;;
    esac
fi

# --- Locate local support files ---
SCRIPT_DIR=$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")

# --- Stage support files ---
# When install.sh is run standalone (downloaded to /tmp), the files/ directory
# isn't available locally.  Fall back to fetching each file from GitHub Raw.
RAW_BASE="https://raw.githubusercontent.com/moein8668-git/aether-openwrt-client/main/files"
STAGE_ROOT="$TMP_DIR/root"

stage_file() {
    # stage_file <repo-relative-path-under-files/> <mode>
    local rel="$1" mode="$2"
    local src_local="$SCRIPT_DIR/files/$rel"
    local staged="$STAGE_ROOT/$rel"
    mkdir -p "$(dirname "$staged")" || return 1
    if [ -f "$src_local" ]; then
        cp -f "$src_local" "$staged" || return 1
    else
        wget -q -O "$staged" "$RAW_BASE/$rel" || {
            error "Failed to download $rel"
            rm -f "$staged"
            return 1
        }
    fi
    [ -s "$staged" ] || {
        error "Staged support file is empty: $rel"
        return 1
    }
    chmod "$mode" "$staged" || return 1
}

stage_file "etc/config/aether" 600 &&
stage_file "etc/init.d/aether" 755 &&
stage_file "usr/bin/aether-ctl" 755 &&
stage_file "usr/bin/aether-run" 755 &&
stage_file "usr/bin/aether-watchdog" 755 &&
stage_file "usr/libexec/rpcd/luci-app-aether" 755 &&
stage_file "usr/share/rpcd/acl.d/luci-app-aether.json" 644 &&
stage_file "usr/share/luci/menu.d/luci-app-aether.json" 644 &&
stage_file "www/luci-static/resources/view/aether.js" 644 || {
    error "Required support files could not be staged. Nothing was installed."
    exit 1
}

# --- Stop previous instance before replacing its binary ---
/etc/init.d/aether stop 2>/dev/null || true
killall aether 2>/dev/null || true
sleep 1

# --- Install staged files ---
install_staged() {
    local rel="$1" mode="$2" dst="/$1"
    mkdir -p "$(dirname "$dst")" &&
        cp -f "$STAGE_ROOT/$rel" "$dst" &&
        chmod "$mode" "$dst" || {
        error "Failed to install $dst"
        return 1
    }
    success "Installed $dst"
}

cp -f "$BINARY" /usr/bin/aether && chmod 755 /usr/bin/aether || {
    error "Failed to install /usr/bin/aether"
    exit 1
}
success "Installed /usr/bin/aether"

if [ -f /etc/config/aether ] && [ "$FORCE_CONFIG" -eq 0 ]; then
    warn "Keeping existing /etc/config/aether"
else
    install_staged "etc/config/aether" 600 || exit 1
fi
chmod 600 /etc/config/aether || {
    error "Failed to protect /etc/config/aether"
    exit 1
}
install_staged "etc/init.d/aether" 755 &&
install_staged "usr/bin/aether-ctl" 755 &&
install_staged "usr/bin/aether-run" 755 &&
install_staged "usr/bin/aether-watchdog" 755 &&
install_staged "usr/libexec/rpcd/luci-app-aether" 755 &&
install_staged "usr/share/rpcd/acl.d/luci-app-aether.json" 644 &&
install_staged "usr/share/luci/menu.d/luci-app-aether.json" 644 &&
install_staged "www/luci-static/resources/view/aether.js" 644 || exit 1

# --- Identity storage ---
# Only create the directory. Do NOT touch an empty aether.toml — Aether
# provisions a real identity when the file is missing, but an empty file
# fails TOML parse (missing device_id) and crashes wg/gool. MASQUE uses a
# sibling path (aether-masque.toml) so it was unaffected by this bug.
mkdir -p /etc/aether 2>/dev/null
chmod 700 /etc/aether 2>/dev/null || true
# Older client versions let relative identity paths resolve in / or /root.
# Move those identities into the deterministic service directory when safe.
for legacy in /aether*.toml /root/aether*.toml; do
    [ -f "$legacy" ] || continue
    identity_name="${legacy##*/}"
    if [ ! -e "/etc/aether/$identity_name" ]; then
        info "Migrating identity $legacy to /etc/aether/$identity_name"
        mv "$legacy" "/etc/aether/$identity_name" || {
            error "Failed to migrate identity: $legacy"
            exit 1
        }
        chmod 600 "/etc/aether/$identity_name" 2>/dev/null || true
    else
        warn "Leaving duplicate legacy identity in place: $legacy"
    fi
done
# Migrate: remove empty/invalid stubs left by older installers
for f in /etc/aether/aether.toml /etc/aether/aether-secondary.toml; do
    if [ -f "$f" ] && ! grep -q 'device_id' "$f" 2>/dev/null; then
        warn "Removing invalid identity stub: $f"
        rm -f "$f"
    fi
done

# --- Register service ---
BOOT_ENABLED=$(uci -q get aether.main.enabled 2>/dev/null)
if [ "$BOOT_ENABLED" = "1" ]; then
    /etc/init.d/aether enable 2>/dev/null
else
    /etc/init.d/aether disable 2>/dev/null
fi || {
    error "Failed to synchronize the Aether boot setting."
    exit 1
}

# --- Clear LuCI caches and restart services ---
rm -f /tmp/luci-indexcache 2>/dev/null || true
rm -rf /tmp/luci-modulecache 2>/dev/null || true
/etc/init.d/rpcd restart 2>/dev/null || true
/etc/init.d/uhttpd restart 2>/dev/null || true

# --- Start if requested ---
if [ "$START_NOW" -eq 1 ]; then
    info "Starting Aether..."
    aether-ctl start || {
        error "Aether was installed but failed to start. Check: logread -e aether"
        exit 1
    }
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