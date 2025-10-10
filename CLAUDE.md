# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build System

This is a Nix-based project using traditional `nix-build` (not flakes). All builds are pure and reproducible.

### Building Images

```bash
# Build all classes (ganeti-node, navidrome, calibre-web, etc.)
nix-build

# Build specific class netboot image
nix-build -A ganeti-node.netbuild
nix-build -A navidrome.netbuild

# Build deploy script for a class
nix-build -A ganeti-node.deploy

# Deploy to boot server (requires SSH key)
./result/bin/deploy ~/.ssh/id_ed25519

# Build Ganeti package alone
nix-build -A ganeti

# Build OVN package
nix-build -A ovn

# Build nginx container for router
nix-build -A nginx
```

### Build Outputs

- `result`: Primary symlink to build output
- `result-2`, `result-3`, etc.: Additional outputs when building multiple targets
- Netbuild outputs contain: `bzImage` (kernel), `initrd`, `ipxe` (boot script)
- Deploy outputs contain: `bin/deploy` script that SCPs to `admin@boot.homelab.tel:/usb1-part1/http/nixos/by-class/`

### Testing Ganeti

The Ganeti derivation has comprehensive test support:

```bash
# Run all standard tests (Haskell + Python legacy + Python unit)
nix-build -A ganeti

# Run with linting
nix-build -A ganeti --arg withLinting true

# Run with coverage
nix-build -A ganeti --arg withCoverage true

# Run with docs generation
nix-build -A ganeti --arg withDocs true
```

Tests run during build via `checkPhase`:
- `hs-tests`: Haskell unit tests (QuickCheck, test-framework)
- `py-tests-legacy`: Legacy Python tests
- `py-tests-unit`: Modern Python unit tests
- `make lint`: Python (pylint, pycodestyle) and Haskell (hlint) linting
- `make coverage`: Python code coverage

## Architecture

### The Build Pipeline

1. **Entry Point** (`default.nix`):
   - Imports `nix/` with system and overlays
   - Builds custom packages: `ovn`, `ganeti`, `ganeti-os-providers`, `prometheus-ganeti-exporter`
   - Creates overlays for these packages
   - Calls `nixos/default.nix` with overlayed pkgs

2. **Overlay System** (`nix/overlays/`):
   - Base overlays loaded automatically: qemu, ovmf, ghc, drbd
   - Additional overlays injected at runtime (ganeti, ovn)
   - Order matters: later overlays can reference earlier ones

3. **mkNetbuild Function** (`nixos/default.nix`):
   - Takes `className` and `modules` list
   - Evaluates NixOS configuration with netboot module
   - Extracts kernel and initrd from `config.system.build`
   - Packages into deployable derivation under `by-class/{className}/`
   - Generates deploy script that uses `scp` to boot server

4. **Class Structure**:
   - Physical nodes: Import ganeti, provisioning, complex disk layouts
   - Service VMs: Import common-vm, simple disko layout, reverse proxy

### Key Architectural Patterns

**Provisioning Pattern**: Two-stage systemd oneshot services:
1. `provision-keys.service`: Downloads SSH keys from boot server (before sshd)
2. `provision-disks.service`: Conditionally formats disks based on kernel cmdline, always mounts

**Module Pattern**: All custom modules follow:
```nix
{ config, lib, ... }:
with lib;
let cfg = config.namespace.module; in
{
  options.namespace.module = { ... };
  config = mkIf cfg.enable { ... };
}
```

**Overlay Pattern**: Self/super pattern for package overrides:
```nix
self: super: {
  packageName = super.packageName.override { ... };
}
```

**Disko Integration**: The `provisioning.disks` module wraps disko to:
- Disable `enableConfig` (we manage filesystems ourselves)
- Check kernel cmdline for `homelab.provision_disks=true` before formatting
- Always mount existing disks regardless of provisioning flag
- Create directories from `ensureDirs` option after mounting

## Critical Dependencies and Constraints

### Python Version Lock

Ganeti **requires Python 3.11** because `asyncore` was removed in Python 3.12. This is hardcoded in `ganeti/default.nix`:

```nix
python311 # asyncore was removed in 3.12
```

When updating nixpkgs, verify Python 3.11 is still available or Ganeti will fail to build.

### Patch Management

Ganeti has 11 patches in `ganeti/default.nix`:

**Upstream patches** (from ganeti-rpm project):
- `ganeti-2.16.1-fix-new-cluster-node-certificates.patch`
- `ganeti-3.0.0-qemu-migrate-set-parameters-version-check.patch`
- `ganeti-3.0.2-kvm-qmp-timeout.patch`

