#!/usr/bin/env bash
set -euo pipefail

# Universal bootc ISO Builder Script
# Usage: ./build-bootc-iso.sh [bootc-image] [config-file] [iso-name]
# Examples:
#   ./build-bootc-iso.sh
#   ./build-bootc-iso.sh quay.io/centos-bootc/centos-bootc:stream10
#   ./build-bootc-iso.sh registry.redhat.io/rhel9/rhel-bootc:latest my-config.toml
#   ./build-bootc-iso.sh quay.io/fedora/fedora-bootc:40 config.toml fedora-40-custom

BOOTC_IMAGE="${1:-quay.io/centos-bootc/centos-bootc:stream10}"
CONFIG_FILE="${2:-config.toml}"
ISO_NAME="${3:-}"
OUTPUT_DIR="$(pwd)/output"
BUILDER_IMAGE="quay.io/centos-bootc/bootc-image-builder:latest"

# Generate ISO name if not provided
if [[ -z "$ISO_NAME" ]]; then
    # Extract image name and tag for auto-naming
    IMAGE_NAME_TAG=$(echo "$BOOTC_IMAGE" | sed 's|.*/||' | sed 's/:/-/g')
    ISO_NAME="${IMAGE_NAME_TAG}-bootc-$(date +%Y%m%d)"
    echo "[INFO] Auto-generated ISO name: $ISO_NAME"
else
    # Remove .iso extension if provided
    ISO_NAME="${ISO_NAME%.iso}"
    echo "[INFO] Using custom ISO name: $ISO_NAME"
fi

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

# Check which container runtime to use and build accordingly
if command -v podman >/dev/null 2>&1 && podman info >/dev/null 2>&1; then
    echo "[INFO] Using Podman..."
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
elif command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    echo "[INFO] Using Docker..."
    docker run --rm -it --privileged \
        --pull always \
        -v "$OUTPUT_DIR:/output" \
        -v "$(pwd)/$CONFIG_FILE:/config.toml" \
        "$BUILDER_IMAGE" \
        --type anaconda-iso \
        --config /config.toml \
        "$BOOTC_IMAGE"
else
    echo "[ERROR] No working container runtime found (podman or docker)"
    exit 1
fi

if [[ $? -eq 0 ]]; then
    echo "[SUCCESS] ISO build completed!"
    echo "[INFO] Built from bootc image: $BOOTC_IMAGE"
    
    # Find the generated ISO file
    ISO_FILE=$(find "$OUTPUT_DIR" -name "*.iso" | head -n 1)
    if [[ -n "$ISO_FILE" ]]; then
        ISO_SIZE=$(du -h "$ISO_FILE" | cut -f1)
        NEW_ISO_NAME="${ISO_NAME}.iso"
        NEW_ISO_PATH="$OUTPUT_DIR/$NEW_ISO_NAME"
        
        # Rename the ISO if it's not already named correctly
        if [[ "$(basename "$ISO_FILE")" != "$NEW_ISO_NAME" ]]; then
            echo "[INFO] Renaming ISO from '$(basename "$ISO_FILE")' to '$NEW_ISO_NAME'..."
            if mv "$ISO_FILE" "$NEW_ISO_PATH" 2>/dev/null; then
                echo "[SUCCESS] ISO renamed successfully!"
            else
                echo "[WARNING] Failed to rename ISO, keeping original name"
                NEW_ISO_NAME=$(basename "$ISO_FILE")
            fi
        fi
        
        echo "[INFO] Generated ISO: $NEW_ISO_NAME (${ISO_SIZE})"
        echo "[INFO] This ISO provides full interactive Anaconda installer"
        echo "[INFO] Based on: $BOOTC_IMAGE"
        echo "[INFO] Location: $OUTPUT_DIR"
    fi
    
    echo "Output files:"
    ls -la "$OUTPUT_DIR"
else
    echo "[ERROR] Build failed. Check the output above for details."
    exit 1
fi