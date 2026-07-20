#!/usr/bin/env bash
# install_pydantic_core.sh
# Automated installer for pydantic-core on Android/Termux via GitHub Releases.
# Repo: https://github.com/troublescope/android-pydantic-core
#
# Usage:
#   ./install_pydantic_core.sh             # Install latest available version
#   ./install_pydantic_core.sh --latest     # Same as above (explicit)
#   ./install_pydantic_core.sh --list       # List all available versions
#   ./install_pydantic_core.sh 2.47.0       # Install specific version
#   ./install_pydantic_core.sh 2.23.4       # Install older version

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
DIM='\033[2m'
NC='\033[0m'

# --- PARSE ARGUMENTS ---
REQUESTED_VER=""
LIST_ONLY=false

case "$1" in
  --list|-l)
    LIST_ONLY=true
    ;;
  --latest|"")
    REQUESTED_VER=""
    ;;
  -h|--help)
    echo "Usage: install_pydantic_core.sh [options] [version]"
    echo ""
    echo "Options:"
    echo "  (no args)     Install latest available version (auto-detect)"
    echo "  --latest      Same as above"
    echo "  --list, -l    List all available versions and exit"
    echo "  2.47.0        Install specific version"
    echo "  -h, --help    Show this help"
    echo ""
    echo "Examples:"
    echo "  ./install_pydantic_core.sh             # Latest"
    echo "  ./install_pydantic_core.sh 2.23.4      # Specific version"
    echo "  ./install_pydantic_core.sh --list       # List all"
    exit 0
    ;;
  *)
    REQUESTED_VER="$1"
    ;;
esac

echo -e "${CYAN}${BOLD}>>> Android Pydantic-Core Installer <<<${NC}"
echo ""

# 1. Environment Check
echo -e "${YELLOW}[1/5] Checking Python environment...${NC}"
if ! command -v python3 >/dev/null 2>&1; then
  echo -e "${RED}❌ Error: Python 3 is not installed.${NC}"
  echo "   Please run: pkg install python"
  exit 1
fi

eval $(python3 -c "import sys; v=sys.version_info; print(f'PY_MAJOR={v.major} PY_MINOR={v.minor}')")
PY_VER_DOT="${PY_MAJOR}.${PY_MINOR}"
PY_TAG="cp${PY_MAJOR}${PY_MINOR}"

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

# 3. Fetch ALL releases from GitHub
echo -e "${YELLOW}[3/5] Fetching available releases...${NC}"
ALL_RELEASES_JSON=$(curl -s --retry 3 --retry-delay 5 \
  "https://api.github.com/repos/${REPO_USER}/${REPO_NAME}/releases?per_page=100")