**Nix-specific patches**:
- `ganeti-3.0.2-make-daemons-scripts-executable.patch`
- `ganeti-3.0.2-makefile-am.patch`
- `ganeti-3.0.2-do-not-link-when-running-ssh-cmds.patch`
- `ganeti-3.0.2-disable-incompatible-pytests.patch`

**Feature patches**:
- `ganeti-3.1-bitarray-compat.patch`: Python bitarray API changes
- `ganeti-3.1-do-not-reset-env-when-updating-master-ip.patch`: Environment handling
- `ganeti-3.1-pandoc-3.6-man-rst.patch`: Documentation generation
- **`ganeti-3.1-drbd-compat.patch`**: DRBD 9.x compatibility (CRITICAL)
- **`ganeti-3.1-ovn.patch`**: OVN networking support (CRITICAL)

When updating Ganeti version:
1. Check if patches still apply cleanly
2. Test DRBD and OVN functionality specifically
3. Re-run full test suite

### Dependency Chain

```
ganeti <- {ovn, drbd, qemu, OVMF, ghc}
  ovn <- openvswitch (built from source)
  drbd <- drbd-utils + kernel module (custom version)
  qemu <- custom iPXE ROM (pxe-virtio.rom)
  ghc <- specific Haskell packages for monitoring
```

The overlay order in `nix/overlays/default.nix` matters because:
1. QEMU must be available for Ganeti
2. DRBD must be available for Ganeti
3. OVMF must be available for QEMU
4. GHC must have monitoring packages for Ganeti Haskell daemons

### LVM and DRBD Interaction

Physical nodes must filter DRBD devices from LVM scanning to prevent corruption:

```nix
environment.etc."/lvm/lvm.conf".text = lib.mkForce ''
  devices {
    filter = ["r|/dev/drbd[0-9]+|"]
  }
'';
```

This is set in `nixos/classes/ganeti-node.nix`. Do NOT remove or modify without understanding implications.

## Dependency Management

