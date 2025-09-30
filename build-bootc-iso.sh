#!/usr/bin/env bash
set -euo pipefail

# Universal bootc ISO Builder Script
# Usage: ./build-bootc-iso.sh [bootc-image] [config-file]
# Examples:
#   ./build-bootc-iso.sh
#   ./build-bootc-iso.sh quay.io/centos-bootc/centos-bootc:stream10
#   ./build-bootc-iso.sh registry.redhat.io/rhel9/rhel-bootc:latest my-config.toml
#   ./build-bootc-iso.sh quay.io/fedora/fedora-bootc:40 config.toml

BOOTC_IMAGE="${1:-quay.io/centos-bootc/centos-bootc:stream10}"
CONFIG_FILE="${2:-config.toml}"
OUTPUT_DIR="$(pwd)/output"
BUILDER_IMAGE="quay.io/centos-bootc/bootc-image-builder:latest"

echo "[INFO] Building ISO for bootc image: $BOOTC_IMAGE"
echo "[INFO] Using config: $CONFIG_FILE"
echo "[INFO] Output directory: $OUTPUT_DIR"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Validate bootc image format
if [[ ! "$BOOTC_IMAGE" =~ ^[a-zA-Z0-9._/-]+:[a-zA-Z0-9._-]+$ ]]; then
    echo "[ERROR] Invalid bootc image format: $BOOTC_IMAGE"
    echo "Expected format: registry/namespace/image:tag"
    echo "Examples:"
    echo "  quay.io/centos-bootc/centos-bootc:stream10"
    echo "  registry.redhat.io/rhel9/rhel-bootc:latest"
    echo "  quay.io/fedora/fedora-bootc:40"
    exit 1
fi

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "[ERROR] Config file not found: $CONFIG_FILE"
    echo "Available configs:"
    ls -1 *.toml 2>/dev/null || echo "  No .toml files found"
    exit 1
fi

echo "[INFO] Pulling images..."
podman pull "$BUILDER_IMAGE"
podman pull "$BOOTC_IMAGE"

echo "[INFO] Building Anaconda ISO..."
echo "This may take 10-30 minutes depending on your system."

sudo podman run --rm -it --privileged \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v "$OUTPUT_DIR:/output:Z" \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    -v "$(pwd)/$CONFIG_FILE:/config.toml:Z" \
    "$BUILDER_IMAGE" \
    --type anaconda-iso \
    --config /config.toml \
    "$BOOTC_IMAGE"

if [[ $? -eq 0 ]]; then
    echo "[SUCCESS] ISO build completed!"
    echo "[INFO] Built from bootc image: $BOOTC_IMAGE"
    echo "Output files:"
    ls -la "$OUTPUT_DIR"
    
    # Find and display ISO details
    ISO_FILE=$(find "$OUTPUT_DIR" -name "*.iso" | head -n 1)
    if [[ -n "$ISO_FILE" ]]; then
        ISO_SIZE=$(du -h "$ISO_FILE" | cut -f1)
        echo "[INFO] Generated ISO: $(basename "$ISO_FILE") (${ISO_SIZE})"
        echo "[INFO] This ISO provides full interactive Anaconda installer"
        echo "[INFO] Based on: $BOOTC_IMAGE"
    fi
else
    echo "[ERROR] Build failed. Check the output above for details."
    exit 1
fi