#!/bin/bash

set -ouex pipefail

# Set OS identity
IMAGE_PRETTY_NAME="RunIO"
IMAGE_LIKE="fedora"
IMAGE_NAME="${IMAGE_NAME:-runio}"
IMAGE_VENDOR="${IMAGE_VENDOR:-runio}"
VERSION="${VERSION:-$(date +%Y%m%d)}"

# Get Fedora version from the base system
if [ -f /usr/lib/os-release ]; then
    . /usr/lib/os-release
    FEDORA_VERSION="${VERSION_ID}"
fi

IMAGE_INFO="/usr/share/ublue-os/image-info.json"
IMAGE_REF="ostree-image-signed:docker://ghcr.io/${IMAGE_VENDOR}/${IMAGE_NAME}"

# Create/update ublue-os image-info.json for KDE Info Center and other tools
mkdir -p /usr/share/ublue-os
cat > "${IMAGE_INFO}" << EOF
{
  "image-name": "${IMAGE_NAME}",
  "image-flavor": "main",
  "image-vendor": "${IMAGE_VENDOR}",
  "image-ref": "${IMAGE_REF}",
  "image-tag": "stable",
  "base-image-name": "aurora",
  "fedora-version": "${FEDORA_VERSION}"
}
EOF

# Modify /usr/lib/os-release to set RunIO branding
sed -i "s|^VARIANT_ID=.*|VARIANT_ID=${IMAGE_NAME}|" /usr/lib/os-release
sed -i "s|^PRETTY_NAME=.*|PRETTY_NAME=\"${IMAGE_PRETTY_NAME} (Version: ${VERSION})\"|" /usr/lib/os-release
sed -i "s|^NAME=.*|NAME=\"${IMAGE_PRETTY_NAME}\"|" /usr/lib/os-release
sed -i "s|^DEFAULT_HOSTNAME=.*|DEFAULT_HOSTNAME=\"${IMAGE_NAME}\"|" /usr/lib/os-release

# Replace ID=fedora and add ID_LIKE in one operation (more reliable than separate replacements)
sed -i "s|^ID=fedora|ID=${IMAGE_NAME}\nID_LIKE=\"${IMAGE_LIKE}\"|" /usr/lib/os-release

# If ID wasn't "fedora", handle it separately
if grep -q "^ID=aurora" /usr/lib/os-release; then
    sed -i "s|^ID=aurora|ID=${IMAGE_NAME}|" /usr/lib/os-release
fi

# Ensure ID_LIKE exists (in case the above replacement didn't add it)
if ! grep -q "^ID_LIKE=" /usr/lib/os-release; then
    echo "ID_LIKE=\"${IMAGE_LIKE}\"" >> /usr/lib/os-release
fi

# Remove Fedora/Red Hat specific fields
sed -i "/^REDHAT_BUGZILLA_PRODUCT=/d; /^REDHAT_BUGZILLA_PRODUCT_VERSION=/d; /^REDHAT_SUPPORT_PRODUCT=/d; /^REDHAT_SUPPORT_PRODUCT_VERSION=/d" /usr/lib/os-release

# Add image identifiers (systemd 249+)
echo "IMAGE_ID=\"${IMAGE_NAME}\"" >> /usr/lib/os-release
echo "IMAGE_VERSION=\"${VERSION}\"" >> /usr/lib/os-release

# Fix issues caused by ID no longer being fedora - critical for bootloader
if [ -f /usr/sbin/grub2-switch-to-blscfg ]; then
    sed -i "s|^EFIDIR=.*|EFIDIR=\"fedora\"|" /usr/sbin/grub2-switch-to-blscfg
fi

echo "OS branding set to: ${IMAGE_PRETTY_NAME}"
