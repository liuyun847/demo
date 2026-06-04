# 项目概述

- **项目名称**: demo
- **项目类型**: 游戏项目
- **当前阶段**: 开发阶段
- **核心用途**: 基于 Godot 4.6 的 2D 网格建筑与流体模拟游戏

# 技术栈

| 技术/工具  | 版本/说明                  |
| ---------- | -------------------------- |
| 游戏引擎   | Godot 4.6                  |
| 开发语言   | GDScript                   |
| 渲染管线   | Forward Plus（Godot 4.x 默认） |

# 项目结构（简化）

```
demo/
├── addons/gut/               # 测试框架
├── scripts/                  # 源码
│   ├── autoload/             # Autoload 单例（GameConfig, EventBus, KeybindManager, SelectionManager, EssencePool, ProgressSystem）
│   ├── building/             # 建筑系统（BuildingManager + 5种建筑 + 工厂 + 管道渲染 + 幽灵预览）
│   ├── elements/             # 元素系统（类型注册 + 运行时数据）
│   ├── grid/                 # 网格系统（坐标转换 + 工具 + 输入处理 + 状态机）
│   ├── reaction/             # 模拟系统（协调器 + 格子管理 + 扩散 + 渲染）
│   ├── ui/                   # UI 组件（选择栏、提示、喷口面板、源质显示）
│   ├── persistence/          # 持久化
│   ├── resources/            # 数据定义（BuildingData、UndoCommand）
│   └── main.gd               # 主场景控制器
├── scenes/                   # 场景文件（main, start_menu, settings, inventory 等）
├── resources/                # 图标资源
├── save/                     # 运行时持久化数据（gitignore）
└── tests/                    # GUT 测试（unit/ + integration/）
```

# 自动加载单例

| 单例              | 用途                           |
| ----------------- | ------------------------------ |
| GameConfig        | 游戏配置与常量集中管理          |
| EventBus          | 模块间事件通信                  |
| KeybindManager    | 按键配置加载/保存/重映射        |
| SelectionManager  | 选中状态/剪贴板/撤销栈管理      |
| ElementRegistry   | 元素类型注册表                  |
| EssencePool       | 源质货币池（增减查）            |
| ProgressSystem    | 源质阈值进度系统（解锁建筑类型） |

**初始化顺序**: GameConfig → EventBus → ElementRegistry → KeybindManager → SelectionManager → EssencePool → ProgressSystem

# 主场景节点树

```
Root (Node2D) → main.gd
├── Camera2D → CameraController.gd
├── InfiniteGridMap → InfiniteGridMap.gd
├── BuildingManager → BuildingManager.gd
│   ├── PipeRenderSystem / GhostPreviewManager / ElementRenderer / ReactionCoordinator
├── SaveManager / MapInputHandler
└── UIOverlay (CanvasLayer)
    ├── StartMenu / SettingsPanel / InventoryBar / BuildingTooltip
    ├── EssenceDisplay / PauseOverlay / EmitterTypePanel（运行时动态创建）
    └── FPSDisplay / KeyHints
```

# 核心系统摘要

- **输入状态机**: 6 个状态（IDLE/DRAGGING/REMOVING/SELECTING/DESELECTING/PASTE_DRAGGING），根据模式切换幽灵预览
- **幽灵预览**: GhostPreviewManager 维护多组预览数组，`_draw()` 统一渲染
- **建筑系统**: 5 种建筑（容器/管道/发射器/收集器/砖块），通过 BuildingFactory 创建，ECS-Lite 管道渲染
- **模拟系统**: ReactionCoordinator 管理 BFS 网络拓扑，每 tick 执行发射→扩散→收集流程
- **元素系统**: 仅水元素，重力驱动扩散（下落 + 填充），水源标记维持水体连续
- **源质经济**: EssencePool 管理货币，ProgressSystem 按阈值解锁建筑类型
- **框选与剪贴板**: 框选 → Ctrl+C/X/V 复制/剪切/粘贴，Ctrl+Z/Y 撤销/重做，粘贴支持旋转和拖拽
- **持久化**: 建筑/按键/设置自动保存到 save/ 目录，启动时加载

# 通信方式

通过 EventBus 进行模块间松耦合通信（同场景兄弟节点允许 `get_node()` 直接引用）。信号覆盖建筑放置/删除、元素生成/移除、源质变更、暂停、选中、粘贴模式等。

# Git Hooks 与工具

## Pre-commit Hook

`.githooks/pre-commit` 在提交时自动运行三步检查：**Godot 项目错误检查** → **GUT 测试** → **AI 审查**。
该文件与 `.githooks/check_godot_project.ps1` 均被 git 跟踪，通过以下配置启用（已为本仓库配置）：

```bash
git config core.hooksPath .githooks
```

> 该项目已配置好，克隆后无需额外操作。

**Godot 路径配置**：钩子使用 `$GODOT_PATH` 环境变量（默认 `C:/Users/MLTZ/Desktop/Godot_v4.6.1-stable_win64.exe`）。
在你的环境中使用前请设置：
```bash
export GODOT_PATH="/path/to/Godot_v4.6.1-stable_win64.exe"   # Linux/macOS
$env:GODOT_PATH="D:\path\to\Godot.exe"                        # Windows PowerShell
```

## Reasonix

[Reasonix](https://github.com/esengine/DeepSeek-Reasonix) 是一个 DeepSeek 原生的 AI 编码代理。
本项目的 `.env` 已配置 `DEEPSEEK_API_KEY`，`reasonix` CLI 自动加载。
自定义 slash 命令位于 `.reasonix/commands/`。

## 更新 reasonix

reasonix 通过 npm 全局安装（预编译 Rust 二进制），更新方式：

```bash
# 方式一：使用更新脚本（推荐，含自动重试）
.\scripts\update_reasonix.bat

# 方式二：手动更新（已配置国内镜像 + 重试优化）
npm install -g reasonix@latest --prefer-offline --no-audit --no-fund

# 方式三：官方 registry（镜像超时时备选）
npm config set registry https://registry.npmjs.org
npm install -g reasonix@latest
npm config set registry https://registry.npmmirror.com
```

> **npm 配置已优化**: fetch-retries=4, fetch-retry-mintimeout=20s, fetch-retry-maxtimeout=120s, fetch-timeout=300s
> 如果遇到 `context deadline exceeded` 超时错误，先运行方式一脚本，脚本会自动重试 3 次并给出备选方案。

# 测试

## 自动流程（推荐）

提交代码时自动触发，**无需手动运行测试**：

| 步骤 | 内容 | 说明 |
|------|------|------|
| **1/3** | `pre-commit` hook 自动运行 godot-debug 项目错误检查 | 静态语法 + 运行时错误检查 |
| **2/3** | `pre-commit` hook 自动运行 GUT 测试套件 | 全部测试通过后才继续 |
| **3/3** | `reasonix run --model deepseek-flash` AI 审查 staged diff | 检查正确性/安全性/可维护性 |

**提交命令**：
```bash
git add -A && git commit -m "feat: 你的改动说明"
```

如果 AI 审查误报，可临时跳过：
```bash
git commit --no-verify -m "feat: ..."
```

## 手动运行

仅用于调试或验证 hook 之外的改动：
```bash
& "C:\Users\MLTZ\Desktop\Godot_v4.6.1-stable_win64.exe" --headless '--path' 'C:\Users\MLTZ\Desktop\程序\godot\bili游戏大赛\demo' '--script' 'res://addons/gut/gut_cmdln.gd'
```

**验证**: 命令退出码 `exit_code == 0` 且 `save/test_output.xml` 中 `failures="0"` 即为全部通过。
