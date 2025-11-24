#!/bin/bash
# Standalone скрипт для ручного увеличения версии темы
# Usage: ./bump-version.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils/version-bump.sh"

# Выполняем version bump
version_bump

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Done! Version updated in style.css"
    exit 0
else
    echo ""
    echo "Version bump failed!"
    exit 1
fi
