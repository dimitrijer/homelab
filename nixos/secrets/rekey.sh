#!/usr/bin/env bash
#
# Re-encrypt all secrets for the current set of host keys. Fetches the
# provisioned key tarballs from the boot server, extracts every host's private
# key and passes them all to `agenix --rekey`.

set -euo pipefail

cd "$(dirname "$0")"

INSTANCES=(
  calibre-web
  metrics
  navidrome
  paperless
  audiobookshelf
  jellyfin
  adguard-home
  uptime-kuma
  immich
)

rm -rf ./keys
trap 'rm -rf ./keys' EXIT

scp -r mikrotik.london:/usb1-part1/http/keys .

identities=()
for instance in "${INSTANCES[@]}"; do
  mkdir "keys/$instance"
  tar -xzf "keys/$instance.tar.gz" -C "keys/$instance"
  identities+=(-i "keys/$instance/host_privkey")
done

agenix --rekey "${identities[@]}"
