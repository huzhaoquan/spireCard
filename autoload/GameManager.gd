extends Node

# 当前一局游戏的轻量全局状态。第一版先服务菜单、地图和各房间跳转。

const SAVE_PATH: String = "user://run.cfg"

var player_hp: int = 70
var player_max_hp: int = 70
var gold: int = 130
var floor: int = 1
var deck_cards: Array = []
var relics: Array = []
var potions: Array = []
var completed_node_ids: Array[String] = []
var available_node_ids: Array[String] = ["1-1"]
var current_map_position: int = 0
var current_node_id: String = ""
var current_node_type: String = ""
var map_connections: Dictionary = {}
var card_reward_pity_counter: int = 0


func start_new_run() -> void:
	delete_save()
	player_hp = 70
	player_max_hp = 70
	gold = 130
	floor = 1
	deck_cards.clear()
	relics.clear()
	potions.clear()
	completed_node_ids.clear()
	available_node_ids.clear()
	available_node_ids.append("1-1")
	current_map_position = 0
	current_node_id = ""
	current_node_type = ""
	map_connections.clear()
	card_reward_pity_counter = 0
	save_run()


func complete_map_node(node_id: String) -> void:
	if node_id.is_empty():
		return

	if not completed_node_ids.has(node_id):
		completed_node_ids.append(node_id)

	current_node_id = ""
	current_node_type = ""
	var layer_index: int = _get_layer_index_from_id(node_id)
	current_map_position = maxi(current_map_position, layer_index)
	floor = maxi(floor, layer_index + 1)
	if map_connections.has(node_id):
		_unlock_connected_nodes(node_id)
	else:
		_unlock_next_layer(layer_index)
	save_run()


func register_map_connections(connections: Dictionary) -> void:
	map_connections = connections.duplicate(true)


func add_card(card_data: Dictionary) -> void:
	deck_cards.append(card_data.duplicate(true))


func add_gold(amount: int) -> void:
	gold = maxi(gold + amount, 0)


func spend_gold(amount: int) -> bool:
	var safe_amount: int = maxi(amount, 0)
	if gold < safe_amount:
		return false
	gold -= safe_amount
	return true


func heal(amount: int) -> void:
	player_hp = clampi(player_hp + maxi(amount, 0), 0, player_max_hp)


func damage_player(amount: int) -> void:
	player_hp = clampi(player_hp - maxi(amount, 0), 0, player_max_hp)


func add_relic(relic_data: Dictionary) -> void:
	relics.append(relic_data.duplicate(true))


func add_potion(potion_data: Dictionary) -> void:
	potions.append(potion_data.duplicate(true))


func save_run() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("meta", "version", 1)
	config.set_value("run", "player_hp", player_hp)
	config.set_value("run", "player_max_hp", player_max_hp)
	config.set_value("run", "gold", gold)
	config.set_value("run", "floor", floor)
	config.set_value("run", "deck_cards", deck_cards)
	config.set_value("run", "relics", relics)
	config.set_value("run", "potions", potions)
	config.set_value("run", "completed_node_ids", completed_node_ids)
	config.set_value("run", "available_node_ids", available_node_ids)
	config.set_value("run", "current_map_position", current_map_position)
	config.set_value("run", "current_node_id", current_node_id)
	config.set_value("run", "current_node_type", current_node_type)
	config.set_value("run", "map_connections", map_connections)
	config.set_value("run", "card_reward_pity_counter", card_reward_pity_counter)
	var error: int = config.save(SAVE_PATH)
	if error != OK:
		push_warning("保存进度失败：%s" % error)


func load_run() -> bool:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return false

	player_hp = int(config.get_value("run", "player_hp", player_hp))
	player_max_hp = int(config.get_value("run", "player_max_hp", player_max_hp))
	gold = int(config.get_value("run", "gold", gold))
	floor = int(config.get_value("run", "floor", floor))
	deck_cards = _to_dictionary_array(config.get_value("run", "deck_cards", deck_cards))
	relics = _to_dictionary_array(config.get_value("run", "relics", relics))
	potions = _to_dictionary_array(config.get_value("run", "potions", potions))
	completed_node_ids = _to_string_array(config.get_value("run", "completed_node_ids", completed_node_ids))
	available_node_ids = _to_string_array(config.get_value("run", "available_node_ids", available_node_ids))
	current_map_position = int(config.get_value("run", "current_map_position", current_map_position))
	current_node_id = str(config.get_value("run", "current_node_id", ""))
	current_node_type = str(config.get_value("run", "current_node_type", ""))
	map_connections = _to_dictionary(config.get_value("run", "map_connections", map_connections))
	card_reward_pity_counter = int(config.get_value("run", "card_reward_pity_counter", card_reward_pity_counter))
	return true


func has_saved_run() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _unlock_next_layer(layer_index: int) -> void:
	var next_layer: int = layer_index + 1
	if next_layer >= 8:
		available_node_ids = []
		return

	available_node_ids.clear()
	var node_count: int = 1
	if next_layer in [1, 2, 3, 4, 5]:
		node_count = 2

	for index in range(node_count):
		available_node_ids.append("%d-%d" % [next_layer + 1, index + 1])


func _unlock_connected_nodes(node_id: String) -> void:
	available_node_ids.clear()
	var next_ids: Array = map_connections.get(node_id, [])
	for next_id in next_ids:
		var id_text: String = str(next_id)
		if not completed_node_ids.has(id_text):
			available_node_ids.append(id_text)


func _get_layer_index_from_id(node_id: String) -> int:
	var parts: PackedStringArray = node_id.split("-")
	if parts.size() == 0:
		return 0
	return maxi(int(parts[0]) - 1, 0)


func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result


func _to_dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			if item is Dictionary:
				result.append((item as Dictionary).duplicate(true))
	return result


func _to_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}
