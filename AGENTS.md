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
├── scripts/                     # 源码（45 个 .gd）
│   ├── autoload/                # 单例（6 个）
│   ├── building/                # 建筑生命周期/注册表（6 个）
│   ├── items/                   # 物品模型 + 操作注册表（2 个）
│   ├── flow/                    # 物品流模拟核心（6 个）
│   ├── machine/                 # 传送带/机器节点 + 带子连接分析（4 个）
│   ├── grid/                    # 网格/输入系统（5 个）
│   ├── resources/               # 数据定义（3 个）
│   ├── ui/                      # UI 组件（5 个）
│   ├── persistence/             # 存档（1 个）
│   ├── utils/                   # FileIOHelper（1 个，原子写 cfg section）
│   └── main.gd / CameraController.gd / InfiniteGridMap.gd / Settings.gd / StartMenu.gd / fps_display.gd
├── scenes/                      # 场景（6 个 .tscn）
├── resources/                   # 图标资源（5 个建筑 svg）
├── save/                        # 运行时存档（gitignore，单文件 game.cfg）
├── tests/                       # GUT 测试（33 个脚本，505 个用例，以 GUT 运行输出为准）
├── working/                     # 开发中临时记录/资料/脚本等（如 TODO.md；不参与构建/提交）
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
| ProgressSystem | 阈值解锁（**纯搭建阶段 0 阈值解锁全部 5 种建筑**，挑战系统后续接入） |

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
- **操作持久化（定义串）**: 复合操作 id 是会话内递增的，重启后旧 id 失效——存档/剪贴板/撤销一律附带 `op_def` 定义串（内置为稳定 key `add1` 等；复合为 JSON `["compose", defA, defB]`，可任意嵌套；分流器 op 条件在 `splitter_filters` 内附带 `op_def`），加载时 `ensure_from_definition` 幂等重建
- **机器规格**: MachineSpec 定义建筑类型 id（5 种可放置 + 1 种隐藏一体建筑）、端口布局（本地坐标+旋转）、行为 kind、颜色、显示名。方向 0东1南2西3北，R 键旋转；拖拽放置按拖拽路径逐格自动定朝向（L 型水平段/垂直段/拐角各沿路径方向）；`get_port_offsets(type_id, dir)` 返回统一端口视图（传送带后入前出，机器用 SPECS），供预览框端口箭头绘制
- **建筑清单**: 传送带 / 数字源(产 1，**无方向**：无固定输出口，每 tick 按北→东→南→西优先级自动向四周相邻传送带/一体建筑格或贴脸对齐机器输出，被占换向，无接收方不产、不落空地；**不投隔一格机器的输入口端口格**（仅相邻承接，旧版"隔空供料"布局变为背压等待）；方向字段对其无意义，存档/剪贴板仍保留) / 应用器(2入1出: **输入口角色固定**——数据口(机器上画半圆标记)只收数字，操作口(方标记)收操作物品按注册表应用、收数字 n 视为 "+n") / 分流器(四向: 任意口进出、均分轮询、被占换向不阻塞；**按输出方向独立过滤**——每方向可设 无条件/数字比较/操作匹配 条件，物品只能走无条件或条件匹配的方向，全部不匹配=背压等待，默认全无条件行为不变；**放置后不自动弹配置面板**，点击分流器/一体建筑手动打开逐方向设置) / 垃圾桶(**两类输入**：①传送带把物品推进垃圾桶本体格（本体格可停靠、不进 machine_cells 守卫）即销毁——带子链尾接垃圾桶是标准排泄口用法；②贴脸机器（数字源四邻扫描命中/应用器/分流器等输出口正对垃圾桶）经 0 格直传面槽投递销毁。**不从旁格主动吸取**：旁格（带格/端口格）上的物品不会被销毁，垃圾桶端口格不可停靠，每 tick 至多 1 个，方向无意义)。**筛选器已移除**（谓词能力并入分流器按方向过滤；旧存档 filter 条目加载静默跳过）。**操作源/合流器已移除**：操作物品暂缺生产来源（应用器操作口/op 过滤仅处理遗留物品，操作口数字 n = +n 是当前可用捷径），待后续机制接入
- **分流器可放传送带上（一体建筑 `belt_splitter`）**: 放置分流器到传送带格 → 该格替换为"传送带+分流器"一体建筑（不占额外格、不上库存栏，仅由转换/撤销/粘贴/存档恢复生成）。物品流：上游带把物品推进一体建筑格（该格可停靠、不进 machine_cells 守卫），分流器在机器阶段读**自身格**物品（优先），否则轮询读取 4 向端口格物品；输出为 4 向均分轮询（splitter_phase 起始方向，投递成功 +1），**排除上游方向与输入方向**（防回流循环），被占换向不阻塞、全部不可投背压等待；该格自身不做传送带移动处理。**删除一体建筑 = 传送带一并删除**；撤销放置会用 UndoCommand.previous 还原原传送带（否则会丢带）；方向取放置方向（缺省沿用原带方向）。其他机器（应用器/垃圾桶等）仍不能放传送带上
- **物品流模拟**: ItemSimulator（纯静态函数，无节点依赖，可直接单元测试）。每 tick 两阶段：
  - 机器阶段：按格坐标排序逐个触发，**输入到齐 + 类型匹配 + 输出格空**才触发，否则背压等待（物品永不丢失）
  - 移动阶段：传送带按方向分组（N→E→S→W 固定顺序），组内下游先处理（让位链），同向链整体推进；**空地守卫：传送带只把物品推进到传送带格或机器端口格，空地不接收（背压等待），数字不落空地**；机器自身格永不放物品（例外：垃圾桶本体格可停靠，见建筑清单）；满环 = 合法积压稳态
