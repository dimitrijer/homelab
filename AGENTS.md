# AGENTS.md - Homelab Repository Context

This file provides essential context for AI agents working with this homelab repository.

## Repository Overview

**Purpose**: NixOS-based homelab infrastructure with PXE network booting for virtualized and physical machines.

**Infrastructure**:
- 4-node Ganeti cluster (aleph, bet, gimel, dalet)
- Hardware: Dell Optiplex Micro 7040
- Network boot via iPXE
- Storage: DRBD for replication, LVM for volume management
- Domain: `homelab.tel`

**Key Technologies**:
- **NixOS**: Base operating system and image builder
- **Ganeti 3.x**: Cluster management and VM orchestration
- **KVM/QEMU**: Virtualization
- **DRBD 9.x**: Distributed replicated block device
- **OVN**: Open Virtual Network for SDN
- **disko**: Declarative disk partitioning
- **agenix**: Age-encrypted secrets management
- **niv**: Nix dependency management

## Architecture

### Network Configuration
- **Primary Interface** (enp0s31f6): Uplink network (10.1.100.0/24)
- **Secondary Interface** (enp3s0): DRBD replication network (10.1.97.0/24)
- **Cluster IP**: 10.1.100.254
- **Boot Server**: boot.homelab.tel

### Storage Layout
- **VG pool_gnt**: Ganeti VM storage (NVMe SSD /dev/nvme0n1)
- **VG pool_host**: Host storage (HDD /dev/sda)
  - swap: 32G
  - home: 100G
  - var: remaining space
- **Boot partition**: 100M EFI on HDD

### Boot Process
1. Physical machines PXE boot via iPXE
2. iPXE loads script from `http://boot.homelab.tel/nixos/by-mac/{mac}/ipxe`
3. Script chainloads kernel, initrd from class-specific directory
4. System provisions disks if `homelab.provision_disks=true` in cmdline
5. SSH keys downloaded from `http://boot.homelab.tel/keys/{hostname}.tar.gz`
6. Agenix decrypts secrets using host keys

## Directory Structure

```
.
├── default.nix                 # Main entry point, builds all targets
├── ganeti/                     # Ganeti derivation and components
│   ├── default.nix            # Ganeti 3.x package with custom patches
│   ├── *.patch                # Compatibility and feature patches
│   ├── os-providers/          # Ganeti OS providers
│   │   └── ganeti-os-pxe.nix # PXE boot OS provider
│   └── prometheus-exporter/   # Ganeti metrics exporter
├── ipxe/
│   └── netboot.ipxe           # Main iPXE boot menu script
├── netboot.ipxe               # Root iPXE script (symlink or copy)
├── nix/
│   ├── sources.json           # niv-managed dependencies
│   ├── sources.nix            # niv fetcher implementation
│   ├── default.nix            # nixpkgs with overlays
│   └── overlays/              # Custom package overlays
│       ├── default.nix        # Overlay aggregator
│       ├── qemu.nix           # QEMU with custom iPXE ROM
│       ├── drbd.nix           # DRBD 9.x kernel module
│       ├── ovmf.nix           # UEFI firmware
│       └── ghc.nix            # GHC for Ganeti
├── nginx/
│   └── default.nix            # nginx container for MikroTik router
├── nixos/
│   ├── default.nix            # mkNetbuild function and class definitions
│   ├── classes/               # NixOS image configurations
│   │   ├── ganeti-node.nix   # Physical cluster node image
│   │   ├── navidrome.nix     # Music streaming service
│   │   ├── calibre-web.nix   # eBook server
│   │   ├── paperless.nix     # Document management
│   │   ├── audiobookshelf.nix# Audiobook server
│   │   └── metrics.nix       # Prometheus/Grafana monitoring
│   ├── modules/               # Reusable NixOS modules
│   │   ├── common.nix        # Base configuration for all images
│   │   ├── common-vm.nix     # Base configuration for VMs
│   │   ├── ganeti.nix        # Ganeti cluster module
│   │   ├── ovn.nix           # OVN networking module
│   │   ├── acme-nginx-reverse-proxy.nix  # ACME + nginx
│   │   ├── prometheus-ganeti-exporter.nix
│   │   └── provisioning/
│   │       ├── disks.nix     # Disk provisioning with disko
│   │       └── keys.nix      # SSH key provisioning
│   ├── layouts/
│   │   └── default.nix       # Disko disk layouts for VMs
│   └── secrets/
│       └── secrets.nix       # Agenix secrets configuration
├── ovn/
│   └── default.nix            # OVN package with OVS
└── initrd/
    └── default.nix            # Custom initrd components
```

## Key Components

### 1. Ganeti Cluster (`ganeti/`, `nixos/modules/ganeti.nix`)

**Custom Derivation** (`ganeti/default.nix`):
- Based on Ganeti 3.x
- Patches for DRBD compatibility, OVN support, QEMU features
- Python 3.11 (asyncore requirement)
- Integration with custom QEMU, OVMF, OVN packages

