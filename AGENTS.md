# 项目概述

- **项目名称**: demo
- **项目类型**: 游戏项目（开发阶段）
- **核心用途**: 基于 Godot 4.6 的 2D 网格**函数式工厂**游戏
- **玩法方向**: 数字与操作都是可流动的物品；用传送带连接机器，构造纯函数计算管道
- **技术栈**: Godot 4.6 / GDScript / Forward Plus 渲染管线

# 项目结构

```
demo/
├── addons/gut/                  # GUT 测试框架
├── scripts/                     # 源码（44 个 .gd）
│   ├── autoload/                # 单例（6 个）
│   ├── building/                # 建筑生命周期/注册表（6 个）
│   ├── items/                   # 物品模型 + 操作注册表（2 个）
│   ├── flow/                    # 物品流模拟核心（6 个）
│   ├── machine/                 # 传送带/机器节点（3 个）
│   ├── grid/                    # 网格/输入系统（5 个）
│   ├── resources/               # 数据定义（3 个）
│   ├── ui/                      # UI 组件（5 个）
│   ├── persistence/             # 存档（1 个）
│   ├── utils/                   # FileIOHelper（1 个，原子写 cfg section）
│   └── main.gd / CameraController.gd / InfiniteGridMap.gd / Settings.gd / StartMenu.gd / fps_display.gd
├── scenes/                      # 场景（6 个 .tscn）
├── resources/                   # 图标资源（6 个建筑 svg）
├── save/                        # 运行时存档（gitignore，单文件 game.cfg）
├── tests/                       # GUT 测试（31 个脚本，426 个用例）
├── project.godot / .gutconfig.json / AGENTS.md / icon.svg
└── .githooks/                   # Git 钩子（pre-commit/commit-msg）
```

# 自动加载单例

| 单例 | 用途 |
| ---- | ---- |
| GameConfig | 游戏配置与常量 |
| EventBus | 模块间事件通信 |
| KeybindManager | 按键绑定管理 |
| SelectionManager | 选中/剪贴板/撤销栈 |
| EssencePool | 源质货币池（**纯搭建阶段禁用**，仅存档保留字段） |
| ProgressSystem | 阈值解锁（**纯搭建阶段 0 阈值解锁全部 6 种建筑**，挑战系统后续接入） |

**初始化顺序**: GameConfig → EventBus → KeybindManager → SelectionManager → EssencePool → ProgressSystem

# 主场景节点树

```
Root (Node2D) → main.gd
├── Camera2D / InfiniteGridMap / BuildingManager（含 GhostPreviewManager、运行时创建的 ItemFlowCoordinator + ItemRenderer）
├── SaveManager / MapInputHandler
└── UIOverlay (CanvasLayer)：StartMenu / SettingsPanel / InventoryBar / BuildingTooltip / PauseOverlay / FPSDisplay / KeyHints / MachineConfigPanel（运行时动态创建）
```

# 核心系统摘要

- **数据模型**: 物品 `Item`（scripts/items/item.gd）= `{类型: NUM|OP, value: int64}`；数字直接存值（int64 溢出**回绕**，突破上限靠玩家自研多物品大数编码），操作存 OpRegistry 索引
- **操作注册表**: OpRegistry（静态表）内置 6 个一元操作：`+1 / -1 / ×2 / ÷2(向零整除) / 取反 / 判零(→1/0)`；`compose(a,b)` 合成复合操作（先 a 后 b，id 从 100 递增，**同内容组合幂等复用**）。**注意 `get_name` 与 GDScript 原生方法冲突，操作显示名用 `op_name()`**
- **操作持久化（定义串）**: 复合操作 id 是会话内递增的，重启后旧 id 失效——存档/剪贴板/撤销一律附带 `op_def`/`filter_op_def` 定义串（内置为稳定 key `add1` 等；复合为 JSON `["compose", defA, defB]`，可任意嵌套），加载时 `ensure_from_definition` 幂等重建
- **机器规格**: MachineSpec 定义建筑类型 id（6 种可放置 + 1 种隐藏一体建筑）、端口布局（本地坐标+旋转）、行为 kind、颜色、显示名。方向 0东1南2西3北，R 键旋转；拖拽放置按拖拽路径逐格自动定朝向（L 型水平段/垂直段/拐角各沿路径方向）；`get_port_offsets(type_id, dir)` 返回统一端口视图（传送带后入前出，机器用 SPECS），供预览框端口箭头绘制
- **建筑清单**: 传送带 / 数字源(产 1) / 应用器(2入1出: op+data→结果) / 分流器(交替位) / 筛选器(谓词分流: 前口通过/侧口拒绝) / 垃圾桶。**操作源/合流器已移除**：操作物品暂缺生产来源（应用器/op 筛选仅处理遗留物品），待后续机制接入
- **分流器可放传送带上（一体建筑 `belt_splitter`）**: 放置分流器到传送带格 → 该格替换为"传送带+分流器"一体建筑（不占额外格、不上库存栏，仅由转换/撤销/粘贴/存档恢复生成）。物品流：上游带把物品推进一体建筑格（该格可停靠、不进 machine_cells 守卫），分流器在机器阶段读**自身格**物品，按交替位送前口（带子延续）或左口（垂直于流向），送达翻位、出口被占等待不翻位；该格自身不做传送带移动处理。**删除一体建筑 = 传送带一并删除**；撤销放置会用 UndoCommand.previous 还原原传送带（否则会丢带）；方向取放置方向（缺省沿用原带方向）。其他机器（应用器/筛选器等）仍不能放传送带上
- **物品流模拟**: ItemSimulator（纯静态函数，无节点依赖，可直接单元测试）。每 tick 两阶段：
  - 机器阶段：按格坐标排序逐个触发，**输入到齐 + 类型匹配 + 输出格空**才触发，否则背压等待（物品永不丢失）
  - 移动阶段：传送带按方向分组（N→E→S→W 固定顺序），组内下游先处理（让位链），同向链整体推进；**空地守卫：传送带只把物品推进到传送带格或机器端口格，空地不接收（背压等待），数字不落空地**；机器自身格永不放物品；满环 = 合法积压稳态
