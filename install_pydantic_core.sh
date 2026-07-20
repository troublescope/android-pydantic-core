#!/usr/bin/env bash
# install_pydantic_core.sh
# Automated installer for pydantic-core on Android/Termux via GitHub Releases.
# Repo: https://github.com/troublescope/android-pydantic-core

set -e

# --- CONFIGURATION ---
REPO_USER="troublescope"
REPO_NAME="android-pydantic-core"

# --- COLORS ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${CYAN}${BOLD}>>> Android Pydantic-Core Installer <<<${NC}"
echo ""

# 1. Environment Check
echo -e "${YELLOW}[1/5] Checking Python environment...${NC}"
if ! command -v python3 >/dev/null 2>&1; then
  echo -e "${RED}❌ Error: Python 3 is not installed.${NC}"
  echo "   Please run: pkg install python"
  exit 1
fi

# Extract version info using Python itself for reliability
eval $(python3 -c "import sys; v=sys.version_info; print(f'PY_MAJOR={v.major} PY_MINOR={v.minor}')")
PY_VER_DOT="${PY_MAJOR}.${PY_MINOR}"  # e.g. 3.12
PY_TAG="cp${PY_MAJOR}${PY_MINOR}"     # e.g. cp312

# Check minimum supported version (3.9+)
if [ "$PY_MAJOR" -lt 3 ] || { [ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -lt 9 ]; }; then
  echo -e "${RED}❌ Error: This installer requires Python 3.9 or higher.${NC}"
  echo -e "   Current version: $PY_VER_DOT"
  exit 1
fi

echo -e "   ${GREEN}✓${NC} Python: ${GREEN}${PY_VER_DOT}${NC} (${PY_TAG})"

# 2. Architecture Detection
echo -e "${YELLOW}[2/5] Detecting architecture...${NC}"
ARCH=$(uname -m)
case "$ARCH" in
  aarch64)       PLAT_TAG="linux_aarch64" ;;
  armv7l|armv8l) PLAT_TAG="linux_armv7l" ;;
  x86_64)       PLAT_TAG="linux_x86_64" ;;
  i686|i386)    PLAT_TAG="linux_i686" ;;
  *)
    echo -e "${RED}❌ Error: Unsupported architecture ($ARCH).${NC}"
    exit 1
    ;;
esac

echo -e "   ${GREEN}✓${NC} Arch: ${GREEN}${ARCH}${NC} → Wheels matching: ${PLAT_TAG}"

# 3. Check Current Installed Version
echo -e "${YELLOW}[3/5] Checking current installation...${NC}"
CURRENT_VER=""
if python3 -c "import pydantic_core" 2>/dev/null; then
  CURRENT_VER=$(python3 -c "import pydantic_core; print(pydantic_core.__version__)" 2>/dev/null || echo "")
  if [ -n "$CURRENT_VER" ]; then
    echo -e "   ${GREEN}✓${NC} Currently installed: ${GREEN}${CURRENT_VER}${NC}"
  fi
else
  echo -e "   ${YELLOW}⚠${NC} pydantic-core not installed yet."
fi

# 4. Fetch Latest Release URL
echo -e "${YELLOW}[4/5] Finding latest compatible wheel...${NC}"

API_URL="https://api.github.com/repos/${REPO_USER}/${REPO_NAME}/releases/latest"
echo -e "   Querying GitHub API for latest release..."
JSON_RESPONSE=$(curl -s --retry 3 --retry-delay 5 "$API_URL")

# Parse JSON with Python to find the right wheel
READ_PYTHON_SCRIPT="
import sys, json
try:
    data = json.load(sys.stdin)
    if 'assets' not in data:
        print('ERROR: No assets in release', file=sys.stderr)
        sys.exit(1)

    py_tag = '${PY_TAG}'
    plat_tag = '${PLAT_TAG}'

    # Try to find a modern android tag first (e.g., android_arm64_v8a)
    for asset in data['assets']:
        name = asset['name']
        if py_tag in name and 'android' in name and name.endswith('.whl'):
            if ('aarch64' in plat_tag and 'arm64' in name) or \
               ('armv7' in plat_tag and 'armv7' in name) or \
               ('x86_64' in plat_tag and 'x86_64' in name) or \
               ('i686' in plat_tag and 'x86' in name and '64' not in name):
                print(asset['browser_download_url'])
                print(asset['name'])
                sys.exit(0)

    # Fallback to the explicit plat_tag (linux_aarch64, etc.)
    for asset in data['assets']:
        name = asset['name']
        if py_tag in name and plat_tag in name and name.endswith('.whl'):
            print(asset['browser_download_url'])
            print(asset['name'])
            sys.exit(0)

    # Last resort: any wheel matching the python tag
    for asset in data['assets']:
        name = asset['name']
        if py_tag in name and name.endswith('.whl'):
            print(asset['browser_download_url'])
            print(asset['name'])
            sys.exit(0)

    print('ERROR: No compatible wheel found', file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
"

set +e
RESULT=$(echo "$JSON_RESPONSE" | python3 -c "$READ_PYTHON_SCRIPT" 2>&1)
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ] || [ -z "$(echo "$RESULT" | head -n1)" ]; then
    echo -e "${RED}❌ Error: No compatible wheel found in the latest release.${NC}"
    echo "   Make sure a release exists for Python $PY_VER_DOT on $ARCH."
    echo ""
    echo "   Available assets in latest release:"
    echo "$JSON_RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for a in data.get('assets', []):
        print(f'   - {a[\"name\"]}')
