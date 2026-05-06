# 项目概述

- **项目名称**: demo
- **项目类型**: 游戏项目
- **当前阶段**: 开发阶段
- **核心用途**: 基于Godot引擎开发的游戏项目

# 技术栈

| 技术/工具       | 版本/说明        |
| ----------- | ------------ |
| 游戏引擎        | Godot 4.6    |
| 开发语言        | GDScript     |
| 渲染管线        | Forward Plus |
| 3D物理引擎      | Jolt Physics |
| Windows渲染驱动 | D3D12        |
| 版本控制        | Git          |

# 项目结构

```
demo/
├── .godot/                    # Godot引擎缓存（自动生成，无需提交）
├── addons/                    # 编辑器插件目录
│   └── godot_mcp/             # MCP调试插件
├── scripts/                   # 脚本文件目录
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
│   │   ├── building_manager.gd # 建筑管理器
│   │   ├── fluid_node_base.gd  # 流体节点基类（FluidNodeBase）
│   │   ├── container_node.gd   # 容器建筑（ContainerNode）
│   │   ├── pipe_node.gd        # 管道建筑（PipeNode）
│   │   └── water_source_node.gd # 水源建筑（WaterSourceNode）
│   ├── grid/                  # 网格系统模块
│   │   ├── grid_coordinate.gd  # 网格坐标转换
│   │   └── map_input_handler.gd # 地图输入处理
│   ├── persistence/           # 持久化模块
│   │   └── save_manager.gd     # 数据存储管理
│   ├── resources/             # 资源定义模块
│   │   ├── building_data.gd    # 建筑实例数据（BuildingData）
│   │   ├── building_type_data.gd # 建筑类型数据（BuildingTypeData）
│   │   └── undo_command.gd     # 撤销命令数据（UndoCommand）
│   ├── fluid/                  # 流体系统模块
│   │   └── fluid_coordinator.gd # 分布式流体协调器（两步提交，压力扩散模型）
│   └── ui/                    # UI组件模块
│       ├── inventory_bar.gd    # 底部建筑类型选择栏
│       ├── inventory_slot.gd   # 建筑类型槽位逻辑
│       └── building_tooltip.gd # 建筑悬停提示面板
├── resources/                 # 资源文件目录
│   ├── building_default.svg   # 默认建筑SVG贴图
│   ├── container_icon.svg     # 容器建筑槽位图标
│   ├── pipe_icon.svg          # 管道建筑槽位图标
│   ├── water_source_icon.svg  # 水源建筑槽位图标
│   └── buildings/             # 建筑类型贴图（类型4~10使用，01~03有独立图标）
├── scenes/                    # 场景文件目录
│   ├── main.tscn              # 游戏主场景文件
│   ├── start_menu.tscn        # 开始页面场景文件
│   ├── settings.tscn          # 设置页面场景文件
│   ├── inventory_bar.tscn     # 建筑选择栏场景
│   ├── inventory_slot.tscn    # 建筑槽位场景
│   └── building_tooltip.tscn  # 建筑悬停提示场景
├── save/                      # 持久化存储目录（运行时生成，gitignore）
│   ├── buildings.json         # 建筑放置数据
│   ├── keybindings.json       # 按键配置数据
│   └── game_settings.json     # 游戏数值设置（滚轮缩放倍率、Shift加速倍率）
├── icon.svg                   # 项目图标
├── project.godot              # Godot项目核心配置文件
├── .editorconfig              # 编辑器代码风格配置
├── .gitattributes             # Git属性配置
├── .gitignore                 # Git忽略文件配置
└── AGENTS.md                  # 项目描述文档
```

# 自动加载单例

| 单例名称         | 脚本路径                                      | 用途                |
| ------------ | ----------------------------------------- | ----------------- |
| GameConfig     | res\://scripts/autoload/game\_config.gd     | 游戏配置与常量集中管理（含 container_type_id, pipe_type_id, water_source_type_id, fluid_* 常量, SAVE_VERSION 等）       |
| EventBus       | res\://scripts/autoload/event\_bus.gd       | 模块间事件通信           |
| KeybindManager | res\://scripts/autoload/keybind_manager.gd | 按键配置加载/保存/重映射    |
| SelectionManager | res\://scripts/autoload/selection_manager.gd | 选中状态/剪贴板/撤销栈管理 |
| MCPRuntime     | addons/godot\_mcp（uid引用）                  | MCP调试运行时辅助（编辑器插件） |

## EventBus 信号列表

| 信号名称                     | 参数                  | 触发时机          |
| ------------------------ | ------------------- | ------------- |
| building\_placed         | grid\_pos: Vector2i | 建筑放置成功时       |
| building\_removed        | grid\_pos: Vector2i | 建筑删除成功时       |
| buildings\_loaded        | 无                   | 存档建筑数据加载完成    |
| keybind\_changed         | action: String      | 按键绑定变更时       |
| start\_game\_requested   | 无                   | 点击开始游戏按钮时      |
| show\_start\_menu\_requested | 无                | 请求显示开始菜单时      |
| show\_settings\_requested | 无                  | 请求显示设置页面时      |
| game\_settings\_changed   | 无                  | 游戏数值设置变更时      |
| selection\_changed        | selected\_cells: Array[Vector2i] | 建筑选中状态变更时   |
| paste\_mode\_changed       | active: bool        | 粘贴模式进入/退出时    |
| fluid\_updated            | 无                  | 流体系统每 tick 有流量时 |
| building\_hovered          | grid\_pos: Vector2i, node: Node2D | 鼠标悬停在建筑上时   |
| building\_hover\_exited     | grid\_pos: Vector2i | 鼠标离开建筑悬停时    |

