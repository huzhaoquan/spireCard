可以，顶部这条其实是 **Top HUD / Dock Bar**，建议单独做成一个可复用组件，先只做视觉和数据展示，后面再接系统逻辑。

它主要包含这些区域：

```text
左侧：职业/角色信息、血量、金币、药水槽
中间：当前楼层
右侧：地图、牌库数量、设置按钮
```

在我们的游戏里建议拆成：

```text
BattleTopDock
├── LeftStatusArea
│   ├── ClassIcon
│   ├── ClassNameLabel
│   ├── HpIcon
│   ├── HpLabel
│   ├── GoldIcon
│   ├── GoldLabel
│   └── PotionSlots
├── FloorArea
│   ├── FloorIcon
│   └── FloorLabel
└── RightMenuArea
    ├── MapButton
    ├── DeckButton
    ├── DeckCountLabel
    └── SettingsButton
```

---

## 第一步：让 Codex 先做顶部 Dock 组件

直接给 Codex 这个 Prompt：

```text
我正在用 Godot 4.6 开发一个类似《杀戮尖塔》的 2D Roguelike 卡牌游戏。

请帮我实现战斗界面顶部 Dock 栏组件。

本次只做 UI 展示，不做真实逻辑。

请创建：
1. scenes/ui/BattleTopDock.tscn
2. scripts/ui/BattleTopDock.gd

设计参考：
类似《杀戮尖塔》顶部状态栏，横向铺满屏幕顶部，高度约 72 px，背景为深色半透明面板。

布局要求：
1. 根节点使用 Control。
2. 尺寸适配 1920x1080，顶部横向铺满。
3. Dock 高度 72。
4. 左侧区域显示：
   - 角色/职业图标
   - 职业名称，例如“铁甲战士”
   - HP 图标
   - HP 数值，例如 85/85
   - 金币图标
   - 金币数值，例如 130
   - 3 个药水槽位
5. 中间区域显示：
   - 楼层图标
   - 当前楼层数字，例如 7
6. 右侧区域显示：
   - 地图按钮
   - 牌库按钮
   - 牌库数量，例如 12
   - 设置按钮
7. 所有图标资源不存在时，用纯色圆形/方形占位，不要报错。
8. 提供以下方法：
   - set_player_info(class_name: String, hp: int, max_hp: int)
   - set_gold(gold: int)
   - set_floor(floor: int)
   - set_deck_count(count: int)
   - set_potions(potions: Array)
9. 药水槽支持空槽和有药水两种状态。
10. 点击地图按钮时打印“打开地图”。
11. 点击牌库按钮时打印“打开牌库”。
12. 点击设置按钮时打印“打开设置”。
13. 代码加中文注释。
14. 不要做战斗逻辑、地图界面、牌库界面、设置界面。
15. 输出完整节点结构和完整 GDScript 代码。
```

预期效果：

```text
屏幕顶部出现一条深色半透明状态栏
左边显示职业、血量、金币、药水槽
中间显示楼层
右边显示地图、牌库数量、设置按钮
```

---

## 第二步：让 Skill 生成 Dock 需要的图标

### 1. HP 图标

```text
Use $generate2dsprite to create a 48x48 pixel art UI icon for a roguelike deckbuilding card game.

Asset:
Red heart HP icon.

Style:
dark fantasy pixel art, clear silhouette, high contrast, readable at small size, slightly worn texture.

Requirements:
transparent background, no text, no numbers.

Technical:
48x48, crisp pixel art, game UI asset.
```

### 2. 金币图标

```text
Use $generate2dsprite to create a 48x48 pixel art UI icon for a roguelike deckbuilding card game.

Asset:
Small coin pouch with golden coins.

Style:
dark fantasy pixel art, warm gold highlights, clear silhouette, readable at small size.

Requirements:
transparent background, no text, no numbers.

Technical:
48x48, crisp pixel art, game UI asset.
```

### 3. 楼层图标

