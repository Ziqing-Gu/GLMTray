# GLM Tray 1.0.2 for Windows x64

Run `GLMTray-1.0.2-Windows-x64-Setup.exe` and choose an installation folder. Setup installs the helper for the current Windows user, together with both guides and the license. Install and configure Genelec GLM 5 and your monitoring hardware separately.

Exit any older tray helper before starting the installed `GLMTray.exe`. When switching versions, clear “登录 Windows 后启动助手” (start at sign-in) in the previous helper, then enable it in the new helper. The last installer page offers to start the helper. GLM has its own sign-in entry; keep that enabled if you want GLM to start at sign-in.

The helper hides the main GLM window about ten seconds after it appears. Double-click the green G in the notification area to restore it; check the overflow menu if needed. Minimize GLM to hide it again. Exiting the helper restores GLM. Resolve any GLM settings or error dialogs before hiding it. On the tested workstation, starting GLM before Cubase or Nuendo avoids a startup conflict. Closing GLM itself stops its software MIDI controls.

For portable use, copy the installed GLMTray.exe to any writable folder. It finds GLM using its uninstall registration or the Windows program-files directory. To override a custom location, create GLMTray.ini beside the helper and put GLMPath=your-path-to-GLMv5.exe under [GLMTray]. Absolute paths and paths relative to the helper are supported. For non-ASCII paths, use UTF-16 LE with BOM. After moving the helper, enable start at sign-in again to register its current path. Minimize preferences are stored in that INI. To enable the optional log, add Diagnostics=1 under the same section and restart the helper; GLMTray.log appears beside it.

To uninstall, exit this version of the helper and remove GLM Tray 1.0.2 from Windows Settings → Apps → Installed apps. A standalone copy has no uninstall entry. Turn off its sign-in option and exit it before removing it.

This independent helper is unaffiliated with Genelec. The included Qing Audio Non-Commercial Source-Share License 1.0 covers the first-party code and documentation.
