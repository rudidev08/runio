# vim: set ft=make :

# Run first-boot setup for RunIO (useful after rebasing)
[group('System')]
setup-runio:
    #!/usr/bin/bash
    set -euo pipefail
    echo "Running RunIO first-boot setup..."
    echo ""

    # Ensure Flathub is configured
    echo "Ensuring Flathub remote is configured..."
    flatpak remote-add --if-not-exists --system flathub https://flathub.org/repo/flathub.flatpakrepo

    # Install recommended flatpaks
    echo "Installing recommended Flatpaks..."
    FLATPAKS=(
        "io.github.kolunmi.Bazaar"
    )
    for app in "${FLATPAKS[@]}"; do
        if ! flatpak list --system --columns=application | grep -q "^${app}$"; then
            echo "Installing ${app}..."
            flatpak install --system -y flathub "${app}" || echo "Note: ${app} may already be installed or unavailable"
        else
            echo "${app} is already installed"
        fi
    done

    # Add ublue-os homebrew tap
    echo "Adding ublue-os homebrew tap..."
    brew tap ublue-os/tap
    echo "See: https://github.com/ublue-os/homebrew-tap"
    if [[ -d /sys/class/dmi/id ]] && grep -qi "framework" /sys/class/dmi/id/board_vendor 2>/dev/null; then
        echo "Framework laptop detected! Install 'framework' tool: brew install framework"
    fi

    echo ""
    echo "RunIO setup complete!"
    echo "You may need to log out and back in for all changes to take effect."
    echo ""
    echo "Tip: Run 'ujust install-runio-apps' to install recommended applications."

# Install an AppImage file from a local file or URL (internal helper)
[private]
_install-appimage-file appimage_src filename="":
    #!/usr/bin/bash
    set -eo pipefail
    APPIMAGE_SRC="{{ appimage_src }}"
    FILENAME="{{ filename }}"
    DOWNLOAD_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ujust/appimages"
    mkdir -p "$DOWNLOAD_DIR"
    trap "rm -rf $DOWNLOAD_DIR" EXIT

    appimage_file="$DOWNLOAD_DIR/${FILENAME:-${APPIMAGE_SRC##*/}}"

    # Install Gear Lever if not already installed
    if ! flatpak list --columns=application | grep -q 'it.mijorus.gearlever'; then
        flatpak install --system -y flathub it.mijorus.gearlever
    fi

    # Download or copy the AppImage
    if [[ $APPIMAGE_SRC =~ ^https?:// ]]; then
        echo "Downloading $APPIMAGE_SRC to $appimage_file"
        wget -nv "$APPIMAGE_SRC" -O "$appimage_file" && echo "Download complete"
    else
        cp "$APPIMAGE_SRC" "$appimage_file"
    fi

    chmod +x "$appimage_file"
    echo "Opening Gear Lever - Click 'Move to the app menu' to finish installation."
    sleep 3
    LC_ALL=C flatpak run it.mijorus.gearlever "$appimage_file"

# Install Gear Lever - AppImage manager
[group('Apps')]
install-gearlever:
    #!/usr/bin/bash
    set -euo pipefail
    echo "Installing Gear Lever..."
    if grep -q 'it.mijorus.gearlever' < <(flatpak list --columns=application); then
        echo "Gear Lever is already installed, skipping."
    else
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        flatpak install --system -y flathub it.mijorus.gearlever
        echo "Gear Lever installed successfully!"
    fi

# Install Vorta Backup - A desktop client for BorgBackup
[group('Apps')]
install-vorta:
    #!/usr/bin/bash
    set -euo pipefail
    echo "Installing Vorta from Flathub..."
    if grep -q 'com.borgbase.Vorta' < <(flatpak list --columns=application); then
        echo "Vorta is already installed, skipping."
    else
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        flatpak install --system -y flathub com.borgbase.Vorta
        echo "Vorta installed successfully!"
    fi

# Install pCloud - Cloud storage client (64-bit)
[group('Apps')]
install-pcloud:
    @echo "Download pCloud from: https://www.pcloud.com/download-free-online-cloud-file-storage.html"

# Install Fastmail - Email client
[group('Apps')]
install-fastmail:
    #!/usr/bin/bash
    set -euo pipefail
    echo "Installing Fastmail from Flathub..."
    if grep -q 'com.fastmail.Fastmail' < <(flatpak list --columns=application); then
        echo "Fastmail is already installed, skipping."
    else
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        flatpak install --system -y flathub com.fastmail.Fastmail
        echo "Fastmail installed successfully!"
    fi

# Install all RunIO apps (Gear Lever, Vorta, pCloud, Fastmail, etc.)
[group('Apps')]
install-runio-apps: install-gearlever install-vorta install-pcloud install-fastmail
    #!/usr/bin/bash
    echo "All Run apps installed successfully!"
