# 项目概述

- **项目名称**: demo
- **项目类型**: 游戏项目
- **当前阶段**: 开发阶段
- **核心用途**: 基于 Godot 引擎开发的 2D 网格建筑与流体模拟游戏

# 技术栈

| 技术/工具        | 版本/说明         |
| ------------ | ----------- |
| 游戏引擎         | Godot 4.6   |
| 开发语言         | GDScript    |
| 渲染管线         | Forward Plus（Godot 4.x 默认） |
| 版本控制         | Git         |

# 项目结构

```
demo/
├── .godot/                    # Godot 引擎缓存（自动生成，无需提交）
├── addons/                    # 编辑器插件目录
│   ├── godot_mcp/             # MCP 调试插件
│   └── gut/                   # GUT 单元测试框架
├── scripts/                   # 脚本文件目录
│   ├── fps_display.gd         # 右上角帧率显示组件
│   ├── main.gd                # 主场景控制器（管理 UI 叠加层和暂停状态）
│   ├── InfiniteGridMap.gd     # 无限方格地图
│   ├── CameraController.gd    # 相机控制器
│   ├── StartMenu.gd           # 开始菜单
│   ├── Settings.gd            # 设置面板
│   ├── autoload/              # 自动加载单例目录
│   │   ├── game_config.gd     # 游戏配置与常量
│   │   ├── event_bus.gd       # 事件总线
│   │   ├── keybind_manager.gd # 按键配置管理
│   │   └── selection_manager.gd # 选中/剪贴板/撤销管理
│   ├── building/              # 建筑系统模块
│   │   ├── building_manager.gd # 建筑管理器（建筑增删改查、管线协调）
│   │   ├── building_base.gd    # 建筑统一基类（BuildingBase）
│   │   ├── container_node.gd   # 容器建筑（ContainerNode）
│   │   ├── pipe_node.gd        # 管道建筑（PipeNode）
│   │   ├── brick_node.gd       # 砖块建筑（BrickNode）
│   │   ├── building_factory.gd # 建筑工厂（BuildingFactory，根据类型创建实例）
│   │   ├── pipe_render_system.gd # 管道批量渲染系统（PipeRenderSystem，ECS-Lite）
│   │   └── ghost_preview_manager.gd # 幽灵预览管理器（GhostPreviewManager）
│   ├── grid/                  # 网格系统模块
│   │   ├── grid_coordinate.gd  # 网格坐标转换
│   │   ├── grid_utils.gd       # 网格工具函数（直线/矩形/L形单元格计算）
│   │   ├── map_input_handler.gd # 地图输入处理（状态机驱动）
│   │   └── input_state_machine.gd # 输入状态机（IDLE / DRAGGING / REMOVING / SELECTING / DESELECTING / PASTE_DRAGGING）
│   ├── persistence/           # 持久化模块
│   │   └── save_manager.gd     # 数据存储管理
│   ├── resources/             # 资源定义模块
│   │   ├── building_data.gd    # 建筑实例数据（BuildingData）
│   │   ├── building_type_data.gd # 建筑类型数据（BuildingTypeData）
│   │   └── undo_command.gd     # 撤销命令数据（UndoCommand）
│   ├── fluid/                  # 反应/连通网络系统模块
│   │   └── fluid_coordinator.gd # BFS 连通检测网络骨架（ReactionCoordinator）
│   └── ui/                    # UI 组件模块
│       ├── inventory_bar.gd    # 底部建筑类型选择栏
│       ├── inventory_slot.gd   # 建筑类型槽位逻辑
│       ├── building_tooltip.gd # 建筑悬停提示面板
│       └── key_hints.gd        # 快捷键提示面板
├── resources/                 # 资源文件目录
│   ├── container_icon.svg     # 容器建筑槽位图标
│   ├── pipe_icon.svg          # 管道建筑槽位图标
│   └── brick_icon.svg         # 砖块建筑槽位图标
├── scenes/                    # 场景文件目录
│   ├── main.tscn              # 游戏主场景文件
│   ├── start_menu.tscn        # 开始页面场景文件
│   ├── settings.tscn          # 设置页面场景文件
│   ├── inventory_bar.tscn     # 建筑选择栏场景
│   ├── inventory_slot.tscn    # 建筑槽位场景
│   └── building_tooltip.tscn  # 建筑悬停提示场景
├── save/                      # 持久化存储目录（运行时生成，gitignore）
│   ├── buildings.json         # 建筑放置数据
│   ├── test_buildings.json    # 测试建筑数据
│   ├── keybindings.json       # 按键配置数据
│   └── game_settings.json     # 游戏数值设置（滚轮缩放倍率、Shift 加速倍率）
├── tests/                     # GUT 测试目录
│   ├── unit/                  # 单元测试
│   └── integration/           # 集成测试
├── .gutconfig.json            # GUT 测试框架配置文件
├── icon.svg                   # 项目图标
├── project.godot              # Godot 项目核心配置文件
├── .editorconfig              # 编辑器代码风格配置
├── .gitattributes             # Git 属性配置
├── .gitignore                 # Git 忽略文件配置
└── AGENTS.md                  # 项目描述文档
```

