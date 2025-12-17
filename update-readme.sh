#!/bin/bash
#
# update-readme.sh
# Fetches GitHub repo stats and regenerates the projects table in README.md
#
# Usage: ./update-readme.sh
# Requires: curl, jq
#
# Add to crontab for automatic updates:
#   0 */6 * * * /path/to/update-readme.sh
#

GITHUB_USER="mattseabrook"
README_PATH="$(dirname "$0")/README.md"

# Define your repos here - add or remove as needed
# Format: "repo_name|description|language|logo|logo_color"
REPOS=(
    "LZSS|2026 Refactoring of the 1989 LZSS.C public domain code|C|c|555555"
    "KICK.com-Streaming-REST-API|KICK REST API Documentation & Extras|PowerShell|powershell|5391FE"
    "v64tng|Game Engine re-creation of The 7th Guest|C++|cplusplus|00599C"
    "XMI2MID|2025 Refactor of the original XMI2MID.EXE|C++|cplusplus|00599C"
    "snes9x-fastlink|Snes9x with RAM State API|C++|cplusplus|00599C"
    "ADP-Silencer|ADPCM-DTK Utility to Mute Background Music in GameCube games|C|c|555555"
)

# Fetch repo data from GitHub API
fetch_repo_data() {
    local repo=$1
    curl -s "https://api.github.com/repos/${GITHUB_USER}/${repo}"
}

# Build the table
build_table() {
    echo "| Project | Language | ⭐ Stars | 🍴 Forks |"
    echo "|---------|----------|---------|---------|"

    # Create temp file to store repo data with stars for sorting
    local temp_file=$(mktemp)

    for entry in "${REPOS[@]}"; do
        IFS='|' read -r repo desc lang logo color <<< "$entry"
        
        # Fetch current stats from GitHub
        local data=$(fetch_repo_data "$repo")
        local stars=$(echo "$data" | jq -r '.stargazers_count // 0')
        local forks=$(echo "$data" | jq -r '.forks_count // 0')
        
        # Handle API errors
        if [[ "$stars" == "null" ]] || [[ -z "$stars" ]]; then
            stars=0
        fi
        if [[ "$forks" == "null" ]] || [[ -z "$forks" ]]; then
            forks=0
        fi

        # Store with stars count for sorting
        echo "${stars}|${repo}|${desc}|${lang}|${logo}|${color}|${forks}" >> "$temp_file"
    done

    # Sort by stars (descending) and generate table rows
    sort -t'|' -k1 -nr "$temp_file" | while IFS='|' read -r stars repo desc lang logo color forks; do
        local lang_badge="![${lang}](https://img.shields.io/badge/-${lang/+/%2B}-${color}?style=flat&logo=${logo}&logoColor=white)"
        local stars_badge="![Stars](https://img.shields.io/github/stars/${GITHUB_USER}/${repo}?style=flat&color=blue)"
        local forks_badge="![Forks](https://img.shields.io/github/forks/${GITHUB_USER}/${repo}?style=flat&color=green)"
        
        echo "| [${repo}](https://github.com/${GITHUB_USER}/${repo}) — ${desc} | ${lang_badge} | ${stars_badge} | ${forks_badge} |"
    done

    rm -f "$temp_file"
}

# Update the README
update_readme() {
    if [[ ! -f "$README_PATH" ]]; then
        echo "ERROR: README.md not found at $README_PATH"
        exit 1
    fi

    # Build new table
    local new_table=$(build_table)

    # Create temp file for new README
    local temp_readme=$(mktemp)
    local in_table=false
    local table_done=false

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Detect start of projects table
        if [[ "$line" =~ ^\|[[:space:]]*Project ]]; then
            in_table=true
            echo "$new_table" >> "$temp_readme"
            continue
        fi

        # Skip old table rows
        if $in_table; then
            if [[ "$line" =~ ^[[:space:]]*$ ]] || [[ "$line" =~ ^\<\!-- ]] || [[ ! "$line" =~ ^\| ]]; then
                in_table=false
                table_done=true
                echo "$line" >> "$temp_readme"
            fi
            continue
        fi

        echo "$line" >> "$temp_readme"
    done < "$README_PATH"

    # Replace old README
    mv "$temp_readme" "$README_PATH"
    echo "✅ README.md updated successfully!"
    echo "   Repos processed: ${#REPOS[@]}"
}

# Main
echo "🔄 Updating README.md with latest GitHub stats..."
update_readme
