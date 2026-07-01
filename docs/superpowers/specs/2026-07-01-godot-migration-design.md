# 词域探险 - Godot 4.7 迁移设计文档

## 概述

将词域探险（Word Realm）从 C# Windows Forms + GDI+ 单文件桌面应用迁移到 Godot 4.7，实现 Android、iOS 和 Windows 三平台支持。

- **开发语言**：GDScript（标准版 Godot 4.7）
- **迁移范围**：完整迁移所有现有功能
- **联网功能**：纯单机
- **操控方式**：PC 键鼠 + 移动端点击移动/拖拽射击
- **美术资源**：复用现有资源，适配移动端

---

## 一、项目结构与场景架构

### 目录结构

```
word_realm/
├── project.godot
├── export_presets.cfg
│
├── assets/
│   ├── sprites/                     # 精灵图集 PNG（从现有项目复制）
│   │   ├── characters_monsters.png
│   │   ├── hero_gun_actions.png
│   │   ├── hero_directions.png
│   │   ├── hero_walk.png
│   │   ├── items_projectiles_chests.png
│   │   ├── theme_obstacles.png
│   │   ├── theme_tiles_walls.png
│   │   └── weapon_ammo.png
│   ├── backgrounds/                 # 房间背景 JPG
│   │   ├── forest.jpg
│   │   ├── office.jpg
│   │   ├── library.jpg
│   │   ├── lab.jpg
│   │   ├── business_mine.jpg
│   │   ├── academic_temple.jpg
│   │   ├── travel_port.jpg
│   │   └── emotion_cave.jpg
│   └── fonts/                       # 跨平台中英文字体
│       └── noto_sans_cjk.ttf
│
├── data/
│   └── wordbank.json
│
├── scenes/
│   ├── main.tscn                    # 入口场景（场景管理器）
│   ├── menu/
│   │   └── main_menu.tscn
│   ├── game/
│   │   ├── game.tscn                # 游戏主场景
│   │   ├── player.tscn              # CharacterBody2D
│   │   ├── monster.tscn             # CharacterBody2D（通用，按 kind 切换行为）
│   │   ├── meaning_token.tscn       # Area2D（中文释义词块）
│   │   ├── projectile.tscn          # Area2D（玩家弹丸）
│   │   ├── enemy_projectile.tscn    # Area2D（敌方弹幕）
│   │   ├── drop_item.tscn           # Area2D（消耗品道具）
│   │   ├── chest.tscn               # Area2D（宝箱）
│   │   └── obstacle.tscn            # StaticBody2D
│   └── ui/
│       ├── hud.tscn
│       ├── touch_controls.tscn      # 移动端触控层
│       ├── reward_panel.tscn
│       ├── pause_menu.tscn
│       ├── game_over.tscn
│       └── memory_book.tscn
│
├── scripts/
│   ├── autoload/
│   │   ├── game_manager.gd          # 全局状态管理
│   │   ├── word_bank.gd             # 词库管理
│   │   ├── save_manager.gd          # 存档管理
│   │   └── audio_manager.gd         # 音频管理（预留）
│   ├── game/
│   │   ├── game.gd                  # 游戏场景主逻辑
│   │   ├── player.gd                # 玩家控制
│   │   ├── monster.gd               # 怪物 AI
│   │   ├── room_generator.gd        # 房间/障碍物生成
│   │   └── combat.gd                # 词汇匹配与伤害计算
│   └── ui/
│       ├── touch_controls.gd
│       └── hud.gd
│
└── resources/
    ├── theme.tres
    └── room_themes.tres
```

### 节点类型对照

| 原有 C# 类 | Godot 节点类型 |
|---|---|
| `Player` | `CharacterBody2D` + `CollisionShape2D` + `AnimatedSprite2D` |
| `Monster` | `CharacterBody2D` + `CollisionShape2D` + `Sprite2D` |
| `Projectile` / `EnemyProjectile` | `Area2D` + `CollisionShape2D` |
| `MeaningToken` / `Drop` / `Chest` | `Area2D`（可拾取物） |
| `Obstacle` | `StaticBody2D` + `CollisionShape2D` + `Sprite2D` |
| `FloatingText` | `Label` + `Tween` 动画 |

---

## 二、输入系统与移动端适配

### 双模式输入

PC 端保留键鼠操控，移动端使用点击移动 + 拖拽射击，通过平台检测切换。

#### 触控层结构（touch_controls.tscn）

```
CanvasLayer (layer=10)
├── InteractButton          # 拾取/交互按钮（靠近词块/宝箱时显示）
├── DashButton              # 冲刺按钮（右下角）
├── PauseButton             # 暂停按钮（右上角）
└── AimIndicator            # 拖拽瞄准时的方向指示线
```

#### 移动端操控

