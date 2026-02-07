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

    httpProxy = mkOption {
      type = types.str;
      default = "";
      description = "HTTP proxy to be used when downloading squashfs nix store";
      example = "http://10.1.1.1:8080";
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

      hashPath = mkOption {
        type = types.str;
        default = "/var/cache/netboot/store.squashfs.sha256";
        description = "Path within the filesystem to cache the squashfs hash";
      };
    };

    hashUrl = mkOption {
      type = types.str;
      default = "";
      description = "URL to download the squashfs hash from (defaults to storeUrl + .sha256)";
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
      type = types.int;
      default = 1;
      description = "Compression to use for squashfs (1 - fastest, 22 - slowest)";
    };
  };

  config = mkIf cfg.enable {
    # Build the squashfs store image
    system.build.squashfsStore = pkgs.callPackage (modulesPath + "/../lib/make-squashfs.nix") {
      storeContents = cfg.storeContents;
      comp = "zstd -Xcompression-level ${toString cfg.squashfsCompression}";
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
      HASH_URL="${if cfg.hashUrl != "" then cfg.hashUrl else cfg.storeUrl + ".sha256"}"
      CACHE_PATH="/mnt-root${cfg.cache.path}"
      HASH_CACHE_PATH="/mnt-root${cfg.cache.hashPath}"
      VAR_DEV="/dev/${cfg.cache.volumeGroup}/var"

      if ! [ -z "${cfg.httpProxy}" ]; then
        export http_proxy="${cfg.httpProxy}"
      fi

      # Function to check if cache is stale using hash comparison
      # Returns 0 for stale, and 1 for fresh.
      is_cache_stale() {
        local cache_file="$1"
        local hash_cache="$2"
        local hash_url="$3"

        # If cache file doesn't exist, it's stale
        if [ ! -f "$cache_file" ]; then
          echo "Cache file does not exist"
          return 0
        fi

        # If local hash doesn't exist, it's stale
        if [ ! -f "$hash_cache" ]; then
          echo "Local hash file does not exist"
          return 0
        fi

        # Fetch remote hash
        local remote_hash=$(${pkgs.wget}/bin/wget -q -O - "$hash_url" 2>/dev/null)
        if [ -z "$remote_hash" ]; then
          echo "Failed to fetch remote hash, assuming stale"
          return 0
        fi

        local local_hash=$(cat "$hash_cache" 2>/dev/null)

        echo "Comparing hashes: local=$local_hash remote=$remote_hash"

        if [ "$local_hash" = "$remote_hash" ]; then
          echo "Hashes match, cache is fresh"
          return 1
        else
          echo "Hashes differ, cache is stale"
          return 0
        fi
      }

      download_to_cache() {
        mkdir -p "$(dirname "$CACHE_PATH")"
        if ${pkgs.wget}/bin/wget -q -O "$CACHE_PATH" "$STORE_URL"; then
          echo "Download to cache complete, size: $(du -h "$CACHE_PATH" | cut -f1)"
          # Save the hash file
          if ${pkgs.wget}/bin/wget -q -O "$HASH_CACHE_PATH" "$HASH_URL"; then
            echo "Hash file saved"
          else
            echo "Warning: Failed to save hash file"
          fi
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
          if is_cache_stale "$CACHE_PATH" "$HASH_CACHE_PATH" "$HASH_URL"; then
            echo "Cache is stale or missing, downloading to $CACHE_PATH"
            download_to_cache || download_to_tmpfs
          else
            echo "Using cached store at $CACHE_PATH"
            TARGET_SQUASHFS="$CACHE_PATH"
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

    # Import store registration so nix-collect-garbage knows about our paths
    systemd.services.nix-register-store-paths = {
      description = "Register Nix store paths from netboot image";
      wantedBy = [ "multi-user.target" ];
      before = [ "nix-daemon.service" ];
      after = [ "local-fs.target" ];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${pkgs.nix}/bin/nix-store --load-db < /nix/store/nix-path-registration
      '';
    };
  };
}