# 自动加载单例

| 单例名称        | 脚本路径                                       | 用途               |
| ----------- | ----------------------------------------- | ---------------- |
| GameConfig   | res://scripts/autoload/game_config.gd      | 游戏配置与常量集中管理  |
| EventBus     | res://scripts/autoload/event_bus.gd        | 模块间事件通信       |
| KeybindManager | res://scripts/autoload/keybind_manager.gd  | 按键配置加载/保存/重映射 |
| SelectionManager | res://scripts/autoload/selection_manager.gd | 选中状态/剪贴板/撤销栈管理 |
| MCPRuntime   | res://addons/godot_mcp/runtime/mcp_runtime.gd | MCP 调试运行时辅助   |

## Autoload 初始化顺序依赖

```
GameConfig（无依赖） → EventBus（无依赖） → KeybindManager（依赖 GameConfig） → SelectionManager（运行时获取 BuildingManager）
```

## EventBus 信号列表

| 信号名称                     | 参数                   | 触发时机          |
| ------------------------ | -------------------- | ------------- |
| building\_placed         | grid\_pos: Vector2i | 建筑放置成功时       |
| building\_removed        | grid\_pos: Vector2i | 建筑删除成功时       |
| buildings\_loaded        | 无                    | 存档建筑数据加载完成    |
| keybind\_changed         | action: String      | 按键绑定变更时       |
| start\_game\_requested   | 无                    | 点击开始游戏按钮时      |
| show\_start\_menu\_requested | 无                 | 请求显示开始菜单时      |
| show\_settings\_requested | 无                   | 请求显示设置页面时      |
| game\_settings\_changed   | 无                    | 游戏数值设置变更时      |
| selection\_changed        | selected\_cells: Array[Vector2i] | 建筑选中状态变更时   |
| paste\_mode\_changed       | active: bool        | 粘贴模式进入/退出时    |
| camera\_changed            | 无                    | 相机缩放或移动时     |
| building\_hovered          | grid\_pos: Vector2i, node: Node2D | 鼠标悬停在建筑上时   |
| building\_hover\_exited     | grid\_pos: Vector2i | 鼠标离开建筑悬停时    |

# 主场景结构

```
Root (Node2D) → main.gd                    # 主场景控制器
├── Camera2D (Camera2D) → CameraController.gd        # 当前激活相机
├── InfiniteGridMap (Node2D) → InfiniteGridMap.gd   # 无限方格地图
├── BuildingManager (Node2D) → BuildingManager.gd    # 建筑管理器
│   ├── PipeRenderSystem (Node2D) → PipeRenderSystem.gd # 管道批量渲染
│   ├── GhostPreviewManager (Node2D) → GhostPreviewManager.gd # 幽灵预览管理
│   └── ReactionCoordinator (Node) → fluid_coordinator.gd # 反应协调器（运行时动态创建）
├── SaveManager (Node) → SaveManager.gd              # 数据持久化管理
├── MapInputHandler (Node) → MapInputHandler.gd     # 地图输入处理
└── UIOverlay (CanvasLayer)                # UI 叠加层
    ├── StartMenu (Control) → StartMenu.gd  # 开始菜单
    ├── SettingsPanel (Control) → Settings.gd # 设置面板
    ├── InventoryBar (HBoxContainer) → InventoryBar.gd # 底部建筑类型选择栏
    ├── BuildingTooltip (Control) → BuildingTooltip.gd # 建筑悬停提示
    ├── FPSDisplay (Label) → fps_display.gd # 帧率显示
    └── KeyHints (VBoxContainer) → key_hints.gd # 快捷键提示面板
```

