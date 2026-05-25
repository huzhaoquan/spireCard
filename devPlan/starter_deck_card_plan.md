# 初始牌组与流派卡牌素材补充计划

## 目标

先照搬《杀戮尖塔》铁甲战士的初始卡组设计，避免在 v1 阶段引入自设计卡牌造成节奏偏差。

当前项目已经有 `打击` 和 `防御` 的卡牌插画与基础逻辑，因此本计划不再重复展开它们的素材 prompt，只记录初始牌组数量关系，并补齐缺失的 `重击`。

在初始牌组之外，补充两套铁甲战士经典构筑方向的核心卡牌计划：

- 力量爆发流：通过力量叠加和攻击复制制造爆发输出。
- 全身撞击流：把格挡积累转化为直接伤害。

这些流派卡牌不进入初始牌组，后续应作为战斗奖励、商店、事件或牌库解锁内容加入。

## 当前实施状态

- 已生成并接入 `重击` 卡牌插画：`res://art/cards/bash_art.png`。
- 已将战斗初始牌组调整为 `打击 x5`、`防御 x4`、`重击 x1`。
- 已从初始牌组移除非原始 starter deck 的 `毒刃` 和 `专注`。
- 已更新 `CardUiTestScene`，让测试卡牌展示新的 `重击` 插画。
- 已生成并接入 8 张流派卡牌插画：
  - `res://art/cards/demon_form_art.png`
  - `res://art/cards/spot_weakness_art.png`
  - `res://art/cards/limit_break_art.png`
  - `res://art/cards/double_tap_art.png`
  - `res://art/cards/body_slam_art.png`
  - `res://art/cards/barricade_art.png`
  - `res://art/cards/feel_no_pain_art.png`
  - `res://art/cards/rage_art.png`
- 已在 `BattleScene.gd` 中接入力量、能力、消耗、攻击复制、格挡保留、全身撞击伤害、盛怒格挡触发等 v1 效果。
- 已将 8 张流派核心卡加入商店商品池，购买后会进入 `GameManager.deck_cards`，下一场战斗自动展开为完整卡牌。
- 已更新 `CardUiTestScene`，用于检查初始牌和流派卡牌的卡面展示。

## 初始牌组结构

| 卡牌 | 数量 | 类型 | 费用 | v1 效果 | 素材状态 |
| --- | ---: | --- | ---: | --- | --- |
| 打击 | 5 | Attack | 1 | 造成 6 点伤害。 | 已有：`res://art/cards/basic_attack_art.png` |
| 防御 | 4 | Skill | 1 | 获得 5 点格挡。 | 已有：`res://art/cards/basic_defend_art.png` |
| 重击 | 1 | Attack | 2 | 造成 8 点伤害。 | 待生成：`res://art/cards/bash_art.png` |

说明：

- 《杀戮尖塔》中铁甲战士的 `Bash` 会造成伤害并施加易伤。
- 当前战斗系统暂未实现易伤、状态回合数和状态 UI，因此 v1 先只保留伤害部分。
- 后续状态系统完成后，再把 `重击` 升级为 `造成 8 点伤害。施加 2 层易伤。`

## 素材生成通用规范

所有新增卡牌插画使用 `$generate2dsprite` 的 `single_asset` 方式生成，匹配当前卡图管线：

- `asset_type`: `prop`
- `action`: `single`
- `bundle`: `single_asset`
- `art_style`: `pixel_art`
- `reference`: `project-native`
- 输出尺寸：`192x120`
- 构图规则：卡牌插画窗口用图，不包含文字、数字、图标、UI 边框或卡框。
- 风格规则：暗黑奇幻、像素风、暗色羊皮纸背景、主体居中、强轮廓、小尺寸可读。
- 处理规则：保留原始生成图，最终资源放入 `res://art/cards/`，并写入对应 `*_prompt_used.txt` 和 `*_pipeline_meta.json`。

