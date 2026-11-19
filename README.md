# GLM Tray

## 1. 产品介绍 / About the product

用 MIDI 控制器调节 Genelec 监听系统时，GLM 可以留在 Windows 通知区域。GLM Tray 会在 GLM 主窗口出现约十秒后将它隐藏，让任务栏留给音频工作站。原有 MIDI 映射和音量控制仍由 GLM 处理。双击托盘里的绿色 G 可以打开主窗口，退出助手也会恢复窗口。遇到设置或错误对话框时，助手会等你处理完再隐藏。

GLM Tray keeps the Genelec GLM main window in the Windows notification area while you work in your DAW. About ten seconds after the window appears, the helper hides it. GLM continues to handle your existing MIDI mappings and monitor levels. Double-click the green G in the tray to bring the window back, or exit the helper to restore it. If GLM opens a settings or error dialog, the helper waits until you finish with it.

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

**1.0.2 · Windows x64 · 2026-11-20**（北京时间 / UTC+8）· 首个 GitHub 正式发布 / First GitHub release. [最新版 Release / Latest release](https://github.com/Ziqing-Gu/GLMTray/releases/latest)

| 下载 / Download | 用途 / What to choose |
| --- | --- |
| [Windows x64 安装包 / Windows x64 installer](https://github.com/Ziqing-Gu/GLMTray/releases/download/v1.0.2/GLMTray-1.0.2-Windows-x64-Setup.exe) | 在 Windows 10 或 11 上为当前账户安装。安装包未做代码签名。 / Installs for the current user on Windows 10 or 11. The installer is unsigned. |
| [中文安装与使用说明](https://github.com/Ziqing-Gu/GLMTray/releases/download/v1.0.2/Install-ZH.md) | 安装、便携运行、托盘操作、登录启动和卸载。 |
| [English installation and user guide](https://github.com/Ziqing-Gu/GLMTray/releases/download/v1.0.2/Install-EN.md) | Installation, portable use, tray controls, sign-in and removal. |

便携使用时，可将安装后的 `GLMTray.exe` 复制到可写目录。升级前先退出旧助手；如需登录后启动，从新位置重新启用该选项。macOS 和 Linux 暂无成品。GitHub 自动生成的 “Source code (zip/tar.gz)” 供查看和构建源码，Windows 用户请选择上表的 EXE 安装包。

For portable use, copy the installed `GLMTray.exe` to a writable folder. Exit the previous helper before upgrading and re-enable start at sign-in from the new location if needed. No macOS or Linux build is available. GitHub's “Source code (zip/tar.gz)” archives are for inspecting or building the source. For Windows installation, choose the EXE above.

如 GLM 与 Cubase 或 Nuendo 在启动时发生冲突，请先启动 GLM。验证使用 GLM 5.2.0；实体 MIDI 控制器全部按键、其他 GLM 版本及常规安装卸载流程尚未覆盖。 / If GLM reports a startup conflict with Cubase or Nuendo, start GLM first. Testing used GLM 5.2.0. It did not cover every physical MIDI control, other GLM versions, or a full registered install/uninstall cycle.

## 4. 逐版本更新记录 / Version history

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