# 核心功能说明

- **输入状态机（InputStateMachine）**：`input_state_machine.gd` 定义 6 个状态（IDLE / DRAGGING / REMOVING / SELECTING / DESELECTING / PASTE_DRAGGING），`map_input_handler.gd` 根据当前模式（放置/删除/框选/粘贴）委托对应状态逻辑，状态切换时自动显示/隐藏对应幽灵预览
- **幽灵预览系统**：GhostPreviewManager 维护多组幽灵数组（ghost_cells / remove_ghost_cells / select_ghost_cells / deselect_ghost_cells / paste_ghost_cells / selected_cells），`_draw()` 统一绘制，`show_*`/`hide_*` 系列方法切换状态；作为 BuildingManager 的子节点管理所有预览渲染
- **无限方格地图**：基于视口动态加载/卸载区块（640px/块），实现无缝漫游
- **细网格线自适应**：大格子数量≥6 时自动隐藏细网格线
- **建筑放置/删除**：左键放置、右键删除，拖拽支持直线批量放置（`get_line_cells`）和矩形批量删除（`get_rect_cells`），拖拽时显示幽灵预览
- **建筑类型选择**：底部 10 槽位，数字键 1~0 切换，选中槽位高亮；重复按下已选中槽位可取消选择；1 号=容器/缓存节点(ContainerNode)，2 号=管道(PipeNode)，4 号=砖块(BrickNode)
- **建筑统一基类**：BuildingBase 抽象基类，定义 grid_position / get_building_name / get_tooltip_summary 等公共接口，所有建筑继承自此基类
- **缓存节点（容器）**：自定义 \_draw() 渲染填充条，带 capacity / max\_capacity 属性，数据持久化，作为连通检测网络中的缓存节点
- **管道建筑**：ECS-Lite 架构——PipeNode 保留 Node2D 骨架用于交互，渲染逻辑由 PipeRenderSystem 批量绘制（PackedVector2Array/PackedInt32Array 存储位置/连接掩码）；自动检测邻居连接显示水平/垂直/多通，无容量纯导体
- **建筑悬停提示**：鼠标悬停建筑时显示浮动面板，展示建筑名称、摘要属性，支持展开查看详细信息
- **吸管功能**：鼠标滚轮在已有建筑格子上按下时，自动切换为该建筑对应的建造类型
- **框选与复制粘贴**：框选建筑（蓝色高亮），Ctrl+C/X/V 复制/剪切/粘贴，Ctrl+Z 撤销，Ctrl+Shift+Z 或 Ctrl+Y 重做；粘贴模式下按 R 键可顺时针旋转剪贴板布局（0°→90°→180°→270° 循环），支持拖拽粘贴（`get_paste_line_anchors` 生成行列式锚点）；管道粘贴后自动重新检测邻居连接
- **快捷键提示面板（KeyHints）**：右上角动态显示当前可用快捷键及模式说明（放置/删除/框选/粘贴/吸取），随当前模式变化实时更新
- **反应/连通检测系统**：ReactionCoordinator 通过脏标记（\_dirty）缓存 BFS 连通网络结构，仅在建筑放置/删除时重建网络拓扑；每 tick 遍历缓存的网络结构（PipeNode + ContainerNode），保留网络骨架为后续反应系统铺路
- **建筑工厂（BuildingFactory）**：静态工厂类，根据 building_type 字符串创建对应的建筑实例（ContainerNode / PipeNode / BrickNode），统一管理建筑实例化逻辑
- **管道渲染系统（PipeRenderSystem）**：ECS-Lite 数据批次渲染，管理所有 PipeNode 的位置/连接掩码；支持单个管道注册/注销/逐位变更和批量更新两种模式；`_draw()` 中统一绘制线段和转角
- **幽灵预览管理器（GhostPreviewManager）**：管理放置/删除/框选/粘贴/选中 5 类幽灵预览数组，提供 `show_*`/`hide_*` 方法和 `_draw()` 统一渲染；监听 `selection_changed` 信号同步选中状态
- **网格工具类（GridUtils）**：提供 `get_line_cells`（直线格）、`get_rect_cells`（矩形格）、`get_l_cells`（L 形格）等静态坐标计算方法
- **数据持久化**：建筑/按键/设置数据自动保存到 save/ 目录，启动自动加载
- **MCP 调试工具**：集成 godot\_mcp 插件，支持场景运行、截图、输入模拟等调试
- **事件驱动架构**：通过 EventBus 实现模块间松耦合通信
- **配置集中管理**：GameConfig 统一管理游戏常量
- **按键配置系统**：KeybindManager 管理 InputMap 按键，支持持久化和设置页面重映射
- **游戏数值设置**：支持调整缩放倍率和加速倍率，持久化到 save/game\_settings.json
- **单元测试**：基于 GUT 框架，覆盖各核心模块