## 初始牌组待补充卡牌

### 重击

- `id`: `bash`
- `name`: `重击`
- `type`: `Attack`
- `rarity`: `Common`
- `cost`: `2`
- `description`: `造成 8 点伤害。`
- `damage`: `8`
- `block`: `0`
- `art_path`: `res://art/cards/bash_art.png`
- `frame_path`: ``
- 机制需求：v1 可直接使用现有 `damage` 字段；易伤效果后续补。
- `$generate2dsprite` prompt:

```text
Create a single card illustration asset for a roguelike deckbuilding game, exact 192x120 pixel composition, crisp dark fantasy pixel art. Subject: a heavy iron mace smashing downward into cracked stone, with one bold orange impact spark cluster and a short dust burst around the point of impact. Strong silhouette, brutal weight, dramatic contrast, readable at small card size, not too detailed. Composition: centered weapon and impact, no text, no UI frame, no number, no icons, no letters. Background: simple dark parchment background with low detail. Game-ready pixel art illustration for an Attack card named Bash.
```

## 流派卡牌扩展

以下卡牌参考《杀戮尖塔》铁甲战士原始设计。当前已完成 v1 机制接入，但仍未实现完整的状态图标栏、关键词高亮、战斗奖励三选一界面和能力图标持久展示。

### 力量爆发流

打法逻辑：通过多张卡牌不断叠加力量数值，配合多段伤害或旋风斩类攻击，在关键回合打出秒杀 Boss 的爆发输出。

#### 恶魔形态

- `id`: `demon_form`
- `name`: `恶魔形态`
- `type`: `Power`
- `rarity`: `Rare`
- `cost`: `3`
- `description`: `在你的回合开始时，获得 2 点力量。`
- `art_path`: `res://art/cards/demon_form_art.png`
- 机制需求：新增 `strength` 属性和 `strength_per_turn` 持续能力。
- `$generate2dsprite` prompt:

```text
Create a single card illustration asset for a roguelike deckbuilding game, exact 192x120 pixel composition, crisp dark fantasy pixel art. Subject: a warrior silhouette transforming into a horned demonic form, with red ember cracks across armor and a dark crimson aura rising behind the body. Strong silhouette, intimidating power, dramatic contrast, readable at small card size, not too detailed. Composition: centered transformation figure, no text, no UI frame, no number, no icons, no letters. Background: simple dark parchment background with low detail. Game-ready pixel art illustration for a Power card named Demon Form.
```

#### 观察弱点

- `id`: `spot_weakness`
- `name`: `观察弱点`
- `type`: `Skill`
- `rarity`: `Uncommon`
- `cost`: `1`
- `description`: `如果目标意图为攻击，获得 3 点力量。`
- `art_path`: `res://art/cards/spot_weakness_art.png`
- 机制需求：读取敌人意图，新增即时 `gain_strength`。
- `$generate2dsprite` prompt:

```text
Create a single card illustration asset for a roguelike deckbuilding game, exact 192x120 pixel composition, crisp dark fantasy pixel art. Subject: a sharp warrior eye studying a cracked enemy armor plate, with a small red glow marking the weak point. Strong silhouette, tactical focus, clear readable shape, suitable for a small card artwork window, not too detailed. Composition: centered eye and marked armor weakness, no text, no UI frame, no number, no icons, no letters. Background: simple dark parchment background with low detail. Game-ready pixel art illustration for a Skill card named Spot Weakness.
```

#### 突破极限

- `id`: `limit_break`
- `name`: `突破极限`
- `type`: `Skill`
- `rarity`: `Rare`
- `cost`: `1`
- `description`: `使你的力量翻倍。消耗。`
- `art_path`: `res://art/cards/limit_break_art.png`
- 机制需求：新增 `double_strength` 与 `exhaust`。
- `$generate2dsprite` prompt:

