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
#   --version <tag>  Install a specific Aether core release (v1.5.0 or newer)
#   --non-interactive  Do not prompt; defaults to v2.4.0

# No set -e — we handle errors explicitly with || blocks and error() calls.
umask 077
CLIENT_VERSION="v0.10.0"

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


# Automatic performance profile from total RAM:
# <256MB -> low, 256MB-768MB -> medium, >768MB -> high
select_perf_profile() {
    local total_kb
    total_kb="$(awk '/^MemTotal/ {print $2}' /proc/meminfo 2>/dev/null)"
    case "$total_kb" in
        ''|*[!0-9]*) echo "low"; return ;;
    esac
    if [ "$total_kb" -lt 262144 ]; then
        echo "low"
    elif [ "$total_kb" -lt 786432 ]; then
        echo "medium"
    else
        echo "high"
    fi
}
# A failed HTTPS fetch reads like a network outage, but a stale router clock is
# the usual cause: every certificate then looks "not yet valid" or "expired".
# Prints the extra lines to show in that case, nothing otherwise.
https_hint_text() {
    if grep -qiE 'certificate|not yet valid|not trusted|expired' "$1" 2>/dev/null; then
        printf '%s\n' "The HTTPS certificate was rejected, which usually means the router clock is wrong"
        printf '%s\n' "(certificates then look 'not yet valid' or 'expired'). Fix the time and retry:"
        printf '%s\n' "  date -u MMDDhhmmCCYY    # e.g. date -u 102908002026"
        printf '%s\n' "  or enable NTP: uci set system.ntp.enabled=1 && /etc/init.d/sysntpd restart"
    fi
}
# --- Parse arguments ---
START_NOW=0
FORCE_CONFIG=0
SKIP_CURL=0
NON_INTERACTIVE=0
REQUESTED_VERSION=""
while [ "$#" -gt 0 ]; do
    arg="$1"
    case "$arg" in
        --start) START_NOW=1 ;;
        --force-config) FORCE_CONFIG=1 ;;
        --no-curl) SKIP_CURL=1 ;;
        --non-interactive) NON_INTERACTIVE=1 ;;
        --version)
            shift
            [ -n "${1:-}" ] || { error "--version requires a release tag"; exit 1; }
            REQUESTED_VERSION="$1"
            ;;
        --version=*)
            REQUESTED_VERSION="${arg#--version=}"
            ;;
        -h|--help)
            echo "Usage: $0 [--start] [--force-config] [--no-curl] [--version <vX.Y.Z>] [--non-interactive]"
            exit 0
            ;;
        *)
            error "Unknown option: $arg"
            exit 1
            ;;
    esac
    shift
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
API_URL="https://api.github.com/repos/${REPO}/releases?per_page=30"
DEFAULT_VERSION="v2.4.0"

echo ""
echo "========================================="
echo " Aether OpenWrt Client $CLIENT_VERSION Installer"
echo " Arch: $ARCH -> $ARCHIVE"
echo "========================================="
echo ""

# --- Check dependencies (wget is built-in on OpenWrt) ---
for cmd in wget tar grep sed awk find sha256sum; do
    command -v "$cmd" >/dev/null 2>&1 || { error "Missing: $cmd"; exit 1; }
done

# --- Resolve core release ---
valid_tag() {
    case "$1" in
        v[0-9]*.[0-9]*.[0-9]*)
            echo "$1" | grep -Eq '^v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$'
            ;;
        *) return 1 ;;
    esac
}

supported_core_version() {
    local tag="$1" version major minor rest
    version="${tag#v}"
    major="${version%%.*}"
    rest="${version#*.}"
    minor="${rest%%.*}"
    [ "$major" -gt 1 ] 2>/dev/null ||
        { [ "$major" -eq 1 ] 2>/dev/null && [ "$minor" -ge 5 ] 2>/dev/null; }
}

contains_tag() {
    echo "$AVAILABLE_TAGS" | grep -Fx "$1" >/dev/null 2>&1
}

info "Fetching available releases from GitHub..."
# No -q here: wget -q suppresses its own error text, and that text is what tells
# a stale clock (certificate rejected) apart from a real network outage. Both the
# progress bar and the errors go to stderr, which is captured, so a successful
# run stays quiet.
FETCH_ERR="/tmp/aether-fetch.$$.err"
RELEASE_JSON=$(wget -4 -T 30 -O- "$API_URL" 2>"$FETCH_ERR") || {
    error "Failed to reach GitHub API. Check internet connection."
    HTTPS_HINT=$(https_hint_text "$FETCH_ERR")
    if [ -n "$HTTPS_HINT" ]; then
        printf '%s\n' "$HTTPS_HINT" | while IFS= read -r hint_line; do error "$hint_line"; done
    fi
    rm -f "$FETCH_ERR"
    exit 1
}
rm -f "$FETCH_ERR"

