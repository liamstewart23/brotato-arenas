# arena_random_popup.gd — Modal popup for configuring the Random arena pool + reroll mode.
#
# Built procedurally (the mod ships no .tscn files). Mirrors the base game's Popin
# pattern (ui/menus/global/popin.gd): a full-screen darkened overlay hosting a centered
# card, shown on a CanvasLayer at layer 9999, with a FocusEmulator child so controller
# and keyboard navigation work. The game tree is paused while open so the underlying
# character-selection focus emulators don't fight ours for input.
#
# Settings apply live (like the options menu) and write straight to ZoneService +
# ProgressData — there is no separate confirm step; "Done" just closes the popup.

extends PanelContainer

const ArenaShapeClass = preload("res://mods-unpacked/PapiLeem-Arenas/arena_shapes/arena_shape.gd")

# Fallback shape-name translation keys (ids 0..7). The owning panel passes its full,
# up-to-date list into setup() so this never has to track new shapes; this const is
# only used if setup() is called without one.
const SHAPE_NAMES = ["ARENA_RECTANGLE", "ARENA_CIRCLE", "ARENA_HEXAGON", "ARENA_CURSE_RUN", "ARENA_SHRINKING", "ARENA_MAZE", "ARENA_MULTIROOM", "ARENA_HAZARD"]

# Minimum number of shapes that must stay in the pool so "Random" is meaningful.
const MIN_POOL = 2

var _canvas_layer: CanvasLayer
var _emulator                       # FocusEmulator instance (controller/keyboard nav)
var _content: VBoxContainer
var _shape_names := []              # name keys passed in by the panel (ids 0..concrete-1)
var _pool_checkboxes := []
var _reroll_wave_button: Button     # selected = new arena every wave
var _reroll_run_button: Button      # selected = one random arena per run
var _last_focus: Control


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS


# Build the full popup UI and populate it from the current ZoneService state.
# Call once after .new(), before the first open(). `shape_names` is the panel's
# full list of name keys (ids 0..concrete-1, optionally with Random last); falls
# back to the local SHAPE_NAMES const if omitted.
func setup(shape_names := []) -> void:
	_shape_names = shape_names if shape_names.size() > 0 else SHAPE_NAMES

	# Root overlay: full-screen, dark, blocks clicks underneath.
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = load("res://resources/themes/base_theme.tres")
	var overlay_style = StyleBoxFlat.new()
	overlay_style.bg_color = Color(0, 0, 0, 0.86)
	add_stylebox_override("panel", overlay_style)

	var center = VBoxContainer.new()
	center.name = "CenterBox"
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.alignment = BoxContainer.ALIGN_CENTER
	add_child(center)

	var card = PanelContainer.new()
	card.name = "Card"
	card.rect_min_size = Vector2(640, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.227, 0.239, 0.262, 1.0)
	card_style.set_corner_radius_all(10)
	card.add_stylebox_override("panel", card_style)
	center.add_child(card)

	var margin = MarginContainer.new()
	margin.name = "CardMargin"
	margin.add_constant_override("margin_left", 30)
	margin.add_constant_override("margin_right", 30)
	margin.add_constant_override("margin_top", 30)
	margin.add_constant_override("margin_bottom", 30)
	card.add_child(margin)

	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.add_constant_override("separation", 16)
	margin.add_child(_content)

	var font_title = load("res://resources/fonts/actual/base/font_32_outline.tres")
	var font_item = load("res://resources/fonts/actual/base/font_26.tres")

	# Title
	var title = Label.new()
	title.align = Label.ALIGN_CENTER
	if font_title:
		title.add_font_override("font", font_title)
	title.text = _tr_or("ARENA_RANDOM_POOL", "Random Pool")
	_content.add_child(title)

	# Checkbox grid (2 columns) for the 8 concrete shapes
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_constant_override("hseparation", 40)
	grid.add_constant_override("vseparation", 8)
	var pool = ZoneService.arena_random_pool
	for i in range(ArenaShapeClass.SHAPE_CONCRETE_COUNT):
		var cb = CheckBox.new()
		cb.text = tr(_shape_names[i]) if i < _shape_names.size() else ("Shape %d" % i)
		cb.add_constant_override("hseparation", 12)  # space the check icon from the label
		if font_item:
			cb.add_font_override("font", font_item)
		cb.pressed = pool.has(i)
		cb.connect("toggled", self, "_on_pool_toggled")
		_pool_checkboxes.append(cb)
		grid.add_child(cb)
	_content.add_child(grid)

	# A pool below the minimum is invalid (e.g. a legacy save) — normalize to all.
	if _selected_count() < MIN_POOL:
		for cb in _pool_checkboxes:
			cb.set_pressed_no_signal(true)
		_rebuild_pool()
	_enforce_minimum()

	# Select All row (no "Clear": with a 2-shape minimum, emptying the pool is invalid).
	var select_row = HBoxContainer.new()
	select_row.alignment = BoxContainer.ALIGN_CENTER
	select_row.add_constant_override("separation", 16)
	var btn_all = Button.new()
	btn_all.text = _tr_or("ARENA_SELECT_ALL", "Select All")
	if font_item:
		btn_all.add_font_override("font", font_item)
	btn_all.connect("pressed", self, "_on_select_all")
	select_row.add_child(btn_all)
	_content.add_child(select_row)

	# Reroll-mode chooser: a heading + two radio-style buttons (one always selected),
	# so both options are visible at once instead of a single self-relabeling toggle.
	var reroll_heading = Label.new()
	reroll_heading.align = Label.ALIGN_CENTER
	if font_item:
		reroll_heading.add_font_override("font", font_item)
	reroll_heading.text = _tr_or("ARENA_REROLL_HEADING", "New arena each:")
	_content.add_child(reroll_heading)

	var reroll_row = HBoxContainer.new()
	reroll_row.alignment = BoxContainer.ALIGN_CENTER
	reroll_row.add_constant_override("separation", 16)
	var reroll_group = ButtonGroup.new()

	_reroll_wave_button = Button.new()
	_reroll_wave_button.toggle_mode = true
	_reroll_wave_button.group = reroll_group
	if font_item:
		_reroll_wave_button.add_font_override("font", font_item)
	_reroll_wave_button.text = _tr_or("ARENA_REROLL_OPT_WAVE", "Wave")
	_reroll_wave_button.connect("pressed", self, "_on_reroll_mode_chosen", [false])
	reroll_row.add_child(_reroll_wave_button)

	_reroll_run_button = Button.new()
	_reroll_run_button.toggle_mode = true
	_reroll_run_button.group = reroll_group
	if font_item:
		_reroll_run_button.add_font_override("font", font_item)
	_reroll_run_button.text = _tr_or("ARENA_REROLL_OPT_RUN", "Run")
	_reroll_run_button.connect("pressed", self, "_on_reroll_mode_chosen", [true])
	reroll_row.add_child(_reroll_run_button)
	_content.add_child(reroll_row)

	# Initial selection (setting .pressed does not emit "pressed", so no premature write)
	if ZoneService.arena_random_per_run:
		_reroll_run_button.pressed = true
	else:
		_reroll_wave_button.pressed = true

	# One-line clarification
	var reroll_desc = Label.new()
	reroll_desc.align = Label.ALIGN_CENTER
	reroll_desc.autowrap = true
	var small_font = load("res://resources/fonts/actual/base/font_smallest_text.tres")
	if small_font:
		reroll_desc.add_font_override("font", small_font)
	reroll_desc.add_color_override("font_color", Color(0.7, 0.7, 0.7, 0.9))
	reroll_desc.text = _tr_or("ARENA_REROLL_DESC", "Wave = fresh arena every wave. Run = one random arena for the whole run.")
	_content.add_child(reroll_desc)

	# Done button
	var done = Button.new()
	done.text = _tr_or("ARENA_DONE", "Done")
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if font_item:
		done.add_font_override("font", font_item)
	done.connect("pressed", self, "_on_done")
	_content.add_child(done)

	# FocusEmulator for controller/keyboard nav (mirror Popin). focus_base_data must be
	# set before the node enters the tree (_ready reads it), so configure it here.
	_emulator = FocusEmulator.new()
	_emulator.name = "FocusEmulator"
	_emulator.pause_mode = Node.PAUSE_MODE_PROCESS
	var bd = FocusEmulatorBaseData.new()
	bd.path = NodePath("../CenterBox/Card/CardMargin/Content")
	_emulator.focus_base_data = [bd]
	add_child(_emulator)


