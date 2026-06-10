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

# 项目结构

```
demo/
├── .githooks/                    # Git 钩子（pre-commit/commit-msg）
│   ├── check_godot_project.ps1
│   ├── commit-msg
│   └── pre-commit
├── addons/
│   ├── godot_mcp/                # MCP 运行时插件（编辑器集成）
│   │   ├── mcp_client.gd / tool_executor.gd / plugin.gd
│   │   ├── runtime/mcp_runtime.gd
│   │   └── utils/paths.gd / variant_codec.gd
│   └── gut/                      # GUT 测试框架
├── scripts/                      # 源码（44 个 .gd 文件）
│   ├── autoload/                 # Autoload 单例（6 个）
│   │   ├── game_config.gd        #   游戏配置与常量
│   │   ├── event_bus.gd          #   事件总线
│   │   ├── keybind_manager.gd    #   按键绑定管理
│   │   ├── selection_manager.gd  #   选中/剪贴板/撤销栈
│   │   ├── essence_pool.gd       #   源质货币池
│   │   └── progress_system.gd    #   阈值解锁系统
│   ├── building/                 # 建筑系统（10 个 .gd）
│   │   ├── building_base.gd      #   建筑基类 Node2D
│   │   ├── building_manager.gd   #   建筑管理器
│   │   ├── building_factory.gd   #   建筑工厂
│   │   ├── brick_node.gd         #   砖块（含碰撞体）
│   │   ├── container_node.gd     #   容器（容量管理）
│   │   ├── emitter_node.gd       #   发射器（元素方向）
│   │   ├── collector_node.gd     #   收集器（半径收集）
│   │   ├── pipe_node.gd          #   管道（连接掩码）
│   │   ├── pipe_render_system.gd #   管道 ECS 批量渲染
│   │   └── ghost_preview_manager.gd  # 幽灵预览管理
│   ├── elements/                 # 元素系统（2 个 .gd）
│   │   ├── element_registry.gd   #   [Autoload] 元素类型注册表
│   │   └── element_type_data.gd  #   元素类型 Resource
│   ├── grid/                     # 网格系统（4 个 .gd）
│   │   ├── grid_coordinate.gd    #   坐标转换工具类
│   │   ├── grid_utils.gd         #   格子工具（直线/L 型）
│   │   ├── input_state_machine.gd#   输入状态机（6 状态）
│   │   └── map_input_handler.gd  #   地图输入处理器
│   ├── reaction/                 # 模拟系统（4 个 .gd）
│   │   ├── reaction_coordinator.gd  # 模拟协调器（Timer 驱动）
│   │   ├── element_grid.gd       #   流体格子数据
│   │   ├── element_diffusion.gd  #   水体扩散/收缩算法
│   │   └── element_renderer.gd   #   流体批量渲染
│   ├── ui/                       # UI 组件（6 个 .gd）
│   │   ├── building_tooltip.gd   #   建筑提示框
│   │   ├── emitter_type_panel.gd #   发射器类型面板
│   │   ├── essence_display.gd    #   源质数值显示
│   │   ├── inventory_bar.gd      #   物品栏
│   │   ├── inventory_slot.gd     #   物品槽
│   │   └── key_hints.gd          #   快捷键提示
│   ├── persistence/              # 持久化（1 个 .gd）
│   │   └── save_manager.gd       #   存档管理器
│   ├── resources/                # 数据定义（3 个 .gd）
│   │   ├── building_data.gd      #   建筑运行时数据（RefCounted）
│   │   ├── building_type_data.gd #   建筑类型定义（Resource）
│   │   └── undo_command.gd       #   撤销/重做命令（RefCounted）
│   ├── main.gd                   # 主场景控制器
│   ├── CameraController.gd       # 摄像机控制（缩放/移动）
│   ├── InfiniteGridMap.gd        # 无限网格地图渲染
│   ├── Settings.gd               # 设置面板
│   ├── StartMenu.gd              # 开始菜单
│   └── fps_display.gd            # FPS 显示
├── scenes/                       # 场景文件（7 个 .tscn）
│   ├── main.tscn / settings.tscn / start_menu.tscn
│   ├── inventory_bar.tscn / inventory_slot.tscn
│   ├── building_tooltip.tscn / emitter_type_panel.tscn
├── resources/                    # 图标资源（8 个 .svg）
├── save/                         # 运行时存档（gitignore）
├── tests/                        # GUT 测试（29 unit + 3 integration）
│   ├── unit/                     #   单元测试
│   └── integration/              #   集成测试
├── project.godot
├── .gutconfig.json
├── AGENTS.md
└── icon.svg
```