# The GitHub response is compact JSON. Split release objects, retain only
# published stable releases, and use API order (newest first).
# Strip JSON whitespace before splitting release objects. GitHub returns pretty
# printed JSON on some OpenWrt wget builds and compact JSON on others.
AVAILABLE_TAGS=$(echo "$RELEASE_JSON" | tr -d '\r\n ' | sed 's/},{/}\n{/g' |
    while IFS= read -r release; do
        echo "$release" | grep -q '"draft":false' || continue
        echo "$release" | grep -q '"prerelease":false' || continue
        tag=$(echo "$release" | sed -n 's/.*"tag_name":"\([^"]*\)".*/\1/p')
        valid_tag "$tag" || continue
        supported_core_version "$tag" || continue
        echo "$tag"
    done | awk '!seen[$0]++' | awk 'NR<=5')

if [ -z "$AVAILABLE_TAGS" ]; then
    error "Could not resolve stable Aether release tags."
    exit 1
fi

if [ -n "$REQUESTED_VERSION" ]; then
    valid_tag "$REQUESTED_VERSION" || {
        error "Invalid release tag: $REQUESTED_VERSION (expected vX.Y.Z)"
        exit 1
    }
    supported_core_version "$REQUESTED_VERSION" || {
        error "Unsupported release tag: $REQUESTED_VERSION (v1.5.0 or newer is required)"
        exit 1
    }
    TAG_NAME="$REQUESTED_VERSION"
elif [ "$NON_INTERACTIVE" -eq 1 ] || [ ! -t 0 ]; then
    TAG_NAME="$DEFAULT_VERSION"
else
    echo ""
    echo "Available Aether core releases (v1.5.0 or newer):"
    i=1
    echo "$AVAILABLE_TAGS" | while IFS= read -r tag; do
        [ -n "$tag" ] || continue
        printf "  %s) %s\n" "$i" "$tag"
        i=$((i + 1))
    done
    printf "Choose a number or type a version [%s]: " "$DEFAULT_VERSION"
    read -r choice
    case "$choice" in
        '') TAG_NAME="$DEFAULT_VERSION" ;;
        1|2|3|4|5)
            TAG_NAME=$(echo "$AVAILABLE_TAGS" | awk -v n="$choice" 'NR == n { print; exit }')
            ;;
        *) TAG_NAME="$choice" ;;
    esac
fi

valid_tag "$TAG_NAME" || {
    error "Invalid release tag: $TAG_NAME (expected vX.Y.Z)"
    exit 1
}

# A custom tag may be older than the displayed five. Verify it against its
# release endpoint before using it in a download URL.
if ! contains_tag "$TAG_NAME"; then
    info "Verifying requested release: $TAG_NAME"
    wget -4 -T 30 -qO- "https://api.github.com/repos/${REPO}/releases/tags/${TAG_NAME}" |
        grep -q '"tag_name"' || {
        error "Release $TAG_NAME was not found."
        exit 1
    }
fi
success "Selected release: $TAG_NAME"

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

# Core v2 archives carry pluggable transports under pt/ (lyrebird, and on
# v2.1+ the Psiphon console client). Keep the whole tree beside the binary.
PT_DIR=$(find "$TMP_DIR" -type d -name pt | head -n1)
PT_BINARY=$(find "$TMP_DIR" -type f -path "*/pt/lyrebird" | head -n1)
# Release archives also ship third-party licences next to the binary.
LICENSES_DIR=$(find "$TMP_DIR" -type d -name LICENSES | head -n1)

chmod +x "$BINARY"
success "Binary: $($BINARY --version 2>&1)"

# --- Ask about curl ---
if [ "$SKIP_CURL" -eq 0 ] && [ "$NON_INTERACTIVE" -eq 1 ]; then
    if ! command -v curl >/dev/null 2>&1; then
        warn "curl is unavailable; non-interactive mode will not install packages."
        warn "LuCI connection tests and the data-plane watchdog will remain unavailable."
    fi
elif [ "$SKIP_CURL" -eq 0 ] && ! command -v curl >/dev/null 2>&1; then
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
CLIENT_BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/moein8668-git/aether-openwrt-client/${CLIENT_BRANCH}/files"
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

