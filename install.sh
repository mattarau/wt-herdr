#!/usr/bin/env sh
# wt-herdr installer — worktrunk ↔ herdr bridge
# Usage: curl -fsSL https://raw.githubusercontent.com/mattarau/wt-herdr/main/install.sh | sh

set -eu

REPO="mattarau/wt-herdr"
SOURCE_URL="https://raw.githubusercontent.com/$REPO/main/wt-herdr"
BIN_NAME="wt-herdr"

# Detect install directory
if [ -n "${PREFIX:-}" ]; then
  INSTALL_DIR="$PREFIX/bin"
elif [ -n "${HOMEBREW_PREFIX:-}" ]; then
  INSTALL_DIR="$HOMEBREW_PREFIX/bin"
elif [ -d "/usr/local/bin" ]; then
  INSTALL_DIR="/usr/local/bin"
else
  INSTALL_DIR="$HOME/.local/bin"
fi

# Ensure target dir exists
mkdir -p "$INSTALL_DIR" 2>/dev/null || true
if [ ! -d "$INSTALL_DIR" ] || [ ! -w "$INSTALL_DIR" ]; then
  echo "Error: cannot write to $INSTALL_DIR"
  echo "Try: curl -fsSL $SOURCE_URL | sudo sh"
  echo "  or: PREFIX=~/.local $0"
  exit 1
fi

echo "Downloading $BIN_NAME to $INSTALL_DIR/$BIN_NAME ..."
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$SOURCE_URL" -o "$INSTALL_DIR/$BIN_NAME"
elif command -v wget >/dev/null 2>&1; then
  wget -q "$SOURCE_URL" -O "$INSTALL_DIR/$BIN_NAME"
else
  echo "Error: need curl or wget"
  exit 1
fi

chmod +x "$INSTALL_DIR/$BIN_NAME"

echo ""
echo "Installed! Run:"
echo "  wt herdr health    # verify dependencies"
echo "  wt herdr init      # set up hooks in a repo"
echo ""
echo "Make sure $INSTALL_DIR is on your PATH."
