#!/bin/bash

set -e

MANIFEST="com.github.ransome1.sleek.yml"
NEW_VERSION="$1"
REPO="ransome1/sleek"
REPO_URL="https://github.com/$REPO"
ARCHES=("x86_64" "aarch64")

if [[ -z "$NEW_VERSION" ]]; then
  echo "Usage: $0 <new-version>"
  exit 1
fi

echo "Updating Flatpak manifest to version $NEW_VERSION..."

# === Get release info for the specified version ===
echo "Fetching release info for version $NEW_VERSION..."
RELEASE_INFO=$(curl -s "https://api.github.com/repos/$REPO/releases/tags/v$NEW_VERSION")

# Check if the release exists
if echo "$RELEASE_INFO" | grep -q '"message": "Not Found"'; then
  echo "Release v$NEW_VERSION not found. Exiting."
  exit 1
fi

# Fetch the latest commit hash from the main branch
RELEASE_COMMIT=$(curl -s "https://api.github.com/repos/$REPO/commits/main" | grep -m 1 '"sha":' | head -n1 | cut -d '"' -f4)

if [[ -z "$RELEASE_COMMIT" ]]; then
  echo "Could not retrieve latest commit hash from main branch. Exiting."
  exit 1
fi

echo "Found commit hash: $RELEASE_COMMIT"

# === Prepare new .deb source entries ===
TMP_SOURCES=$(mktemp)

for ARCH in "${ARCHES[@]}"; do
  DEB_ARCH="${ARCH/x86_64/amd64}"
  FILE_NAME="sleek-${NEW_VERSION}-linux-${DEB_ARCH}.deb"
  DEB_URL="$REPO_URL/releases/download/v$NEW_VERSION/$FILE_NAME"

  echo "Downloading $DEB_URL..."
  curl -sLO "$DEB_URL"

  SHA256=$(sha256sum "$FILE_NAME" | cut -d ' ' -f1)

  cat >> "$TMP_SOURCES" <<EOF
        - type: file
          dest-filename: com.github.ransome1.sleek.deb
          url: $DEB_URL
          sha256: $SHA256
          only-arches:
            - $ARCH
EOF

  rm "$FILE_NAME"
done

# === Patch YAML ===

# Step 1: Remove the old modules section entirely, including sources
awk '/^modules:/ { in_modules=1 } in_modules && /^$/ { in_modules=0; next } !in_modules { print }' "$MANIFEST" > "$MANIFEST.tmp"

# Step 2: Add the updated module section with the new sources
cat >> "$MANIFEST.tmp" <<EOF
modules:
  - name: sleek
    buildsystem: simple
    build-commands:
      - ar x com.github.ransome1.sleek.deb
      - tar -xf data.tar.* -C /app
      - find /app/opt/sleek/ -exec chmod -R a-s,go+rX,go-w {} \;
      - install -Dm755 sleek-entrypoint.sh /app/bin/sleek
      - install -Dm644 ./build/128x128.png /app/share/icons/hicolor/128x128/apps/com.github.ransome1.sleek.png
      - install -Dm644 ./build/256x256.png /app/share/icons/hicolor/256x256/apps/com.github.ransome1.sleek.png
      - install -Dm644 ./build/512x512.png /app/share/icons/hicolor/512x512/apps/com.github.ransome1.sleek.png
      - install -Dm644 flatpak/com.github.ransome1.sleek.desktop /app/share/applications/com.github.ransome1.sleek.desktop
      - install -Dm644 flatpak/com.github.ransome1.sleek.appdata.xml /app/share/metainfo/com.github.ransome1.sleek.appdata.xml
    sources:
      - type: git
        url: https://github.com/ransome1/sleek.git
        commit: $RELEASE_COMMIT
      - type: script
        commands:
          - |
            echo '#!/bin/sh' > sleek-entrypoint.sh
            echo 'exec env TMPDIR=\$XDG_CACHE_HOME zypak-wrapper /app/opt/sleek/sleek "\$@"' >> sleek-entrypoint.sh
        dest-filename: sleek-entrypoint.sh
$(cat "$TMP_SOURCES")
EOF

rm "$TMP_SOURCES"

# Step 3: Replace the original manifest with the updated one
mv "$MANIFEST.tmp" "$MANIFEST"

# === Set Git Config for Automation ===
git config user.name "github-actions"
git config user.email "github-actions@github.com"

# === Git commit and push ===
#echo "Committing and pushing changes..."
#git add "$MANIFEST"
#git commit -m "Update sleek to version $NEW_VERSION (commit $RELEASE_COMMIT)"
#git push

echo "\u2705 Update complete!"
