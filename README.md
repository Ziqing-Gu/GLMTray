# GLM Tray

## 1. 产品介绍 / About the product

用 MIDI 控制器调节 Genelec 监听系统时，GLM 可以留在 Windows 后台。GLM Tray 会在识别到 GLM 主窗口约十秒后将它隐藏，让任务栏留给音频工作站。原有 MIDI 映射和音量控制仍由 GLM 处理。双击通知区域里的绿色监听音箱图标可以打开主窗口，退出助手也会恢复窗口。遇到设置或错误对话框时，助手会等你处理完再隐藏。

GLM Tray keeps the Genelec GLM main window in the Windows notification area while you work in your DAW. About ten seconds after the window appears, the helper hides it. GLM continues to handle your existing MIDI mappings and monitor levels. Double-click the green monitor icon in the tray to bring the window back, or exit the helper to restore it. If GLM opens a settings or error dialog, the helper waits until you finish with it.

1.0.5 增加 macOS 菜单栏助手。首次选择原版 GLM 后，可以隐藏、显示并继续使用原有 MIDI 控制器。macOS 13 或更新版本支持 Apple 芯片和 Intel。同一版本提供 Windows x64 EXE 与 macOS 通用 PKG。原版 GLM 在 Mac 的程序坞中仍保留图标。

Version 1.0.5 adds a native macOS menu bar helper for Apple silicon and Intel on macOS 13 or later. Select your installed Genelec GLM app, then hide or show it from the menu bar. The original GLM app retains its Dock icon. The Windows x64 installer and macOS Universal PKG share the same version.

本工具由 Qing Audio 独立提供。Genelec GLM 与监听硬件需另行安装、配置。 / An independent Qing Audio utility, unaffiliated with Genelec. Install and configure Genelec GLM and your monitoring hardware separately.

## 2. 许可证 / License

### ⚠️ 禁止商业使用 / NO COMMERCIAL USE

**Qing Audio 非商业源码共享许可证 1.0 / Qing Audio Non-Commercial Source-Share License 1.0**

**本项目源码公开，但不属于 OSI 认可的开源软件。 / Source is available, but this is not OSI-approved open-source software.**

> **禁止任何商业使用。** 仅允许个人、学习、教育、研究、评估、爱好及其他非商业用途。发布原版、二进制版或修改版时，必须同时免费公开完整对应源代码，保留作者、版权和许可证声明，醒目标明原项目名称、作者、来源链接、修改者、修改日期及修改内容，并使整个修改版继续采用同一许可证。完整条款见 [LICENSE](LICENSE)。
>
> **NO COMMERCIAL USE.** Use is permitted only for personal, educational, research, evaluation, hobby, charitable, and other non-commercial purposes. Any distributed original, binary, or modified version must provide the complete corresponding source without charge, preserve authorship, copyright, and license notices, prominently identify the original project, author, source URL, modifier, date, and changes, and license the entire modified work under the same terms. See [LICENSE](LICENSE).
>
> 许可证政策变更与后续 AI 维护说明见 [LICENSE_POLICY_CHANGE.md](LICENSE_POLICY_CHANGE.md)。 / See [LICENSE_POLICY_CHANGE.md](LICENSE_POLICY_CHANGE.md) for the policy record and future AI maintenance instructions.

## 3. 最新版本下载与说明书 / Latest downloads and guides

本分支的 1.0.5 正在进行跨平台试用。下表列出当前已公开的正式安装包。 / Version 1.0.5 is being tested on this branch. The table links to the current published release.

1.0.5 试用包的完整安装步骤、安装包校验和排错方法见随包的两份 TXT。 / For setup, installer verification and troubleshooting for the 1.0.5 trial, see the two guides supplied with the package. [中文安装说明](docs/delivery/1.0.5/GLM%20Tray%201.0.5%20%E5%AE%89%E8%A3%85%E8%AF%B4%E6%98%8E%EF%BC%88%E4%B8%AD%E6%96%87%EF%BC%89.txt) · [English installation guide](docs/delivery/1.0.5/GLM%20Tray%201.0.5%20Installation%20Guide%20%28English%29.txt)

**1.0.4 Stable · Windows x64 · 2026-11-21**（北京时间 / UTC+8）. [最新版 Release / Latest release](https://github.com/Ziqing-Gu/GLMTray/releases/latest)

| 下载 / Download | 用途 / What to choose |
| --- | --- |
| [Windows x64 安装包 / Windows x64 installer](https://github.com/Ziqing-Gu/GLMTray/releases/download/v1.0.4/GLMTray-1.0.4-Windows-x64-Setup.exe) | 在 Windows 10 或 11 上为当前账户安装。安装包未做代码签名。 / Installs for the current user on Windows 10 or 11. The installer is unsigned. |
| [快速上手 TXT / Quick start](https://github.com/Ziqing-Gu/GLMTray/releases/download/v1.0.4/GLMTray-Quick-Start.txt) | 一页读懂用途和日常操作，中英双语。 / A short bilingual guide to everyday use. |
| [中文安装与使用说明](https://github.com/Ziqing-Gu/GLMTray/releases/download/v1.0.4/Install-ZH.md) | 安装、便携运行、托盘操作、登录启动和卸载。 |
| [English installation and user guide](https://github.com/Ziqing-Gu/GLMTray/releases/download/v1.0.4/Install-EN.md) | Installation, portable use, tray controls, sign-in and removal. |

从旧版安装包升级时，直接运行新安装包即可。保留向导预选的文件夹会原位更新；点击浏览改选目录会迁移程序并卸载旧安装。安装器保留已启用的登录任务、设置和指向旧程序的开始菜单、桌面及桌面一级文件夹快捷方式。独立便携副本请在升级前手动退出。1.0.4 公开版仅提供 Windows 安装包。GitHub 的 “Source code (zip/tar.gz)” 是源码快照，Windows 安装请选择上表的 EXE。

Run Setup to upgrade an installed copy. Keep the preselected folder to update in place, or browse to move the program and uninstall the previous copy. Setup carries over an enabled sign-in task, preferences and existing links to the helper in Start, on the desktop and in its immediate subfolders. Exit a separate portable instance before upgrading. The published 1.0.4 release provides a Windows installer only. GitHub's “Source code (zip/tar.gz)” files contain source snapshots. Choose the EXE above for installation.

验证环境为 Windows x64 和 Genelec GLM 5.2.0。若 GLM 与 Cubase 或 Nuendo 在启动时争用设备，请先开 GLM。本次未遍历实体控制器的所有按键，也未验证其他 GLM 版本。 / Testing used Windows x64 and Genelec GLM 5.2.0. If GLM and Cubase or Nuendo compete for a device at startup, open GLM first. Testing did not cover every physical control or other GLM versions.

## 4. 逐版本更新记录 / Version history

### 1.0.5 · 2026-11-28 · macOS 菜单栏助手 / macOS menu bar helper

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

## 5. 历史版本下载 / Previous releases

1.0.2 是首次公开发布的版本。 / Public releases begin with 1.0.2. [全部 Release / All releases](https://github.com/Ziqing-Gu/GLMTray/releases)