if echo "$ALL_RELEASES_JSON" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
  RELEASE_COUNT=$(echo "$ALL_RELEASES_JSON" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
  echo -e "   ${GREEN}✓${NC} Found ${GREEN}${RELEASE_COUNT}${NC} release(s) on GitHub"
else
  echo -e "${RED}❌ Failed to fetch releases from GitHub.${NC}"
  exit 1
fi

# --- LIST MODE ---
if [ "$LIST_ONLY" = true ]; then
  echo ""
  echo -e "${CYAN}${BOLD}Available pydantic-core versions:${NC}"
  echo ""
  echo "$ALL_RELEASES_JSON" | python3 -c "
import sys, json

releases = json.load(sys.stdin)
py_tag = '${PY_TAG}'
plat_tag = '${PLAT_TAG}'

# Header
print(f'{\"Version\":<14} {\"Python Match\":<14} {\"Your Arch Match\":<16} Wheel File')
print(f'{\"─\"*14} {\"─\"*14} {\"─\"*16} {\"─\"*40}')

for rel in releases:
    tag = rel.get('tag_name', '?').lstrip('v')
    assets = rel.get('assets', [])

    has_py = False
    has_arch = False
    wheel_name = '—'

    for a in assets:
        name = a['name']
        if name.endswith('.whl'):
            if py_tag in name:
                has_py = True
                if plat_tag in name:
                    has_arch = True
                    wheel_name = name
                    break
                elif not has_py:
                    wheel_name = name

    # Find best wheel for display
    best = None
    for a in assets:
        name = a['name']
        if name.endswith('.whl') and py_tag in name:
            if plat_tag in name:
                best = name
                break
            best = best or name

    py_mark = '✅' if has_py else '❌'
    arch_mark = '✅' if has_arch else '❌'
    display = best or '(no wheel)'
    print(f'{tag:<14} {py_mark:<14} {arch_mark:<16} {display}')
"
  echo ""
  echo -e "${DIM}✅ = compatible with your Python ${PY_VER_DOT} (${PY_TAG}) and arch ${ARCH} (${PLAT_TAG})${NC}"
  echo -e "${DIM}Install with: ./install_pydantic_core.sh <version>${NC}"
  exit 0
fi

# 4. Check Current Installation
echo -e "${YELLOW}[4/5] Checking current installation...${NC}"
CURRENT_VER=""
if python3 -c "import pydantic_core" 2>/dev/null; then
  CURRENT_VER=$(python3 -c "import pydantic_core; print(pydantic_core.__version__)" 2>/dev/null || echo "")
  if [ -n "$CURRENT_VER" ]; then
    echo -e "   ${GREEN}✓${NC} Currently installed: ${GREEN}${CURRENT_VER}${NC}"
  fi
else
  echo -e "   ${YELLOW}⚠${NC} pydantic-core not installed yet."
fi

# 5. Find Compatible Wheel
echo -e "${YELLOW}[5/5] Finding compatible wheel...${NC}"

if [ -n "$REQUESTED_VER" ]; then
  echo -e "   Looking for version ${GREEN}${REQUESTED_VER}${NC}..."
  SEARCH_VER="$REQUESTED_VER"
else
  echo -e "   Looking for latest version..."
  SEARCH_VER=""
fi

# Search across ALL releases (not just latest) for a compatible wheel
FIND_SCRIPT="
import sys, json

releases = json.load(sys.stdin)
py_tag = '${PY_TAG}'
plat_tag = '${PLAT_TAG}'
requested = '${REQUESTED_VER}'

# Filter releases by requested version if specified
if requested:
    # Match version (strip 'v' prefix)
    matching = []
    for rel in releases:
        tag = rel.get('tag_name', '').lstrip('v')
        if tag == requested:
            matching.append(rel)
    if not matching:
        # Try partial match
        for rel in releases:
            tag = rel.get('tag_name', '').lstrip('v')
            if tag.startswith(requested):
                matching.append(rel)
    if not matching:
        print(f'ERROR: Version {requested} not found in any release', file=sys.stderr)
        sys.exit(1)
    releases = matching
# else: search all releases, latest first (API returns newest first)

# Search for wheel: exact plat_tag match first, then fallback
for release in releases:
    tag = release.get('tag_name', '').lstrip('v')
    assets = release.get('assets', [])

    # Priority 1: exact python tag + exact platform tag
    for a in assets:
        name = a['name']
        if name.endswith('.whl') and py_tag in name and plat_tag in name:
            print(a['browser_download_url'])
            print(name)
            print(tag)
            sys.exit(0)

    # Priority 2: exact python tag + android tag matching arch
    for a in assets:
        name = a['name']
        if name.endswith('.whl') and py_tag in name and 'android' in name:
            if ('aarch64' in plat_tag and 'arm64' in name) or \
               ('armv7' in plat_tag and 'armv7' in name) or \
               ('x86_64' in plat_tag and 'x86_64' in name) or \
               ('i686' in plat_tag and 'x86' in name and '64' not in name):
                print(a['browser_download_url'])
                print(name)
                print(tag)
                sys.exit(0)

    # Priority 3: exact python tag + any platform (last resort)
    for a in assets:
        name = a['name']
        if name.endswith('.whl') and py_tag in name:
            print(a['browser_download_url'])
            print(name)
            print(tag)
            sys.exit(0)

# No wheel found in any release
print('ERROR: No compatible wheel found', file=sys.stderr)
sys.exit(1)
"

set +e
RESULT=$(echo "$ALL_RELEASES_JSON" | python3 -c "$FIND_SCRIPT" 2>&1)
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ] || [ -z "$(echo "$RESULT" | head -n1)" ]; then
  echo -e "${RED}❌ No compatible wheel found.${NC}"
  echo ""

  # Show what's available
  if [ -n "$REQUESTED_VER" ]; then
    echo "   Version ${REQUESTED_VER} either doesn't exist or has no wheel for:"
  else
    echo "   No release has a wheel for:"
  fi
  echo "   Python: $PY_VER_DOT ($PY_TAG)"
  echo "   Arch:   $ARCH ($PLAT_TAG)"
  echo ""
  echo -e "${CYAN}Available versions:${NC}"
  echo "$ALL_RELEASES_JSON" | python3 -c "
