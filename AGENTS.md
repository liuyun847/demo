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
├── .godot/                    # Godot引擎缓存目录（自动生成，无需提交）
│   ├── editor/                # 编辑器配置缓存
│   ├── imported/              # 资源导入缓存
│   ├── shader_cache/          # 着色器编译缓存
│   └── 其他缓存文件
│   # 注：每个.gd文件会自动生成同名.gd.uid文件，.svg等资源会自动生成.import文件，均无需手动管理
├── addons/                    # 编辑器插件目录（gitignore，不入版本控制）
│   └── godot_mcp/             # MCP调试插件
├── scripts/                   # 脚本文件目录
│   ├── main.gd                # 主场景控制器（管理 UI 叠加层显示/隐藏、暂停状态）
│   ├── InfiniteGridMap.gd     # 无限方格地图核心实现脚本
│   ├── CameraController.gd    # 相机控制器脚本，负责视角漫游控制
│   ├── StartMenu.gd           # 开始页面逻辑脚本
│   ├── Settings.gd            # 设置页面逻辑脚本
│   ├── autoload/              # 自动加载单例目录
│   │   ├── game_config.gd     # 游戏配置与常量
│   │   ├── scene_paths.gd     # 场景路径管理
│   │   ├── event_bus.gd       # 事件总线
│   │   ├── scene_manager.gd   # 场景管理器
│   │   ├── keybind_manager.gd # 按键配置管理
│   │   └── selection_manager.gd # 选中/剪贴板/撤销管理
│   ├── building/              # 建筑系统模块
│   │   └── building_manager.gd # 建筑管理器
│   ├── grid/                  # 网格系统模块
│   │   ├── grid_coordinate.gd  # 网格坐标转换
│   │   └── map_input_handler.gd # 地图输入处理
│   ├── persistence/           # 持久化模块
│   │   └── save_manager.gd     # 数据存储管理
│   ├── resources/             # 资源定义模块
│   │   ├── building_data.gd    # 建筑实例数据（class_name BuildingData, extends RefCounted）
│   │   ├── building_type_data.gd # 建筑类型数据（class_name BuildingTypeData, extends Resource）
│   │   └── undo_command.gd     # 撤销命令数据（class_name UndoCommand, extends RefCounted）
│   └── ui/                    # UI组件模块
│       ├── inventory_bar.gd    # 底部建筑类型选择栏
│       └── inventory_slot.gd   # 建筑类型槽位逻辑
├── resources/                 # 资源文件目录
│   ├── building_default.svg   # 默认建筑SVG贴图
│   └── buildings/             # 各类型建筑贴图目录
│       ├── building_01.svg ~ building_10.svg  # 10种建筑类型贴图
├── scenes/                    # 场景文件目录
│   ├── main.tscn              # 游戏主场景文件
│   ├── start_menu.tscn        # 开始页面场景文件
│   ├── settings.tscn          # 设置页面场景文件
│   ├── inventory_bar.tscn     # 建筑选择栏场景
│   └── inventory_slot.tscn    # 建筑槽位场景
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
| GameConfig     | res\://scripts/autoload/game\_config.gd     | 游戏配置与常量集中管理       |
| ScenePaths     | res\://scripts/autoload/scene\_paths.gd     | 场景路径常量管理          |
| EventBus       | res\://scripts/autoload/event\_bus.gd       | 模块间事件通信           |
| SceneManager   | res\://scripts/autoload/scene\_manager.gd   | 场景切换管理            |
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

# 主场景结构

```
Root (Node2D) → main.gd                    # 主场景控制器（管理 UI 叠加层显隐）
├── Camera2D (Camera2D) → CameraController.gd        # 当前激活相机
├── InfiniteGridMap (Node2D) → InfiniteGridMap.gd   # 无限方格地图
├── BuildingManager (Node2D) → BuildingManager.gd    # 建筑管理器
├── SaveManager (Node) → SaveManager.gd              # 数据持久化管理
├── MapInputHandler (Node) → MapInputHandler.gd     # 地图输入处理
└── UIOverlay (CanvasLayer)                # UI 叠加层
    ├── StartMenu (Control) → StartMenu.gd  # 开始菜单（实例化 start_menu.tscn）
    ├── SettingsPanel (Control) → Settings.gd # 设置面板（实例化 settings.tscn）
    └── InventoryBar (HBoxContainer) → InventoryBar.gd # 底部建筑类型选择栏（实例化 inventory_bar.tscn）
```

# 核心功能说明

当前项目处于开发阶段，已实现的功能：

