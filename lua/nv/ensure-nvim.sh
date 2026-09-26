#!/bin/sh
# Runs on an SSH host (sent by nv): make sure a Neovim release is installed under
# ~/.local/share/nv/nvim/<version> and print the path of its binary.
#
#   sh -s -- <version> [tarball]   version: a release tag like v0.12.5, or nightly
#
# Exit codes: 3 = couldn't download (nv then uploads the tarball), 4 = unsupported system.
set -eu

version=$1
tarball=${2:-}
dir="${XDG_DATA_HOME:-$HOME/.local/share}/nv/nvim/$version"
bin="$dir/bin/nvim"

if [ -x "$bin" ] && "$bin" --version >/dev/null 2>&1; then
  echo "$bin"
  exit 0
fi

case $(uname -s) in
  Linux) os=linux ;;
  Darwin) os=macos ;;
  *) echo "Neovim has no prebuilt release for $(uname -s)." >&2; exit 4 ;;
esac
case $(uname -m) in
  x86_64 | amd64) arch=x86_64 ;;
  aarch64 | arm64) arch=arm64 ;;
  *) echo "Neovim has no prebuilt release for $(uname -m)." >&2; exit 4 ;;
esac

echo "Installing Neovim $version on $(hostname)..." >&2
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
if [ -n "$tarball" ]; then
  mv "$tarball" "$tmp/nvim.tar.gz"
else
  url="https://github.com/neovim/neovim/releases/download/$version/nvim-$os-$arch.tar.gz"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$tmp/nvim.tar.gz" "$url" || exit 3
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$tmp/nvim.tar.gz" "$url" || exit 3
  else
    exit 3
  fi
fi

rm -rf "$dir"
mkdir -p "$dir"
tar -xzf "$tmp/nvim.tar.gz" -C "$dir" --strip-components=1
if ! "$bin" --version >/dev/null 2>&1; then
  rm -rf "$dir"
  echo "Neovim's prebuilt release doesn't run here (on Linux it needs glibc 2.34 or newer)." >&2
  exit 4
fi
echo "$bin"
