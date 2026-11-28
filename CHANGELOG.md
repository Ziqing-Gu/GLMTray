# 版本记录 / Changelog

### 1.0.5 · 2026-11-28 · Stable · macOS 菜单栏助手 / macOS menu bar helper

- 已交付的 1.0.5 Windows 和 macOS 安装包已确认为稳定版。Windows 可回滚到上一稳定版 1.0.4。1.0.5 是首个 macOS 稳定版。
- The existing 1.0.5 installers for Windows and macOS were designated Stable. Windows users can roll back to the previous stable version, 1.0.4. This is the first stable version of the Mac helper.
- 新增 macOS 13 及以上版本的菜单栏助手和通用 PKG，同时支持 Apple 芯片和 Intel。首次选定原版 GLM 后，可以隐藏、恢复窗口或选择登录启动。自动隐藏会等到 GLM 离开前台；原版程序的 Dock 图标保留。Windows 使用同版本安装包和双语说明，继续支持原位升级及快捷方式迁移。
- Added a menu bar helper and Universal PKG for macOS 13 or later on Apple silicon and Intel. Select the installed Genelec GLM app once to hide or show it and optionally start the helper at login. Automatic hiding waits for GLM to leave the foreground. The original app keeps its Dock icon. Windows ships at the same version with the existing upgrade and shortcut migration behavior.

### 1.0.4 · 2026-11-21 · Stable · 安装与迁移 / Installation and upgrades

- 安装器默认沿用已安装的位置，也可更换目录。换目录时校验新程序，更新已启用的登录任务和现有快捷方式，再通过旧版卸载程序收尾。已运行的助手会恢复，原有设置和用户文件得到保留。新增中英双语快速上手 TXT。
- Setup reuses the existing folder by default and accepts a new destination. A move verifies the new program, updates its active sign-in task and existing shortcuts, then runs the old uninstaller. A previously running helper resumes. Preferences and user files are preserved. A bilingual plain-text quick start is included.
- 17 项窗口检查和 18 项安装迁移检查通过。在 GLM 5.2.0 的实际安装上，两处现有快捷方式均能恢复窗口。助手空闲时，120 个约一秒的采样区间均未测得超过全机 CPU 的 0.05%。
- All 17 window checks and 18 installer checks passed. Both existing shortcuts restored the GLM 5.2.0 window after an in-place upgrade. In one idle run, the helper stayed within 0.05% of whole-machine CPU in all 120 roughly one-second samples.

### 1.0.3 · 2026-11-21 · 登录启动和程序图标 / Sign-in and application icon

- 登录启动改用当前账户的 Windows 计划任务。助手、托盘和安装包共用绿色监听音箱图标。17 项窗口测试通过。在一次真实 GLM 后台测试中，120 个约一秒区间均未测到助手超过全机 CPU 的 0.05%。
- Moved start at sign-in to a per-user Windows scheduled task and added a green monitor icon to the program, tray and installer. All 17 window checks passed. With GLM hidden, a single 120-interval test measured no one-second sample above 0.05% of whole-machine CPU.

### 1.0.2 · 2026-11-20 · 便携运行 / Portable use

- 支持从可写目录运行。可自动查找 GLM，也可在程序旁的 `GLMTray.ini` 指定安装路径；最小化偏好随副本保存，诊断日志默认关闭。移动助手后须从新位置重新启用登录启动。17 项隔离窗口测试通过；实际 GLM 5.2.0 隐藏运行时，120 个约一秒采样区间内，助手自身均未测到超过全机 CPU 的 0.05%。此值来自一次测量。
- Run from a writable folder. The helper discovers GLM or accepts an override in an adjacent `GLMTray.ini`. Minimize preferences travel with the copy, and diagnostic logging is off by default. Re-enable start at sign-in after moving it. All 17 isolated window tests passed. In one run with GLM 5.2.0 hidden, the helper stayed within 0.05% of whole-machine CPU in all 120 roughly one-second samples.

### 1.0.1 · 2026-11-20 设为 Stable / Designated Stable

- 改为原生 Windows 事件驱动。定位到 GLM 后仅监听目标进程，主窗口出现约十秒后隐藏，并等待设置或错误对话框处理完毕。验证了隐藏、恢复、退出助手和 GLM 重启后的重新识别。此版沿用原工作站的路径配置。
- Switched to native Windows events. Once attached, the helper watches the GLM process, hides its main window after about ten seconds and waits for settings or error dialogs to close. Tests covered hiding, restoring, exiting the helper and reconnecting after GLM restarts. This version used workstation-specific paths.

### 1.0.0 · 2026-11-19 · 首个本地版本 / Initial local version

- 首版 C# 助手每秒查询一次 GLM 窗口，支持托盘隐藏、恢复及登录启动。12 项隔离窗口测试通过，并在 GLM 5.2.0 上验证了隐藏和恢复操作。
- The first C# helper checked for GLM windows once per second and supported hiding, restoring and start at sign-in. Twelve isolated window tests passed, and hide/restore was verified with GLM 5.2.0.
