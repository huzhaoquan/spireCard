# 卡牌视觉与文字清晰度优化

## 目标

修复卡牌上的白色噪点，提升卡牌文字清晰度，并让卡牌插画和整体质感更饱满。只处理卡牌资源和 CardView 展示，不改战斗结算、拖拽、能量或出牌逻辑。

## 已实施

- 资源备份：
  - `art/ui/card_frame_attack_before_polish.png`
  - `art/ui/card_frame_skill_before_polish.png`
  - `art/ui/card_frame_power_before_polish.png`
  - `art/cards/basic_attack_art_before_polish.png`
  - `art/cards/basic_defend_art_before_polish.png`
  - `art/cards/focus_art_before_polish.png`

- 卡框清理：
  - 对 Attack / Skill / Power 三类卡框进行近白低饱和噪点扫描。
  - 小块孤立白点用周围非噪点颜色补齐。
  - 大块近白区域轻微压暗、转暖，避免高光变成刺眼白斑。

- 插画增强：
  - 对 3 张卡牌插画做轻量对比度、饱和度和锐化增强。
  - 压低异常纯白区域，让插画更厚重，减少脏白点观感。

- CardView 展示：
  - 插画显示区域扩大为 `192x120`，匹配现有卡牌插画资源比例。
  - 描述区域加高并增加淡色底板，提升文字承载感。
  - 名称、费用、类型文字加中文 UI 字体和细描边。
  - 类型显示从英文改为中文：`攻击` / `技能` / `能力`。
  - 卡牌纹理过滤改为 Linear，减少缩放时的锯齿和闪点。

## 验证项

- 卡框尺寸保持 `240x320`。
- 插画尺寸保持 `192x120`。
- Alpha 通道保留。
- Skill / Power 卡框近白异常像素应明显下降。
- 战斗中 hover、拖拽、出牌信号不受影响。

## 后续建议

- 如果当前 3 张插画增强后仍不够生动，再用 `generate2dsprite` 单独重生成攻击、防御、专注插画。
- 后续可以为描述文字增加关键词着色，例如伤害、格挡、能量等。