- **启动直接加载主场景**：游戏启动默认加载 main.tscn，开始菜单作为前景覆盖层显示在游戏画面上方
  - 游戏世界（含存档建筑）在菜单后方完整渲染，玩家启动时即可看到游戏内容
  - 等待存档建筑加载完成后自动弹出开始菜单
  - 点击「开始游戏」关闭菜单，进入游戏操作
  - 游戏中按 ESC 键重新显示开始菜单
- **动态加载无限方格地图**：支持基于相机视口动态加载/卸载地图块，实现无限大地图的无缝漫游效果
  - 区块（block）大小 = cell\_size × big\_cell\_size（默认 64×10 = 640像素）
  - 视口范围外扩1个区块作为缓冲区预加载
  - 离开视口的区块自动卸载
- **细网格线自动隐藏**：当视口内可见的大格子数量达到6个及以上时，自动隐藏小格子细网格线，只保留大方格粗网格线，优化视觉效果
- **相机漫游控制**：支持键盘移动/加速、鼠标滚轮缩放（详见运行方式），按键绑定通过 InputMap 系统管理
- **建筑系统交互**：
  - 鼠标左键单击：在目标格子放置单个建筑（使用当前选中的建筑类型）
  - 鼠标左键拖拽：在拖拽起点与终点之间沿直线批量放置建筑
  - 鼠标右键单击：删除目标格子的单个建筑
  - 鼠标右键拖拽：以拖拽起点和终点构成矩形区域，批量删除区域内所有建筑
  - 拖拽过程中显示幽灵预览（白色半透明框表示即将放置，红色半透明框表示即将删除）
- **建筑类型选择系统**：底部提供10个槽位的建筑选择栏，支持切换不同建筑类型进行放置
  - 数字键1~0：快速切换对应的10种建筑类型；若该槽位已选中，则取消选择进入框选模式
  - 每种建筑类型拥有独立的图标贴图和配色（基于HSV色环分配）
  - 选中的槽位会高亮显示，放置建筑时自动使用当前选中类型
  - 点击已选中的槽位可取消选择，进入「无建筑选中」状态
- **建筑框选与复制粘贴系统**：支持框选建筑和复制粘贴操作
  - 无建筑选中时（框选模式）：
    - 鼠标左键单击/拖拽：框选建筑（矩形选取），已选中建筑显示蓝色高亮
    - 鼠标右键单击/拖拽：取消框选区域内的建筑选中状态
  - 复制（Ctrl+C）：将选中建筑写入剪贴板
  - 剪切（Ctrl+X）：将选中建筑写入剪贴板并从地图上删除
  - 粘贴（Ctrl+V）：进入粘贴模式，鼠标位置显示粘贴虚影（按建筑类型着色）
    - 粘贴模式下左键点击：在目标位置放置虚影中的建筑
    - 粘贴模式下右键点击：取消粘贴模式
  - 撤销（Ctrl+Z）：撤销最近的放置/删除/剪切/粘贴操作
- **建筑数据持久化存储**：用户放置/删除的建筑数据自动保存到 `save/buildings.json`，游戏启动时自动加载
  - 存档格式：`{ "version": "1.0.0", "saved_at": "时间戳", "buildings": { "x,y": { "type": "type_01" } } }`
  - 编辑器模式下存档路径为 `res://save/`，导出后为可执行文件同级的 `save/` 目录
  - 所有持久化存储数据均统一存放于save目录下
- **MCP调试工具**：项目集成了 godot\_mcp 编辑器插件和 MCPRuntime 自动加载单例，用于AI辅助开发时的场景运行、截图、输入模拟等调试操作
- **事件驱动架构**：通过 EventBus 实现模块间松耦合通信
- **配置集中管理**：所有游戏配置常量统一在 GameConfig 中管理
- **按键配置系统**：通过 KeybindManager 管理按键绑定，支持持久化到 `save/keybindings.json`
  - 使用 Godot InputMap 系统定义动作（move\_up/down/left/right、speed\_up、zoom\_in/out、place/remove\_building）
  - 修改按键后自动保存，游戏启动时自动加载
  - 设置页面支持点击按键按钮进入监听模式，按下新按键即可重映射
- **游戏数值设置系统**：支持在设置页面调整滚轮缩放倍率和 Shift 加速倍率，持久化到 `save/game_settings.json`
  - 设置页面采用左右两列布局，左列「按键设置」、右列「游戏设置」
  - 游戏设置使用滑动条 + 短文本框组合，支持拖动和键入数字
  - 修改后实时生效并自动保存，游戏启动时自动加载

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

