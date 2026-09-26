#!/bin/sh
# One-step setup for this Neovim config.
#
#   curl -fsSL https://raw.githubusercontent.com/bryce-happel-walton/nvim/main/install.sh | sh
#   or, from a clone:  ./install.sh
#
# Needs Neovim 0.12+ and Rust (rustup). Installs everything else: the config, the nv
# command, rust-analyzer, rustfmt, ripgrep, the tree-sitter CLI, a Nerd Font, plugins
# and tree-sitter parsers. Safe to run again to repair or update.
#
# `install.sh --server` is what nv runs on SSH hosts: the config is already there, Rust
# and a C compiler are optional, and there's no font.
set -eu

SERVER=0
[ "${1:-}" = "--server" ] && SERVER=1

REPO_URL="https://github.com/bryce-happel-walton/nvim.git"
APPNAME=${NVIM_APPNAME:-nvim}
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/$APPNAME"
TOOLS_BIN="${XDG_DATA_HOME:-$HOME/.local/share}/$APPNAME/bin" # Neovim adds this to its PATH
CARGO_BIN="${CARGO_HOME:-$HOME/.cargo}/bin"
TREE_SITTER_MIN="0.26.1"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"
OS=$(uname -s)
ARCH=$(uname -m)
USER_PATH=$PATH
PATH="$TOOLS_BIN:$CARGO_BIN:$PATH"
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

  RUST=0
  if has rustup && cargo --version >/dev/null 2>&1; then
    RUST=1
    ok "Rust $(cargo --version | cut -d' ' -f2)"
  elif [ "$SERVER" -eq 1 ]; then
    say "No Rust here, so no rust-analyzer. Install Rust with https://rustup.rs to get it."
  elif has rustup; then
    die "rustup has no default Rust toolchain. Run: rustup default stable"
  else
    die "Rust (rustup) not found. Install it from https://rustup.rs, open a new terminal and run this again."
  fi

  missing=""
  for tool in git curl tar; do
    has "$tool" || missing="$missing $tool"
  done
  if ! has cc; then
    if [ "$SERVER" -eq 1 ]; then
      say "No C compiler here, so syntax highlighting uses the basic version."
    else
      missing="$missing cc"
    fi
  fi
  if [ -n "$missing" ]; then
    if [ "$OS" = Darwin ]; then
      die "Missing:$missing. Install Apple's command line tools with: xcode-select --install"
    fi
    die "Missing:$missing. Install them with your package manager (for example: sudo apt install git curl tar build-essential)."
  fi
  if has cc; then ok "git, curl, tar and a C compiler"; else ok "git, curl and tar"; fi

  ###############################################################################
  if [ "$SERVER" -eq 1 ]; then
    [ -f "$CONFIG_DIR/lua/config/bootstrap.lua" ] || die "No config in $CONFIG_DIR."
  else
    step "Putting the config in $CONFIG_DIR"

    # The folder this script is in, when it's run from a file (not piped from curl).
    SRC_DIR=""
    case $0 in
      *install.sh) SRC_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P) ;;
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
      if [ "$(CDPATH='' cd -- "$CONFIG_DIR" 2>/dev/null && pwd -P)" = "$SRC_DIR" ]; then
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
  fi

  ###############################################################################
  step "Installing tools"

  if [ "$RUST" -eq 1 ]; then
    if out=$(rustup component add rust-analyzer rustfmt 2>&1); then
      ok "rust-analyzer and rustfmt"
    else
      warn "rustup couldn't add rust-analyzer and rustfmt:"
      printf '%s\n' "$out" | sed 's/^/      /'
    fi
  fi

  # Prebuilt ripgrep (a static binary on Linux, so it runs anywhere).
  rg_prebuilt() {
    case $OS-$ARCH in
      Linux-x86_64 | Linux-amd64) rg_target=x86_64-unknown-linux-musl ;;
      Linux-aarch64 | Linux-arm64) rg_target=aarch64-unknown-linux-musl ;;
      Darwin-x86_64) rg_target=x86_64-apple-darwin ;;
      Darwin-arm64) rg_target=aarch64-apple-darwin ;;
      *) return 1 ;;
    esac
    rg_tag=$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/BurntSushi/ripgrep/releases/latest) || return 1
    rg_tag=${rg_tag##*/}
    curl -fsSL "https://github.com/BurntSushi/ripgrep/releases/download/$rg_tag/ripgrep-$rg_tag-$rg_target.tar.gz" |
      tar -xzf - -C "$TMP" || return 1
    mkdir -p "$TOOLS_BIN" && mv -f "$TMP/ripgrep-$rg_tag-$rg_target/rg" "$TOOLS_BIN/rg" && "$TOOLS_BIN/rg" --version >/dev/null
  }
  if has rg; then
    ok "ripgrep"
  elif has brew && brew install ripgrep >/dev/null 2>&1; then
    ok "ripgrep"
  elif rg_prebuilt; then
    ok "ripgrep"
  elif [ "$RUST" -eq 1 ] && say "Building ripgrep (about a minute)..." && cargo install --locked --quiet ripgrep; then
    ok "ripgrep"
  else
    warn "ripgrep failed to install (searching in files won't work)"
  fi

  ts_version() { "${1:-tree-sitter}" --version 2>/dev/null | awk '{ print $2 }'; }
  # Prebuilt binary (seconds); needs a recent glibc on Linux, so it's tested before use.
  ts_prebuilt() {
    case $OS in Darwin) ts_os=macos ;; Linux) ts_os=linux ;; *) return 1 ;; esac
    case $ARCH in x86_64 | amd64) ts_arch=x64 ;; arm64 | aarch64) ts_arch=arm64 ;; *) return 1 ;; esac
    curl -fsSL -o "$TMP/tree-sitter.gz" \
      "https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-$ts_os-$ts_arch.gz" &&
      gunzip -f "$TMP/tree-sitter.gz" && chmod +x "$TMP/tree-sitter" || return 1
    version_ge "$(ts_version "$TMP/tree-sitter")" "$TREE_SITTER_MIN" || return 1
    mkdir -p "$TOOLS_BIN" && mv -f "$TMP/tree-sitter" "$TOOLS_BIN/tree-sitter"
  }
  if has tree-sitter && version_ge "$(ts_version)" "$TREE_SITTER_MIN"; then
    ok "tree-sitter CLI $(ts_version)"
  elif ts_prebuilt; then
    ok "tree-sitter CLI $(ts_version)"
  elif [ "$RUST" -eq 1 ] && say "Building the tree-sitter CLI (a few minutes)..." && cargo install --locked --quiet tree-sitter-cli; then
    ok "tree-sitter CLI $(ts_version)"
  else
    warn "The tree-sitter CLI couldn't be installed (building it needs Rust 1.90 or newer; try: rustup update). Highlighting falls back to the basic version."
  fi
  # An older tree-sitter earlier on your PATH would be used instead of the new one.
  user_ts=$(PATH=$USER_PATH; command -v tree-sitter 2>/dev/null || true)
  if [ -n "$user_ts" ] && ! version_ge "$("$user_ts" --version 2>/dev/null | awk '{ print $2 }')" "$TREE_SITTER_MIN"; then
    warn "An old tree-sitter at $user_ts comes first on your PATH. Remove it so the new one is used."
  fi

  if [ "$SERVER" -eq 0 ]; then
    # The nv command: persistent sessions, locally and on SSH hosts.
    case ":$USER_PATH:" in
      *":$HOME/.local/bin:"*) nv_dir="$HOME/.local/bin" ;;
      *":$CARGO_BIN:"*) nv_dir=$CARGO_BIN ;;
      *) nv_dir="$HOME/.local/bin"; note "Add $nv_dir to your PATH to use the nv command." ;;
    esac
    mkdir -p "$nv_dir" && ln -sf "$CONFIG_DIR/bin/nv" "$nv_dir/nv"
    ok "nv command"
  fi

  ###############################################################################
  if [ "$SERVER" -eq 0 ]; then
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
  fi

  ###############################################################################
  step "Installing plugins, parsers and plugin binaries"
  say "Installing plugins..."

  if nvim --headless "+lua require('config.bootstrap').run()" </dev/null 2>"$TMP/nvim.log"; then
    ok "Done"
  else
    FAILED=1
    tail -n 15 "$TMP/nvim.log" | awk '{ print "      " $0 }'
    warn "Some of this didn't install (see above). Run this again to retry."
  fi

  ###############################################################################
  if [ "$SERVER" -eq 0 ]; then
    if [ "$OS" = Darwin ]; then
      note "For the Alt shortcuts (like Alt+1 and Shift+Alt+F), set your terminal's Option key to act as Alt. See the README."
    fi
    case ${TERM_PROGRAM:-} in
      Apple_Terminal)
        note "macOS Terminal can't send shortcuts like Ctrl+Shift+O or Ctrl+Tab. Use Ghostty, kitty, WezTerm or iTerm2." ;;
      iTerm.app)
        note "In iTerm2, turn on Settings > Profiles > Keys > \"Report keys using CSI u\" so every shortcut works." ;;
      vscode)
        note "VS Code's built-in terminal keeps many shortcuts for itself. Run nvim in a standalone terminal." ;;
    esac
  fi

  if [ "$FAILED" -ne 0 ]; then
    step "Finished with problems"
  elif [ "$SERVER" -eq 1 ]; then
    step "Done"
  else
    step "All set. Start Neovim with: nv"
    say "(nv keeps your session running when you close the terminal; nv HOST works over SSH.)"
  fi
  [ -n "$NOTES" ] && printf '%s\n' "$NOTES"
  [ "$WARNINGS" -gt 0 ] && printf '\n  %s%s warning(s) above.%s\n' "$YELLOW" "$WARNINGS" "$RESET"
  exit "$FAILED"
}

# Everything runs from main, so `curl ... | sh` reads the whole script before starting.
main "$@"
