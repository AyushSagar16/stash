# Stash v0.1.1 Release Notes

Stash is distributed as an unsigned macOS DMG for this release.

This patch fixes a crash that could happen when the overlay was shown.

## Install

1. Download `Stash-v0.1.1.dmg` from the GitHub Release.
2. Open the DMG.
3. Drag `Stash.app` into `Applications`.
4. Launch from `Applications`.

Because this build is unsigned and not notarized, macOS may block the first launch. If that happens, right-click `Stash.app`, choose `Open`, then confirm the launch.

## First Run

Stash runs without a Dock icon or menu bar icon.

- Allow Notifications when prompted.
- Enable Stash in System Settings -> Privacy & Security -> Accessibility.
- Restart Stash after granting Accessibility: `pkill -x Stash && open /Applications/Stash.app`.

Double-tap Control to show the overlay.