```text
Use $generate2dsprite to create a 48x48 pixel art UI icon for a roguelike deckbuilding card game.

Asset:
Stone stair or dungeon floor icon.

Style:
dark fantasy pixel art, gray stone texture, simple readable shape, suitable for floor progress display.

Requirements:
transparent background, no text, no numbers.

Technical:
48x48, crisp pixel art, game UI asset.
```

### 4. 地图按钮图标

```text
Use $generate2dsprite to create a 48x48 pixel art UI icon for a roguelike deckbuilding card game.

Asset:
Folded parchment map icon.

Style:
dark fantasy pixel art, beige parchment, red route marks, readable at small size.

Requirements:
transparent background, no text, no numbers.

Technical:
48x48, crisp pixel art, game UI asset.
```

### 5. 牌库按钮图标

```text
Use $generate2dsprite to create a 48x48 pixel art UI icon for a roguelike deckbuilding card game.

Asset:
Small stack of cards icon.

Style:
dark fantasy pixel art, parchment cards with worn edges, readable silhouette.

Requirements:
transparent background, no text, no numbers.

Technical:
48x48, crisp pixel art, game UI asset.
```

### 6. 设置按钮图标

```text
Use $generate2dsprite to create a 48x48 pixel art UI icon for a roguelike deckbuilding card game.

Asset:
Gear settings icon.

Style:
dark fantasy pixel art, metal gear, clear outline, readable at small size.

Requirements:
transparent background, no text, no numbers.

Technical:
48x48, crisp pixel art, game UI asset.
```

放到目录：

```text
res://art/ui/icon_hp.png
res://art/ui/icon_gold.png
res://art/ui/icon_floor.png
res://art/ui/icon_map.png
res://art/ui/icon_deck.png
res://art/ui/icon_settings.png
```

---

## 第三步：接入真实资源

给 Codex：

```text
我已经生成了顶部 Dock 图标资源：

res://art/ui/icon_hp.png
res://art/ui/icon_gold.png
res://art/ui/icon_floor.png
res://art/ui/icon_map.png
res://art/ui/icon_deck.png
res://art/ui/icon_settings.png

请修改 BattleTopDock.gd：

要求：
1. 自动加载这些图标。
2. 如果图标不存在，使用当前占位图。
3. 保留所有 set_xxx 方法。
4. 保留按钮点击打印。
5. 输出完整 BattleTopDock.gd。
```

---

## 第四步：把 Dock 加入 BattleScene

给 Codex：

```text
现在我已经有 BattleTopDock.tscn。

请把它加入 BattleScene。

要求：
1. BattleTopDock 显示在屏幕最顶部。
2. 层级高于背景、角色、特效。
3. 不遮挡底部 HandArea。
4. BattleScene 启动时调用：
   - set_player_info("铁甲战士", 85, 85)
   - set_gold(130)
   - set_floor(7)
   - set_deck_count(12)
   - set_potions([
       {"id": "fire_potion", "name": "火焰药水", "icon_path": ""},
       null,
       null
     ])
5. 输出修改后的 BattleScene 节点结构和 BattleScene.gd。
```

预期效果：

```text
顶部 Dock 正常显示
数值和截图类似：
铁甲战士  85/85  金币 130  药水槽
中间：第 7 层
右侧：地图 / 牌库 12 / 设置
```

---

## 第五步：后续要扩展的功能

顶部 Dock 先别做太复杂，后续再接：

```text
地图按钮 → 打开地图界面
牌库按钮 → 打开当前卡组列表
设置按钮 → 打开暂停菜单
药水槽 → 点击使用药水
金币 → 商店系统
血量 → 战斗状态同步
楼层 → 爬塔进度同步
```

这个 Dock 最好不要写战斗逻辑，只负责展示。后面由 `GameManager` 或 `BattleManager` 调它：

```gdscript
top_dock.set_player_info("铁甲战士", player.hp, player.max_hp)
top_dock.set_gold(player.gold)
top_dock.set_floor(run_state.floor)
top_dock.set_deck_count(player.deck.size())
```

这样最稳。
