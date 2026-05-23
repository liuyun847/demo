class_name BuildingFactory
extends RefCounted

static var _placeholder_label_settings: LabelSettings


static func _get_placeholder_label_settings() -> LabelSettings:
	if _placeholder_label_settings == null:
		_placeholder_label_settings = LabelSettings.new()
		_placeholder_label_settings.font_size = 12
		_placeholder_label_settings.font_color = Color.WHITE
	return _placeholder_label_settings


static func _create_emitter(type_id: String, grid_pos: Vector2i, world_pos: Vector2, node_name: String) -> EmitterNode:
	var emitter := EmitterNode.new()
	emitter.name = node_name
	emitter.global_position = world_pos
	emitter.grid_position = grid_pos

	match type_id:
		GameConfig.emitter_water_type_id:
			emitter.element_type_id = "water"
			emitter.output_direction = emitter.get_default_direction()
		GameConfig.emitter_fire_type_id:
			emitter.element_type_id = "fire"
			emitter.output_direction = emitter.get_default_direction()
		GameConfig.emitter_earth_type_id:
			emitter.element_type_id = "earth"
			emitter.output_direction = emitter.get_default_direction()

	return emitter

static func create_building(building_type: String, grid_pos: Vector2i, world_pos: Vector2, node_name: String) -> Node2D:
	var building_node: Node2D

	if building_type == GameConfig.container_type_id:
		var container := ContainerNode.new()
		container.name = node_name
		container.global_position = world_pos
		container.grid_position = grid_pos
		building_node = container
	elif building_type == GameConfig.pipe_type_id:
		var pipe := PipeNode.new()
		pipe.name = node_name
		pipe.global_position = world_pos
		pipe.grid_position = grid_pos
		building_node = pipe
	elif building_type == GameConfig.brick_type_id:
		var brick := BrickNode.new()
		brick.name = node_name
		brick.global_position = world_pos
		brick.grid_position = grid_pos
		building_node = brick
	elif BuildingData.is_emitter(building_type):
		building_node = _create_emitter(building_type, grid_pos, world_pos, node_name)
	elif BuildingData.is_collector(building_type):
		var collector := CollectorNode.new()
		collector.name = node_name
		collector.global_position = world_pos
		collector.grid_position = grid_pos
		building_node = collector
	else:
		var idx := 0
		if building_type.begins_with("type_"):
			idx = building_type.substr(5).to_int()
		var placeholder := Node2D.new()
		placeholder.name = node_name
		placeholder.global_position = world_pos
		placeholder.set_meta("building_type", building_type)
		building_node = placeholder
		var half_size := GameConfig.building_size / 2.0
		var box := ColorRect.new()
		box.size = Vector2(GameConfig.building_size, GameConfig.building_size)
		box.position = Vector2(-half_size, -half_size)
		var bg_color: Color
		if building_type == "default":
			bg_color = GameConfig.building_default_color
		elif building_type.begins_with("type_"):
			idx = building_type.substr(5).to_int()
			if idx >= 1 and idx <= 10:
				bg_color = Color.from_hsv(float(idx - 1) / 10.0, 0.7, 0.9)
			else:
				bg_color = GameConfig.building_default_color
		else:
			bg_color = GameConfig.building_default_color
		bg_color.a = 0.3
		box.color = bg_color
		placeholder.add_child(box)
		var label := Label.new()
		label.text = "占位-%d" % idx if idx > 0 else "占位"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = Vector2(GameConfig.building_size, GameConfig.building_size)
		label.position = Vector2(-half_size, -half_size)
		label.label_settings = _get_placeholder_label_settings()
		placeholder.add_child(label)

	return building_node