Dependencies are managed with [niv](https://github.com/nmattia/niv):

```bash
# Update all dependencies
niv update

# Update specific dependency
niv update nixpkgs
niv update disko
niv update agenix

# Add new dependency
niv add owner/repo

# Pin to specific revision
niv update nixpkgs -r abc123def
```

Current pinned dependencies (`nix/sources.json`):
- **nixpkgs**: nixpkgs-unstable (for latest QEMU, DRBD)
- **disko**: For declarative disk management
- **agenix**: Custom fork `dimitrijer/agenix-as-oneshot-service` for oneshot secret provisioning
- **nixfiles**: Reference to personal nixfiles (informational)

When updating nixpkgs:
1. Check Python 3.11 availability
2. Verify DRBD version compatibility (9.2.x)
3. Test Ganeti build with patches
4. Test at least one full netboot image build

## Common Modification Patterns

### Adding a New Service VM

1. Create class file in `nixos/classes/myservice.nix`:

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

  services.myservice = {
    enable = true;
    # service-specific config
  };

  services.acme-nginx-reverse-proxy = {
    enable = true;
    domain = "myservice.homelab.tel";
    redirectDomains = [ "myservice" ];  # Optional short names
    upstreamPort = config.services.myservice.port;
  };
}
```

2. Add to `nixos/default.nix`:

```nix
{
  # ... existing classes
  myservice = mkNetbuild {
    className = "myservice";
    modules = [ ./classes/myservice.nix ];
  };
}
```

3. Build and deploy:

```bash
nix-build -A myservice.netbuild
nix-build -A myservice.deploy
./result/bin/deploy ~/.ssh/key
```

### Adding a Node to the Cluster

Edit `nixos/classes/ganeti-node.nix` in the `virtualisation.ganeti.nodes` attribute set:

```nix
nodes = {
  # ... existing nodes
  epsilon = {
    hostname = "epsilon";
    address = "10.1.100.6";
    secondaryAddress = "10.1.97.6";
    rootPubkey = "ssh-ed25519 AAAA... root@epsilon";
    hostPubkey = "ssh-rsa AAAA... root@epsilon";
  };
};
```

The SSH keys must be pre-generated and the `{hostname}.tar.gz` must exist on the boot server before the node boots.

### Modifying Ganeti Configuration

Common Ganeti options in `nixos/classes/ganeti-node.nix`:

```nix
virtualisation.ganeti = {
  enable = true;
  clusterAddress = "10.1.100.254";     # Floating IP
  clusterName = "gnt";                  # Short name
  domain = "homelab.tel";               # DNS domain
  vgName = "pool_gnt";                  # LVM VG for VMs
  primaryInterface = "enp0s31f6";       # Uplink
  secondaryInterface = "enp3s0";        # DRBD replication
  osProviders = [ pkgs.ganeti-os-pxe ];
  rapiUsers = [ {...} ];                # For monitoring
  adminUsers = [ "dimitrije" ];         # gnt-admin group
};
```

Changes require rebuilding and deploying ganeti-node image, then rebooting all physical nodes.

### Updating DRBD Version

1. Edit `nix/overlays/drbd.nix`:

```nix
version = "9.2.XX";  # Update version
hash = "sha256-...";  # Update hash
```

2. If Ganeti needs changes, update `ganeti/ganeti-3.1-drbd-compat.patch`

3. Rebuild Ganeti to verify compatibility:

```bash
nix-build -A ganeti
```

4. Rebuild ganeti-node image:

```bash
nix-build -A ganeti-node.netbuild
```

### Adding Custom QEMU Features

Edit `nix/overlays/qemu.nix`:

```nix
super.qemu.override {
  # Add feature flags
  spiceSupport = true;
  # etc.
}
```

The custom iPXE ROM (`pxe-virtio.rom`) must remain in `${out}/share/qemu/` for Ganeti VMs to network boot.

### Modifying Disk Layouts

For VMs, edit `nixos/layouts/default.nix` `mkLayout` function:

```nix
mkLayout = { vgName ? "pool_state", homeSize ? "1G", swapSize ? "1G" }:
```

Parameters can be customized per-class:

```nix
disko.devices = (import ../layouts).mkLayout {
  homeSize = "10G";
  swapSize = "4G";
};
```

For physical nodes, disk layout is directly in `nixos/classes/ganeti-node.nix` (complex with LVM PVs on both NVMe and HDD).

## Network Configuration

Physical nodes have dual network interfaces:

- **Primary** (`enp0s31f6`): Uplink to 10.1.100.0/24
  - Node IPs: .2 (aleph), .3 (bet), .4 (gimel), .5 (dalet)
  - Cluster IP: .254 (floating)
  - Router: .1 (MikroTik)

- **Secondary** (`enp3s0`): DRBD replication 10.1.97.0/24
  - Node IPs: .2, .3, .4, .5 (same hostname mapping)

VMs use Ganeti-managed networking (OVN or bridged).

Serial console on all physical nodes: `ttyS1` at 19200 baud (Serial over LAN).

## Boot and Provisioning Flow

Understanding this flow is critical for debugging boot issues:

1. **PXE Boot**: Physical machine's NIC requests DHCP + boot file
2. **iPXE Load**: MikroTik serves iPXE NBP, machine executes it
3. **Main Menu**: iPXE loads `http://boot.homelab.tel/nixos/by-mac/{mac}/ipxe`
4. **Class Script**: MAC-based symlink points to class-specific iPXE script
5. **Kernel Boot**: iPXE chainloads `bzImage` and `initrd` from class directory
6. **Disk Provisioning**: `provision-disks.service` checks kernel cmdline:
   - If `homelab.provision_disks=true`: Wipe disks, run disko format, mount
   - Else: Just mount existing filesystems
7. **Key Provisioning**: `provision-keys.service` downloads `{hostname}.tar.gz`:
   - Extracts `root_privkey` to `/root/.ssh/id_ed25519`
   - Extracts `host_privkey` to `/etc/ssh/ssh_host_rsa_key`
8. **SSHD Start**: Starts with provisioned host key
9. **Agenix**: Decrypts secrets using host key
10. **Services**: All other services start with secrets available

To trigger full disk reprovisioning on next boot, add to kernel cmdline:
```
homelab.provision_disks=true
```

## Secrets Management

