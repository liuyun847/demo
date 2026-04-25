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
├── addons/                    # 编辑器插件目录（gitignore，不入版本控制）
│   └── godot_mcp/             # MCP调试插件
├── scripts/                   # 脚本文件目录
│   ├── InfiniteGridMap.gd     # 无限方格地图核心实现脚本
│   ├── CameraController.gd    # 相机控制器脚本，负责视角漫游控制
│   ├── StartMenu.gd           # 开始页面逻辑脚本
│   ├── Settings.gd            # 设置页面逻辑脚本
│   ├── autoload/              # 自动加载单例目录
│   │   ├── game_config.gd     # 游戏配置与常量
│   │   ├── scene_paths.gd     # 场景路径管理
│   │   ├── event_bus.gd       # 事件总线
│   │   └── scene_manager.gd   # 场景管理器
│   ├── building/              # 建筑系统模块
│   │   └── building_manager.gd # 建筑管理器
│   ├── grid/                  # 网格系统模块
│   │   ├── grid_coordinate.gd  # 网格坐标转换
│   │   └── map_input_handler.gd # 地图输入处理
│   ├── persistence/           # 持久化模块
│   │   └── save_manager.gd     # 数据存储管理
│   └── resources/             # 资源定义模块
│       └── building_data.gd   # 建筑数据资源定义（class_name BuildingData, extends Resource）
├── scenes/                    # 场景文件目录
│   ├── main.tscn              # 游戏主场景文件
│   ├── start_menu.tscn        # 开始页面场景文件
│   └── settings.tscn          # 设置页面场景文件
├── save/                      # 持久化存储目录（运行时生成，gitignore）
│   └── buildings.json         # 建筑放置数据
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
| GameConfig   | res\://scripts/autoload/game\_config.gd   | 游戏配置与常量集中管理       |
| ScenePaths   | res\://scripts/autoload/scene\_paths.gd   | 场景路径常量管理          |
| EventBus     | res\://scripts/autoload/event\_bus.gd     | 模块间事件通信           |
| SceneManager | res\://scripts/autoload/scene\_manager.gd | 场景切换管理            |
| MCPRuntime   | addons/godot\_mcp（uid引用）                  | MCP调试运行时辅助（编辑器插件） |

## EventBus 信号列表

| 信号名称              | 参数                  | 触发时机       |
| ----------------- | ------------------- | ---------- |
| building\_placed  | grid\_pos: Vector2i | 建筑放置成功时    |
| building\_removed | grid\_pos: Vector2i | 建筑删除成功时    |
| buildings\_loaded | 无                   | 存档建筑数据加载完成 |

# 主场景结构

```
Root (Node2D)
├── Camera2D (Camera2D) → CameraController.gd        # 当前激活相机
├── InfiniteGridMap (Node2D) → InfiniteGridMap.gd   # 无限方格地图
├── GridCoordinate (Node) → GridCoordinate.gd       # 网格坐标转换工具
├── BuildingManager (Node2D) → BuildingManager.gd    # 建筑管理器
├── SaveManager (Node) → SaveManager.gd              # 数据持久化管理
└── MapInputHandler (Node) → MapInputHandler.gd     # 地图输入处理
```

# 核心功能说明

当前项目处于开发阶段，已实现的功能：

- **启动开始页面**：游戏启动默认显示开始页面，包含「开始游戏」和「设置」两个按钮
  - 点击「开始游戏」进入主游戏场景
  - 点击「设置」进入设置页面，可返回开始菜单
- **动态加载无限方格地图**：支持基于相机视口动态加载/卸载地图块，实现无限大地图的无缝漫游效果
  - 区块（block）大小 = cell\_size × big\_cell\_size（默认 64×10 = 640像素）
  - 视口范围外扩1个区块作为缓冲区预加载
  - 离开视口的区块自动卸载
- **细网格线自动隐藏**：当视口内可见的大格子数量达到6个及以上时，自动隐藏小格子细网格线，只保留大方格粗网格线，优化视觉效果
- **相机漫游控制**：支持键盘移动/加速、鼠标滚轮缩放（详见运行方式）
- **建筑数据持久化存储**：用户放置/删除的建筑数据自动保存到 `save/buildings.json`，游戏启动时自动加载
  - 存档格式：`{ "version": "1.0.0", "saved_at": "时间戳", "buildings": { "x,y": { "type": "default" } } }`
  - 编辑器模式下存档路径为 `res://save/`，导出后为可执行文件同级的 `save/` 目录
  - 所有持久化存储数据均统一存放于save目录下
- **MCP调试工具**：项目集成了 godot\_mcp 编辑器插件和 MCPRuntime 自动加载单例，用于AI辅助开发时的场景运行、截图、输入模拟等调试操作
- **事件驱动架构**：通过 EventBus 实现模块间松耦合通信
- **配置集中管理**：所有游戏配置常量统一在 GameConfig 中管理

# 开发规范

- 对于不确定的接口，先查询，禁止猜测用法
- 修改后使用godot-debug技能或mcp工具进行代码静态检查和运行时错误检测，确保无错误
- 使用`@export`注解暴露可配置参数
- 节点脚本使用`extends`继承对应节点类型
- 使用事件总线(EventBus)进行模块间通信，避免直接节点引用
- 遵循单一职责原则，每个脚本只负责一个功能域

# 运行方式

1. 打开Godot 4.6编辑器，导入项目根目录
2. 点击运行按钮或按F5键启动游戏
3. 操作说明：
   - WASD键：控制相机前后左右移动
   - Shift键：加速移动（3倍速）
   - 鼠标滚轮：缩放视角（以鼠标位置为中心）
   - 鼠标左键：放置建筑
   - 鼠标右键：删除建筑

# 部署方式

1. 在Godot编辑器中选择菜单栏「项目」->「导出」
2. 选择目标导出平台（Windows/Linux/macOS等）
3. 配置导出参数（如图标、版本号等）
4. 点击「导出项目」即可生成对应平台的独立可执行文件

# 安全约束

- 禁止提交.godot目录下的自动生成缓存文件
- 代码修改后必须经过调试无误后才能合并
- 不要在代码中硬编码任何敏感信息（如密钥、密码等）

