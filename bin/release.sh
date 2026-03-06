#!/usr/bin/env bash
# Create a GitHub release for a WordPress plugin.
#
# Usage: release.sh [major|minor|patch]
#   major: x.y.z => (x+1).0.0
#   minor: x.y.z => x.(y+1).0
#   patch: x.y.z => x.y.(z+1)  (default)
#
# The script:
# 1. Reads current version from the main plugin PHP file
# 2. Bumps the version (in plugin header + define)
# 3. Commits, pushes, and creates a GitHub release
set -euo pipefail

BUMP="${1:-patch}"

# Find the main plugin PHP file (has "Plugin Name:" header).
PLUGIN_FILE=$(grep -rl "Plugin Name:" ./*.php 2>/dev/null | head -1)
if [[ -z "$PLUGIN_FILE" ]]; then
	echo "ERROR: No plugin PHP file found in current directory." >&2
	exit 1
fi

# Extract current version from the define() line.
CURRENT=$(grep -oP "define\(\s*'[A-Z_]+_VERSION',\s*'\K[0-9]+\.[0-9]+\.[0-9]+" "$PLUGIN_FILE")
if [[ -z "$CURRENT" ]]; then
	echo "ERROR: Could not extract version from $PLUGIN_FILE" >&2
	exit 1
fi

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

case "$BUMP" in
	major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
	minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
	patch) PATCH=$((PATCH + 1)) ;;
	*) echo "ERROR: Unknown bump type '$BUMP'. Use major, minor, or patch." >&2; exit 1 ;;
esac

NEW="${MAJOR}.${MINOR}.${PATCH}"

echo "Bumping version: $CURRENT => $NEW"

# Update version in plugin file (header + define).
sed -i "s/\* Version: $CURRENT/* Version: $NEW/" "$PLUGIN_FILE"
sed -i "s/VERSION', '$CURRENT'/VERSION', '$NEW'/" "$PLUGIN_FILE"

# Verify the replacement worked.
if ! grep -q "Version: $NEW" "$PLUGIN_FILE"; then
	echo "ERROR: Version replacement failed in plugin header." >&2
	exit 1
fi

# Commit, tag, push, release.
git add "$PLUGIN_FILE"
git commit -m "Bump version to $NEW"
git push origin HEAD
gh release create "v${NEW}" --title "v${NEW}" --generate-notes
echo "Released v${NEW}"