- **0 格贴脸直传（面槽）**: 机器 A 输出口恰好是机器 B 本体格且 B 有输入口正对 A（**双向端口互认对齐**，如数字源紧贴分流器）时，物品经 `ItemGrid.edge_slots`（键=生产者格，值={item, front: Vector2i}）直接传递，不占任何网格格；面槽满/不对齐 → 按"输出被占"背压等待；`belt_splitter` 是带子语义：作为**消费目标**时输入=自身格（面输入不适用，由目标侧检查排除），但作为**生产者**可向贴脸机器面直传（读侧不排除一体建筑——否则其面输出永久不可读，回归测试覆盖）。机器格守卫回归语义不变。**带子"端口吸附"保持穿过+顺带抽取现状**：带格是机器输入口时机器在机器相位取走带格上的物品，带子照常推进（端口不是带子终点）；带子连口/顺带抽取的连接分析供视觉绘制（BeltConnection）
- **分帧模拟**: ItemFlowCoordinator（Node 包装）0.1s Timer 仅置标记，`_process` 每帧推进一个阶段（MACHINE→MOVE）；`_on_tick()` 同步完整 tick 供测试直调；暂停即刻冻结（先补发已产生事件保持渲染一致）；tick 完成后发 `sim_tick_completed(events)` 事件数组
- **渲染**: ItemRenderer 消费 tick 事件，每格一个视觉实体（数字=圆形/操作=方形 + Label），**位置插值**平滑（记录 tick 起止位置，`_process` 插值）；面槽物品按事件 `face` 偏移定位到**共享边中点**（视觉键 = Vector3i(cell.x, cell.y, face 索引)，与网格格视觉分离）。**机器进出动画（"其他建筑补全移动动画"）**：模拟器在机器相关事件上附加可选字段——spawn 带 `producer`（产出机器格）、despawn 带 `consumer`（消费/销毁位置格；垃圾桶本体格销毁时 consumer=自身格）；渲染器仅对这些带字段的事件做动画——"机器产出"视觉从机器格中心滑入落点（数字源产 1/应用器/分流器吐出）、"机器消费"视觉滑入目标格后消失（应用器吞输入/垃圾桶销毁；退场视觉暂存 `_dying` 列表，动画结束释放）；同 tick 衔接 move 保留机器口起点延伸终点（`_batch_spawned` 批次标记，跨 tick 失效防跳变重滑）；**不带 producer/consumer 的事件一律原地出现/原地消失（无动画）**：传送带推进 move 照常插值、清理型 despawn（删除建筑残留/面槽扫描）原地消失。物品不落盘：重载后清空带子，源头重新产出；删除建筑时其上/端口残留物品同步 despawn（渲染不悬空）
- **带子连接视觉**: `BeltConnection.compute(buildings)`（纯静态）分析每带子格连接：`feed`(主上游边/-1) / `feeds`(全部上游边,多上游合流格每条都画) / `exits`(出口边集；一体建筑=四向) / `taps`(本地格是哪些机器输入口——顺带抽取,画绿色 T 形支路；**存机器相对本格的轴向偏移**) / `fed_by`(哪些机器输出口正对本格——画输入接驳短线；**存机器相对本格的轴向偏移**；数字源无方向：四周相邻带格全部计入 fed_by)；BuildingManager 在建筑增删/清空时刷新 `belt_connections` 缓存并重绘节点；BeltNode/BeltSplitterNode 据此绘制连续连接带（直线/圆角转弯/Y 形/合流多入/端口接驳），MachineNode 绘制端口连接高亮环（输入被喂=绿环、输出有承接=白环）
- **建筑生命周期**: BuildingManager 持有 `buildings: Dictionary[Vector2i, BuildingData]`，朝向/操作选择/分流位/按方向过滤条件存于 BuildingData；节点（BeltNode/MachineNode）仅负责视觉；BuildingDataSyncService 双向同步 + entry↔restore_data 助手（撤销/剪贴板/存档共用）；删除建筑清理物品时同步清理**面槽**（生产者消失或消费端失配的面物品 despawn）
- **持久化**: 单文件存档 `save/game.cfg`（ConfigFile），`[buildings]` 含 per-building `type/direction/op_choice/splitter_phase/splitter_in_phase/splitter_filters`（默认配置省略；splitter_filters 任一方向有条件才落盘，op 条件附带 op_def；**数组下标即方向索引，固定顺序 [E,S,W,N]（FOUR_WAY_PORTS 契约），存档/恢复按序回填**）；`last_out_dir`（分流器防循环搬运的最近输出方向记忆）是**纯运行时字段不落盘**，撤销/粘贴/存档恢复后回到 -1（初始态），下一次投递即重新写入自愈；**未知类型（旧流体存档/已移除的筛选器/操作源/合流器）加载跳过不崩溃**；物品流不落盘
- **UI**: 库存栏 10 槽（5 建筑 + 5 占位锁定，键盘 1-5 覆盖前 5 槽，其余点击）；MachineConfigPanel 仅服务分流器/一体建筑（逐方向设过滤条件：无条件/数字/操作）；配置变更经 `machine_config_changed` 触发延迟存档；放置/粘贴预览框按类型+朝向绘制**端口方向箭头**（输入=绿箭头指向格内，输出=白箭头指向格外；传送带后入前出；分流器/垃圾桶四向中性端口）
- **UI 输入守卫（按键穿透防护）**: 全屏 UI 遮挡时屏蔽世界输入——Settings 用 `_input`（ESC/按键重绑，handled 后不再进入 `_unhandled_input`），世界快捷键在 `_unhandled_input` 阶段响应：**设置面板可见** = main/CameraController/MapInputHandler 全部拦截（main 直接 return；ESC 由 Settings._input 处理）；**开始菜单可见** = main 仅放行 ui_cancel（ESC 关闭菜单），其余世界快捷键（数字键/空格暂停/E 放置等）拦截，CameraController 经 `_ui_blocking()`（菜单或设置可见）在 `_process`（WASD 轮询移动）与 `_unhandled_input`（滚轮缩放）都拦截；MapInputHandler 已有 StartMenu/SettingsPanel 可见守卫。测试注意：SaveManager._ready 会 call_deferred 加载并触发 `buildings_loaded` → main 自动开菜单，测试中打开设置前需先等加载完成（`_open_settings_stable` 等帧再 emit），否则会被帧后的菜单覆盖

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
- 面传输边界：同轴"生产者排在消费者前"（排序规则天然满足）时可同相位直传；反向轴链晚一拍（确定性流水延迟）。机器格守卫的语义内核是"机器本体格永不持有网格物品"（例外：垃圾桶本体格接受带子推入，见建筑清单），面槽只是共享边暂存，不破坏该守卫
- 管道容量：反馈回路的带链容量有限，持续注入物品会填满并全局背压冻结（物品不丢、机器等待），属正常积压稳态；需要排泄口（垃圾桶）或控制注入速率
- 进程内状态陷阱：SelectionManager 等 autoload 状态跨测试共享，测试需显式复位（如粘贴模式残留会让 R 键走粘贴分支）；GUT 场景树是活的，协调器 0.1s Timer 会在测试期间真实运行，测试需停 Timer 防竞态