# 自动加载单例

| 单例              | 文件位置                          | 用途                           |
| ----------------- | --------------------------------- | ------------------------------ |
| GameConfig        | `autoload/game_config.gd`         | 游戏配置与常量集中管理          |
| EventBus          | `autoload/event_bus.gd`           | 模块间事件通信                  |
| ElementRegistry   | `elements/element_registry.gd`    | 元素类型注册表                  |
| KeybindManager    | `autoload/keybind_manager.gd`     | 按键配置加载/保存/重映射        |
| SelectionManager  | `autoload/selection_manager.gd`   | 选中状态/剪贴板/撤销栈管理      |
| EssencePool       | `autoload/essence_pool.gd`        | 源质货币池（增减查）            |
| ProgressSystem    | `autoload/progress_system.gd`     | 源质阈值进度系统（解锁建筑类型） |

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
- **幽灵预览**: GhostPreviewManager 维护多组预览数组（ghost/selected/paste/remove），`_draw()` 统一渲染
- **建筑系统**: 5 种建筑（容器/管道/发射器/收集器/砖块），通过 BuildingFactory 创建，ECS-Lite 管道批量渲染
- **模拟系统**: ReactionCoordinator 管理 BFS 网络拓扑，每 tick 执行发射→扩散→收集流程
- **元素系统**: 仅水元素（注册表 + Resource 类型定义），重力驱动扩散（下落 + 填充），水源标记维持水体连续
- **源质经济**: EssencePool 管理货币，ProgressSystem 按阈值解锁建筑类型
- **框选与剪贴板**: 选中 → Ctrl+C/X/V 复制/剪切/粘贴，Ctrl+Z/Y 撤销/重做（栈上限 100），粘贴支持旋转和拖拽
- **持久化**: 建筑/按键/设置自动保存到 save/ 目录，启动时加载
- **可视化**: 管道 ECS 批量渲染（PackedVector2Array）、流体批量渲染、无限网格分块渲染

# 通信方式

通过 EventBus 进行模块间松耦合通信（同场景兄弟节点允许 `get_node()` 直接引用）。信号覆盖建筑放置/删除、元素生成/移除、源质变更、暂停、选中、粘贴模式、阈值解锁等。

# Git Hooks 与工具

## Pre-commit Hook

`.githooks/pre-commit` 在提交时自动运行两步检查：**Godot 项目错误检查** → **GUT 测试**
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


# 测试

## 自动流程（推荐）

提交代码时自动触发，**无需手动运行测试**：

| 步骤 | 内容 | 说明 |
|------|------|------|
| **1/2** | `pre-commit` hook 自动运行 godot-debug 项目错误检查 | 静态语法 + 运行时错误检查 |
| **2/2** | `pre-commit` hook 自动运行 GUT 测试套件 | 全部测试通过后才继续 |

**提交命令**：
```bash
git add -A && git commit -m "feat: 你的改动说明"
```

## 手动运行

仅用于调试或验证 hook 之外的改动：
```bash
& "C:\Users\MLTZ\Desktop\Godot_v4.6.1-stable_win64.exe" --headless '--path' 'C:\Users\MLTZ\Desktop\程序\godot\bili游戏大赛\demo' '--script' 'res://addons/gut/gut_cmdln.gd'
```

**验证**: 命令退出码 `exit_code == 0` 且 `save/test_output.xml` 中 `failures="0"` 即为全部通过。