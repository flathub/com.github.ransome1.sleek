#!/bin/bash
# Accept the commit ID as an argument
COMMIT_ID=$1

# Update the manifest file with the new commit ID
sed -i "s/commit: .*/commit: $COMMIT_ID/" com.github.ransome1.sleek.yml

echo $COMMIT_ID

# Commit and push changes
#git config user.name github-actions
#git config user.email github-actions@github.com
#git add com.github.ransome1.sleek.yml
#git commit -m "Update commit ID in Flatpak manifest"
#git push