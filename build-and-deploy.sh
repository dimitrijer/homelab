#!/bin/bash
#
# Build and deploy netboot images to the boot server.
#
# Usage:
#   ./build-and-deploy.sh [IMAGE...]
#
# Arguments:
#   IMAGE  One or more image names to build and deploy.
#          If omitted, all images are built and deployed.
#
# Examples:
#   ./build-and-deploy.sh                      # Build and deploy all images
#   ./build-and-deploy.sh ganeti-node          # Build and deploy single image
#   ./build-and-deploy.sh jellyfin navidrome   # Build and deploy multiple images

set -eu -o pipefail

ALL_IMAGES=(
    adguard-home
    audiobookshelf
    calibre-web
    ganeti-node
    jellyfin
    metrics
    navidrome
    paperless
)

if [[ $# -gt 0 ]]; then
    IMAGES=("$@")
    # Validate that all specified images are known
    for image in "${IMAGES[@]}"; do
        found=0
        for valid in "${ALL_IMAGES[@]}"; do
            if [[ "$image" == "$valid" ]]; then
                found=1
                break
            fi
        done
        if [[ $found -eq 0 ]]; then
            echo "Unknown image: $image" >&2
            echo "Valid images: ${ALL_IMAGES[*]}" >&2
            exit 1
        fi
    done
else
    IMAGES=("${ALL_IMAGES[@]}")
fi

echo "==="
for image in "${IMAGES[@]}"
do
    echo "Building $image..."
    nix-build -I . -A "${image}" -o "$image"
    echo "Deploying $image..."
    "./$image/bin/deploy" ~/.ssh/id_ed25519
    echo "==="
done

echo
echo "All done!"
