#!/usr/bin/env bash
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
#
# Images are built and deployed one at a time. If an image fails to build or
# deploy, the script moves on to the next one, and exits non-zero at the end
# listing the images that failed.

set -eu -o pipefail

cd "$(dirname "$0")"

mapfile -t ALL_IMAGES < <(nix-instantiate --eval --strict --raw \
    -E 'builtins.concatStringsSep "\n" (import ./. { }).imageNames')

if [[ $# -gt 0 ]]; then
    IMAGES=("$@")
    for image in "${IMAGES[@]}"; do
        if [[ ! " ${ALL_IMAGES[*]} " == *" $image "* ]]; then
            echo "Unknown image: $image" >&2
            echo "Valid images: ${ALL_IMAGES[*]}" >&2
            exit 1
        fi
    done
else
    IMAGES=("${ALL_IMAGES[@]}")
fi

FAILED=()
for image in "${IMAGES[@]}"; do
    echo "=== Building $image..."
    if ! deploy=$(nix-build --no-out-link -A "$image.deploy"); then
        echo "=== Building $image failed, moving on" >&2
        FAILED+=("$image (build)")
        continue
    fi
    echo "=== Deploying $image..."
    if ! "$deploy/bin/deploy" ~/.ssh/id_ed25519; then
        echo "=== Deploying $image failed, moving on" >&2
        FAILED+=("$image (deploy)")
    fi
done

echo
if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo "Failed: ${FAILED[*]}" >&2
    exit 1
fi
echo "All done!"
