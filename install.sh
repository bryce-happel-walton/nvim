#!/bin/sh
# One-step setup for this Neovim config.
#
#   curl -fsSL https://raw.githubusercontent.com/bryce-happel-walton/nvim/main/install.sh | sh
#   or, from a clone:  ./install.sh
#
# Needs Neovim 0.12+ and Rust. Installs everything else: the config, rust-analyzer,
# rustfmt, ripgrep, the tree-sitter CLI, a Nerd Font, plugins and tree-sitter parsers.
# Safe to run again to repair or update.
set -eu

REPO_URL="https://github.com/bryce-happel-walton/nvim.git"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
CARGO_BIN="${CARGO_HOME:-$HOME/.cargo}/bin"
TREE_SITTER_MIN="0.26.1"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"
OS=$(uname -s)
USER_PATH=$PATH
PATH="$CARGO_BIN:$PATH"
export PATH

if [ -t 1 ]; then
  BOLD=$(printf '\033[1m') GREEN=$(printf '\033[32m') YELLOW=$(printf '\033[33m') RED=$(printf '\033[31m') RESET=$(printf '\033[0m')
else
  BOLD="" GREEN="" YELLOW="" RED="" RESET=""
fi
WARNINGS=0
FAILED=0
NOTES=""

step() { printf '\n%s==> %s%s\n' "$BOLD" "$1" "$RESET"; }
ok() { printf '  %s✓%s %s\n' "$GREEN" "$RESET" "$1"; }
say() { printf '  %s\n' "$1"; }
warn() { printf '  %s!%s %s\n' "$YELLOW" "$RESET" "$1"; WARNINGS=$((WARNINGS + 1)); }
die() { printf '\n%sError:%s %s\n' "$RED" "$RESET" "$1" >&2; exit 1; }
note() { NOTES="$NOTES
  - $1"; }
has() { command -v "$1" >/dev/null 2>&1; }

# version_ge A B: succeeds if dotted version A >= B.
version_ge() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    n = split(a, x, "."); m = split(b, y, ".")
    for (i = 1; i <= (n > m ? n : m); i++) {
      if (x[i] + 0 > y[i] + 0) exit 0
      if (x[i] + 0 < y[i] + 0) exit 1
    }
    exit 0
  }'
}