if [ -n "$PT_DIR" ] && [ -d "$PT_DIR" ]; then
    mkdir -p /usr/bin/pt || {
        error "Failed to create /usr/bin/pt for pluggable transports"
        exit 1
    }
    pt_installed=0
    for pt_src in "$PT_DIR"/*; do
        [ -f "$pt_src" ] || continue
        pt_name="${pt_src##*/}"
        cp -f "$pt_src" "/usr/bin/pt/$pt_name" &&
            chmod 755 "/usr/bin/pt/$pt_name" || {
            error "Failed to install /usr/bin/pt/$pt_name"
            exit 1
        }
        success "Installed /usr/bin/pt/$pt_name"
        pt_installed=1
    done
    [ "$pt_installed" -eq 1 ] || {
        error "pt/ directory was empty"
        exit 1
    }
elif [ -n "$PT_BINARY" ] && [ -f "$PT_BINARY" ]; then
    mkdir -p /usr/bin/pt || {
        error "Failed to create /usr/bin/pt for the Tor pluggable transport"
        exit 1
    }
    cp -f "$PT_BINARY" /usr/bin/pt/lyrebird &&
        chmod 755 /usr/bin/pt/lyrebird || {
        error "Failed to install /usr/bin/pt/lyrebird"
        exit 1
    }
    success "Installed /usr/bin/pt/lyrebird"
fi

if [ -n "$LICENSES_DIR" ] && [ -d "$LICENSES_DIR" ]; then
    rm -rf /usr/share/aether/LICENSES 2>/dev/null
    mkdir -p /usr/share/aether/LICENSES &&
        cp -f "$LICENSES_DIR"/* /usr/share/aether/LICENSES/ 2>/dev/null &&
        chmod 755 /usr/share/aether /usr/share/aether/LICENSES &&
        chmod 644 /usr/share/aether/LICENSES/* &&
        success "Installed third-party licences to /usr/share/aether/LICENSES" ||
        warn "Could not install third-party licences"
fi

if [ -f /etc/config/aether ] && [ "$FORCE_CONFIG" -eq 0 ]; then
    warn "Keeping existing /etc/config/aether"
    existing_perf="$(uci -q get aether.main.perf_profile 2>/dev/null)"
    if [ -z "$existing_perf" ]; then
        detected_perf="$(select_perf_profile)"
        uci set aether.main.perf_profile="$detected_perf" 2>/dev/null &&
            uci commit aether 2>/dev/null &&
            info "Initialized perf_profile = $detected_perf (auto-detected from RAM)"
    fi
    if ! uci -q show aether.main.exit_loc >/dev/null 2>&1; then
        uci set aether.main.exit_loc=!IR 2>/dev/null &&
            uci commit aether 2>/dev/null &&
            info "Initialized exit_loc = !IR (refuse Iranian WARP exits)"
    fi
    # Core v2.3 made --gool the modern WireGuard-inside-MASQUE transport. A
    # config written before that meant the classic WireGuard-in-WireGuard hop
    # pair, so keep it on classic; everything else starts on modern.
    if ! uci -q show aether.main.gool_mode >/dev/null 2>&1; then
        existing_proto="$(uci -q get aether.main.protocol 2>/dev/null)"
        existing_wiw="$(uci -q get aether.main.wiw_outer 2>/dev/null)$(uci -q get aether.main.wiw_inner 2>/dev/null)"
        if [ "$existing_proto" = "gool" ] || [ -n "$existing_wiw" ]; then
            new_gool_mode=classic
        else
            new_gool_mode=modern
        fi
        uci set aether.main.gool_mode=$new_gool_mode 2>/dev/null &&
            uci commit aether 2>/dev/null &&
            info "Initialized gool_mode = $new_gool_mode"
    fi
else
    install_staged "etc/config/aether" 600 || exit 1
    detected_perf="$(select_perf_profile)"
    uci set aether.main.perf_profile="$detected_perf" 2>/dev/null &&
        uci commit aether 2>/dev/null &&
        info "Configured perf_profile = $detected_perf (auto-detected from RAM)"
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
# Migrate: remove empty/invalid identity stubs left by older installers.
# *-lastconn.toml is the core's last-working-gateway cache and has no device_id
# by design; keep it so the first start after an upgrade can quick-reconnect.
for f in /etc/aether/*.toml; do
    [ -f "$f" ] || continue
    case "$f" in
        *-lastconn.toml) continue ;;
    esac
    if ! grep -q 'device_id' "$f" 2>/dev/null; then
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
