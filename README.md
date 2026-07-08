# Vocab Roguelike / 词域探险

一个 Windows 桌面 2D 背单词 Roguelike 游戏。玩家在不同主题房间中移动、瞄准、发射中文释义词块，击败身上显示英文单词的怪物，并通过宝箱、道具和奖励卡不断强化角色。

## 运行游戏

直接运行：

```text
dist\WordRealm.exe
```

`dist\wordbank.json` 和 `dist\assets\runtime` 需要和 exe 保持在同一目录结构下。游戏会在 `dist` 目录生成 `savegame.json`，用于保存学习数据和继续游戏进度。

## 当前内容

- 三档词库难度：
  - 简单：高中词汇
  - 普通：四六级词汇
  - 困难：雅思词汇
- 已导入高中、四六级、雅思词库，中文释义已压缩为适合游戏显示的短释义。
- 8 个主题地图背景和主题障碍物。
- 英文单词怪物、精英怪、护盾怪、冲刺怪、追踪怪。
- 中文词块拾取、发射、错配惩罚、回声卷轴通用弹。
- 宝箱、道具、三选一奖励卡。
- 继续游戏存档。
- F11 全屏切换。

## 操作

| 操作 | 按键 |
|---|---|
| 移动 | `WASD` / 方向键 |
| 瞄准 | 鼠标移动 |
| 发射中文词块 | 鼠标左键 |
| 拾取词块 / 开宝箱 / 快速进入下一房间 | `E` |
| 闪避 | `Space` |
| 使用护盾药剂 | `Q` |
| 查看记忆书 | `Tab` |
| 暂停 | `Esc` |
| 全屏切换 | `F11` |
| 奖励卡选择 | 鼠标点击 / `1` `2` `3` |

## 词库格式

词库文件是 `wordbank.json`，每个词条格式如下：

```json
{
  "word": "increase",
  "meaning": "增加",
  "difficulty": 2,
  "frequencyRank": 1200,
  "tags": ["highschool", "verb"]
}
```

`difficulty` 规则：

- `1-2`：高中词汇
- `3-4`：四六级词汇
- `5-6`：雅思词汇

游戏会根据当前模式、房间进度、玩家表现、错词记录和掌握度动态抽取词汇。

## 项目结构

```text
WordRogue.cs                 主游戏代码
wordbank.json                游戏词库
build.ps1                    构建脚本
assets/runtime/              游戏运行时素材
assets/generated/ASSET_INDEX.md  素材索引说明
dist/WordRealm.exe           已构建的 Windows 可执行文件
```

## 重新构建

在项目根目录运行：

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\build.ps1
```

构建结果会输出到：

```text
dist\WordRealm.exe
```

## 技术栈

- C#
- Windows Forms
- System.Drawing / GDI+
- .NET Framework 编译器 `csc.exe`

这是一个轻量的纯 C# 桌面 2D 游戏项目，不依赖 Unity 或 Godot。