# 开发规范

- 对于不确定的接口，先查询，禁止猜测用法
- 修改后使用 godot-debug 技能或 mcp 工具进行代码静态检查和运行时错误检测，确保无错误
- 修改后运行测试：`& "C:\Users\MLTZ\Desktop\Godot_v4.6.1-stable_win64.exe" --headless '--path' 'C:\Users\MLTZ\Desktop\程序\godot\bili游戏大赛\demo' '--script' 'res://addons/gut/gut_cmdln.gd'`，结果导出至 save/test\_results.xml（disable\_colors 和 junit\_xml\_file 已在 .gutconfig.json 中配置）
- **验证测试结果无需查看完整输出**：检查命令退出码（exit\_code == 0 = 全部通过）和 save/test\_results.xml 的 failures 属性（failures="0" = 全部通过）
- 使用事件总线(EventBus)进行模块间松耦合通信；同场景内兄弟节点允许通过 get\_node() 直接引用，跨场景通信必须通过 EventBus
- 遵循单一职责原则，每个脚本只负责一个功能域
- 新增功能需编写对应的 GUT 测试，单元测试放在 tests/unit/ 下，集成测试放在 tests/integration/ 下，以 test\_ 为前缀
- 测试类继承 GutTest，测试方法以 test\_ 开头，使用 autoqfree / add\_child\_autoqfree 管理节点生命周期

# 运行方式

1. 打开 Godot 4.6 编辑器，导入项目根目录
2. 点击运行按钮或按 F5 键启动游戏
3. 操作说明（默认按键，可在设置页面修改）：
   - W 键：相机上移
   - S 键：相机下移
   - A 键：相机左移
   - D 键：相机右移
   - Shift 键：加速移动（默认 5 倍速，可在设置页面调整）
   - 鼠标滚轮上：放大视角
   - 鼠标滚轮下：缩小视角
   - 鼠标滚轮在有建筑的格子上按下：吸取建筑类型（自动切换为对应建筑类型）
   - 鼠标左键单击：放置单个建筑（使用当前选中的类型）
   - 鼠标左键拖拽：沿直线批量放置建筑
   - 鼠标右键单击：删除单个建筑
   - 鼠标右键拖拽：矩形框选批量删除建筑
   - 数字键 1~0：切换建筑类型（对应底部选择栏 10 个槽位）；重复按下已选中槽位可取消选择
   - ESC 键：显示/关闭开始菜单
   - Ctrl+C：复制选中的建筑
   - Ctrl+X：剪切选中的建筑
   - Ctrl+V：进入粘贴模式
   - R 键（粘贴模式下）：顺时针旋转剪贴板布局 90°（0°→90°→180°→270° 循环）
   - Ctrl+Z：撤销上一次操作
   - Ctrl+Shift+Z 或 Ctrl+Y：重做被撤销的操作
