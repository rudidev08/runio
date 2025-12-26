# vim: set ft=make :

# Configure KDE Plasma with RunIO defaults:
# - Icons-only task manager: Brave, Steam, Dolphin, Terminal
# - Digital clock: 24h format, "MMM d" date format
[group('System')]
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

    # === Configure icons-only task manager ===
    echo ""
    echo "Configuring icons-only task manager..."

    # Define the launchers we want: Brave, Steam, Dolphin, Terminal
    LAUNCHERS="applications:com.brave.Browser.desktop,applications:steam.desktop,preferred://filemanager,applications:org.gnome.Ptyxis.desktop"

    # Find the icontasks applet section and update launchers
    ICONTASKS_ID=$(grep -B5 "plugin=org.kde.plasma.icontasks" "$PLASMA_CONFIG" | grep -oP '\[Containments\]\[\d+\]\[Applets\]\[\d+\]' | head -1)

    if [[ -z "$ICONTASKS_ID" ]]; then
        echo "Warning: Could not find icons-only task manager applet."
        echo "Make sure you have the icons-only task manager widget on your panel."
    else
        # Extract the group path for kwriteconfig6
        CONTAINMENT_NUM=$(echo "$ICONTASKS_ID" | grep -oP 'Containments\]\[\K\d+')
        APPLET_NUM=$(echo "$ICONTASKS_ID" | grep -oP 'Applets\]\[\K\d+')

        echo "Found icontasks applet: Containment $CONTAINMENT_NUM, Applet $APPLET_NUM"

        kwriteconfig6 --file "$PLASMA_CONFIG" \
            --group "Containments" --group "$CONTAINMENT_NUM" \
            --group "Applets" --group "$APPLET_NUM" \
            --group "Configuration" --group "General" \
            --key "launchers" "$LAUNCHERS"

        echo "Task manager configured with: Brave, Steam, Dolphin, Terminal"
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
    echo "KDE Plasma configuration complete!"
    echo "Please restart Plasma or log out/in for changes to take effect."
    echo "Quick restart: kquitapp6 plasmashell && kstart plasmashell"

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

# Install Fastmail - Email client, add to Internet category, and add to taskbar after Brave
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

    # Add Fastmail to taskbar after Brave
    PLASMA_CONFIG="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
    FASTMAIL_LAUNCHER="applications:com.fastmail.Fastmail.desktop"

    if [[ ! -f "$PLASMA_CONFIG" ]]; then
        echo "Note: Plasma config not found, skipping taskbar configuration."
        exit 0
    fi

    # Find the icontasks applet
    APPLET_ID=$(grep -B5 "plugin=org.kde.plasma.icontasks" "$PLASMA_CONFIG" | grep -oP '\[Containments\]\[\d+\]\[Applets\]\[\d+\]' | head -1)

    if [[ -z "$APPLET_ID" ]]; then
        echo "Note: Icons-only task manager not found, skipping taskbar configuration."
        exit 0
    fi

    # Extract containment and applet numbers
    CONTAINMENT_NUM=$(echo "$APPLET_ID" | grep -oP 'Containments\]\[\K\d+')
    APPLET_NUM=$(echo "$APPLET_ID" | grep -oP 'Applets\]\[\K\d+')

    # Get current launchers
    CURRENT_LAUNCHERS=$(kreadconfig6 --file "$PLASMA_CONFIG" \
        --group "Containments" --group "$CONTAINMENT_NUM" \
        --group "Applets" --group "$APPLET_NUM" \
        --group "Configuration" --group "General" \
        --key "launchers")

    # Check if Fastmail is already in the taskbar
    if echo "$CURRENT_LAUNCHERS" | grep -q "com.fastmail.Fastmail"; then
        echo "Fastmail is already on the taskbar."
        exit 0
    fi

    # Insert Fastmail after Brave (com.brave.Browser.desktop)
    if echo "$CURRENT_LAUNCHERS" | grep -q "com.brave.Browser"; then
        # Insert Fastmail after Brave
        NEW_LAUNCHERS=$(echo "$CURRENT_LAUNCHERS" | sed "s|com.brave.Browser.desktop|com.brave.Browser.desktop,$FASTMAIL_LAUNCHER|")
    else
        # Brave not found, prepend Fastmail
        NEW_LAUNCHERS="$FASTMAIL_LAUNCHER,$CURRENT_LAUNCHERS"
    fi

    # Update the taskbar
    kwriteconfig6 --file "$PLASMA_CONFIG" \
        --group "Containments" --group "$CONTAINMENT_NUM" \
        --group "Applets" --group "$APPLET_NUM" \
        --group "Configuration" --group "General" \
        --key "launchers" "$NEW_LAUNCHERS"

    echo "Fastmail added to taskbar after Brave."
    echo "Restart Plasma for changes to take effect: kquitapp6 plasmashell && kstart plasmashell"

# Install all RunIO apps (Gear Lever, Vorta, pCloud, Fastmail, etc.)
[group('Apps')]
install-runio-apps: install-gearlever install-vorta install-pcloud install-fastmail
    #!/usr/bin/bash
    echo "All Run apps installed successfully!"
