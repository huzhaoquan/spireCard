# 真实战斗流程开发方案

## Summary
把当前 BattleScene 从视觉演示升级为可跑通的 v1 战斗闭环：进入战斗 -> 抽牌 -> 拖拽出牌 -> 扣能量 -> 结算伤害/格挡 -> 结束回合 -> 敌人行动 -> 新回合抽牌 -> 胜负判断。

同时修复当前问题：攻击牌不能直接拖到怪物区域出牌。根因是 `HandArea.gd` 现在只用固定 Y 高度判断释放有效性，攻击牌要求 `release_y < 500`，没有真正识别怪物区域。

## Key Changes
- 在 `BattleScene.gd` 中实现 v1 战斗状态机：`PLAYER_TURN`、`RESOLVING_CARD`、`ENEMY_TURN`、`VICTORY`、`DEFEAT`。
- 使用轻量 Dictionary/Array 管理战斗数据：玩家 HP/Block/Energy、敌人 HP/Block/Intent、draw pile、hand、discard pile、played pile。
- 将当前 demo cards 扩展为可结算卡牌：Strike 造成 6 点伤害，Defend 获得 5 点格挡，Bash 造成 8 点伤害，Poison Blade v1 先造成 5 点伤害，Focus v1 先获得 1 点格挡。
- `BattleActorView` 继续只负责表现，通过现有 `setup_hp()`、`set_hp()`、`play_attack()`、`play_hit()`、`play_death()` 驱动战斗反馈。

## Drag And Drop
- 修改 `HandArea.gd`，新增目标区域注册：`set_drop_targets(targets: Array)`。
- `BattleScene` 在创建敌人后传入敌人投放区域：`id: "enemy_0"`、`type: "enemy"`、`global_rect: Rect2`、`play_position: Vector2`。
- 攻击牌释放规则：鼠标释放点落入敌人 `global_rect` 才能出牌；释放到中间空白区域不再算攻击成功。
- Skill / Power 释放规则：释放到战斗区域即可出牌，释放回手牌区域则回到手牌。
- `HandArea` 新增信号：`card_play_requested(card_data: Dictionary, card_view: Control, target_id: String)`。
- `BattleScene` 负责最终校验：不是玩家回合、能量不足、攻击目标无效或敌人已死时拒绝出牌；校验通过后扣能量、结算卡牌、移除手牌。

## Battle Flow
- 进入战斗：玩家 HP `70/70`，敌人 HP `32/32`，最大能量 `3`，初始化 starter deck，洗牌，抽 5 张，敌人 v1 固定意图为攻击 6 点。
- 玩家回合开始：清空玩家格挡，能量恢复到 `3/3`，抽到 5 张手牌，更新顶部 Dock 牌库数量。
- 玩家出牌：先校验目标和能量，再扣能量。Attack 扣敌人 HP，Skill 增加玩家格挡，Power v1 只做简化效果。
- 结束回合：点击 `EndTurnButton` 后禁用手牌交互，当前手牌进入弃牌堆，进入敌人回合。
- 敌人行动：敌人播放 attack，伤害先扣玩家格挡，剩余扣玩家 HP；玩家 HP <= 0 进入失败，否则进入新玩家回合。
- 胜负判断：敌人 HP <= 0 显示 Victory；玩家 HP <= 0 显示 Defeat；结束后禁用出牌和结束回合按钮。

## UI And Assets
- 新增 UI 元素：`EndTurnButton`、`TurnStatusLabel`、`EnemyIntentDisplay`、`ResultOverlay`、玩家/敌人格挡显示。
- 若需要新增视觉资源，使用 `$generate2dsprite` 生成小型 UI 图标，例如结束回合、攻击意图、格挡盾牌图标。
- 本阶段先使用 Godot 控件和现有图标占位，不阻塞真实战斗流程。

## Test Plan
- 启动 BattleScene 后自动进入玩家回合，显示 5 张手牌和 `3/3` 能量。
- Attack 拖到怪物区域可以打出；拖到中间空白区域不能打出。
- Skill 拖到战斗区域可以打出；拖回手牌区域不能打出。
- 能量不足时卡牌回手牌，能量不减少。
- Attack 成功后敌人 HP 减少，敌人播放 hit。
- Defend 成功后玩家 Block 增加。
- 点击结束回合后，敌人攻击，伤害先扣 Block 再扣 HP。
- 新回合恢复能量并抽牌。
- 抽牌堆为空时弃牌堆洗回抽牌堆。
- 敌人 HP 到 0 显示 Victory，玩家 HP 到 0 显示 Defeat。

## Assumptions
- v1 只支持单个敌人，目标 id 固定为 `enemy_0`。
- 不引入复杂卡牌数据库，先在 `BattleScene.gd` 内定义 starter deck。
- 不做中毒、力量、易伤、药水、奖励、地图跳转。
- `HandArea` 只负责手牌 UI、拖拽和动画，不做战斗结算。
- `BattleScene` 是 v1 战斗逻辑入口，后续再拆 `BattleManager` 或独立数据层。
