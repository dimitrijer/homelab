#!/bin/sh

set -euo pipefail

rm -rf ./keys

INSTANCES=(
  calibre-web
  metrics
  navidrome
  paperless
  audiobookshelf
  jellyfin
  adguard-home
  uptime-kuma
)

scp -r mikrotik.london:/usb1-part1/http/keys .

pushd keys
for instance in ${INSTANCES[@]}; do
    mkdir "$instance"
    mv "./$instance.tar.gz" "$instance"
    pushd "$instance"
    tar -xzvf "./$instance.tar.gz"
    popd
done
popd

agenix --rekey \
    -i keys/calibre-web/host_privkey \
    -i keys/metrics/host_privkey \
    -i keys/navidrome/host_privkey \
    -i keys/paperless/host_privkey \
    -i keys/audiobookshelf/host_privkey \
    -i keys/jellyfin/host_privkey \
    -i keys/adguard-home/host_privkey \
    -i keys/uptime-kuma/host_privkey

rm -rf keys