**Module Options** (`virtualisation.ganeti.*`):
- `clusterName`: Cluster name (default: "gnt")
- `clusterAddress`: Floating cluster IP
- `nodes`: Attribute set of node configurations (hostname, IPs, SSH keys)
- `initialMasterNode`: First master node
- `vgName`: LVM volume group for VM storage
- `primaryInterface`/`secondaryInterface`: Network interfaces
- `osProviders`: List of OS provider packages
- `rapiUsers`: RAPI authentication for monitoring

**ganeti-os-pxe Provider**:
- Writes iPXE NBP to VM disks for network boot
- Modified from upstream to use nixpkgs iPXE

### 2. NixOS Classes (`nixos/classes/`, `nixos/default.nix`)

**mkNetbuild Function**:
- Creates network-bootable NixOS images
- Outputs: bzImage (kernel), initrd, ipxe script
- Bundles into deployable derivation
- Provides deploy script for SCP to boot server

**Physical Node Class** (`ganeti-node.nix`):
- Full Ganeti node configuration
- Dual network interfaces
- DRBD kernel module
- Serial console on ttyS1
- LVM filter to exclude DRBD devices
- Extensive system tools (vim, ethtool, iperf3, etc.)

**Service Classes** (navidrome, calibre-web, etc.):
- Import `common-vm.nix` for VM basics
- Use `mkLayout` from `layouts/default.nix` for disks
- Typically enable `acme-nginx-reverse-proxy` for HTTPS
- Provision directories via `provisioning.disks.ensureDirs`

### 3. Custom Modules (`nixos/modules/`)

**common.nix**:
- User `dimitrije` with sudo access
- SSH authorized keys
- Basic packages (vim, dig, rsync)
- Node exporter for Prometheus
- Firewall enabled by default

**provisioning/disks.nix**:
- Wraps disko for disk formatting and mounting
- Checks `/proc/cmdline` for `homelab.provision_disks=true`
- Conditionally wipes and provisions disks
- Always mounts disks
- Creates directories from `ensureDirs` option

**provisioning/keys.nix**:
- Downloads `{hostname}.tar.gz` from boot server
- Extracts root SSH key and host key
- Runs before sshd.service
- Enables agenix secret decryption

**acme-nginx-reverse-proxy.nix**:
- ACME certificate management
- nginx reverse proxy configuration
- Domain and redirect domain support
- Customizable proxy config

### 4. Overlays (`nix/overlays/`)

**qemu.nix**:
- Custom QEMU build
- Includes custom iPXE ROM (pxe-virtio.rom)
- Enables specific features for Ganeti

**drbd.nix**:
- DRBD 9.2.x from custom source
- Kernel module and userspace tools
- Compatibility patches

**ovmf.nix**:
- UEFI firmware for VMs
- SecureBoot support

### 5. Dependencies (`nix/sources.json`)

Managed via niv:
- **nixpkgs**: nixpkgs-unstable
- **disko**: Disk partitioning (nix-community)
- **agenix**: Secrets (dimitrijer/agenix-as-oneshot-service)
- **nixfiles**: Personal nixfiles reference

## Common Tasks

### Building Images

```bash
# Build specific class
nix-build -A ganeti-node.netbuild
nix-build -A navidrome.netbuild

# Build all classes
nix-build

# Access deploy script
./result/bin/deploy /path/to/ssh/key
```

### Deploying Images

```bash
# Build and deploy ganeti-node
nix-build -A ganeti-node.deploy
./result/bin/deploy ~/.ssh/id_ed25519

# This SCPs to admin@boot.homelab.tel:/usb1-part1/http/nixos/by-class/
```

### Adding a New Service Class

1. Create `nixos/classes/myservice.nix`:
   ```nix
   { config, ... }:
   {
     imports = [
       ../modules/common-vm.nix
       ../modules/acme-nginx-reverse-proxy.nix
       ../modules/provisioning/disks.nix
     ];

     disko.devices = (import ../layouts).mkLayout { };
     provisioning.disks.enable = true;

     services.myservice.enable = true;

     services.acme-nginx-reverse-proxy = {
       enable = true;
       domain = "myservice.homelab.tel";
       upstreamPort = config.services.myservice.port;
     };
   }
   ```

2. Add to `nixos/default.nix`:
   ```nix
   myservice = mkNetbuild {
     className = "myservice";
     modules = [ ./classes/myservice.nix ];
   };
   ```

3. Build and deploy:
   ```bash
   nix-build -A myservice.netbuild
   nix-build -A myservice.deploy
   ./result/bin/deploy ~/.ssh/key
   ```

### Updating Dependencies

```bash
# Update all niv sources
niv update

# Update specific source
niv update nixpkgs

# Pin to specific revision
niv update nixpkgs -r <commit-sha>
```

### Adding Patches to Ganeti

1. Create patch file in `ganeti/`:
   ```bash
   ganeti-3.x-my-feature.patch
   ```

2. Add to `ganeti/default.nix` patches list:
   ```nix
   patches = [
     # ... existing patches
     ./ganeti-3.x-my-feature.patch
   ];
   ```

### Modifying Network Boot

1. Edit `ipxe/netboot.ipxe` for boot menu changes
2. Class-specific boot scripts generated by mkNetbuild
3. MAC-based routing handled by boot server file structure

