#!/bin/bash
set -euo pipefail

APPS_ROOT="$HOME/Applications"
SUPPORT_ROOT="$HOME/Library/Application Support"
CACHE_ROOT="$HOME/Library/Caches"
PREFERENCES_ROOT="$HOME/Library/Preferences"
LOG_ROOT="$HOME/Library/Logs"
STATE_ROOT="$HOME/Library/Saved Application State"
LAUNCH_AGENTS_ROOT="$HOME/Library/LaunchAgents"

FIXTURES=(
    "Atlas Fixture Browser|com.example.atlas.fixture.browser|support,caches,preferences"
    "Atlas Fixture Dev|com.example.atlas.fixture.dev|support,caches,logs,launch"
    "Atlas Fixture Sparse|com.example.atlas.fixture.sparse|saved-state"
)

create_blob() {
    local path="$1"
    local size_kb="$2"
    mkdir -p "$(dirname "$path")"
    if command -v mkfile > /dev/null 2>&1; then
        mkfile "${size_kb}k" "$path"
    else
        dd if=/dev/zero of="$path" bs=1024 count="$size_kb" status=none
    fi
}

write_info_plist() {
    local plist_path="$1"
    local bundle_id="$2"
    local app_name="$3"
    cat > "$plist_path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>${bundle_id}</string>
  <key>CFBundleName</key>
  <string>${app_name}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleExecutable</key>
  <string>fixture</string>
</dict>
</plist>
EOF
}

create_app_bundle() {
    local app_name="$1"
    local bundle_id="$2"
    local bundle_path="$APPS_ROOT/${app_name}.app"
    local contents_path="$bundle_path/Contents"
    local executable_path="$contents_path/MacOS/fixture"
    local plist_path="$contents_path/Info.plist"

    mkdir -p "$(dirname "$executable_path")"
    printf '#!/bin/sh\nexit 0\n' > "$executable_path"
    chmod +x "$executable_path"
    write_info_plist "$plist_path" "$bundle_id" "$app_name"
    create_blob "$bundle_path/Contents/Resources/fixture.dat" 128
}

create_leftovers() {
    local app_name="$1"
    local bundle_id="$2"
    local categories="$3"

    IFS=',' read -r -a parts <<< "$categories"
    for category in "${parts[@]}"; do
        case "$category" in
            support)
                create_blob "$SUPPORT_ROOT/$bundle_id/settings.json" 32
                ;;
            caches)
                create_blob "$CACHE_ROOT/$bundle_id/cache.bin" 48
                ;;
            preferences)
                create_blob "$PREFERENCES_ROOT/$bundle_id.plist" 4
                ;;
            logs)
                create_blob "$LOG_ROOT/$bundle_id/runtime.log" 24
                ;;
            launch)
                mkdir -p "$LAUNCH_AGENTS_ROOT"
                cat > "$LAUNCH_AGENTS_ROOT/$bundle_id.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${bundle_id}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/true</string>
  </array>
</dict>
</plist>
EOF
                ;;
            saved-state)
                create_blob "$STATE_ROOT/$bundle_id.savedState/data.data" 8
                ;;
        esac
    done
}

cleanup_fixture() {
    local app_name="$1"
    local bundle_id="$2"

    rm -rf \
        "$APPS_ROOT/${app_name}.app" \
        "$SUPPORT_ROOT/$bundle_id" \
        "$CACHE_ROOT/$bundle_id" \
        "$PREFERENCES_ROOT/$bundle_id.plist" \
        "$LOG_ROOT/$bundle_id" \
        "$STATE_ROOT/$bundle_id.savedState" \
        "$LAUNCH_AGENTS_ROOT/$bundle_id.plist"
}

print_status() {
    local found=false
    for fixture in "${FIXTURES[@]}"; do
        IFS='|' read -r app_name bundle_id categories <<< "$fixture"
        local bundle_path="$APPS_ROOT/${app_name}.app"
        if [[ -d "$bundle_path" ]]; then
            found=true
            echo "Fixture: $app_name ($bundle_id)"
            du -sh "$bundle_path" "$SUPPORT_ROOT/$bundle_id" "$CACHE_ROOT/$bundle_id" \
                "$PREFERENCES_ROOT/$bundle_id.plist" "$LOG_ROOT/$bundle_id" \
                "$STATE_ROOT/$bundle_id.savedState" "$LAUNCH_AGENTS_ROOT/$bundle_id.plist" 2> /dev/null || true
            echo "Expected review-only categories: $categories"
            echo ""
        fi
    done
    if [[ "$found" == false ]]; then
        echo "No Apps manual fixtures found."
    fi
}

create_fixtures() {
    for fixture in "${FIXTURES[@]}"; do
        IFS='|' read -r app_name bundle_id categories <<< "$fixture"
        cleanup_fixture "$app_name" "$bundle_id"
        create_app_bundle "$app_name" "$bundle_id"
        create_leftovers "$app_name" "$bundle_id" "$categories"
    done

    echo "Created Apps manual fixtures:"
    print_status
}

cleanup_fixtures() {
    for fixture in "${FIXTURES[@]}"; do
        IFS='|' read -r app_name bundle_id _ <<< "$fixture"
        cleanup_fixture "$app_name" "$bundle_id"
    done
    echo "Removed Apps manual fixtures."
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