except:
    print('   (Could not parse release info)')
" 2>/dev/null || true
    echo ""
    echo "   Supported Python versions: 3.9 - 3.14"
    echo "   Your Python: $PY_VER_DOT ($PY_TAG)"
    echo ""
    echo "   If your Python version is not listed, the build may still be in progress."
    echo "   Try again later, or install a supported Python version:"
    echo "     pkg install python3.13"
    exit 1
fi

DOWNLOAD_URL=$(echo "$RESULT" | head -n 1)
FILENAME=$(echo "$RESULT" | tail -n 1)

# Extract version from filename for comparison
REMOTE_VER=$(echo "$FILENAME" | grep -oP 'pydantic_core-\K[0-9]+\.[0-9]+\.[0-9]+' || echo "")

echo -e "   ${GREEN}✓${NC} Found: ${GREEN}${FILENAME}${NC}"

# Check if update is needed
if [ -n "$CURRENT_VER" ] && [ -n "$REMOTE_VER" ] && [ "$CURRENT_VER" = "$REMOTE_VER" ]; then
  echo ""
  echo -e "${GREEN}✅ Already up to date! (v${CURRENT_VER})${NC}"
  echo -e "   No update needed."
  exit 0
fi

if [ -n "$CURRENT_VER" ] && [ -n "$REMOTE_VER" ]; then
  echo -e "   ${YELLOW}ℹ${NC} Update available: ${CURRENT_VER} → ${REMOTE_VER}"
fi

# 5. Download and Install
echo -e "${YELLOW}[5/5] Downloading and installing...${NC}"

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

echo -e "   Downloading to temp dir..."
if curl -fL -o "$TMPDIR/$FILENAME" "$DOWNLOAD_URL" --progress-bar 2>&1; then
  echo ""
  echo -e "   ${YELLOW}Installing wheel with pip...${NC}"

  # Install using pip
  if pip install "$TMPDIR/$FILENAME" 2>&1; then
      echo ""
      echo -e "${GREEN}${BOLD}✅ Success! Installed: ${FILENAME}${NC}"

      # Verify installation
      if python3 -c "import pydantic_core; print(f'   Verified: pydantic_core v{pydantic_core.__version__}')" 2>/dev/null; then
          echo ""
          echo -e "${CYAN}${BOLD}>>> Installation complete! <<<${NC}"
      fi
  else
      echo -e "${YELLOW}⚠ Pip install failed. Trying alternative platform tags...${NC}"
      # Rename to android tags and retry
      if [[ "$FILENAME" == *"linux_"* ]]; then
          NEW_FILENAME=$(echo "$FILENAME" | \
            sed -e 's/linux_aarch64/android_arm64_v8a/' \
                -e 's/linux_armv7l/android_armv7/' \
                -e 's/linux_x86_64/android_x86_64/' \
                -e 's/linux_i686/android_x86/')
          cp "$TMPDIR/$FILENAME" "$TMPDIR/$NEW_FILENAME"
          if pip install "$TMPDIR/$NEW_FILENAME" 2>&1; then
              echo ""
              echo -e "${GREEN}${BOLD}✅ Success! Installed: ${NEW_FILENAME}${NC}"
              exit 0
          fi
      fi
      echo -e "${RED}❌ Pip install failed.${NC}"
      echo ""
      echo "   You can try manually:"
      echo "   pip install --no-deps $TMPDIR/$FILENAME"
      exit 1
  fi
else
  echo ""
  echo -e "${RED}❌ Download failed.${NC}"
  exit 1
fi