main() {
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT
  trap 'exit 130' INT TERM

  ###############################################################################
  step "Checking what you have"

  has nvim || die "Neovim not found. Install Neovim 0.12 or newer: https://github.com/neovim/neovim/releases"
  NVIM_VERSION=$(nvim --version | sed -n '1s/^NVIM v\([0-9][0-9.]*\).*/\1/p')
  version_ge "${NVIM_VERSION:-0}" 0.12.0 || die "Neovim ${NVIM_VERSION:-?} is too old. Install 0.12 or newer."
  ok "Neovim $NVIM_VERSION"

  has cargo || die "Rust not found. Install it from https://rustup.rs, open a new terminal and run this again."
  ok "Rust $(cargo --version | cut -d' ' -f2)"

  missing=""
  for tool in git curl tar cc; do
    has "$tool" || missing="$missing $tool"
  done
  if [ -n "$missing" ]; then
    if [ "$OS" = Darwin ]; then
      die "Missing:$missing. Install Apple's command line tools with: xcode-select --install"
    fi
    die "Missing:$missing. Install them with your package manager (for example: sudo apt install git curl tar build-essential)."
  fi
  ok "git, curl, tar and a C compiler"

  ###############################################################################
  step "Putting the config in $CONFIG_DIR"

  # The folder this script is in, when it's run from a file (not piped from curl).
  SRC_DIR=""
  case $0 in
    *install.sh) SRC_DIR=$(cd "$(dirname "$0")" && pwd -P) ;;
  esac
  [ -n "$SRC_DIR" ] && [ ! -f "$SRC_DIR/lua/config/bootstrap.lua" ] && SRC_DIR=""

  backup_config() {
    if [ -e "$CONFIG_DIR" ] || [ -L "$CONFIG_DIR" ]; then
      bak="$CONFIG_DIR.bak.$(date +%Y%m%d-%H%M%S)"
      mv "$CONFIG_DIR" "$bak"
      say "Moved your old config to $bak"
      note "Your old config is saved in $bak"
    fi
    mkdir -p "$(dirname "$CONFIG_DIR")"
  }

  if [ -n "$SRC_DIR" ]; then
    if [ "$(cd "$CONFIG_DIR" 2>/dev/null && pwd -P)" = "$SRC_DIR" ]; then
      ok "Already there"
    else
      backup_config
      ln -s "$SRC_DIR" "$CONFIG_DIR"
      ok "Linked to $SRC_DIR"
    fi
  elif [ -d "$CONFIG_DIR/.git" ] && git -C "$CONFIG_DIR" remote get-url origin 2>/dev/null | grep -q 'bryce-happel-walton/nvim'; then
    if git -C "$CONFIG_DIR" pull --ff-only --quiet; then
      ok "Updated to the latest version"
    else
      warn "Couldn't update $CONFIG_DIR (it has local changes?), so using it as it is"
    fi
  else
    backup_config
    git clone --quiet "$REPO_URL" "$CONFIG_DIR"
    ok "Downloaded"
  fi

  ###############################################################################
  step "Installing tools"

  if has rustup; then
    if out=$(rustup component add rust-analyzer rustfmt 2>&1); then
      ok "rust-analyzer and rustfmt"
    else
      warn "rustup couldn't add rust-analyzer and rustfmt:"
      printf '%s\n' "$out" | sed 's/^/      /'
    fi
  elif has rust-analyzer && has rustfmt; then
    ok "rust-analyzer and rustfmt"
  else
    warn "rustup not found, so rust-analyzer and rustfmt weren't installed. Install them with your package manager."
  fi

  if has rg; then
    ok "ripgrep"
  elif has brew && brew install ripgrep >/dev/null 2>&1; then
    ok "ripgrep"
  else
    say "Building ripgrep (about a minute)..."
    if cargo install --locked --quiet ripgrep; then ok "ripgrep"; else warn "ripgrep failed to install (search won't work)"; fi
  fi

  ts_version() { tree-sitter --version 2>/dev/null | awk '{ print $2 }'; }
  if has tree-sitter && version_ge "$(ts_version)" "$TREE_SITTER_MIN"; then
    ok "tree-sitter CLI $(ts_version)"
  else
    say "Building the tree-sitter CLI (a few minutes)..."
    if cargo install --locked --quiet tree-sitter-cli; then
      ok "tree-sitter CLI $(ts_version)"
    else
      warn "tree-sitter CLI failed to install (syntax highlighting falls back to the basic version)"
    fi
  fi
  # An older tree-sitter earlier on your PATH would be used instead of the new one.
  user_ts=$(PATH=$USER_PATH; command -v tree-sitter 2>/dev/null || true)
  if [ -n "$user_ts" ] && ! version_ge "$("$user_ts" --version 2>/dev/null | awk '{ print $2 }')" "$TREE_SITTER_MIN"; then
    warn "An old tree-sitter at $user_ts comes first on your PATH. Remove it so $CARGO_BIN/tree-sitter is used."
  fi

  ###############################################################################
  step "Installing a Nerd Font (for icons)"

  font_installed() {
    if [ "$OS" = Darwin ]; then
      find "$HOME/Library/Fonts" /Library/Fonts -maxdepth 1 -iname '*nerd*' 2>/dev/null | grep -q .
    elif has fc-list; then
      fc-list : family 2>/dev/null | grep -qi 'nerd font'
    else
      find "${XDG_DATA_HOME:-$HOME/.local/share}/fonts" "$HOME/.fonts" -iname '*nerd*' 2>/dev/null | grep -q .
    fi
  }

  install_font() {
    if [ "$OS" = Darwin ]; then
      font_dir="$HOME/Library/Fonts"
    else
      font_dir="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/HackNerdFont"
    fi
    if [ "$OS" = Darwin ] || has xz; then
      curl -fsSL -o "$TMP/font.tar.xz" "$FONT_URL/Hack.tar.xz" &&
        tar -xJf "$TMP/font.tar.xz" -C "$TMP" || return 1
    elif has unzip; then
      curl -fsSL -o "$TMP/font.zip" "$FONT_URL/Hack.zip" &&
        unzip -qo "$TMP/font.zip" -d "$TMP" || return 1
    else
      return 1
    fi
    mkdir -p "$font_dir" && cp "$TMP"/HackNerdFont-*.ttf "$font_dir"/ || return 1
    if has fc-cache; then fc-cache -f "$font_dir" >/dev/null 2>&1 || true; fi
  }

  if font_installed; then
    ok "You already have one"
  elif install_font; then
    ok "Hack Nerd Font"
    note "Set your terminal's font to \"Hack Nerd Font\" so icons show up."
  else
    warn "Couldn't install the font. Get one from https://www.nerdfonts.com and set it as your terminal's font."
  fi

  ###############################################################################
  step "Installing plugins, parsers and plugin binaries"
  say "Installing plugins..."

  if nvim --headless "+lua require('config.bootstrap').run()" </dev/null 2>"$TMP/nvim.log"; then
    ok "Done"
  else
    FAILED=1
    tail -n 15 "$TMP/nvim.log" | awk '{ print "      " $0 }'
    warn "Some of this didn't install (see above). Run this script again to retry."
  fi

  ###############################################################################
  case ${TERM_PROGRAM:-} in
    Apple_Terminal)
      note "macOS Terminal can't send shortcuts like Ctrl+Shift+O or Ctrl+Tab. Use Ghostty, kitty, WezTerm or iTerm2." ;;
    iTerm.app)
      note "In iTerm2, turn on Settings > Profiles > Keys > \"Report keys using CSI u\" so every shortcut works." ;;
    vscode)
      note "VS Code's built-in terminal keeps many shortcuts for itself. Run nvim in a standalone terminal." ;;
  esac
  case ":$USER_PATH:" in
    *":$CARGO_BIN:"*) ;;
    *) note "$CARGO_BIN isn't on your PATH. Neovim still finds its tools, but add it to use them in your shell." ;;
  esac

  if [ "$FAILED" -eq 0 ]; then
    step "All set. Start Neovim with: nvim"
  else
    step "Finished with problems"
  fi
  [ -n "$NOTES" ] && printf '%s\n' "$NOTES"
  [ "$WARNINGS" -gt 0 ] && printf '\n  %s%s warning(s) above.%s\n' "$YELLOW" "$WARNINGS" "$RESET"
  exit "$FAILED"
}

# Everything runs from main, so `curl ... | sh` reads the whole script before starting.
main "$@"