import sys, json
releases = json.load(sys.stdin)
for rel in releases:
    tag = rel.get('tag_name', '?')
    assets = [a['name'] for a in rel.get('assets', []) if a['name'].endswith('.whl')]
    py_wheels = [w for w in assets if '${PY_TAG}' in w]
    marker = '✅' if py_wheels else '❌'
    print(f'   {marker} {tag}  ({len(py_wheels)} wheel(s) for ${PY_TAG})' if py_wheels else f'   {marker} {tag}  (no ${PY_TAG} wheels)')
" 2>/dev/null || echo "   (Could not list releases)"

  echo ""
  echo -e "   Run ${CYAN}./install_pydantic_core.sh --list${NC} to see all available versions."
  echo -e "   Supported Python versions: 3.9 - 3.14"
  echo ""
  echo -e "   ${YELLOW}If your Python version is not listed, the build may still be in progress.${NC}"
  echo -e "   ${YELLOW}Try again later, or install a supported Python:${NC}"
  echo -e "     pkg install python3.13"
  exit 1
fi

DOWNLOAD_URL=$(echo "$RESULT" | head -n1)
FILENAME=$(echo "$RESULT" | sed -n '2p')
FOUND_VER=$(echo "$RESULT" | sed -n '3p')

echo -e "   ${GREEN}✓${NC} Found: ${GREEN}${FILENAME}${NC}"
echo -e "   ${DIM}Version: ${FOUND_VER}${NC}"

# Check if already up-to-date
if [ -n "$CURRENT_VER" ] && [ -n "$FOUND_VER" ] && [ "$CURRENT_VER" = "$FOUND_VER" ] && [ -z "$REQUESTED_VER" ]; then
  echo ""
  echo -e "${GREEN}✅ Already up to date! (v${CURRENT_VER})${NC}"
  echo -e "   No update needed."
  exit 0
fi

if [ -n "$CURRENT_VER" ] && [ -n "$FOUND_VER" ]; then
  if [ "$CURRENT_VER" = "$FOUND_VER" ]; then
    echo -e "   ${YELLOW}ℹ${NC} Reinstalling same version: ${CURRENT_VER}"
  else
    echo -e "   ${YELLOW}ℹ${NC} Update: ${CURRENT_VER} → ${FOUND_VER}"
  fi
fi

# Download and Install
echo ""
echo -e "${CYAN}${BOLD}Downloading and installing...${NC}"

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

echo -e "   Downloading..."
if ! curl -fL -o "$TMPDIR/$FILENAME" "$DOWNLOAD_URL" --progress-bar 2>&1; then
  echo ""
  echo -e "${RED}❌ Download failed.${NC}"
  exit 1
fi

echo ""
echo -e "   ${YELLOW}Installing wheel with pip...${NC}"

# Try install with original platform tag first
if pip install "$TMPDIR/$FILENAME" 2>&1; then
  echo ""
  echo -e "${GREEN}${BOLD}✅ Success! Installed: ${FILENAME}${NC}"
  if python3 -c "import pydantic_core; print(f'   Verified: pydantic_core v{pydantic_core.__version__}')" 2>/dev/null; then
    echo ""
    echo -e "${CYAN}${BOLD}>>> Installation complete! <<<${NC}"
  fi
  exit 0
fi

# Fallback: try with android platform tags
echo -e "   ${YELLOW}⚠ Direct install failed. Trying android platform tags...${NC}"
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
    if python3 -c "import pydantic_core; print(f'   Verified: pydantic_core v{pydantic_core.__version__}')" 2>/dev/null; then
      echo ""
      echo -e "${CYAN}${BOLD}>>> Installation complete! <<<${NC}"
    fi
    exit 0
  fi
fi

echo -e "${RED}❌ Pip install failed.${NC}"
echo ""
echo "   You can try manually:"
echo "   pip install --no-deps $TMPDIR/$FILENAME"
exit 1