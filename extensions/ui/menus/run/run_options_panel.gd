# run_options_panel.gd — Adds arena shape dropdown to the run options screen.
#
# Creates an OptionButton populated with shape names (translated via tr())
# and a description Label that updates on selection. The selected shape index
# is persisted in ProgressData.settings["arena_shape_selected"] so it survives
# save/resume and is read by zone_service.gd when loading a zone.
#
# SHAPE_NAMES indices (0-7) must stay aligned with arena_shape.gd's constants.
# SHAPE_DESCS_EN provides English fallback descriptions in case translation
# returns the key unchanged (which happens when a locale is missing).

extends "res://ui/menus/run/run_options_panel.gd"

const ArenaShapeClass = preload("res://mods-unpacked/PapiLeem-Arenas/arena_shapes/arena_shape.gd")
const ArenaRandomPopup = preload("res://mods-unpacked/PapiLeem-Arenas/ui/arena_random_popup.gd")

var _arena_shape_option: OptionButton
var _arena_desc_label: Label

# Random settings: a trigger button (shown only when "Random" is selected) that opens
# a modal popup holding the pool checkboxes + reroll toggle.
var _random_settings_button: Button
var _random_popup

# Translation keys — indices match ArenaShapeClass.SHAPE_* constants
const SHAPE_NAMES = ["ARENA_RECTANGLE", "ARENA_CIRCLE", "ARENA_HEXAGON", "ARENA_CURSE_RUN", "ARENA_SHRINKING", "ARENA_MAZE", "ARENA_MULTIROOM", "ARENA_HAZARD", "ARENA_ROAMING_HAZARD", "ARENA_METEOR", "ARENA_SAFE_ZONE", "ARENA_RANDOM"]

# English fallback descriptions (used when tr() returns the key unchanged)
const SHAPE_DESCS_EN = [
	"Standard arena",
	"Circular arena - no corners to hide in",
	"Six-sided arena with flat edges",
	"Run right or die - curse wall chases you",
	"Arena shrinks over time - battle royale style",
	"Procedural maze - different layout every wave",
	"Rooms connected by doorways",
	"Curse clouds that damage you on contact",
	"Roaming curse clouds drift around the arena",
	"Meteors rain down - get off the marked spot",
	"Stay in the moving safe zone or take damage",
	"Random arena shape each wave",
]


func init():
	.init()
	_setup_arena_shape()


# Build the arena shape dropdown and description label, insert into the UI.
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

	# Restore random-pool settings into ZoneService (persists across save/resume)
	if ProgressData.settings.has("arena_random_pool"):
		ZoneService.arena_random_pool = ProgressData.settings.arena_random_pool.duplicate()
	if ProgressData.settings.has("arena_random_per_run"):
		ZoneService.arena_random_per_run = bool(ProgressData.settings.arena_random_per_run)

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

	# "Random Settings" trigger button (visible only when Random is selected)
	_setup_random_settings_button(buttons_vbox)
	_update_random_ui_visibility()


# Callback when the player selects a shape from the dropdown.
# Persists the selection in ProgressData so zone_service.gd can read it.
func _on_arena_shape_selected(index: int):
	ZoneService.arena_shape_id = index
	ProgressData.settings["arena_shape_selected"] = index
	_update_desc_label()
	_update_random_ui_visibility()


# Build the compact "Random Settings" button that opens the pool/reroll popup.
# Inserted below the description label; visibility is driven by the dropdown.
func _setup_random_settings_button(buttons_vbox):
	var small_font = load("res://resources/fonts/actual/base/font_smallest_text.tres")

	_random_settings_button = Button.new()
	_random_settings_button.name = "ArenaRandomSettingsButton"
	if small_font:
		_random_settings_button.add_font_override("font", small_font)
	var t = tr("ARENA_RANDOM_SETTINGS")
	_random_settings_button.text = ("Random Settings" if t == "ARENA_RANDOM_SETTINGS" else t)
	_random_settings_button.connect("pressed", self, "_on_random_settings_pressed")
	buttons_vbox.add_child_below_node(_arena_desc_label, _random_settings_button)


# Lazily build the popup, then open it.
func _on_random_settings_pressed():
	if _random_popup == null:
		_random_popup = ArenaRandomPopup.new()
		_random_popup.setup(SHAPE_NAMES)
	_random_popup.open()


# The popup's CanvasLayer is parented to the scene root, so free it explicitly when
# this panel leaves the tree (e.g. leaving the character selection screen).
func _exit_tree():
	if _random_popup != null and is_instance_valid(_random_popup):
		_random_popup.destroy()
		_random_popup = null


# Show the settings button only when "Random" is the selected shape; close the popup
# if the selection moves away from Random while it's open.
func _update_random_ui_visibility():
	var is_random = (_arena_shape_option.selected == ArenaShapeClass.SHAPE_RANDOM)
	if _random_settings_button:
		_random_settings_button.visible = is_random
	if not is_random and _random_popup != null and _random_popup.is_open():
		_random_popup.close()


# Derive the description translation key from the shape name key.
# e.g., "ARENA_CIRCLE" -> "ARENA_SHAPE_DESC_CIRCLE"
func _get_desc_key(shape_name: String) -> String:
	return shape_name.replace("ARENA_", "ARENA_SHAPE_DESC_")


# Update the description label text for the currently selected shape.
# Uses tr() for localized text, falling back to SHAPE_DESCS_EN if untranslated.
func _update_desc_label():
	var index = _arena_shape_option.selected
	var desc_key = _get_desc_key(SHAPE_NAMES[index])
	var desc_text = tr(desc_key)
	# Fallback to English if translation returns the key unchanged
	if desc_text == desc_key:
		desc_text = SHAPE_DESCS_EN[index] if index < SHAPE_DESCS_EN.size() else ""
	_arena_desc_label.text = desc_text