Secrets use [agenix](https://github.com/ryantm/agenix) with custom oneshot service variant:

- Secrets defined in `nixos/secrets/secrets.nix`
- Encrypted with age using host public keys
- Decrypted by `agenix.service` (oneshot) after keys are provisioned
- Host keys must exist before agenix can decrypt

Common pattern in classes:

```nix
age.secrets.myservice-password = {
  file = ../secrets/myservice-password.age;
  owner = "myservice";
  group = "users";
  mode = "0400";
};

services.myservice.passwordFile = config.age.secrets.myservice-password.path;
```

Encrypting new secrets (requires `agenix` CLI):

```bash
agenix -e myservice-password.age
```

## Module Development Guidelines

### When to Create a Module

Create a new module in `nixos/modules/` when:
1. Configuration will be reused across multiple classes
2. Complex logic needs encapsulation (like provisioning)
3. External service integration needs standardization (like ACME + nginx)

Keep class-specific configuration in the class file.

### Module Structure Template

```nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.mymodule;
in
{
  options.services.mymodule = {
    enable = mkEnableOption "My Module";

    option = mkOption {
      type = types.str;
      default = "value";
      description = "Description";
    };
  };

  config = mkIf cfg.enable {
    # Implementation
    systemd.services.myservice = { ... };
  };
}
```

### Testing Modules Locally

Modules are tested by building a class that uses them:

```bash
# Quick syntax check
nix-instantiate --eval -E 'import ./nixos/modules/mymodule.nix'

# Full build test
nix-build -A test-class.netbuild
```

## Debugging Build Issues

### Common Build Failures

**Ganeti patches don't apply**:
```bash
# Check patch status
nix-build -A ganeti 2>&1 | grep -A 10 "patch"

# Apply patches manually to debug
cd /tmp
nix-build -A ganeti.src
cd result
patch -p1 < ~/git/homelab/ganeti/ganeti-3.1-drbd-compat.patch
```

**Python dependency issues**:
```bash
# Check available Python packages
nix-instantiate --eval -E 'with import ./nix {}; python311.pkgs.bitarray.version'

# Test Python environment
nix-build -A ganeti.buildInputs
```

**Overlay ordering issues**:
```bash
# Check final package
nix-instantiate --eval -E 'with import ./nix {}; qemu.version'

# See overlay application
nix-build -A ganeti --show-trace
```

**Disko formatting failures**:
- Check device paths match actual hardware
- Verify devices aren't mounted
- Look for LVM PV/VG conflicts: `pvs`, `vgs`

### Build Debugging Flags

```bash
# Show full trace
nix-build --show-trace

# Keep build directory on failure
nix-build --keep-failed
# Build dir will be printed, cd there to inspect

# Verbose output
nix-build -v

# Don't use binary cache (force local build)
nix-build --option substitute false
```

## Working with Git

Current uncommitted changes (as of last snapshot):
- Modified: `ganeti/ganeti-3.1-drbd-compat.patch`
- Modified: `nix/overlays/qemu.nix`
- Modified: `nixos/classes/ganeti-node.nix`
- Modified: `nixos/classes/navidrome.nix`
- Untracked: `initrd/`, `netboot.ipxe`, `nix/overlays/pxe-virtio.rom`

When committing:
1. Group related changes (e.g., "Update DRBD to 9.2.15" includes drbd.nix + compat patch)
2. Test build before committing: `nix-build -A ganeti-node.netbuild`
3. For Ganeti changes, run tests: `nix-build -A ganeti`

## OVN Networking

OVN (Open Virtual Network) provides SDN capabilities for VMs:

- **Package**: Custom derivation in `ovn/default.nix` includes both OVN and OVS
- **Module**: `nixos/modules/ovn.nix` configures OVN services
- **Northd**: Runs only on `dalet` (controlled by systemd `ConditionHost=dalet`)
- **Integration**: Ganeti patched to support OVN via `ganeti-3.1-ovn.patch`

All physical nodes run:
- `ovn-controller.service`: Local OVN agent
- `ovs-vswitchd.service`: OVS datapath
- `ovsdb-server.service`: OVS database

Only `dalet` runs:
- `ovn-northd.service`: Central control plane

Configuration in `nixos/classes/ganeti-node.nix`:

```nix
virtualisation.ovn = {
  enable = true;
  openFirewall = true;
};
systemd.services.ovn-northd.unitConfig.ConditionHost = "dalet";
```

## Performance Tuning

Kernel parameters in `nixos/classes/ganeti-node.nix` optimized for DRBD replication:

```nix
boot.kernel.sysctl = {
  "net.ipv4.tcp_slow_start_after_idle" = 0;
  "net.core.rmem_max" = 56623104;
  "net.core.wmem_max" = 56623104;
  # ... see file for full list
};
```

These are from [LINBIT's DRBD performance testing](https://linbit.com/blog/independent-performance-testing-of-drbd-by-e4/). Do not modify without benchmarking.

## References

- **Ganeti Documentation**: https://docs.ganeti.org/
- **DRBD Documentation**: https://linbit.com/drbd-user-guide/
- **OVN Documentation**: https://www.ovn.org/en/
- **Disko Documentation**: https://github.com/nix-community/disko
- **Niv Documentation**: https://github.com/nmattia/niv
