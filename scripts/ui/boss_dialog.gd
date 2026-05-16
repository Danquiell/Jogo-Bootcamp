extends CanvasLayer
## Post-victory monologue from the GPT boss before the final victory screen.

const LINES: Array[String] = [
	"Você pode ter vencido essa batalha, mas nunca vencerá a guerra...",
	"...o Claude lhe aguarda...",
]

const PORTRAIT_PATH: String = "res://assets/generated/sprites/gpt-chat/gpt-pro-png.png"
const FONT_PATH: String = "res://assets/shared/fonts/PressStart2P-Regular.ttf"
const VICTORY_SCENE_PATH: String = "res://scenes/ui/victory.tscn"
const BOSS_NAME: String = "GPT-Pro"

var _current_line: int = 0
var _text_label: Label
var _continue_button: Button
var _font: Font


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	get_tree().paused = true

	_font = load(FONT_PATH)
	_build_ui()
	_show_line(0)


func _build_ui() -> void:
	# Dim backdrop
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	# Speech box (white panel) — bottom strip
	var box := PanelContainer.new()
	box.position = Vector2(8, 100)
	box.size = Vector2(304, 75)
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.1, 0.1, 0.15, 1.0)
	box.add_theme_stylebox_override("panel", style)
	add_child(box)

	# Name label above box (left side)
	var name_label := Label.new()
	name_label.text = BOSS_NAME
	name_label.position = Vector2(12, 86)
	_apply_font(name_label, 8)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	name_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(name_label)

	# Speech text — left side, full width below name
	_text_label = Label.new()
	_text_label.position = Vector2(14, 106)
	_text_label.size = Vector2(220, 50)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_font(_text_label, 7)
	_text_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.15, 1.0))
	add_child(_text_label)

	# Portrait — Sprite2D with region cropped to the face area for a zoomed headshot
	var portrait_tex: Texture2D = load(PORTRAIT_PATH)
	var face_region: Rect2 = Rect2(200, 80, 200, 200)
	var portrait := Sprite2D.new()
	portrait.texture = portrait_tex
	portrait.centered = false
	portrait.region_enabled = true
	portrait.region_rect = face_region
	portrait.position = Vector2(248, 100)
	var portrait_target_size: float = 56.0
	portrait.scale = Vector2(
		portrait_target_size / face_region.size.x,
		portrait_target_size / face_region.size.y
	)
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(portrait)

	# Continue button — bottom-right, directly below portrait
	_continue_button = Button.new()
	_continue_button.text = "Prosseguir"
	_continue_button.position = Vector2(244, 158)
	_continue_button.size = Vector2(64, 14)
	_apply_font(_continue_button, 6)
	_continue_button.pressed.connect(_on_continue)
	add_child(_continue_button)


func _apply_font(node: Control, size: int) -> void:
	if _font:
		node.add_theme_font_override("font", _font)
	node.add_theme_font_size_override("font_size", size)


func _show_line(idx: int) -> void:
	_current_line = idx
	_text_label.text = LINES[idx]


func _unhandled_input(event: InputEvent) -> void:
	# Allow keyboard advance (attack/interact keys)
	if event.is_action_pressed("interact") or event.is_action_pressed("attack"):
		_on_continue()
		get_viewport().set_input_as_handled()


func _on_continue() -> void:
	if _current_line + 1 < LINES.size():
		_show_line(_current_line + 1)
	else:
		_finish()


func _finish() -> void:
	get_tree().paused = false
	_show_victory()
	queue_free()


func _show_victory() -> void:
	var scene: PackedScene = load(VICTORY_SCENE_PATH)
	if scene:
		var inst: Node = scene.instantiate()
		get_tree().current_scene.add_child(inst)