# 主场景结构

```
Root (Node2D) → main.gd                    # 主场景控制器（管理 UI 叠加层显隐）
├── Camera2D (Camera2D) → CameraController.gd        # 当前激活相机
├── InfiniteGridMap (Node2D) → InfiniteGridMap.gd   # 无限方格地图
├── BuildingManager (Node2D) → BuildingManager.gd    # 建筑管理器
│   └── FluidCoordinator (Node) → FluidCoordinator.gd # 流体协调器（运行时动态创建）
├── SaveManager (Node) → SaveManager.gd              # 数据持久化管理
├── MapInputHandler (Node) → MapInputHandler.gd     # 地图输入处理
└── UIOverlay (CanvasLayer)                # UI 叠加层
    ├── StartMenu (Control) → StartMenu.gd  # 开始菜单（实例化 start_menu.tscn）
    ├── SettingsPanel (Control) → Settings.gd # 设置面板（实例化 settings.tscn）
    ├── InventoryBar (HBoxContainer) → InventoryBar.gd # 底部建筑类型选择栏（实例化 inventory_bar.tscn）
    └── BuildingTooltip (Control) → BuildingTooltip.gd # 建筑悬停提示（实例化 building_tooltip.tscn）
```

# 核心功能说明

- **直接加载主场景**：启动加载 main.tscn，开始菜单作为覆盖层，点击「开始游戏」后进入操作，ESC 重新呼出菜单
- **无限方格地图**：基于视口动态加载/卸载区块（640px/块），实现无缝漫游
- **细网格线自适应**：大格子数量≥6时自动隐藏细网格线
- **建筑放置/删除**：左键放置、右键删除，拖拽支持直线批量放置和矩形批量删除，拖拽时显示幽灵预览
- **建筑类型选择**：底部10槽位，数字键1~0切换，选中槽位高亮；1号=容器(ContainerNode)，2号=管道(PipeNode)，3号=水源(WaterSourceNode)
- **流体节点基类**：FluidNodeBase 抽象基类，定义 get_pressure/collect_transfers/get_tooltip_summary 等接口，所有流体建筑继承自此基类
- **容器建筑**：自定义 _draw() 渲染填充条，带 capacity/max_capacity 属性，数据持久化
- **管道建筑**：自定义 _draw() 渲染，自动检测邻居连接状态显示水平/垂直/多通，带容量缓冲，数据持久化
- **水源建筑**：自定义 _draw() 渲染石井水面效果，每 tick 产出固定水量（output_per_tick=30），压力恒为1.0，向低压力邻居推水
- **建筑悬停提示**：鼠标悬停建筑时显示浮动面板，展示建筑名称、摘要属性，支持展开查看详细信息
- **框选与复制粘贴**：框选建筑（蓝色高亮），Ctrl+C/X/V 复制/剪切/粘贴，Ctrl+Z 撤销
- **流体系统**：基于压力梯度的分布式流体算法，FluidCoordinator 每 tick 驱动多轮子迭代；水源（压力1.0）→管道（按填充率计压）→容器（压力0.0，充当汇），通过 collect_transfers 两步提交模式向低压力邻居推水，自然实现均分、防环、防溢出
- **数据持久化**：建筑/按键/设置数据自动保存到 save/ 目录，启动自动加载
- **MCP调试工具**：集成 godot_mcp 插件，支持场景运行、截图、输入模拟等调试
- **事件驱动架构**：通过 EventBus 实现模块间松耦合通信
- **配置集中管理**：GameConfig 统一管理游戏常量
- **按键配置系统**：KeybindManager 管理 InputMap 按键，支持持久化和设置页面重映射
- **游戏数值设置**：支持调整缩放倍率和加速倍率，持久化到 save/game_settings.json

# 开发规范

- 对于不确定的接口，先查询，禁止猜测用法
- 修改后使用godot-debug技能或mcp工具进行代码静态检查和运行时错误检测，确保无错误
- 使用事件总线(EventBus)进行模块间松耦合通信；同场景内兄弟节点允许通过`get_node()`直接引用（如BuildingManager、GridCoordinate），跨场景通信必须通过EventBus
- 遵循单一职责原则，每个脚本只负责一个功能域

# 运行方式

1. 打开Godot 4.6编辑器，导入项目根目录
2. 点击运行按钮或按F5键启动游戏
3. 操作说明（默认按键，可在设置页面修改）：
   - W键：相机上移
   - S键：相机下移
   - A键：相机左移
   - D键：相机右移
   - Shift键：加速移动（默认5倍速，可在设置页面调整）
   - 鼠标滚轮上：放大视角
   - 鼠标滚轮下：缩小视角
   - 鼠标左键单击：放置单个建筑（使用当前选中的类型）
   - 鼠标左键拖拽：沿直线批量放置建筑
   - 鼠标右键单击：删除单个建筑
   - 鼠标右键拖拽：矩形框选批量删除建筑
   - 数字键1~0：切换建筑类型（对应底部选择栏10个槽位）；重复按下已选中槽位可取消选择
   - ESC键：显示/关闭开始菜单
   - Ctrl+C：复制选中的建筑
   - Ctrl+X：剪切选中的建筑
   - Ctrl+V：进入粘贴模式
   - Ctrl+Z：撤销上一次操作

