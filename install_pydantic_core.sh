#!/data/data/com.termux/files/usr/bin/bash

set -euo pipefail

REPO="troublescope/android-pydantic-core"
PACKAGE="pydantic-core"
TMPDIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TMPDIR"
}

trap cleanup EXIT

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
NC="\033[0m"

echo
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  pydantic-core Android Installer${NC}"
echo -e "${CYAN}========================================${NC}"
echo

if ! command -v python >/dev/null 2>&1; then
    echo -e "${RED}❌ Python is not installed${NC}"
    exit 1
fi

if ! command -v pip >/dev/null 2>&1; then
    echo -e "${RED}❌ pip is not installed${NC}"
    exit 1
fi

PYTHON_VERSION="$(
    python -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")'
)"

PYTHON_TAG="$(
    python -c '
import sys
print(f"cp{sys.version_info.major}{sys.version_info.minor}")
'
)"

MACHINE="$(uname -m)"

case "$MACHINE" in
    aarch64|arm64)
        ARCH="arm64-v8a"
        PLATFORM="android_24_arm64_v8a"
        ;;

    armv7l|armv8l)
        ARCH="armeabi-v7a"
        PLATFORM="android_24_armeabi_v7a"
        ;;

    *)
        echo -e "${RED}❌ Unsupported architecture: $MACHINE${NC}"
        echo
        echo "Supported:"
        echo "  aarch64"
        echo "  armv7l"
        exit 1
        ;;
esac

case "$PYTHON_VERSION" in
    3.9|3.10|3.11|3.12|3.13|3.14)
        ;;
    *)
        echo -e "${RED}❌ Unsupported Python version: $PYTHON_VERSION${NC}"
        echo
        echo "Supported:"
        echo "  Python 3.9"
        echo "  Python 3.10"
        echo "  Python 3.11"
        echo "  Python 3.12"
        echo "  Python 3.13"
        echo "  Python 3.14"
        exit 1
        ;;
esac

if [[ $# -ge 1 && -n "${1:-}" ]]; then
    VERSION="$1"
else
    echo "Fetching latest release..."

    VERSION="$(
        curl -fsSL \
            --retry 5 \
            --retry-delay 5 \
            --connect-timeout 30 \
            "https://api.github.com/repos/${REPO}/releases/latest" |
        python -c '
import json
import sys

data = json.load(sys.stdin)
tag = data.get("tag_name", "")

if not tag:
    raise SystemExit("Unable to determine latest release")

print(tag.lstrip("v"))
'
    )"
fi

if [[ -z "$VERSION" ]]; then
    echo -e "${RED}❌ Could not determine version${NC}"
    exit 1
fi

FILENAME="${PACKAGE//-/_}-${VERSION}-${PYTHON_TAG}-${PYTHON_TAG}-${PLATFORM}.whl"

DOWNLOAD_URL="https://github.com/${REPO}/releases/download/v${VERSION}/${FILENAME}"

echo "Python:      $PYTHON_VERSION"
echo "Python tag:  $PYTHON_TAG"
echo "Architecture: $MACHINE"
echo "Android ABI: $ARCH"
echo "Platform:    $PLATFORM"
echo "Version:     $VERSION"
echo
echo "Wheel:"
echo "  $FILENAME"
echo

WHEEL="$TMPDIR/$FILENAME"

echo -e "${YELLOW}Downloading...${NC}"

if ! curl -fL \
    --retry 5 \
    --retry-delay 5 \
    --connect-timeout 30 \
    "$DOWNLOAD_URL" \
    -o "$WHEEL"; then

    echo
    echo -e "${RED}❌ Failed to download wheel${NC}"
    echo
    echo "URL:"
    echo "$DOWNLOAD_URL"
    exit 1
fi

if [[ ! -s "$WHEEL" ]]; then
    echo -e "${RED}❌ Downloaded wheel is empty${NC}"
    exit 1
fi

echo
echo -e "${GREEN}✓ Download complete${NC}"

echo
echo "Wheel information:"
echo "  $(basename "$WHEEL")"
echo "  $(du -h "$WHEEL" | awk '{print $1}')"

echo
echo -e "${YELLOW}Installing wheel with pip...${NC}"

if python -m pip install \
    --no-deps \
    --force-reinstall \
    "$WHEEL"; then

    echo
    echo -e "${GREEN}✓ Installation successful${NC}"
else
    echo
    echo -e "${RED}❌ Pip installation failed${NC}"
    echo
    echo "Wheel:"
    echo "$WHEEL"
    echo
    echo "Try manually:"
    echo "python -m pip install --no-deps --force-reinstall \"$WHEEL\""
    exit 1
fi

echo
echo -e "${YELLOW}Verifying installation...${NC}"

INSTALLED_VERSION="$(
    python -c '
import pydantic_core
print(pydantic_core.__version__)
' 2>/dev/null || true
)"

if [[ "$INSTALLED_VERSION" == "$VERSION" ]]; then
    echo -e "${GREEN}✓ pydantic-core $INSTALLED_VERSION installed successfully${NC}"
else
    echo -e "${RED}❌ Installation verification failed${NC}"

    if [[ -n "$INSTALLED_VERSION" ]]; then
        echo "Installed version: $INSTALLED_VERSION"
        echo "Expected version:  $VERSION"
    fi

    exit 1
fi

echo
echo -e "${GREEN}Done.${NC}"
echo
