#!/bin/bash
#
# VoiceOS source-build entrypoint for the Preflight QA platform.
#
# Reconstructs the build pipeline that voiceos-snapshot's package.json
# references (`bash build-binaries.sh --mac --universal` + `bash build-app.sh
# mac`) — those upstream shell scripts aren't committed to this repo, so we
# replicate their effect from observed signals (electron-builder.config.js
# binary inventory, native/* build-system mix, electron-vite + electron-builder
# config).
#
# Run from the workspace root via .preflight/preflight.yaml's build.commands:
#   - bash .preflight/build.sh
#
# Output: dist/mac-arm64/VoiceOS.app (matched by build.artifact_glob
# "dist/**/VoiceOS.app"). Exits non-zero on any step failure.
#
# Toolchain expectations on the host:
#   - rustup with stable + aarch64-apple-darwin target
#   - Xcode command-line tools (provides swiftc + system frameworks)
#   - bun (used as install_command + electron-vite/electron-builder runner)
#   - Node 20+ on PATH (node-gyp shim shell-execs `node`)
#   - python3 with distutils for node-gyp native modules (Apple's /usr/bin/
#     python3 has it; Homebrew 3.12+ doesn't, hence the PYTHON override)

set -euo pipefail

# Locate this script regardless of cwd, then resolve workspace root as
# the parent of .preflight/. Lets the script be invoked from anywhere.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ASSETS_DIR="${SCRIPT_DIR}/assets"
cd "${WORKSPACE_ROOT}"

export PATH="${HOME}/.cargo/bin:/opt/homebrew/bin:${PATH}"
export PYTHON="${PYTHON:-/usr/bin/python3}"
export npm_config_python="${npm_config_python:-/usr/bin/python3}"

# Make sure Node 20 is on PATH. The Preflight QA VM image ships bun but
# not node — install the official arm64 tarball into a per-run dir and
# prepend. ~25MB download, one-time per VM (cached across steps when
# the same path is reused).
NODE_VERSION="${NODE_VERSION:-v20.18.0}"
NODE_DIR="/tmp/preflight-node-${NODE_VERSION}"
if ! command -v node >/dev/null 2>&1 || [ "$(node --version 2>/dev/null)" != "${NODE_VERSION}" ]; then
  if [ ! -x "${NODE_DIR}/bin/node" ]; then
    echo "[build] installing node ${NODE_VERSION} (arm64) -> ${NODE_DIR}"
    TARBALL="node-${NODE_VERSION}-darwin-arm64.tar.gz"
    curl --fail --silent --show-error -L -o "/tmp/${TARBALL}" \
      "https://nodejs.org/dist/${NODE_VERSION}/${TARBALL}"
    mkdir -p "${NODE_DIR}"
    tar -xzf "/tmp/${TARBALL}" -C "${NODE_DIR}" --strip-components=1
    rm -f "/tmp/${TARBALL}"
  fi
  export PATH="${NODE_DIR}/bin:${PATH}"
fi
echo "[build]   node: $(node --version) at $(command -v node)"
echo "[build]   bun:  $(bun --version 2>/dev/null || echo 'not found') at $(command -v bun || echo '-')"

# electron-builder's ${arch} substitution emits "arm64-apple-darwin" for
# arm64 builds. Cargo's target triple is "aarch64-apple-darwin" (LLVM
# convention). Normalize to electron-builder's name so produced binaries
# land where electron-builder.config.js expects.
ARCH_OUT="arm64-apple-darwin"
ARCH_CARGO="aarch64-apple-darwin"
ARCH_SWIFT="arm64"

RUST_CRATES=(
  keyboard-listener
  text-injector
  selection-reader
)

SWIFT_CRATES=(
  app-observer
  window-text-reader
  focused-element-reader
)

echo "[build] cargo build (release, ${ARCH_CARGO} → mirrored to ${ARCH_OUT}) for ${#RUST_CRATES[@]} crates"
for crate in "${RUST_CRATES[@]}"; do
  echo "[build]   ${crate}"
  (cd "native/${crate}" && cargo build --release --target "${ARCH_CARGO}")
  # Cargo writes to target/aarch64-apple-darwin/. Symlink the directory
  # under the arm64-apple-darwin name so electron-builder picks it up.
  ln -snf "${ARCH_CARGO}" "native/${crate}/target/${ARCH_OUT}"
