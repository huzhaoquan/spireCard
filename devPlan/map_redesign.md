# 大地图重设计实施记录

## 目标

参考 `9a4d7df5-df33-4b25-aa0a-de40f86c82b5.png` 的暗黑幻想地图样式，重做大地图为“全屏背景 + 路线节点 + 左侧图例 + 右侧详情 + 顶部状态栏”的结构。

## 已实施

- 使用 `generate2dsprite` 流程生成并接入大地图 UI 资产：
  - `art/map/map_bg_dark_fantasy.png`
  - `art/map/map_node_ring.png`
  - `art/map/map_node_ring_available.png`
  - `art/map/map_node_ring_completed.png`
  - `art/map/map_panel_frame.png`
  - `art/map/map_return_button_ornament.png`
  - `art/map/icon_map_tab.png`
  - `art/map/icon_deck_tab.png`
  - `art/map/icon_relic_tab.png`
  - `art/map/icon_settings_tab.png`
- 重写 `scripts/map/MapScene.gd`：
  - 使用生成背景图作为全屏地图底图。
  - 使用显式节点图 `MAP_NODES` 驱动路线、节点、解锁关系。
  - 绘制节点连线，并根据完成/可选状态调整颜色和粗细。
  - 增加顶部状态栏、左侧图例、右侧节点详情面板、返回按钮。
  - hover 任意节点时显示节点详情；只有可选节点可点击进入对应房间。
- 更新 `scripts/map/MapNode.gd`：
  - 节点尺寸改为 `96x96`。
  - 增加三态节点环：locked / available / completed。
  - 增加 `node_hovered` 信号用于右侧详情面板。
- 更新 `autoload/GameManager.gd`：
  - 增加 `map_connections`。
  - 大地图进入时注册真实路线连接。
  - 完成节点后优先按真实连接解锁下一批节点。

## 验证

- 静态搜索确认没有残留 `GameManager.xxx` 直接单例引用。
- 新增透明 UI PNG 资源可读取，节点环、图标、面板框、返回按钮装饰均带 Alpha 通道。
- 当前环境中未找到 `godot` 或 `godot_console` 命令，因此还未做 Godot 引擎级运行验证。

## 后续建议

- 在 Godot 编辑器中打开 `res://scenes/map/MapScene.tscn` 检查布局实际比例。
- 根据截图效果微调 `MAP_NODES` 中的节点坐标。
- 如果需要顶部栏按钮可点击，再给地图/牌组/遗物/设置图标补充 Button 包裹和跳转逻辑。
