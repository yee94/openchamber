#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

TARGET="native"
DRY_RUN=false
NO_BUNDLE=false
VERBOSE=false

usage() {
    cat <<'EOF'
Usage: ./scripts/test-release-build.sh [target] [options]

Targets:
  native, all       Build for the current macOS architecture (default)
  aarch64, arm64    Require and build on Apple Silicon
  x86_64, intel     Require and build on Intel macOS

Options:
  --dry-run         Print the release smoke commands
  --no-bundle       Build staged assets and Electron main without packaging
  --verbose, -v     Enable shell tracing
  --help, -h        Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        native|all|both)
            TARGET="native"
            ;;
        aarch64|arm64|arm)
            TARGET="arm64"
            ;;
        x86_64|intel|x86)
            TARGET="x64"
            ;;
        --dry-run)
            DRY_RUN=true
            ;;
        --no-bundle)
            NO_BUNDLE=true
            ;;
        --verbose|-v)
            VERBOSE=true
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
    shift
done

[[ "$VERBOSE" == true ]] && set -x

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Native release smoke currently packages the macOS Electron target; use the Release workflow for Windows and Linux." >&2
    exit 1
fi

host_arch="$(uname -m)"
case "$host_arch" in
    arm64|aarch64)
        host_target="arm64"
        ;;
    x86_64|amd64)
        host_target="x64"
        ;;
    *)
        echo "Unsupported macOS architecture: $host_arch" >&2
        exit 1
        ;;
esac

if [[ "$TARGET" != "native" && "$TARGET" != "$host_target" ]]; then
    echo "Requested $TARGET release smoke on $host_target host; run that architecture on its native GitHub runner." >&2
    exit 1
fi

commands=(
    "bun install --frozen-lockfile"
    "bun run --cwd packages/electron test:architecture"
    "bun run --cwd packages/electron test:updater"
    "bun run --cwd packages/electron build:web-assets"
    "bun run --cwd packages/electron prepare:opencode-cli"
    "bun run --cwd packages/electron verify:opencode-cli"
    "bun run --cwd packages/electron bundle:main"
)

if [[ "$NO_BUNDLE" == false ]]; then
    commands+=(
        "ELECTRON_BUILDER_ARCH=$host_target bun run --cwd packages/electron rebuild:native"
        "(cd packages/electron && node ./scripts/package.mjs --mac --$host_target --publish=never)"
        "bun run --cwd packages/electron verify:opencode-cli:packaged"
    )
fi

echo "Electron release smoke: macOS $host_target"
for command in "${commands[@]}"; do
    echo "+ $command"
    if [[ "$DRY_RUN" == false ]]; then
        eval "$command"
    fi
done

echo "Electron release smoke completed for macOS $host_target."