```text
Create a single card illustration asset for a roguelike deckbuilding game, exact 192x120 pixel composition, crisp dark fantasy pixel art. Subject: a clenched armored fist breaking glowing red chains, with force lines and a compact burst of crimson light. Strong silhouette, explosive strength, dramatic contrast, readable at small card size, not too detailed. Composition: centered fist and shattered chains, no text, no UI frame, no number, no icons, no letters. Background: simple dark parchment background with low detail. Game-ready pixel art illustration for a Skill card named Limit Break.
```

#### 双发

- `id`: `double_tap`
- `name`: `双发`
- `type`: `Skill`
- `rarity`: `Rare`
- `cost`: `1`
- `description`: `本回合你的下一张攻击牌打出两次。`
- `art_path`: `res://art/cards/double_tap_art.png`
- 机制需求：新增 `next_attack_repeat_count` 回合状态。
- `$generate2dsprite` prompt:

```text
Create a single card illustration asset for a roguelike deckbuilding game, exact 192x120 pixel composition, crisp dark fantasy pixel art. Subject: two overlapping weapon strike afterimages crossing the same target point, one bright orange slash and one darker red echo slash. Strong silhouette, quick repeated attack feeling, clear readable shape, not too detailed. Composition: centered paired strike trails, no text, no UI frame, no number, no icons, no letters. Background: simple dark parchment background with low detail. Game-ready pixel art illustration for a Skill card named Double Tap.
```

### 全身撞击流

打法逻辑：将铁甲战士强大的格挡属性转化为直观的伤害输出，并通过保留格挡、获得额外格挡、攻击时叠格挡来形成攻防一体循环。

#### 全身撞击

- `id`: `body_slam`
- `name`: `全身撞击`
- `type`: `Attack`
- `rarity`: `Common`
- `cost`: `1`
- `description`: `造成等同于当前格挡的伤害。`
- `art_path`: `res://art/cards/body_slam_art.png`
- 机制需求：新增 `damage_from_block`。
- `$generate2dsprite` prompt:

```text
Create a single card illustration asset for a roguelike deckbuilding game, exact 192x120 pixel composition, crisp dark fantasy pixel art. Subject: a heavily armored warrior shoulder-charging forward behind a raised shield, with a compact blue-white impact burst at the shield rim. Strong silhouette, heavy momentum, clear readable shape, suitable for a small card artwork window, not too detailed. Composition: centered shield charge, no text, no UI frame, no number, no icons, no letters. Background: simple dark parchment background with low detail. Game-ready pixel art illustration for an Attack card named Body Slam.
```

#### 壁垒

- `id`: `barricade`
- `name`: `壁垒`
- `type`: `Power`
- `rarity`: `Rare`
- `cost`: `3`
- `description`: `你的格挡在回合开始时不再消失。`
- `art_path`: `res://art/cards/barricade_art.png`
- 机制需求：新增 `retain_block` 持续能力。
- `$generate2dsprite` prompt:

```text
Create a single card illustration asset for a roguelike deckbuilding game, exact 192x120 pixel composition, crisp dark fantasy pixel art. Subject: a towering wall of locked iron shields forming an unbroken barricade, with cold blue steel highlights and small dust at the base. Strong silhouette, immovable defense, dramatic contrast, readable at small card size, not too detailed. Composition: centered shield wall, no text, no UI frame, no number, no icons, no letters. Background: simple dark parchment background with low detail. Game-ready pixel art illustration for a Power card named Barricade.
```

#### 无惧疼痛

- `id`: `feel_no_pain`
- `name`: `无惧疼痛`
- `type`: `Power`
- `rarity`: `Uncommon`
- `cost`: `1`
- `description`: `每当有一张牌被消耗时，获得 3 点格挡。`
- `art_path`: `res://art/cards/feel_no_pain_art.png`
- 机制需求：新增 `on_card_exhaust_gain_block` 触发能力。
- `$generate2dsprite` prompt:

