# vim: set ft=make :

# Start here: base config, apps, KDE defaults, and Framework tools if applicable
[group('RunIO')]
setup-runio-all: setup-runio-base setup-runio-apps setup-runio-kde
    #!/usr/bin/bash
    set -euo pipefail
    # Install framework-tool on Framework laptops
    if [[ -d /sys/class/dmi/id ]] && grep -qi "framework" /sys/class/dmi/id/board_vendor 2>/dev/null; then
        if command -v brew &>/dev/null; then
            echo "Framework laptop detected, installing framework-tool..."
            brew install framework-tool || echo "Note: framework-tool installation failed"
        fi
    fi
    echo ""
    echo "RunIO setup complete!"

# Configure Flathub, install base flatpaks, and add ublue-os homebrew tap
[group('RunIO')]
setup-runio-base:
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
    brew tap ublue-os/tap || true

    echo ""
    echo "RunIO base setup complete!"

# Install all RunIO apps (Gear Lever, Vorta, pCloud, Fastmail, etc.)
[group('RunIO')]
setup-runio-apps: install-gearlever install-vorta install-pcloud install-fastmail
    #!/usr/bin/bash
    echo "All Run apps installed successfully!"

# KDE defaults: 24h clock with custom date format
[group('RunIO')]
setup-runio-kde:
    #!/usr/bin/bash
    set -euo pipefail
    echo "Configuring KDE Plasma with RunIO defaults..."

    PLASMA_CONFIG="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"

    if [[ ! -f "$PLASMA_CONFIG" ]]; then
        echo "Error: Plasma config not found at $PLASMA_CONFIG"
        echo "Please log into KDE Plasma first and try again."
        exit 1
    fi

    # === Configure digital clock ===
    echo ""
    echo "Configuring digital clock..."

    # Find the digitalclock applet
    CLOCK_ID=$(grep -B5 "plugin=org.kde.plasma.digitalclock" "$PLASMA_CONFIG" | grep -oP '\[Containments\]\[\d+\]\[Applets\]\[\d+\]' | head -1)

    if [[ -z "$CLOCK_ID" ]]; then
        echo "Warning: Could not find digital clock applet."
    else
        CLOCK_CONTAINMENT=$(echo "$CLOCK_ID" | grep -oP 'Containments\]\[\K\d+')
        CLOCK_APPLET=$(echo "$CLOCK_ID" | grep -oP 'Applets\]\[\K\d+')

        echo "Found digital clock: Containment $CLOCK_CONTAINMENT, Applet $CLOCK_APPLET"

        # Set 24-hour format (2 = 24h, 0 = 12h)
        kwriteconfig6 --file "$PLASMA_CONFIG" \
            --group "Containments" --group "$CLOCK_CONTAINMENT" \
            --group "Applets" --group "$CLOCK_APPLET" \
            --group "Configuration" --group "Appearance" \
            --key "use24hFormat" "2"

        # Set custom date format
        kwriteconfig6 --file "$PLASMA_CONFIG" \
            --group "Containments" --group "$CLOCK_CONTAINMENT" \
            --group "Applets" --group "$CLOCK_APPLET" \
            --group "Configuration" --group "Appearance" \
            --key "dateFormat" "custom"

        kwriteconfig6 --file "$PLASMA_CONFIG" \
            --group "Containments" --group "$CLOCK_CONTAINMENT" \
            --group "Applets" --group "$CLOCK_APPLET" \
            --group "Configuration" --group "Appearance" \
            --key "customDateFormat" "MMM d"

        echo "Digital clock configured: 24h format, 'MMM d' date format"
    fi

    echo ""
    echo "KDE Plasma configuration complete! Restarting Plasma..."
    kquitapp6 plasmashell && kstart plasmashell &
    echo "Plasma restarted successfully."

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

# Install Fastmail - Email client, add to Internet category
[group('Apps')]
install-fastmail:
    #!/usr/bin/bash
    set -euo pipefail
    echo "Installing Fastmail from Flathub..."
    if grep -q 'com.fastmail.Fastmail' < <(flatpak list --columns=application); then
        echo "Fastmail is already installed, skipping installation."
    else
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        flatpak install --system -y flathub com.fastmail.Fastmail
        echo "Fastmail installed successfully!"
    fi

    # Configure Fastmail in app launcher: Internet category, after Brave (alphabetically)
    echo "Configuring Fastmail in app launcher..."
    LOCAL_APPS_DIR="$HOME/.local/share/applications"
    FASTMAIL_DESKTOP="com.fastmail.Fastmail.desktop"
    FLATPAK_DESKTOP="/var/lib/flatpak/exports/share/applications/$FASTMAIL_DESKTOP"

    mkdir -p "$LOCAL_APPS_DIR"

    if [[ -f "$FLATPAK_DESKTOP" ]]; then
        # Copy the flatpak desktop file and ensure it's in the Internet (Network) category
        cp "$FLATPAK_DESKTOP" "$LOCAL_APPS_DIR/$FASTMAIL_DESKTOP"

        # Ensure Categories includes Network (shows as "Internet" in KDE)
        if grep -q "^Categories=" "$LOCAL_APPS_DIR/$FASTMAIL_DESKTOP"; then
            # Update existing Categories line to include Network
            if ! grep -q "Network" "$LOCAL_APPS_DIR/$FASTMAIL_DESKTOP"; then
                sed -i 's/^Categories=/Categories=Network;/' "$LOCAL_APPS_DIR/$FASTMAIL_DESKTOP"
            fi
        else
            # Add Categories line
            echo "Categories=Network;Email;" >> "$LOCAL_APPS_DIR/$FASTMAIL_DESKTOP"
        fi
        echo "Fastmail configured in Internet category (appears after Brave alphabetically)."
    else
        echo "Note: Flatpak desktop file not found, skipping app launcher configuration."
    fi
