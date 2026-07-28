#!/usr/bin/env bash

set -euo pipefail

fail() {
    echo "::error::$1"
    exit 1
}

require_text() {
    local file="$1"
    local text="$2"
    grep --fixed-strings --quiet "$text" "$file" ||
        fail "$file is missing: $text"
}

require_text scenes/Catapult.tscn "Cataclysm: Cleanwater Bomb"
require_text scenes/Catapult.tscn "HTTPRequest_CCB"
require_text scripts/ReleaseManager.gd \
    "https://api.github.com/repos/CrimsonCrossBunker/Cataclysm-Cleanwater-Bomb/releases"
require_text scripts/ReleaseManager.gd "ccb-linux-with-graphics-and-sounds-x64"
require_text scripts/ReleaseManager.gd "ccb-windows-with-graphics-and-sounds-x64"
require_text scripts/ReleaseManager.gd "ccb-osx-with-graphics-universal"
require_text scripts/settings_manager.gd '"active_install_ccb": ""'
require_text scripts/path_helper.gd '"ccb"'
require_text scripts/AboutUI.gd "Dabdoob by Hihahahalol"
require_text README.md "Hihahahalol/Catapult_Dabdoob"
require_text NOTICE.md "Hihahahalol"

translation_count=0
for directory in text/*; do
    [[ -d "$directory" ]] || continue
    [[ -f "$directory/general.csv" ]] || continue
    [[ -f "$directory/release_manager.csv" ]] || continue

    require_text "$directory/general.csv" "desc_ccb"
    require_text "$directory/release_manager.csv" "msg_fetching_releases_ccb"
    translation_count=$((translation_count + 1))
done

[[ "$translation_count" -eq 11 ]] ||
    fail "Expected 11 translation directories, found $translation_count"

echo "CCB integration is complete across code, scene, credits, and translations."