# Show the popup (lazily creating + parenting its CanvasLayer to the scene root).
# Uses Engine.get_main_loop() for the tree since this node isn't in the tree yet
# when first opened (get_tree() would return null and crash).
func open() -> void:
	var tree = _scene_tree()
	if _canvas_layer == null:
		_canvas_layer = CanvasLayer.new()
		_canvas_layer.layer = 9999
		_canvas_layer.pause_mode = Node.PAUSE_MODE_PROCESS
		_canvas_layer.add_child(self)
	if _canvas_layer.get_parent() == null:
		tree.root.add_child(_canvas_layer)

	# self is in the tree now — safe to read focus/viewport.
	_last_focus = get_focus_owner()
	visible = true
	tree.paused = true

	if _emulator:
		_emulator.set_process_input(true)
		_emulator.player_index = 0
	if _pool_checkboxes.size() > 0:
		_pool_checkboxes[0].grab_focus()


# Hide the popup, unpause, and restore focus. The CanvasLayer (with this popup still
# parented under it) is removed from the root, ready to be re-added on the next open().
func close() -> void:
	var tree = _scene_tree()
	if _emulator:
		_emulator.set_process_input(false)
		_emulator.player_index = -1
	visible = false
	if tree != null:
		tree.paused = false

	if _last_focus and is_instance_valid(_last_focus):
		_last_focus.grab_focus()
	_last_focus = null

	if _canvas_layer and _canvas_layer.get_parent() != null and tree != null:
		tree.root.call_deferred("remove_child", _canvas_layer)


func is_open() -> bool:
	return _canvas_layer != null and _canvas_layer.get_parent() != null


# The SceneTree, resolved even when this node isn't in the tree yet (get_tree()
# returns null in that case, but Engine.get_main_loop() is the SceneTree).
func _scene_tree() -> SceneTree:
	var tree = get_tree()
	if tree == null:
		tree = Engine.get_main_loop() as SceneTree
	return tree


# Free the popup and its CanvasLayer. Called by the owning panel when it leaves the
# tree, since the CanvasLayer is parented to the scene root (not under the panel).
func destroy() -> void:
	var tree = _scene_tree()
	if tree != null and tree.paused and is_open():
		tree.paused = false
	if _canvas_layer != null and is_instance_valid(_canvas_layer):
		_canvas_layer.queue_free()  # frees this popup (its child) too
	elif get_parent() == null:
		queue_free()  # created but never opened — free the orphaned popup
	_canvas_layer = null


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_tree().set_input_as_handled()


# --- Persistence (live apply) ---

func _rebuild_pool() -> void:
	var pool = []
	for i in range(_pool_checkboxes.size()):
		if _pool_checkboxes[i].pressed:
			pool.append(i)
	ZoneService.arena_random_pool = pool
	ProgressData.settings["arena_random_pool"] = pool


func _on_pool_toggled(_pressed: bool) -> void:
	_rebuild_pool()
	_enforce_minimum()


func _on_select_all() -> void:
	for cb in _pool_checkboxes:
		cb.set_pressed_no_signal(true)
	_rebuild_pool()
	_enforce_minimum()


func _selected_count() -> int:
	var n = 0
	for cb in _pool_checkboxes:
		if cb.pressed:
			n += 1
	return n


# Keep at least MIN_POOL shapes selected: once the count hits the floor, lock the
# still-checked boxes (disable them) so they can't be unchecked; unlock when above it.
func _enforce_minimum() -> void:
	var at_floor = _selected_count() <= MIN_POOL
	for cb in _pool_checkboxes:
		cb.disabled = at_floor and cb.pressed


func _on_reroll_mode_chosen(per_run: bool) -> void:
	ZoneService.arena_random_per_run = per_run
	ProgressData.settings["arena_random_per_run"] = per_run
	# Clear any stale per-run cache so the next run rolls fresh under the new mode.
	ProgressData.settings["arena_random_run_resolved"] = -1


func _on_done() -> void:
	close()


# tr() with an English fallback when the key is untranslated for the active locale.
func _tr_or(key: String, fallback: String) -> String:
	var t = tr(key)
	return fallback if t == key else t
