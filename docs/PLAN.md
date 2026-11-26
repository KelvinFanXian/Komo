# KMonitor 首版规划

维护人：范显
日期：2026-11-26

## 定位

KMonitor 是供本机多 Agent 开发时使用的原生 macOS 服务面板。它从当前监听进程读取实际服务，不依赖固定应用清单或 Agent 对话内容；用进程的工作目录与 Git worktree 识别业务分支。

## 首版范围

1. 自动发现当前用户启动、工作目录位于主目录下开发 Git worktree 的 TCP 监听进程；可显式选择其他监控目录。
2. 按真实分支分组，显示仓库、worktree、端口、PID、进程名及监听状态；支持搜索、手动刷新与点击折叠。
3. 可选工作区目录过滤，也可隐藏单项服务并随时恢复；配置仅保存在本机。
4. 打开本地服务地址；对已识别服务可单项停止，也可关闭当前分支中显示的服务；执行前逐项复核进程、端口和 worktree。
5. 原生 SwiftUI 窗口及菜单栏快捷入口；提供本机可构建的 App 图标与打包脚本。

功能流程图见 [README 的 Mermaid 功能描述](../README.md#功能描述mermaid)。

## 边界与约定

- `lsof` 监听记录是状态事实源，`.claude/launch.json` 等静态配置只可作为后续辅助线索。
- 分支来自 Git，目录名不用于猜分支；无法确认归属的监听进程不提供停止按钮。
- 默认排除主目录以外的系统及包管理目录（例如 `/opt/homebrew`）、`~/Library` 与主目录下隐藏目录，避免把基础设施服务放进面板。
- 首版不代替 Codex 启动服务，不扫描其他用户进程，不自动结束进程，不对远端服务器操作。
- 发送 SIGTERM 后重新扫描；端口仍在时如实显示，不默认强制终止。
- 手动刷新遇到后台扫描仍在执行时直接跳过；结果未变化时不重置服务列表，避免不必要的闪动。
- 进程存活及端口监听不等于业务 HTTP 健康；首版只报告监听状态。

## 软件形象

应用名使用 **KMonitor**，副题“心天之眼”。图标是一只以天穹之眼观察分支的守望妖怪：独眼虹膜内有星空与心形高光，枝角上的彩色光点象征同时运行的服务。图标使用内置图像生成工具制作，最终位图保存在 `Resources/AppIcon.png`。生成提示词的核心是 “original small mythic yokai creature called the Eye of the Heart Sky; one luminous celestial eye; compact indigo body; branch-like horns with colored light nodes; warm ivory rounded-square macOS icon; no text or UI”。

## 验收场景

- 当前 48090 对应 `ym2fog-api-dev` 的 `dev_yunbiao`。
- 当前 48092、5182、5180 分别对应历史功能 worktree 的实际 `feature/yunbiao-history`，即使静态启动配置描述不同。
- 新进程加入或退出后面板更新；停止操作仅作用于复核通过的本机进程。
