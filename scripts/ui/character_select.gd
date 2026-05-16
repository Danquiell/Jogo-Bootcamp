extends CanvasLayer

const GAME_SCENE: String = "res://scenes/world/vila.tscn"

const SWORD_TEX: String = "res://assets/rpg/sprites/player/Swordsman_lvl1/Without_shadow/Swordsman_lvl1_Idle_without_shadow.png"
const GEMINI_TEX: String = "res://assets/generated/SPRITES-GEMINI/rotations/south.png"

const CARD_NAMES: Array[String] = ["Swordsman", "Gemini"]
const CARD_SKINS: Array[int] = [GameManager.CharacterSkin.SWORDSMAN, GameManager.CharacterSkin.GEMINI]

var _selected: int = 0
var _cards: Array[PanelContainer] = []
var _confirmed: bool = false

const COLOR_BG: Color = Color(0.05, 0.05, 0.12, 1.0)
const COLOR_CARD_NORMAL: Color = Color(0.15, 0.15, 0.25, 1.0)
const COLOR_CARD_SELECTED: Color = Color(0.25, 0.25, 0.45, 1.0)
const COLOR_BORDER_NORMAL: Color = Color(0.35, 0.35, 0.55, 1.0)
const COLOR_BORDER_SELECTED: Color = Color(1.0, 0.82, 0.2, 1.0)


func _ready() -> void:
	_build_ui()
	_refresh_cards()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = COLOR_BG
	add_child(bg)

	var title := Label.new()
	title.text = "SELECT CHARACTER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_position(Vector2(0, 8))
	title.set_size(Vector2(320, 16))
	add_child(title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	row.set_position(Vector2(0, 30))
	row.set_size(Vector2(320, 120))
	add_child(row)

	var textures: Array[String] = [SWORD_TEX, GEMINI_TEX]
	for i: int in range(2):
		var card := _make_card(CARD_NAMES[i], textures[i], i == 0)
		row.add_child(card)
		_cards.append(card)

	var hint := Label.new()
	hint.text = "A / D or LEFT / RIGHT to choose   ENTER / Z to confirm"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_position(Vector2(0, 165))
	hint.set_size(Vector2(320, 12))
	add_child(hint)


func _make_card(char_name: String, tex_path: String, is_sword: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(80, 100)

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_CARD_NORMAL
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = COLOR_BORDER_NORMAL
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	# Sprite2D container (Control wrapper so it works inside VBoxContainer)
	var sprite_container := Control.new()
	var preview := Sprite2D.new()
	var tex: Texture2D = load(tex_path)
	preview.texture = tex
	preview.centered = true

	if is_sword:
		# Show south-facing idle frame (12 cols × 4 rows sheet, each frame 64×64)
		preview.hframes = 12
		preview.vframes = 4
		preview.frame = 0
		sprite_container.custom_minimum_size = Vector2(64, 64)
		preview.position = Vector2(32, 32)
	else:
		# Single 36×36 frame, scale up 2×
		preview.scale = Vector2(2.0, 2.0)
		sprite_container.custom_minimum_size = Vector2(36, 36)
		preview.position = Vector2(18, 18)

	sprite_container.add_child(preview)
	vbox.add_child(sprite_container)

	var lbl := Label.new()
	lbl.text = char_name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)

	return card


func _refresh_cards() -> void:
	for i: int in range(_cards.size()):
		var style := _cards[i].get_theme_stylebox("panel") as StyleBoxFlat
		if i == _selected:
			style.bg_color = COLOR_CARD_SELECTED
			style.border_color = COLOR_BORDER_SELECTED
		else:
			style.bg_color = COLOR_CARD_NORMAL
			style.border_color = COLOR_BORDER_NORMAL


func _unhandled_input(event: InputEvent) -> void:
	if _confirmed:
		return

	if event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
		_selected = 1 - _selected
		_refresh_cards()

	if event.is_action_pressed("attack") or event.is_action_pressed("interact"):
		_confirm()


func _confirm() -> void:
	_confirmed = true
	GameManager.selected_skin = CARD_SKINS[_selected]
	get_tree().change_scene_to_file(GAME_SCENE)
