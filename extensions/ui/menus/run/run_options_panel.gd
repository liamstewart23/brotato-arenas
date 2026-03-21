extends "res://ui/menus/run/run_options_panel.gd"

var _arena_shape_option: OptionButton
var _arena_desc_label: Label

const SHAPE_NAMES = ["ARENA_RECTANGLE", "ARENA_CIRCLE", "ARENA_HEXAGON", "ARENA_CURSE_RUN", "ARENA_SHRINKING", "ARENA_MAZE", "ARENA_MULTIROOM", "ARENA_HAZARD"]

const SHAPE_DESCS_EN = [
	"Standard arena",
	"Circular arena - no corners to hide in",
	"Six-sided arena with flat edges",
	"Run right or die - curse wall chases you",
	"Arena shrinks over time - battle royale style",
	"Procedural maze - different layout every wave",
	"Rooms connected by doorways",
	"Curse clouds that damage you on contact",
]


func init():
	.init()
	_setup_arena_shape()


func _setup_arena_shape():
	var buttons_vbox = $MarginContainer/VBoxContainer/VBoxContainer
	var zone_button = buttons_vbox.get_child(0)  # ZoneSelectionButton is first child
	var zone_theme = load("res://resources/themes/zone_selection_button_theme.tres")

	_arena_shape_option = OptionButton.new()
	_arena_shape_option.name = "ArenaShapeButton"
	_arena_shape_option.clip_text = true
	if zone_theme:
		_arena_shape_option.theme = zone_theme

	for i in SHAPE_NAMES.size():
		_arena_shape_option.add_item(tr(SHAPE_NAMES[i]), i)

	# Restore saved selection before connecting signal to avoid triggering callback
	var saved = 0
	if ProgressData.settings.has("arena_shape_selected"):
		saved = int(clamp(ProgressData.settings.arena_shape_selected, 0, SHAPE_NAMES.size() - 1))
	ZoneService.arena_shape_id = saved
	_arena_shape_option.selected = saved

	# Connect after setting selected
	_arena_shape_option.connect("item_selected", self, "_on_arena_shape_selected")

	# Insert right after ZoneSelectionButton
	buttons_vbox.add_child_below_node(zone_button, _arena_shape_option)

	# Description label below the dropdown
	_arena_desc_label = Label.new()
	_arena_desc_label.name = "ArenaDescLabel"
	_arena_desc_label.autowrap = true
	_arena_desc_label.size_flags_horizontal = Control.SIZE_FILL
	var small_font = load("res://resources/fonts/actual/base/font_smallest_text.tres")
	if small_font:
		_arena_desc_label.add_font_override("font", small_font)
	_arena_desc_label.add_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
	buttons_vbox.add_child_below_node(_arena_shape_option, _arena_desc_label)
	_update_desc_label()


func _on_arena_shape_selected(index: int):
	ZoneService.arena_shape_id = index
	ProgressData.settings["arena_shape_selected"] = index
	_update_desc_label()


func _get_desc_key(shape_name: String) -> String:
	return shape_name.replace("ARENA_", "ARENA_SHAPE_DESC_")


func _update_desc_label():
	var index = _arena_shape_option.selected
	var desc_key = _get_desc_key(SHAPE_NAMES[index])
	var desc_text = tr(desc_key)
	# Fallback to English if translation returns the key unchanged
	if desc_text == desc_key:
		desc_text = SHAPE_DESCS_EN[index] if index < SHAPE_DESCS_EN.size() else ""
	_arena_desc_label.text = desc_text
