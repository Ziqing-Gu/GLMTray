# 版本记录 / Changelog

### 1.0.2 · 2026-11-20 · 便携运行 / Portable use

- 支持从可写目录运行。可自动查找 GLM，也可在程序旁的 `GLMTray.ini` 指定安装路径；最小化偏好随副本保存，诊断日志默认关闭。移动助手后须从新位置重新启用登录启动。17 项隔离窗口测试通过；实际 GLM 5.2.0 隐藏运行时，120 个约一秒采样区间内，助手自身均未测到超过全机 CPU 的 0.05%。此值来自一次测量。
- Run from a writable folder. The helper discovers GLM or accepts an override in an adjacent `GLMTray.ini`. Minimize preferences travel with the copy, and diagnostic logging is off by default. Re-enable start at sign-in after moving it. All 17 isolated window tests passed. In one run with GLM 5.2.0 hidden, the helper stayed within 0.05% of whole-machine CPU in all 120 roughly one-second samples.

### 1.0.1 · 2026-11-20 设为 Stable / Designated Stable

- 改为原生 Windows 事件驱动。定位到 GLM 后仅监听目标进程，主窗口出现约十秒后隐藏，并等待设置或错误对话框处理完毕。验证了隐藏、恢复、退出助手和 GLM 重启后的重新识别。此版沿用原工作站的路径配置。
- Switched to native Windows events. Once attached, the helper watches the GLM process, hides its main window after about ten seconds and waits for settings or error dialogs to close. Tests covered hiding, restoring, exiting the helper and reconnecting after GLM restarts. This version used workstation-specific paths.

### 1.0.0 · 2026-11-19 · 首个本地版本 / Initial local version

- 首版 C# 助手每秒查询一次 GLM 窗口，支持托盘隐藏、恢复及登录启动。12 项隔离窗口测试通过，并在 GLM 5.2.0 上验证了隐藏和恢复操作。
- The first C# helper checked for GLM windows once per second and supported hiding, restoring and start at sign-in. Twelve isolated window tests passed, and hide/restore was verified with GLM 5.2.0.
