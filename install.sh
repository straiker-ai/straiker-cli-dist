#!/bin/sh
# Install the Straiker CLI.
#
#   curl -fsSL https://raw.githubusercontent.com/straiker-ai/straiker-cli-dist/main/install.sh | sh
#
# Environment:
#   STRAIKER_VERSION   version to install (default: the latest release)
#   STRAIKER_INSTALL   directory to install into (default: /usr/local/bin, or
#                      ~/.local/bin when that is not writable)
#
# POSIX sh, not bash: this runs on Alpine CI images where /bin/sh is busybox
# ash and bash is not installed.
set -eu

REPO="straiker-ai/straiker-cli-dist"
BIN="straiker"

say()  { printf '%s\n' "$*"; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "$1 is required but not installed"; }

need uname
need tar
if command -v curl >/dev/null 2>&1; then
  fetch() { curl -fsSL "$1"; }
  download() { curl -fsSL -o "$2" "$1"; }
elif command -v wget >/dev/null 2>&1; then
  fetch() { wget -qO- "$1"; }
  download() { wget -qO "$2" "$1"; }
else
  die "curl or wget is required"
fi

# ── platform ────────────────────────────────────────────────────────────────
os=$(uname -s | tr '[:upper:]' '[:lower:]')
arch=$(uname -m)

case "$os" in
  linux)  ;;
  darwin) ;;
  *) die "unsupported OS: $os (linux and darwin only)" ;;
esac

case "$arch" in
  x86_64|amd64)  arch=amd64 ;;
  aarch64|arm64) arch=arm64 ;;
  *) die "unsupported architecture: $arch" ;;
esac

# GoReleaser merges the two macOS builds into one universal binary, so darwin
# has a single archive rather than one per architecture.
if [ "$os" = darwin ]; then
  arch=all
fi

# ── version ─────────────────────────────────────────────────────────────────
version="${STRAIKER_VERSION:-}"
if [ -z "$version" ]; then
  version=$(fetch "https://api.github.com/repos/$REPO/releases/latest" |
    sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
  [ -n "$version" ] || die "could not determine the latest version; set STRAIKER_VERSION"
fi
num=${version#v}

base="https://github.com/$REPO/releases/download/$version"
archive="straiker_${num}_${os}_${arch}.tar.gz"

# ── download and verify ─────────────────────────────────────────────────────
tmp=$(mktemp -d)
# The archive is extracted here and the binary is moved out; nothing should
# survive a failure part-way through.
trap 'rm -rf "$tmp"' EXIT INT TERM

say "Downloading straiker $version ($os/$arch)"
download "$base/$archive" "$tmp/$archive" || die "no release asset $archive at $version"

# The checksum is what makes piping this script to sh defensible: without it a
# corrupted or substituted archive installs silently.
if download "$base/checksums.txt" "$tmp/checksums.txt" 2>/dev/null; then
  expected=$(grep " $archive\$" "$tmp/checksums.txt" | awk '{print $1}')
  if [ -n "$expected" ]; then
    if command -v sha256sum >/dev/null 2>&1; then
      actual=$(sha256sum "$tmp/$archive" | awk '{print $1}')
    elif command -v shasum >/dev/null 2>&1; then
      actual=$(shasum -a 256 "$tmp/$archive" | awk '{print $1}')
    fi
    if [ -n "${actual:-}" ] && [ "$actual" != "$expected" ]; then
      die "checksum mismatch for $archive
  expected $expected
  actual   $actual"
    fi
    [ -n "${actual:-}" ] && say "Checksum verified"
  fi
else
  say "warning: checksums.txt unavailable; skipping verification" >&2
fi

tar -xzf "$tmp/$archive" -C "$tmp"
[ -f "$tmp/$BIN" ] || die "archive did not contain $BIN"
chmod +x "$tmp/$BIN"

# ── install ─────────────────────────────────────────────────────────────────
target="${STRAIKER_INSTALL:-}"
if [ -z "$target" ]; then
  if [ -w /usr/local/bin ] 2>/dev/null; then
    target=/usr/local/bin
  elif command -v sudo >/dev/null 2>&1 && [ -d /usr/local/bin ]; then
    target=/usr/local/bin
    sudo=sudo
  else
    target="$HOME/.local/bin"
    mkdir -p "$target"
  fi
fi
mkdir -p "$target"

${sudo:-} mv "$tmp/$BIN" "$target/$BIN"
# s6r is an alias for the same binary, matching what the Homebrew formula does.
${sudo:-} ln -sf "$target/$BIN" "$target/s6r" 2>/dev/null || true

say "Installed to $target/$BIN"

case ":$PATH:" in
  *":$target:"*) ;;
  *) say ""
     say "$target is not on your PATH. Add it with:"
     say "  export PATH=\"$target:\$PATH\"" ;;
esac

say ""
say "Next: straiker login"
