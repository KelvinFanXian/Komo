# KMonitor 首版验证记录

维护人：范显

## 已执行

- `swift test --disable-sandbox`：7 项通过，含 lsof 多端口解析、进程身份变化拒绝、默认范围与真实端口扫描。
- 48090：识别 `ym2fog-api-dev` worktree 为 `dev_yunbiao`。
- 5180：识别 `ym2fog-admin-ui-history` worktree 为 `feature/yunbiao-history`；与静态启动配置的条目不同。
- 用户走查发现 Homebrew 的 Redis 6379 无需显示；收紧默认范围后，本机复验 6379 不在服务列表中，5180 仍被正确识别。新增可恢复的单项隐藏。
- 58991：在本项目目录启动临时 Python HTTP 服务，KMonitor 二次扫描后发送 SIGTERM，端口退出；原有业务服务未受影响。
- `./Scripts/build-app.sh`：Release 构建、`AppIcon.icns` 生成、ad-hoc 签名和 `codesign --verify --deep --strict` 通过。
- `open .build/app/KMonitor.app` 后进程保持运行。
- 将构建产物安装至 `/Applications/KMonitor.app`：安装包签名校验通过，主程序 SHA-256 与构建产物一致，进程从安装路径启动。
- 本次用 58992、58993 两个临时 HTTP 服务验证“关闭分支服务”：两项均在 `feature/branchscope`，逐个复核后停止，两个端口均不再监听；其他业务服务未操作。
- 从 `/Applications` 启动 Release 应用并截取窗口：顶部搜索居中，右上角无刷新按钮；分支标题、折叠箭头和“关闭分支服务”均可见。
- 相隔约 2 秒截取安装版窗口，底栏更新时间由 10:31:27 变为 10:31:29，确认自动轮询持续工作。

## 待人工走查

- 在窗口和菜单栏核对图标、分组、搜索、工作区过滤及确认弹窗的实际视觉表现。
- 关闭主窗口后留在菜单栏，观察服务列表是否仍按 1 秒周期更新。
- 核对顶部品牌大块和右上角刷新按钮已移除；自动刷新时列表不闪动，后台扫描进行中再次触发不会重复扫描。
- 核对分支标题可折叠和展开；“关闭分支服务”只作用于该分支当前显示的服务。
- 对由 npm/pnpm 等父进程启动、可能自动重启的服务，观察停止后的再出现行为。

停止操作没有对现有开发服务直接演练；验证时使用了可控临时服务。
