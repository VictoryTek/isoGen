# CentOS Stream 10 bootc Anaconda ISO Builder

This project creates CentOS Stream 10 bootc-based Anaconda installer ISOs with full interactive capabilities including user creation, disk partitioning, network setup, and software selection.

## ✅ Your Current Setup Works!

Your existing command and `config.toml` will create a **fully functional interactive Anaconda ISO**:

```bash
sudo podman run --rm -it --privileged --pull=newer --security-opt label=type:unconfined_t \
  -v ~/Projects/ISO/centos-bootc:/output:Z \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  -v ~/Projects/ISO/centos-bootc/config.toml:/config.toml:Z \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type anaconda-iso --config /config.toml \
  quay.io/centos-bootc/centos-bootc:stream10
```

Your `config.toml` enables:
- ✅ Interactive mode
- ✅ User account creation screens
- ✅ Storage/partitioning interface  
- ✅ Network configuration UI

## Quick Start Options

### Option 1: Use Your Current Setup (Recommended)
Run your existing command - it's perfectly configured!

### Option 2: Use Enhanced Config
```bash
# Windows PowerShell
.\build-bootc-iso.ps1 config-enhanced.toml

# Linux
./build-bootc-iso.sh config-enhanced.toml
```

### Option 3: Use Build Scripts
```bash
# Windows - uses your current config.toml
.\build-bootc-iso.ps1

# Linux - uses your current config.toml  
./build-bootc-iso.sh
```

## Files in This Project

### Core Files
- **`config.toml`** - Your working configuration (keep using this!)
- **`config-enhanced.toml`** - Enhanced version with more packages
- **`bootc-interactive.ks`** - Standalone kickstart alternative

### Build Scripts
- **`build-bootc-iso.ps1`** - Windows PowerShell build script
- **`build-bootc-iso.sh`** - Linux bash build script

## Prerequisites

- **Podman** (or Docker with podman compatibility)
- **Linux host recommended** (Windows with Podman Desktop works)
- **10-15 GB free space** for build and output
- **Internet connection** for container image pulls
- **Privileged execution** (sudo/administrator)

## What You Get

The resulting ISO provides:

🖥️ **Full Anaconda Installer Interface**
- Graphical or text-mode installation
- Language and keyboard selection
- User account creation with password/SSH key setup
- Network configuration (DHCP/static)
- Disk partitioning (automatic or custom)
- Software package selection
- System configuration options

🚀 **Modern bootc Technology**
- Image-based OS updates via ostree
- Atomic upgrades and rollbacks  
- Container-native workflows
- Immutable base system with flexible /var

## Advanced Usage

### Custom Packages
Add to your `config.toml`:
```toml
[[customizations.rpm]]
name = "package-name"
```

### Custom Services
```toml
[customizations.services]
enabled = ["service1", "service2"]
disabled = ["unwanted-service"]
```

### Kernel Parameters
```toml
[customizations.kernel]
append = "custom.option=value"
```

## Troubleshooting

### Missing Interactive Options
- Ensure `interactive` is in kickstart section
- Verify installer modules are enabled in config

### Build Failures
- Check podman/sudo privileges
- Verify `/dev/fuse` access on host
- Ensure sufficient disk space (15+ GB)
- Try `podman system prune` to clean up

### Slow Builds
- First build downloads large images (2-4 GB)
- Subsequent builds use cached layers
- Build time: 10-30 minutes typical

### Windows-Specific Issues
- Use PowerShell (not Command Prompt)
- Ensure Podman Desktop is running
- Check WSL2 integration if using WSL

## Security Notes

🔒 **For Production Use:**
- Replace any sample passwords with secure ones
- Consider secure boot and image signing
- Review and customize firewall rules
- Implement proper user management policies

## What's Different from Standard CentOS

This creates a **bootc-based system** which means:
- OS updates via container images (not individual packages)
- Atomic upgrades with automatic rollback on failure
- Base system is largely immutable
- Applications via containers/flatpaks preferred
- Traditional package management available in /usr/local

## Support and Resources

- [CentOS bootc Documentation](https://docs.centos.org/en-US/stream-10-development/bootc/)
- [bootc-image-builder GitHub](https://github.com/osbuild/bootc-image-builder)
- [Anaconda Kickstart Reference](https://pykickstart.readthedocs.io/)

## License

This project configuration is provided as-is for educational and development purposes.