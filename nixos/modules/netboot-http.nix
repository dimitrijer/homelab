{ config, lib, pkgs, modulesPath, ... }:

with lib;

let
  cfg = config.netboot-http;
in
{
  options.netboot-http = {
    enable = mkEnableOption "HTTP-based netboot with remote squashfs store";

    storeUrl = mkOption {
      type = types.str;
      description = "URL to download the squashfs nix store from";
      example = "http://boot.homelab.tel/nixos/by-class/calibre-web/store.squashfs";
    };

    cache = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable persistent caching of squashfs to /var";
      };

      volumeGroup = mkOption {
        type = types.str;
        default = "pool_state";
        description = "LVM volume group containing the var LV";
      };

      path = mkOption {
        type = types.str;
        default = "/var/cache/netboot/store.squashfs";
        description = "Path within the filesystem to cache the squashfs";
      };
    };

    storeContents = mkOption {
      type = types.listOf types.package;
      default = [ config.system.build.toplevel ];
      description = ''
        Additional derivations to include in the Nix store.
        This is used during build time to create the squashfs image.
      '';
    };

    squashfsCompression = mkOption {
      type = types.str;
      default = "zstd -Xcompression-level 1";
      description = "Compression to use for squashfs";
    };
  };

  config = mkIf cfg.enable {
    # Build the squashfs store image
    system.build.squashfsStore = pkgs.callPackage (modulesPath + "/../lib/make-squashfs.nix") {
      storeContents = cfg.storeContents;
      comp = cfg.squashfsCompression;
    };

    # Minimal initrd with network and squashfs support
    boot.initrd.availableKernelModules = [ "squashfs" "overlay" "xfs" ];
    boot.initrd.kernelModules = [ "loop" "overlay" ];

    # Network support in initrd for downloading
    boot.initrd.network.enable = true;

    # Root filesystem configuration (netboot uses tmpfs)
    fileSystems."/" = {
      fsType = "tmpfs";
      device = "tmpfs";
      options = [ "mode=0755" ];
    };

    # Disable bootloader (we netboot)
    boot.loader.grub.enable = false;

    # Script to download and mount the store
    boot.initrd.postMountCommands = ''
      echo "=== HTTP Netboot: Starting store setup ==="

      STORE_URL="${cfg.storeUrl}"
      CACHE_PATH="/mnt-root${cfg.cache.path}"
      VAR_DEV="/dev/${cfg.cache.volumeGroup}/var"

      # Function to check if cache is stale using HTTP If-Modified-Since
      is_cache_stale() {
        local cache_file="$1"
        local url="$2"

        # Get cache file's modification time and format as HTTP date
        local cache_epoch=$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)

        # Format as HTTP date using busybox-compatible approach
        # HTTP date format: "Sat, 04 Jan 2026 12:34:56 GMT"
        local cache_date=$(date -u -d "@$cache_epoch" "+%a, %d %b %Y %H:%M:%S GMT" 2>/dev/null)

        if [ -z "$cache_date" ]; then
          echo "Could not format cache date, assuming stale"
          return 0  # Stale
        fi

        echo "Checking cache freshness (cached: $cache_date)"

        # Make conditional GET request with If-Modified-Since header
        local response=$(${pkgs.wget}/bin/wget -q --spider -S \
          --header="If-Modified-Since: $cache_date" "$url" 2>&1)

        # Check for 304 Not Modified
        if echo "$response" | grep -q "304"; then
          echo "Cache is up to date (HTTP 304)"
          return 1  # Fresh
        else
          echo "Server has newer version"
          return 0  # Stale
        fi
      }

      download_to_cache() {
        mkdir -p "$(dirname "$CACHE_PATH")"
        if ${pkgs.wget}/bin/wget -q -O "$CACHE_PATH" "$STORE_URL"; then
          echo "Download to cache complete, size: $(du -h "$CACHE_PATH" | cut -f1)"
          TARGET_SQUASHFS="$CACHE_PATH"
          return 0
        else
          echo "Download to cache failed, cleaning up partial file"
          rm -f "$CACHE_PATH"
          return 1
        fi
      }

      download_to_tmpfs() {
        local tmpfs_path="/mnt-root/store.squashfs"
        if ${pkgs.wget}/bin/wget -q -O "$tmpfs_path" "$STORE_URL"; then
          echo "Download to tmpfs complete, size: $(du -h "$tmpfs_path" | cut -f1)"
          TARGET_SQUASHFS="$tmpfs_path"
          return 0
        else
          echo "ERROR: Download to tmpfs also failed!"
          rm -f "$tmpfs_path"
          return 1
        fi
      }

      ${optionalString cfg.cache.enable ''
        # Attempt to mount persistent storage for caching
        CACHE_AVAILABLE=false
        if [ -b "$VAR_DEV" ]; then
          echo "Found $VAR_DEV, attempting to mount for cache"
          mkdir -p /mnt-root/var
          if mount "$VAR_DEV" /mnt-root/var; then
            CACHE_AVAILABLE=true
            echo "Persistent storage mounted for caching"
          else
            echo "Failed to mount /var, will use tmpfs"
          fi
        else
          echo "No persistent storage found at $VAR_DEV"
        fi

        if [ "$CACHE_AVAILABLE" = "true" ]; then
          if [ -f "$CACHE_PATH" ]; then
            if is_cache_stale "$CACHE_PATH" "$STORE_URL"; then
              echo "Cache is stale, re-downloading to $CACHE_PATH"
              download_to_cache || download_to_tmpfs
            else
              echo "Using cached store at $CACHE_PATH"
              TARGET_SQUASHFS="$CACHE_PATH"
            fi
          else
            echo "No cache found, downloading to $CACHE_PATH"
            download_to_cache || download_to_tmpfs
          fi
        else
          echo "No persistent storage, downloading to tmpfs"
          download_to_tmpfs
        fi
      ''}

      ${optionalString (!cfg.cache.enable) ''
        echo "Caching disabled, downloading to tmpfs"
        download_to_tmpfs
      ''}

      # Verify we have a valid squashfs before mounting
      if [ -z "$TARGET_SQUASHFS" ] || [ ! -f "$TARGET_SQUASHFS" ]; then
        echo "ERROR: No valid squashfs file available (TARGET_SQUASHFS=$TARGET_SQUASHFS)"
        exit 1
      fi

      # Mount the squashfs
      echo "Mounting squashfs ($TARGET_SQUASHFS) at /mnt-root/nix/.ro-store"
      mkdir -p /mnt-root/nix/.ro-store /mnt-root/nix/.rw-store /mnt-root/nix/store

      if ! mount -t squashfs -o loop "$TARGET_SQUASHFS" /mnt-root/nix/.ro-store; then
        echo "ERROR: Failed to mount squashfs"
        exit 1
      fi

      # Create overlay for writable store
      echo "Setting up overlay at /mnt-root/nix/store"
      mount -t tmpfs tmpfs /mnt-root/nix/.rw-store
      mkdir -p /mnt-root/nix/.rw-store/store /mnt-root/nix/.rw-store/work

      if ! mount -t overlay overlay \
        -o lowerdir=/mnt-root/nix/.ro-store,upperdir=/mnt-root/nix/.rw-store/store,workdir=/mnt-root/nix/.rw-store/work \
        /mnt-root/nix/store; then
        echo "ERROR: Failed to mount overlay"
        exit 1
      fi

      echo "=== HTTP Netboot: Store setup complete ==="
    '';

    # Set netboot iPXE script (use relative paths like traditional netboot)
    # ${cmdline} allows MAC-specific wrappers to pass hostname= and other params
    system.build.netbootIpxeScript = pkgs.writeTextDir "netboot.ipxe" ''
      #!ipxe
      kernel bzImage init=${config.system.build.toplevel}/init initrd=initrd ${toString config.boot.kernelParams} ''${cmdline}
      initrd initrd
      boot
    '';
  };
}
