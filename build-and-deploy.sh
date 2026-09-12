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
# All requested images are built with a single nix-build invocation (one
# evaluation; Nix schedules the builds of all images together), producing
# ./result/<image>/bin/deploy for each of them.

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

names=$(printf '"%s" ' "${IMAGES[@]}")

echo "=== Building: ${IMAGES[*]}"
nix-build -o result -E "(import ./. { }).mkDeployFarm [ $names ]"

for image in "${IMAGES[@]}"; do
    echo "=== Deploying $image..."
    "./result/$image/bin/deploy" ~/.ssh/id_ed25519
done

echo
echo "All done!"