```text
Create a single card illustration asset for a roguelike deckbuilding game, exact 192x120 pixel composition, crisp dark fantasy pixel art. Subject: an armored warrior standing firm while broken blade fragments and red sparks bounce away from a glowing blue guard aura. Strong silhouette, stoic endurance, clear readable shape, not too detailed. Composition: centered armored figure and guard aura, no text, no UI frame, no number, no icons, no letters. Background: simple dark parchment background with low detail. Game-ready pixel art illustration for a Power card named Feel No Pain.
```

#### 盛怒

- `id`: `rage`
- `name`: `盛怒`
- `type`: `Skill`
- `rarity`: `Uncommon`
- `cost`: `0`
- `description`: `本回合每当你打出一张攻击牌，获得 3 点格挡。`
- `art_path`: `res://art/cards/rage_art.png`
- 机制需求：新增 `on_attack_played_gain_block` 回合状态。
- `$generate2dsprite` prompt:

```text
Create a single card illustration asset for a roguelike deckbuilding game, exact 192x120 pixel composition, crisp dark fantasy pixel art. Subject: a battered iron shield and sword surrounded by a controlled red battle aura, with blue guard sparks forming around the shield edge. Strong silhouette, aggressive defense mood, clear readable shape, suitable for a small card artwork window, not too detailed. Composition: centered sword and shield with aura, no text, no UI frame, no number, no icons, no letters. Background: simple dark parchment background with low detail. Game-ready pixel art illustration for a Skill card named Rage.
```

## 实施步骤

1. 使用 `$generate2dsprite` 生成 `bash_art.png`。
2. 将生成图处理到 `192x120` 并放入 `art/cards/`。
3. 保存 `bash_art_prompt_used.txt` 和 `bash_art_pipeline_meta.json`。
4. 更新 `scripts/battle/BattleScene.gd` 的 `_build_starter_deck()`：
   - 保留 5 张 `strike`
   - 保留 4 张 `defend`
   - 保留 1 张 `bash`
   - 将 `bash` 的 `art_path` 改为 `res://art/cards/bash_art.png`
   - 移除当前初始牌组里的 `poison_blade` 和 `focus`
5. 更新 `scenes/test/CardUiTestScene.tscn` 中的测试牌，确保 `重击` 使用新插画。
6. 已实现通用卡牌效果字段，并生成接入两套流派卡牌素材。

## 验证项

- 进入战斗后初始牌组总数为 10。
- 初始牌组构成为 `打击 x5`、`防御 x4`、`重击 x1`。
- `重击` 显示为攻击牌卡框，费用为 2，描述为 `造成 8 点伤害。`
- `重击` 拖到敌人目标区域后正确造成 8 点伤害。
- 能量不足时 `重击` 回手牌且不结算。
- `bash_art.png` 在 `CardView` 的 `192x120` 插画区域内清晰、不包含文字或 UI 边框。
- 力量流后续验证：力量能正确增加攻击牌伤害，`双发` 能复制下一张攻击牌。
- 全身撞击流后续验证：`全身撞击` 能读取当前格挡，`壁垒` 能保留格挡。
- 商店购买流派牌后，下一场战斗的抽牌堆包含购买的卡牌。
- `恶魔形态`、`壁垒`、`无惧疼痛` 作为能力牌打出后移出本场战斗，不进入弃牌堆。
- `突破极限` 打出后消耗，并能触发 `无惧疼痛` 的格挡。

## 后续扩展

- 状态系统完成后，为 `重击` 增加易伤效果。
- 卡牌数据库拆分后，把初始牌组从 `BattleScene.gd` 移到独立配置文件。
- 奖励系统完成后，把力量爆发流和全身撞击流卡牌加入奖励池和事件奖励池。
- 增加战斗内状态栏，显示力量、恶魔形态、壁垒、无惧疼痛、盛怒和双发的剩余状态。
