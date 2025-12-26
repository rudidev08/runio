#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 install -y tmux

# Install Steam from RPM Fusion (critical package - must succeed)
dnf5 install -y steam

# Install gamescope for Steam integration and CLI use
# Core gamescope is critical, but some additional packages may not exist in all repos
dnf5 install -y gamescope
dnf5 install -y --skip-unavailable \
    gamescope-libs \
    gamescope-shaders \
    gamescope-session-plus \
    gamescope-session-steam

# Add Brave Browser repository and install
dnf5 config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
dnf5 install -y brave-browser

# Add 1Password repository and install
rpm --import https://downloads.1password.com/linux/keys/1password.asc
cat <<EOF > /etc/yum.repos.d/1password.repo
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
EOF
dnf5 install -y 1password

# Add Visual Studio Code repository and install
rpm --import https://packages.microsoft.com/keys/microsoft.asc
cat <<EOF > /etc/yum.repos.d/vscode.repo
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
dnf5 install -y code

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

### Remove unwanted packages from base aurora image

# Remove Thunderbird if installed
if rpm -q thunderbird &>/dev/null; then
    dnf5 -y remove thunderbird
fi

#### Enable System Services

systemctl enable podman.socket
