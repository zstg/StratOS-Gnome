#!/usr/bin/env bash

# Function to handle errors
handle_error() {
    echo "Error on line $1"
    exit 1
}

# Trap errors
trap 'handle_error $LINENO' ERR
[ -d /workspace ] && git config --global --add safe.directory /workspace

set_environment() {
    echo "Setting up environment..."
    export BUILD_DATE=$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)
    echo "BUILD_DATE=${BUILD_DATE}" >> $GITHUB_ENV
}

build() {
    echo "Cleaning up..."
    sudo rm -rf output.bak 2>/dev/null
    sudo mv -f output output.bak 2>/dev/null
    sudo pacman -Sy archiso --noconfirm
    echo "Initializing ISO"
    sudo mkarchiso -v \
        -w output \
        -o output \
        ./
    ISO_NAME=$(echo output/*.iso | awk -F/ '{print $NF}')
    echo "Built ISO: ${ISO_NAME}"
}

create_github_release() {
    echo "Creating GitHub release..."
    local UPLOAD_URL

    UPLOAD_URL=$(curl -s -X POST \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -d "{\"tag_name\": \"v${BUILD_DATE}\", \"name\": \"v${BUILD_DATE}\", \"body\": \"Automated release powered by GitHub Actions.\"}" \
        https://api.github.com/repos/${GITHUB_REPOSITORY}/releases | jq -r .upload_url | sed -e "s/{?name,label}//")

    echo "Uploading ISO to release..."
    curl -s --data-binary @"output/${ISO_NAME}" \dev
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Content-Type: application/octet-stream" \
        "${UPLOAD_URL}?name=${ISO_NAME}"
}

main() {
    set_environment
    build
    create_github_release
}

# Ensure GITHUB_TOKEN is set
if [ ! -d "/workspace" ] && [ -z "$GITHUB_TOKEN" ]; then
    echo "GITHUB_TOKEN is not set. Please set it before running this script."
    exit 1
fi

# Execute main function
main
