#!/bin/bash
set -euo pipefail

CACHE_ROOT="$HOME/Library/Caches/AtlasExecutionFixturesCache"
LOG_ROOT="$HOME/Library/Logs/AtlasExecutionFixturesLogs"
DERIVED_ROOT="$HOME/Library/Developer/Xcode/DerivedData/AtlasExecutionFixturesDerivedData"
PYCACHE_ROOT="$HOME/Library/Caches/AtlasExecutionFixturesPycache"
PNPM_ROOT="$HOME/Library/pnpm/store/v3/files/AtlasExecutionFixturesPnpm"

create_blob() {
    local path="$1"
    local size_mb="$2"
    mkdir -p "$(dirname "$path")"
    if command -v mkfile > /dev/null 2>&1; then
        mkfile -n "${size_mb}m" "$path"
    else
        dd if=/dev/zero of="$path" bs=1m count="$size_mb" status=none
    fi
}

print_status() {
    local existing=false
    for path in "$CACHE_ROOT" "$LOG_ROOT" "$DERIVED_ROOT" "$PYCACHE_ROOT" "$PNPM_ROOT"; do
        if [[ -e "$path" ]]; then
            existing=true
            du -sh "$path"
            find "$path" -maxdepth 3 -type f | sort
        fi
    done
    if [[ "$existing" == false ]]; then
        echo "No Smart Clean manual fixtures found."
    fi
}

create_fixtures() {
    cleanup_fixtures > /dev/null 2>&1 || true

    create_blob "$CACHE_ROOT/cache-a.bin" 24
    create_blob "$CACHE_ROOT/cache-b.bin" 12
    create_blob "$LOG_ROOT/app.log" 8
    create_blob "$DERIVED_ROOT/Build/Logs/build-products.bin" 16
    mkdir -p "$PYCACHE_ROOT/project/__pycache__"
    create_blob "$PYCACHE_ROOT/project/__pycache__/sample.cpython-312.pyc" 4
    create_blob "$PNPM_ROOT/package.tgz" 10

    echo "Created Smart Clean manual fixtures:"
    print_status
    echo ""
    echo "Note: bin/clean.sh --dry-run may aggregate these fixtures into higher-level roots such as ~/Library/Caches, ~/Library/Logs, or ~/Library/Developer/Xcode/DerivedData."
}

cleanup_fixtures() {
    rm -rf "$CACHE_ROOT" "$LOG_ROOT" "$DERIVED_ROOT" "$PYCACHE_ROOT" "$PNPM_ROOT"
    echo "Removed Smart Clean manual fixtures."
}

case "${1:-create}" in
    create)
        create_fixtures
        ;;
    status)
        print_status
        ;;
    cleanup)
        cleanup_fixtures
        ;;
    *)
        echo "Usage: $0 [create|status|cleanup]" >&2
        exit 1
        ;;
esac
