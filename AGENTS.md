# 项目概述

- **项目名称**: demo
- **项目类型**: 游戏项目（开发阶段）
- **核心用途**: 基于 Godot 4.6 的 2D 网格建筑与流体模拟游戏
- **技术栈**: Godot 4.6 / GDScript / Forward Plus 渲染管线

# 项目结构

```
demo/
├── addons/gut/                  # GUT 测试框架
├── scripts/                     # 源码（48 个 .gd）
│   ├── autoload/                # 单例（6 个）
│   ├── building/                # 建筑系统（12 个）
│   ├── elements/                # 元素系统（2 个）
│   ├── grid/                    # 网格/输入系统（5 个）
│   ├── reaction/                # 模拟系统（6 个）
│   ├── ui/                      # UI 组件（6 个）
│   ├── persistence/             # 存档（1 个）
│   ├── resources/               # 数据定义（3 个）
│   └── main.gd / CameraController.gd / InfiniteGridMap.gd / Settings.gd / StartMenu.gd / fps_display.gd
├── scenes/                      # 场景（7 个 .tscn）
├── resources/                   # 图标资源（5 个 .svg）
├── save/                        # 运行时存档（gitignore，单文件 game.cfg）
├── tests/                       # GUT 测试（33 unit + 3 integration）
├── project.godot / .gutconfig.json / AGENTS.md / icon.svg
└── .githooks/                   # Git 钩子（pre-commit/commit-msg）
```

# 自动加载单例

| 单例 | 用途 |
| ---- | ---- |
| GameConfig | 游戏配置与常量 |
| EventBus | 模块间事件通信 |
| ElementRegistry | 元素类型注册表 |
| KeybindManager | 按键绑定管理 |
| SelectionManager | 选中/剪贴板/撤销栈 |
| EssencePool | 源质货币池（MAX_ESSENCE 上限） |
| ProgressSystem | 源质阈值解锁建筑类型 |

**初始化顺序**: GameConfig → EventBus → ElementRegistry → KeybindManager → SelectionManager → EssencePool → ProgressSystem

# 主场景节点树

```
Root (Node2D) → main.gd
├── Camera2D / InfiniteGridMap / BuildingManager（含 PipeRenderSystem/GhostPreviewManager/ElementRenderer/ReactionCoordinator）
├── SaveManager / MapInputHandler
└── UIOverlay (CanvasLayer)：StartMenu / SettingsPanel / InventoryBar / BuildingTooltip / EssenceDisplay / PauseOverlay / ElementTypePanel（运行时动态创建）/ FPSDisplay / KeyHints
```

# 核心系统摘要