done

echo "[build] swift build (release, ${ARCH_SWIFT} → mirrored to ${ARCH_OUT}) for ${#SWIFT_CRATES[@]} crates"
for crate in "${SWIFT_CRATES[@]}"; do
  echo "[build]   ${crate}"
  (cd "native/${crate}" && swift build -c release --arch "${ARCH_SWIFT}")
  dst_dir="native/${crate}/target/${ARCH_OUT}/release"
  src_bin="native/${crate}/.build/${ARCH_SWIFT}-apple-macosx/release/${crate}"
  mkdir -p "${dst_dir}"
  cp "${src_bin}" "${dst_dir}/${crate}"
done

echo "[build] node-gyp rebuild for window-corners native module"
# window-corners is a node-gyp / N-API module under native/window-corners/.
# It's a standalone package (not in node_modules) — electron-rebuild only
# rebuilds installed deps, so it would log "Rebuild Complete" without
# touching anything. Invoke node-gyp directly inside the crate dir
# against the bundled electron's node ABI.
ELECTRON_HEADERS_VERSION="$(bun -e 'const p=require("./package.json"); const v=(p.devDependencies?.electron||p.dependencies?.electron||"").replace(/^[^0-9]*/,""); process.stdout.write(v)')"
if [ -z "${ELECTRON_HEADERS_VERSION}" ]; then
  echo "[build] FAIL: package.json has no electron version pin" >&2
  exit 1
fi
echo "[build]   targeting electron ${ELECTRON_HEADERS_VERSION} headers"
NODE_GYP_BIN="$(pwd)/node_modules/.bin/node-gyp"
if [ ! -x "${NODE_GYP_BIN}" ]; then
  echo "[build] FAIL: node-gyp not installed at ${NODE_GYP_BIN}" >&2
  exit 1
fi
(
  cd native/window-corners
  "${NODE_GYP_BIN}" rebuild \
    --target="${ELECTRON_HEADERS_VERSION}" \
    --arch=arm64 \
    --dist-url=https://electronjs.org/headers \
    --release
)
WC_NODE_SRC="$(find native/window-corners -name 'window_corners.node' -type f -path '*Release*' | head -1 || true)"
if [ -z "${WC_NODE_SRC}" ]; then
  echo "[build] FAIL: node-gyp did not produce window_corners.node under native/window-corners/build/Release/" >&2
  exit 1
fi
mkdir -p "native/window-corners/target/${ARCH_SWIFT}"
cp "${WC_NODE_SRC}" "native/window-corners/target/${ARCH_SWIFT}/window_corners.node"
echo "[build]   window-corners → target/${ARCH_SWIFT}/window_corners.node"

echo "[build] staging build assets from .preflight/assets/ (no-clobber)"
# voiceos-snapshot gitignores .env* and doesn't commit build/icon.icns or
# resources/build/*.png to the source tree (the production icon is part
# of a sibling release pipeline). .preflight/assets/ ships placeholders
# so a fresh clone produces a working .app. Any in-repo asset already
# at the destination wins — we only fill in missing ones.
if [ -d "${ASSETS_DIR}" ]; then
  while IFS= read -r -d '' src; do
    rel="${src#${ASSETS_DIR}/}"
    if [ ! -e "${rel}" ]; then
      mkdir -p "$(dirname "${rel}")"
      cp "${src}" "${rel}"
      echo "[build]   staged ${rel}"
    fi
  done < <(find "${ASSETS_DIR}" -type f -print0)
fi

echo "[build] electron-vite build (renderer + main + preload bundles)"
bun run electron-vite build

echo "[build] electron-builder --mac --dir (produces VoiceOS.app under dist/mac-arm64/)"
# --dir skips dmg packaging + signing — the QA harness installs an
# unsigned .app into a Tart guest with SIP off, no Apple Developer cert
# required.
./node_modules/.bin/electron-builder --mac --dir --config electron-builder.config.js

echo "[build] verifying produced .app"
APP_PATH="$(find dist -maxdepth 4 -name 'VoiceOS.app' -type d | head -1 || true)"
if [ -z "${APP_PATH}" ]; then
  echo "[build] FAIL: no VoiceOS.app found under dist/" >&2
  exit 1
fi
echo "[build] OK: ${APP_PATH}"
