#!/bin/bash

set -eu -o pipefail

IMAGES=(
    adguard-home
    audiobookshelf
    calibre-web
    ganeti-node
    jellyfin
    metrics
    navidrome
    paperless
)

echo "==="
for image in "${IMAGES[@]}"
do
    if [[ -h "$image" ]]; then
      echo "Removing previous result for $image..."
      unlink "$image"
    fi
    echo "Building $image..."
    nix-build -I . -A "${image}" -o "$image"
    echo "Deploying $image..."
    "./$image/bin/deploy" ~/.ssh/id_ed25519
    echo "==="
done

echo
echo "All done!"