- **输入状态机**: 6 状态（IDLE/DRAGGING/REMOVING/SELECTING/DESELECTING/PASTE_DRAGGING），按模式切换幽灵预览。R 键仅切换拖拽角点
- **幽灵预览**: GhostPreviewManager 维护多组预览数组（ghost/selected/paste/remove），`_draw()` 统一渲染
- **建筑系统**: 管道/源头/收集器/砖块 + 地图中心核心，BuildingFactory 基于 `BuildingTypeData.Category` 枚举注册表创建。`clear_all_buildings()` 逐个 emit `building_removed`，`clear_all_buildings_silent()` 静默清空
- **源头系统**: SourceNode 无方向概念，不自行产出。默认关闭态（未选类型 `has_type_selected=false`）灰显且不产出，开启后按类型着色。关闭态不落盘元素类型（重载后仍保持关闭），旧存档携带类型的源头重载后自动转为已确认。ElementDiffusion 每 tick 开头按需创建种子：相邻已有同类型元素→免费维持；否则按状态选种子位置（LIQUID→DOWN、GAS→UP）免费创建。源质仅在扩散扩张时消耗（每格 1.0）。元素类型存于 SourceNode，ElementGrid._source_buildings 仅记录位置
- **收集器筛选**: CollectorNode 的 filter_element_type 字段，空串=收全部（默认，兼容旧存档），非空仅收匹配类型。通过共享 ElementTypePanel（Mode.COLLECTOR）选择
- **共享 UI 面板**: ElementTypePanel 用 Mode 枚举（SOURCE/COLLECTOR）服务两类建筑，源头模式无"全部"，收集器模式有"全部"按钮（空筛选）。信号 `element_type_panel_opened/closed`。源头/收集器放置后自动弹出面板；**任何模式**（选择/放置）下左键点击已有源头/收集器均可重新打开面板
- **模拟系统**: ReactionCoordinator 管理 BFS 网络拓扑（从核心搜索），每 tick：产物计时器递减→收集→扩散(含源头种子)→反应→周期性距离/遗弃清理。水源标记每 tick 清空重建（源头类型切换后旧类型元素体立即失去源，只滑动不扩张）。元素失去源后不增殖，仅沿自然方向**滑动**（液体下沉/气体上浮，格子总数不变、不耗源质），移出距离边界由 `cleanup_abandoned` 兜底（每 CLEANUP_INTERVAL_TICKS 移除距核心切比雪夫距离超 ELEMENT_ABANDON_DISTANCE 的元素）。只有连通核心的管道网络才能激活源头/收集器
- **元素系统**: 水/火/蒸汽，按 State（LIQUID/GAS/SOLID）差异化扩散（液体向下、气体向上、固体不动），反应产物存续标记防瞬间消失
- **反应系统**: ReactionRegistry 注册规则（无序匹配，重复注册跳过并告警），ReactionProcessor 每 tick 检测相邻格子反应，密度决定产物位置
- **源质经济**: EssencePool 管理货币（MAX_ESSENCE 上限，setter/add 均 clampf），ProgressSystem 按阈值解锁。BuildingManager/ReactionCoordinator/ElementDiffusion/ReactionProcessor 通过依赖注入（`_essence_service` + `set_essence_service()`）解耦，未注入回退 EssencePool，支持测试隔离
- **框选与剪贴板**: 选中 → Ctrl+C/X/V 复制/剪切/粘贴，Ctrl+Z/Y 撤销/重做（栈上限 100），粘贴支持旋转和拖拽
- **持久化**: 单文件存档 `save/game.cfg`（ConfigFile），含 `[buildings]`/`[settings]`/`[keybindings]` 三 section。各模块经 `FileIOHelper.write_cfg_section` 读写自己的 section（保留其他 section，原子保存 .tmp->rename）。启动自动加载；首次启动检测到旧版多 JSON 存档会迁移到 game.cfg 并重命名旧文件为 .json.bak
- **可视化**: 管道 ECS 批量渲染（PackedVector2Array）、流体批量渲染、无限网格分块渲染

# 通信方式

通过 EventBus 松耦合通信（同场景兄弟节点允许 `get_node()` 直接引用）。信号覆盖建筑放置/删除、元素生成/移除、源质变更、暂停、选中、粘贴模式、阈值解锁、按键重置（`keybinds_reset`，区别于单键变更的 `keybind_changed`）等。

# Git Hooks 与工具

`.githooks/pre-commit` 提交时自动运行：**Godot 项目错误检查** → **GUT 测试**。已通过 `git config core.hooksPath .githooks` 启用。

**Godot 路径**: 钩子用 `$GODOT_PATH` 环境变量（默认 `C:/Users/MLTZ/Desktop/Godot_v4.6.1-stable_win64.exe`），使用前需设置。

# 测试

## 使用 godot_use 试玩(可选)

通过 godot_use MCP 工具在运行时试玩/验证游戏

## 自动流程

提交代码时 pre-commit hook 自动运行 godot-debug 错误检查 + GUT 测试套件，全部通过后才继续。

```bash
git add -A && git commit -m "feat: 你的改动说明"
```

## 手动运行

```bash
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1
```

**验证**: 脚本退出码 `exit_code == 0` 即全部通过。脚本自动删除旧 `save/test_output.xml`（避免残留结果误读上一轮状态），运行后清理测试输出。