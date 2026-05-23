class_name EssenceDisplay
extends Control

var _label: Label = null

func _ready() -> void:
	custom_minimum_size = Vector2(200, 32)
	_label = Label.new()
	add_child(_label)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ls := LabelSettings.new()
	ls.font_size = 18
	ls.font_color = Color("#ffd700")
	_label.label_settings = ls

	EssencePool.essence_changed.connect(_on_essence_changed)
	_on_essence_changed(EssencePool.essence)

func _exit_tree() -> void:
	if EssencePool.essence_changed.is_connected(_on_essence_changed):
		EssencePool.essence_changed.disconnect(_on_essence_changed)

func _on_essence_changed(value: float) -> void:
	_label.text = "源质: %d" % floori(value)
