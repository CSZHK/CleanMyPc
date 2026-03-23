#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE_SCRIPT="$SCRIPT_DIR/apps-manual-fixtures.sh"

print_guide() {
    cat <<'EOF'
Apps Evidence Acceptance Guide

1. Run Atlas and open the Apps screen.
2. Verify these fixture apps appear:
   - Atlas Fixture Browser
   - Atlas Fixture Dev
   - Atlas Fixture Sparse
3. For each fixture app, build the uninstall plan and confirm:
   - preview categories match the expected review-only evidence
   - recoverable bundle removal is separated from review-only evidence
   - observed paths are listed for review-only groups
4. Execute uninstall for Atlas Fixture Dev and confirm:
   - completion summary mentions real removal and review-only categories
   - History shows the uninstall with review-only evidence still informational
5. Restore the Atlas Fixture Dev recovery item and confirm:
   - the app reappears in Apps after the restore-driven inventory refresh
   - stale uninstall preview is cleared
   - History shows restore-path evidence when supported
6. Re-run Apps refresh and verify leftover counts remain consistent with current disk state.
7. Clean up fixtures when done.
EOF
}

case "${1:-guide}" in
    setup)
        "$FIXTURE_SCRIPT" create
        print_guide
        ;;
    status)
        "$FIXTURE_SCRIPT" status
        ;;
    cleanup)
        "$FIXTURE_SCRIPT" cleanup
        ;;
    guide)
        print_guide
        ;;
    *)
        echo "Usage: $0 [setup|status|cleanup|guide]" >&2
        exit 1
        ;;
esac