## Important Context

### Constraints and Conventions

1. **Python Version**: Ganeti requires Python 3.11 (asyncore removed in 3.12)

2. **Serial Console**: All physical nodes use ttyS1 at 19200 baud for serial-over-LAN

3. **LVM Filter**: Must exclude DRBD devices (`/dev/drbd[0-9]+`) from LVM scanning

4. **SSH Keys**:
   - Host keys provisioned, not generated
   - Agenix requires host keys before secret decryption

5. **Disk Provisioning**:
   - Only happens if kernel cmdline has `homelab.provision_disks=true`
   - Otherwise just mounts existing disks

6. **Network Interfaces**:
   - Physical nodes: enp0s31f6 (primary), enp3s0 (secondary)
   - VMs: Depends on Ganeti network configuration

7. **Boot Order**:
   - Keys provisioned before sshd
   - Disks provisioned before local-fs.target
   - Both before most services

8. **Secrets Management**:
   - Uses agenix-as-oneshot-service variant
   - Secrets in `nixos/secrets/`
   - Requires host keys from provisioning

### Notable Files

- **ganeti/ganeti-3.1-drbd-compat.patch**: Critical for DRBD 9.x compatibility
- **ganeti/ganeti-3.1-ovn.patch**: Enables OVN networking in Ganeti
- **nix/overlays/pxe-virtio.rom**: Custom iPXE ROM for VM network boot
- **nixos/modules/ganeti.nix**: ~600 lines, core cluster logic

### Git Status Notes

Current modifications (from initial git status):
- `ganeti/ganeti-3.1-drbd-compat.patch`: Modified
- `nix/overlays/qemu.nix`: Modified
- `nixos/classes/ganeti-node.nix`: Modified
- `nixos/classes/navidrome.nix`: Modified
- Untracked: `initrd/`, `netboot.ipxe`, `nix/overlays/pxe-virtio.rom`

### Troubleshooting

**Build Failures**:
- Check niv sources: `niv show`
- Verify overlay paths in `nix/overlays/default.nix`
- Look for patch conflicts in `ganeti/default.nix`

**Boot Issues**:
- Check iPXE menu timeout (5000ms default)
- Verify boot server reachability: `curl http://boot.homelab.tel`
- Check MAC-based routing: `/usb1-part1/http/nixos/by-mac/{mac}/ipxe`

**Provisioning Issues**:
- Verify kernel cmdline for `homelab.provision_disks=true`
- Check disko device paths match actual hardware
- Review systemd logs: `journalctl -u provision-disks`

**Key Issues**:
- Ensure `{hostname}.tar.gz` exists on boot server
- Check network connectivity before key download
- Verify service ordering: keys before sshd

## Quick Reference

### Important File Locations

| Task | File(s) |
|------|---------|
| Add Ganeti patch | `ganeti/default.nix`, `ganeti/*.patch` |
| Add service class | `nixos/classes/*.nix`, `nixos/default.nix` |
| Modify base config | `nixos/modules/common.nix` |
| Change disk layout | `nixos/layouts/default.nix` |
| Update dependencies | `niv update` (modifies `nix/sources.json`) |
| Customize QEMU | `nix/overlays/qemu.nix` |
| Change boot menu | `ipxe/netboot.ipxe` |
| Manage secrets | `nixos/secrets/secrets.nix` |
| Add node to cluster | `nixos/classes/ganeti-node.nix` (nodes attr) |

### Build Outputs

- `result`: Primary output (usually deploy script or main class)
- `result-2`, `result-3`, etc.: Additional outputs
- Classes output to `by-class/{className}/` with:
  - `bzImage`: Linux kernel
  - `initrd`: Initial ramdisk
  - `ipxe`: iPXE chainload script

### Network Details

- **Cluster Network**: 10.1.100.0/24
- **DRBD Network**: 10.1.97.0/24
- **Nodes**:
  - aleph: 10.1.100.2 / 10.1.97.2
  - bet: 10.1.100.3 / 10.1.97.3
  - gimel: 10.1.100.4 / 10.1.97.4
  - dalet: 10.1.100.5 / 10.1.97.5
- **OVN Northd**: Runs on dalet only (systemd condition)
- **Boot Server**: boot.homelab.tel (on MikroTik router)

## Understanding the Codebase

**Total Lines of Nix Code**: ~938 lines across all .nix files

**Complexity Distribution**:
- Simple: Service classes (navidrome, calibre-web) - ~40 lines each
- Medium: Modules (provisioning, ovn) - ~100-150 lines
- Complex: ganeti.nix, ganeti-node.nix - ~280-600 lines

**Key Patterns**:
1. **Module Pattern**: Options + mkIf config blocks
2. **Overlay Pattern**: self/super for package overrides
3. **Provisioning Pattern**: systemd oneshot services
4. **Class Pattern**: imports + disko + service config

**Entry Points for Changes**:
- New service → `nixos/classes/`
- Infrastructure → `nixos/modules/`
- Package version → `nix/overlays/` or `niv update`
- Cluster config → `nixos/classes/ganeti-node.nix`