| 操作 | 触控方式 |
|---|---|
| 移动 | 点击地面任意位置，玩家通过 `NavigationAgent2D` 自动寻路 |
| 拾取词块 | 靠近词块时出现拾取按钮，点击拾取；手上有词块时自动丢弃旧的再拾取新的 |
| 瞄准射击 | 持有词块时，按住屏幕拖拽出方向线，松手发射 |
| 冲刺 | 点击冲刺按钮，向当前移动方向冲刺 |
| 开宝箱 | 靠近宝箱时交互按钮变为"开箱" |

#### PC 端操控（保持原有）

| 操作 | 按键 |
|---|---|
| 移动 | WASD / 方向键 |
| 拾取 | E |
| 射击 | 鼠标左键 |
| 冲刺 | 空格 |
| 暂停 | Esc |

#### 平台检测

- `game_manager.gd` 启动时 `OS.get_name()` 判断平台
- Android/iOS → 显示触控层，隐藏准星
- Windows/macOS/Linux → 隐藏触控层，显示准星
- 设置中可手动切换（平板外接键鼠场景）

### 屏幕适配

- 逻辑分辨率保持 1280x720
- `stretch_mode = canvas_items`，`stretch_aspect = keep_height`
- 移动端锁定横屏（`orientation = landscape`）
- UI 使用锚点系统，HUD 元素锚定到屏幕边缘
- 触控按钮确保不小于 44x44 物理像素

---

## 三、核心游戏逻辑

### 游戏状态管理（game_manager.gd）

信号驱动状态切换：

```
Menu → Playing → RoomClear → Playing（循环）
                           → RewardChoice → Playing
Playing → GameOver → Menu
Playing → Paused → Playing
Playing → Win → Menu
```

- `game_manager.gd` 持有 run 级别数据（难度、房间号、连击数、增益剩余等）
- Menu ↔ Game 用 `SceneTree.change_scene_to_packed()` 切换
- 游戏内状态切换用信号通知（暂停/奖励面板作为叠加层显隐）

### 房间生成（room_generator.gd）

对照原有 `GenerateObstacles()` + `StartRoom()` 逻辑：

1. 根据 `room` 和 `theme_index` 选择背景和障碍物类型
2. 随机放置障碍物 `StaticBody2D`，保留碰撞检测 + flood-fill 可达性验证
3. 调用 `word_bank.pick_room_words(count)` 选词
4. 为每个词生成 `Monster` 实例，生成正确释义 + 干扰释义的 `MeaningToken`
5. 概率（52%）生成宝箱

词数规则（与原版一致）：
- 基数：`3 + min(3, room / 2)`
- `roomDifficultyScale > 1.15` 时 +1
- 普通难度 room > 3 时 +1
- 困难难度 room > 5 时 +1
- 上限 6 个

### 怪物 AI（monster.gd）

在 `_physics_process()` 中按 `kind` 执行不同行为：

| 类型 | 行为 |
|---|---|
| Wanderer | 随机游走，靠近玩家（<180px）时微调方向 |
| Chaser | 持续追踪玩家（0.82 惯性 + 0.18 追踪） |
| Dasher | 间歇蓄力（0.55s），距离 <360 时冲锋（4.2 倍速） |
| Shield | 类似 Wanderer，带护盾需先破盾 |
| Ghost | 错词生成，速度 +38 的追踪者 |

速度公式：`55 + room * 3 + difficulty * 8`（Chaser +28，Ghost +38，狂暴 ×1.8）

移动用 `CharacterBody2D.move_and_slide()`。

精英怪（MaxHp >= 2 / Shield / difficulty >= 5）会发射弹幕，间隔 `max(1.25, 3.3 - room*0.08 - difficulty*0.08)` 秒。

### 词汇匹配与战斗（combat.gd）

弹丸（`Area2D`）通过 `area_entered` 信号检测碰撞：

**命中正确**（`meaning == monster.entry.meaning` 或 `universal`）：
- correctCount++，mastery +1（上限 10）
- combo++
- 连击 >= 3 时额外 +1 伤害，玩家回 4 HP
- 护盾怪先破盾
- 普通怪一击必杀，精英怪扣 1 HP

**命中错误**：
- wrongCount++，mastery -1（下限 0）
- combo 归零
- 怪物狂暴 3 秒（速度 ×1.8）
- 怪物扣 0.15 HP（轻微伤害）
- 连错 2 次 → roomDifficultyScale +0.08

弹丸命中错误后，词块刷新回地面。

### 道具与奖励系统

**消耗品道具**（走近自动拾取，距离 < 34）：

| 道具 | 效果 |
|---|---|
| 苹果 | 回复 30% 最大生命 |
| 咖啡 | 加速 7 秒（×1.35） |
| 护盾药剂 | 减伤 10 秒（×0.55） |
| 穿透墨水 | 弹丸穿透，持续 3 间 |
| 风之靴 | 移速 +18，持续 3 间 |
| 轻羽 | 冲刺 CD -0.12s，持续 3 间 |
| 磁力手套 | 拾取范围 +18，持续 3 间 |

**奖励卡**（房间怪物 > 3 时触发，3 选 1）：

