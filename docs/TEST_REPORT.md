# KMonitor 首版验证记录

维护人：范显

## 已执行

- `swift test --disable-sandbox`：6 项通过，含 lsof 多端口解析、进程身份变化拒绝、默认范围与真实端口扫描。
- 48090：识别 `ym2fog-api-dev` worktree 为 `dev_yunbiao`。
- 5180：识别 `ym2fog-admin-ui-history` worktree 为 `feature/yunbiao-history`；与静态启动配置的条目不同。
- 用户走查发现 Homebrew 的 Redis 6379 无需显示；收紧默认范围后，本机复验 6379 不在服务列表中，5180 仍被正确识别。新增可恢复的单项隐藏。
- 58991：在本项目目录启动临时 Python HTTP 服务，KMonitor 二次扫描后发送 SIGTERM，端口退出；原有业务服务未受影响。
- `./Scripts/build-app.sh`：Release 构建、`AppIcon.icns` 生成、ad-hoc 签名和 `codesign --verify --deep --strict` 通过。
- `open .build/app/KMonitor.app` 后进程保持运行。

## 待人工走查

- 在窗口和菜单栏核对图标、分组、搜索、工作区过滤及确认弹窗的实际视觉表现。
- 关闭主窗口后留在菜单栏，观察服务列表是否仍按 5 秒周期更新。
- 对由 npm/pnpm 等父进程启动、可能自动重启的服务，观察停止后的再出现行为。

停止操作没有对现有开发服务直接演练；验证时使用了可控临时服务。
