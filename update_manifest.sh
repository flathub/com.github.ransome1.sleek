#!/bin/bash
# Define the new commit ID
NEW_COMMIT_ID=$(git rev-parse HEAD)

# Update the manifest file with the new commit ID
sed -i "s/commit: .*/commit: $NEW_COMMIT_ID/" com.github.ransome1.sleek.yml