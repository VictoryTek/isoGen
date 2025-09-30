# Standalone interactive kickstart for CentOS Stream 10 bootc
#version=DEVEL

# Enable full interactive mode - all screens available
interactive

# Default language and keyboard (user can change)
lang en_US.UTF-8
keyboard us

# Default timezone (user can change)
timezone UTC --utc

# Use graphical installer if available
graphical

# Network configuration (user can modify)
network --bootproto=dhcp --device=link --activate
network --hostname=centos-bootc

# Security settings
firewall --enabled --service=ssh
selinux --enforcing
eula --agreed

# Services to enable
services --enabled=sshd,chronyd,NetworkManager

# This is where bootc-image-builder will inject the ostree setup
# The user will see storage configuration screens for partitioning

# Minimal package selection (user can add more via software selection)
%packages
@core
NetworkManager
NetworkManager-wifi
chrony
openssh-server
%end

# Post-installation customization
%post --log=/var/log/anaconda/post-install.log
# Set up bootc update automation
systemctl enable ostree-remount.service

# Create bootc update timer (optional)
cat > /etc/systemd/system/bootc-update.timer << 'EOF'
[Unit]
Description=Check for bootc updates daily
Requires=network-online.target
After=network-online.target

[Timer]
OnBootSec=30m
OnUnitInactiveSec=1d

[Install]
WantedBy=timers.target
EOF

systemctl enable bootc-update.timer
%end

# Reboot after installation
reboot