| 卡牌 | 效果 |
|---|---|
| 生命补给 | 最大/当前生命 +20%~50% |
| 机动步伐 / 能量护盾 | 移速永久 +14 / 减伤 +6% + 护盾 12s |
| 风箱补给 / 弹药校准 / 回声卷轴 | 对应宝箱道具 3 间 |

限时增益在 `game_manager.gd` 中按房间递减计数。

---

## 四、存档系统与词库管理

### 词库管理（word_bank.gd）

- 加载 `data/wordbank.json`（8713 词）
- 难度分级：1-2 高中、3-4 四六级、5-6 雅思
- 选词权重算法（保留原版）：
  - 难度匹配：`40 - abs(difficulty - target) * 9`
  - 新词加权：seenCount == 0 → +30
  - 错词优先：wrongCount × 20
  - 死因词优先：deathCount × 50
  - 已掌握减权：mastery × 8
  - 近期减权：3 间内见过 → -30
  - 完全掌握减权：correct >= 3 且 wrong == 0 → -18
  - 最低权重：2

### 存档管理（save_manager.gd）

- 路径：`user://savegame.json`（各平台自动映射）
- 内容：
  - 每词统计（seen/correct/wrong/death/mastery/lastSeenRoom）
  - 最高房间记录、总正确/错误数
  - 继续游戏状态（玩家属性、房间号、所有增益剩余）
- 存档时机：每间房结束、关闭游戏时
- 移动端额外处理：
  - 监听 `NOTIFICATION_APPLICATION_PAUSED`（Android 切后台）自动存档
  - 监听 `NOTIFICATION_APPLICATION_FOCUS_OUT`（iOS 切后台）自动存档

---

## 五、渲染与动画

### 精灵图集处理

为每张图集 PNG 创建 `AtlasTexture` 资源，定义 `region` 裁切区域：

| 图集 | 规格 | 用途 |
|---|---|---|
| `characters_monsters.png` | 4×2 | 英雄 + 6 种怪物 |
| `hero_walk.png` | 6×4 | 4 方向行走/冲刺动画 |
| `hero_gun_actions.png` | 8×4 | 持枪动画（idle/walk/dash/fire/hurt × 4 方向） |
| `items_projectiles_chests.png` | 4×4 | 词块、弹丸、宝箱、道具、特效 |
| `theme_obstacles.png` | 4×2 | 8 种主题障碍物 |
| `theme_tiles_walls.png` | 4×4 | 8 种地砖 + 8 种墙壁 |
| `weapon_ammo.png` | 4×1 | 枪械、枪口闪光、弹药 |

### 房间背景

8 张 1280×720 JPG 作为 `Sprite2D` 铺满房间，按 `(room - 1) % 8` 切换。

### 动画

| 动画 | 实现方式 |
|---|---|
| 玩家行走 | `AnimatedSprite2D` + `SpriteFrames`，4 方向各 6 帧 |
| 玩家冲刺 | 切换冲刺帧，0.22s 后恢复 |
| 玩家射击 | 切换射击帧，0.16s 后恢复 |
| 怪物朝向 | `Sprite2D.flip_h` 水平翻转 |
| 怪物蓄力 | `Tween` 缩放抖动 |
| 怪物狂暴 | `modulate` 变红 + 闪烁 |
| 浮动文字 | `Label` + `Tween` 向上漂浮 + 淡出，1.35s 后 `queue_free()` |
| 护盾效果 | 半透明圆环叠加 |
| 词块发光 | `modulate` 脉冲 `Tween` |

### 字体

- 替换 `Microsoft YaHei UI`（Windows 专有）为 Noto Sans CJK（跨平台）
- Godot 4.7 原生支持 TTF/OTF 字体导入

---

## 六、平台导出与构建配置

### 项目配置（project.godot）

- 应用名称：WordRealm / 词域探险
- 主场景：`scenes/main.tscn`
- 逻辑分辨率：1280×720
- 拉伸模式：`canvas_items`
- 拉伸比例：`keep_height`
- 方向：`landscape`

### 自动加载

| 名称 | 路径 |
|---|---|
| GameManager | `scripts/autoload/game_manager.gd` |
| WordBank | `scripts/autoload/word_bank.gd` |
| SaveManager | `scripts/autoload/save_manager.gd` |

### Android 导出

- Android 构建模板（编辑器内安装）
- JDK 17+ 和 Android SDK（API 33+）
- 包名：`com.wordrealm.game`
- 最低 API：24（Android 7.0）
- 目标 API：34
- 屏幕方向：landscape
- 无特殊权限
- 输出：`.apk`（测试）/ `.aab`（上架）

### iOS 导出

- 需 macOS + Xcode 15+
- Bundle ID：`com.wordrealm.game`
- 最低 iOS：15.0
- 屏幕方向：landscape
- 签名：开发者证书 + Provisioning Profile
- 导出 Xcode 项目后用 Xcode 打包 `.ipa`

### Windows 导出

- 直接导出 `.exe`，替代原有 `csc.exe` 编译
- 保留键鼠操控，不显示触控层
