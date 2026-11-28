# GLM Tray 1.0.5 · Installation and use

## macOS 13 or later · Apple silicon and Intel

1. Open `Mac/GLMTray-1.0.5-macOS-Universal.pkg` from the combined ZIP and follow Installer. The same file supports both processors. It installs `/Applications/GLM Tray.app`. Quit a running copy of the helper from its menu before upgrading.
2. Open **GLM Tray** from Applications. On first use, select the **Genelec GLM application** you use for monitoring. If you move that app, select it again from the menu. The helper starts Genelec GLM only when you explicitly choose **Open GLM**.
3. Use the speaker in the menu bar to hide or show GLM. Automatic hiding is enabled initially. About ten seconds after attaching to GLM, the helper hides it when another app is frontmost. You can keep using a foreground settings or calibration window. A manually restored window stays visible until you hide it again or restart GLM.
4. Select **Open GLM Tray at login**. macOS may ask for approval under System Settings → General → Login Items. You can also add the installed helper under Open at Login. The helper waits for GLM to start normally.
5. Quitting the helper restores a window it hid. The helper lives in the menu bar. The running Genelec application retains its own Dock icon. GLM continues to handle the existing MIDI mapping, monitor level and mute.

**First installation and security.** The PKG has no Developer ID Installer signature. The app has an ad hoc signature and has not been notarized by Apple. Gatekeeper may block a downloaded copy. Verify the source and follow your own or your organization's security policy. [Apple guidance on safely opening apps](https://support.apple.com/en-us/102445)

**Hardware check.** At your existing listening level, confirm the controller works with GLM visible, hide GLM, toggle mute and restore it, then show GLM again. If the DAW and GLM compete for a device, start Genelec GLM before Cubase or Nuendo. To uninstall, remove the login item, quit the helper and move GLM Tray from Applications to the Trash.

## Windows 10/11 x64

Run `GLMTray-1.0.5-Windows-x64-Setup.exe`. This unsigned installer installs for the current Windows account. A first install defaults to the user's programs folder. On the destination page, browse to any dedicated folder you can write to. Install and configure Genelec GLM 5 and your monitors separately.

**Upgrade an installed copy.** Setup selects the previous installation directory by default. Keep it to update in place, or browse to a different folder to move. For a move, Setup verifies the new files, transfers the sign-in preference and applicable shortcuts, then runs the old helper's uninstaller. If the installed helper was running, Setup briefly closes it and starts the installed version again. Genelec GLM can stay open. Portable copies run from any writable folder. Exit a separate portable instance yourself before upgrading.

**Existing shortcuts.** Keep using your existing Start menu entry and shortcuts on the desktop or in its immediate subfolders, such as a music production folder. When you move the installation, Setup updates the existing links in place, preserving their names, locations and launch arguments. It does not recreate a removed desktop icon.

**Settings and files.** Settings live in `GLMTray.ini` beside the helper. A move copies your preferences to the destination if it has no INI of its own. User-created files, the original INI and logs remain in the old folder. Set `GLMPath=your-path` under `[GLMTray]` for a custom GLM installation. Absolute paths and paths relative to the helper are supported. Use UTF-16 LE with a BOM for non-ASCII paths. Set `Diagnostics=1` and restart the helper to enable its optional log.

**Tray and monitoring.** The GLM main window hides after about ten seconds. Double-click the green monitor icon to restore it; check the notification area's overflow menu if needed. Resolve GLM settings or error dialogs first. Right-click the icon to toggle start at sign-in. This logon task starts the helper. Keep using GLM's own startup and MIDI settings. If GLM reports a device conflict with Cubase or Nuendo, start GLM before the DAW.

**Uninstall.** Remove GLM Tray in Windows Settings → Apps → Installed apps. Setup removes the installed files and the sign-in task belonging to this copy. For a portable copy, disable its sign-in option and exit the helper first.

This independent Qing Audio utility is unaffiliated with Genelec. Use and distribution are governed by the included Qing Audio Non-Commercial Source-Share License 1.0.