- **分帧模拟**: ItemFlowCoordinator（Node 包装）0.1s Timer 仅置标记，`_process` 每帧推进一个阶段（MACHINE→MOVE）；`_on_tick()` 同步完整 tick 供测试直调；暂停即刻冻结（先补发已产生事件保持渲染一致）；tick 完成后发 `sim_tick_completed(events)` 事件数组
- **渲染**: ItemRenderer 消费 tick 事件，每格一个视觉实体（数字=圆形/操作=方形 + Label），**位置插值**平滑（记录 tick 起止位置，`_process` 插值）。物品不落盘：重载后清空带子，源头重新产出；删除建筑时其上/端口残留物品同步 despawn（渲染不悬空）
- **建筑生命周期**: BuildingManager 持有 `buildings: Dictionary[Vector2i, BuildingData]`，朝向/操作选择/筛选谓词/分流位存于 BuildingData；节点（BeltNode/MachineNode）仅负责视觉；BuildingDataSyncService 双向同步 + entry↔restore_data 助手（撤销/剪贴板/存档共用）
- **持久化**: 单文件存档 `save/game.cfg`（ConfigFile），`[buildings]` 含 per-building `type/direction/op_choice/filter_*/splitter_phase`（默认配置省略）；**未知类型（旧流体存档）加载跳过不崩溃**（含已移除的操作源/合流器旧条目，同样静默跳过）；物品流不落盘
- **UI**: 库存栏 10 槽（6 建筑 + 4 占位锁定，键盘 1-6 覆盖前 6 槽，其余点击）；MachineConfigPanel 仅服务筛选器（设谓词）；配置变更经 `machine_config_changed` 触发延迟存档；放置/粘贴预览框按类型+朝向绘制**端口方向箭头**（输入=绿箭头指向格内，输出=白箭头指向格外；传送带后入前出）

# 通信方式

通过 EventBus 松耦合通信（同场景兄弟节点允许 `get_node()` 直接引用）。新增信号：`sim_tick_completed(events)`、`machine_config_changed(grid_pos)`、`config_panel_opened/closed`。旧元素信号（element_*）与旧类型 id 常量保留声明兼容旧存档。

# Git Hooks 与工具

`.githooks/pre-commit` 提交时自动运行：**Godot 导入缓存刷新** → **godot-debug 技能脚本项目检查**（`$HOME/.trae-cn/skills/godot-debug/check_godot_project.ps1`，集中维护，不在仓库内，缺失则提交失败）→ **GUT 测试**。测试通过时静默，失败时仅显示 fail/error 相关行。已通过 `git config core.hooksPath .githooks` 启用。

`.githooks/commit-msg` 强制 **Conventional Commits** 格式（`type(scope): 描述`，标题后空行；type ∈ feat/fix/docs/style/refactor/perf/test/build/ci/chore/revert），不满足则阻止提交。已有提交历史均遵循此规范。

**Godot 路径**: 钩子/脚本用 `$GODOT_PATH` 环境变量（默认 `C:/Users/MLTZ/Desktop/Godot_v4.6.1-stable_win64.exe`），使用前需设置。

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

# 设计决策备忘

- 数值/操作皆为一等物品 → 反馈带 = 纯函数式迭代（无状态循环）
- 物品永不丢失（背压等待），唯一删除途径是垃圾桶
- 纯搭建阶段：全部建筑 0 阈值解锁、免费放置；挑战系统（输入/输出终端、大数解锁）留待后续
- 分帧模拟与增量优化思路继承自旧流体版（ReactionCoordinator 模式），渲染插值替代 MultiMesh 批处理
- 数据同步陷阱：`MachineSpec.get_name` 类命名需避开 GDScript 原生方法（如 `get_name`）；类型化 Dictionary 属性不能用 `Object.set` 重置（静默失败），用 `.clear()`
- UI 陷阱：autowrap Label 的 min size 宽度恒为 1（可压缩到任意窄），BuildingTooltip 短摘要文本必须关闭 autowrap 才能按自然宽度撑开卡片（否则 VBox 塌缩成竖排窄条，面板尺寸与内容错位）；异步尺寸重算（await process_frame）须用代次守卫防止过期续体覆盖新布局
- 坐标陷阱：机器端口偏移必须叠加机器格转世界坐标（曾直接当世界坐标导致非原点机器错位，被"机器全在原点"的测试掩盖）；`rotate_offset` 顺时针公式为 `(x,y)->(-y,x)`（方向编号即顺时针转数）
- 管道容量：反馈回路的带链容量有限，持续注入物品会填满并全局背压冻结（物品不丢、机器等待），属正常积压稳态；需要排泄口（垃圾桶）或控制注入速率
- 进程内状态陷阱：SelectionManager 等 autoload 状态跨测试共享，测试需显式复位（如粘贴模式残留会让 R 键走粘贴分支）；GUT 场景树是活的，协调器 0.1s Timer 会在测试期间真实运行，测试需停 Timer 防竞态