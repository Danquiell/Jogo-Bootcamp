extends CharacterBody2D
## GPT Boss — two-phase final boss.
## Phase 1: melee wrench attacks. Phase 2 (50% HP): gains area fire attack,
## new walk animation, and the arena floor changes.

# --- Enums ---
enum Phase { ONE, TWO }
enum AIState { CHASE, ATTACK_MELEE, ATTACK_AREA, HURT, DEATH }
enum Direction { DOWN = 0, LEFT = 1, RIGHT = 2, UP = 3 }

# --- Sprite Paths ---
const P1_BASE := "res://assets/generated/sprites/gptPhase1/"
const P2_BASE := "res://assets/generated/sprites/gptPhase2/"

const P1_WALK_PATH   := P1_BASE + "GPT-walk.png"
const P1_ATTACK_PATH := P1_BASE + "GPT-attack.png"

const P2_WALK_DOWN_PATH  := P2_BASE + "GPT Pro-iso_walk_down.png"
const P2_WALK_RIGHT_PATH := P2_BASE + "GPT Pro-iso_walk_right.png"
const P2_AREA_PATH       := P2_BASE + "GPT Pro-iso_custom_heat_attack_right.png"

# --- Sprite Layout ---
# All sheets: 5 cols × 5 rows, 256×256 per frame (1280 / 256 = 5).
# vframes MUST be the actual row count (5), not 1 — otherwise Godot calculates
# frame_height = texture_height / vframes = 1280 / 1 = 1280, showing a full
# vertical column of the sheet (5 stacked bosses) per frame.
# We animate frame indices 0..4 to show only the first row.
const P1_HFRAMES        := 5
const P1_VFRAMES        := 5
const P1_FRAMES_PER_DIR := 5
const P1_WALK_CYCLE     := 0.8

# Phase 2 walk: same 5×5 layout, first row only
const P2_WALK_FRAMES := 5
const P2_WALK_CYCLE  := 0.6

# Area attack: 5×5 sheet, use all 25 frames for full ring animation
const P2_AREA_HFRAMES      := 5
const P2_AREA_VFRAMES      := 5
const P2_AREA_TOTAL_FRAMES := 25

# 256px frame × 0.5 scale = 128px rendered; visible character ~80–100px
const SPRITE_SCALE      := Vector2(0.5, 0.5)
# Ring rendered at 192px — slightly bigger than area range (90px) for visual clarity
const AREA_SPRITE_SCALE := Vector2(0.75, 0.75)

# --- Stats ---
const MAX_HP             := 20
const PHASE2_THRESHOLD   := 10   # 50% HP triggers phase 2

const SPEED_P1           := 40.0
const SPEED_P2           := 55.0

const MELEE_RANGE        := 60.0
const AREA_RANGE         := 90.0

const MELEE_DAMAGE       := 2
const AREA_DAMAGE        := 3

const MELEE_DURATION     := 0.8
const MELEE_COOLDOWN     := 1.5
const AREA_DURATION      := 1.2
const AREA_COOLDOWN      := 5.0
const HURT_DURATION      := 0.25

# --- Node References ---
@onready var sprite: Sprite2D             = $Sprite
@onready var area_attack_sprite: Sprite2D = $AreaAttackSprite
@onready var hurtbox: Area2D              = $Hurtbox
@onready var hitbox: Area2D               = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/HitboxShape

# --- State ---
var current_phase: Phase    = Phase.ONE
var current_state: AIState  = AIState.CHASE
var current_hp: int         = MAX_HP
var _is_dead: bool          = false
var facing: Direction       = Direction.DOWN
var _target: CharacterBody2D = null

var anim_timer: float        = 0.0
var current_anim_frame: int  = 0
var attack_timer: float      = 0.0
var melee_cooldown: float    = 0.0
var area_cooldown: float     = 0.0
var hurt_timer: float        = 0.0
var _area_damage_dealt: bool = false

# --- Textures ---
var _p1_walk_tex: Texture2D
var _p1_attack_tex: Texture2D
var _p2_walk_down_tex: Texture2D
var _p2_walk_right_tex: Texture2D
var _p2_area_tex: Texture2D


# --- Lifecycle ---

func _ready() -> void:
	current_hp = MAX_HP
	add_to_group("enemies")

	_p1_walk_tex      = load(P1_WALK_PATH)
	_p1_attack_tex    = load(P1_ATTACK_PATH)
	_p2_walk_down_tex = load(P2_WALK_DOWN_PATH)
	_p2_walk_right_tex = load(P2_WALK_RIGHT_PATH)
	_p2_area_tex      = load(P2_AREA_PATH)

	# Main sprite — phase 1 walk
	sprite.scale   = SPRITE_SCALE
	sprite.texture = _p1_walk_tex
	sprite.hframes = P1_HFRAMES
	sprite.vframes = P1_VFRAMES

	# Area attack sprite — additive blend so black background is invisible
	area_attack_sprite.scale   = AREA_SPRITE_SCALE
	area_attack_sprite.texture = _p2_area_tex
	area_attack_sprite.hframes = P2_AREA_HFRAMES
	area_attack_sprite.vframes = P2_AREA_VFRAMES
	area_attack_sprite.visible = false
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	area_attack_sprite.material = mat

	hitbox.set_meta("damage", MELEE_DAMAGE)
	hitbox.add_to_group("enemy_hitbox")
	hitbox_shape.set_deferred("disabled", true)
	hitbox.monitoring = false

	hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	await get_tree().process_frame
	_target = get_parent().get_node_or_null("Player") as CharacterBody2D


func _physics_process(delta: float) -> void:
	if _is_dead:
		_animate(delta)
		return

	if melee_cooldown > 0.0: melee_cooldown -= delta
	if area_cooldown  > 0.0: area_cooldown  -= delta

	match current_state:
		AIState.CHASE:        _process_chase(delta)
		AIState.ATTACK_MELEE: _process_attack_melee(delta)
		AIState.ATTACK_AREA:  _process_attack_area(delta)
		AIState.HURT:         _process_hurt(delta)
		AIState.DEATH:        pass

	_animate(delta)


# --- AI States ---

func _process_chase(_delta: float) -> void:
	if not is_instance_valid(_target):
		velocity = Vector2.ZERO
		return

	var dist: float = global_position.distance_to(_target.global_position)

	# Phase 2: area attack takes priority when player is in range
	if current_phase == Phase.TWO and area_cooldown <= 0.0 and dist < AREA_RANGE:
		_enter_attack_area()
		return

	# Melee only exists in phase 1
	if current_phase == Phase.ONE and melee_cooldown <= 0.0 and dist < MELEE_RANGE:
		_enter_attack_melee()
		return

	var dir: Vector2 = global_position.direction_to(_target.global_position)
	velocity = dir * _speed()
	_update_facing(dir)
	move_and_slide()


func _process_attack_melee(delta: float) -> void:
	velocity = Vector2.ZERO
	attack_timer -= delta
	if attack_timer <= 0.0:
		hitbox_shape.set_deferred("disabled", true)
		hitbox.monitoring = false
		current_state = AIState.CHASE
		_apply_walk_texture()


func _process_attack_area(delta: float) -> void:
	velocity = Vector2.ZERO
	attack_timer -= delta

	# Deal damage at the midpoint of the animation
	if not _area_damage_dealt and attack_timer < AREA_DURATION * 0.5:
		_area_damage_dealt = true
		if is_instance_valid(_target):
			var dist: float = global_position.distance_to(_target.global_position)
			if dist < AREA_RANGE and _target.has_method("take_damage"):
				_target.take_damage(AREA_DAMAGE, global_position)

	if attack_timer <= 0.0:
		area_attack_sprite.visible = false
		current_state = AIState.CHASE
		anim_timer = 0.0
		current_anim_frame = 0
		_apply_walk_texture()


func _process_hurt(delta: float) -> void:
	hurt_timer -= delta
	velocity = velocity.move_toward(Vector2.ZERO, _speed() * 4.0 * delta)
	move_and_slide()
	if hurt_timer <= 0.0:
		current_state = AIState.CHASE


# --- State Transitions ---

func _enter_attack_melee() -> void:
	current_state  = AIState.ATTACK_MELEE
	attack_timer   = MELEE_DURATION
	melee_cooldown = MELEE_COOLDOWN
	anim_timer     = 0.0
	current_anim_frame = 0
	hitbox_shape.set_deferred("disabled", false)
	hitbox.monitoring = true
	sprite.texture = _p1_attack_tex
	sprite.hframes = P1_HFRAMES
	sprite.vframes = P1_VFRAMES
	sprite.flip_h  = facing == Direction.LEFT


func _enter_attack_area() -> void:
	current_state       = AIState.ATTACK_AREA
	attack_timer        = AREA_DURATION
	area_cooldown       = AREA_COOLDOWN
	_area_damage_dealt  = false
	anim_timer          = 0.0
	current_anim_frame  = 0
	area_attack_sprite.visible = true
	area_attack_sprite.frame   = 0


func _enter_hurt(from_pos: Vector2) -> void:
	current_state = AIState.HURT
	hurt_timer    = HURT_DURATION
	var knockback: Vector2 = from_pos.direction_to(global_position)
	velocity = knockback * _speed() * 3.0
	_flash_damage()


func _enter_death() -> void:
	_is_dead      = true
	current_state = AIState.DEATH
	velocity      = Vector2.ZERO
	hitbox_shape.set_deferred("disabled", true)
	hitbox.monitoring = false
	for child: Node in hurtbox.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", true)
	if GameManager:
		GameManager.defeat_boss()
	get_tree().create_timer(1.5).timeout.connect(queue_free)


func _enter_phase_two() -> void:
	current_phase = Phase.TWO

	# Swap arena floor
	var arena: Node = get_parent()
	var bg1: Node = arena.get_node_or_null("BossArenaPhase1")
	var bg2: Node = arena.get_node_or_null("BossArenaPhase2")
	if bg1: bg1.visible = false
	if bg2: bg2.visible = true

	_apply_walk_texture()

	# Brief white flash to signal the transition
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.4)


# --- Combat ---

func take_damage(amount: int, from_pos: Vector2) -> void:
	if _is_dead:
		return
	current_hp -= amount
	AudioManager.play_sfx("hit")

	if current_phase == Phase.ONE and current_hp <= PHASE2_THRESHOLD:
		_enter_phase_two()

	if current_hp <= 0:
		AudioManager.play_sfx("enemy_death")
		_enter_death()
	else:
		_enter_hurt(from_pos)


func _flash_damage() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)


# --- Animation ---

func _apply_walk_texture() -> void:
	var new_tex: Texture2D
	var new_flip: bool = false

	if current_phase == Phase.ONE:
		new_tex  = _p1_walk_tex
		new_flip = facing == Direction.LEFT
	else:
		match facing:
			Direction.DOWN, Direction.UP:
				new_tex  = _p2_walk_down_tex
			Direction.RIGHT:
				new_tex  = _p2_walk_right_tex
			Direction.LEFT:
				new_tex  = _p2_walk_right_tex
				new_flip = true

	# Swapping to a different texture mid-animation makes the boss "jump" to a
	# random pose from the new sheet. Restart the animation when that happens.
	var texture_changed: bool = sprite.texture != new_tex
	sprite.hframes = P1_HFRAMES
	sprite.vframes = P1_VFRAMES
	sprite.texture = new_tex
	sprite.flip_h  = new_flip

	if texture_changed:
		anim_timer = 0.0
		current_anim_frame = 0
		_update_sprite_frame()


func _update_facing(dir: Vector2) -> void:
	var prev: Direction = facing
	if absf(dir.x) > absf(dir.y):
		facing = Direction.RIGHT if dir.x > 0.0 else Direction.LEFT
	else:
		facing = Direction.DOWN if dir.y > 0.0 else Direction.UP

	# Refresh phase 2 texture when direction changes
	if current_phase == Phase.TWO and facing != prev and current_state == AIState.CHASE:
		_apply_walk_texture()


func _animate(delta: float) -> void:
	anim_timer += delta

	match current_state:
		AIState.CHASE:
			var frames: int   = P1_FRAMES_PER_DIR if current_phase == Phase.ONE else P2_WALK_FRAMES
			var cycle: float  = P1_WALK_CYCLE if current_phase == Phase.ONE else P2_WALK_CYCLE
			if anim_timer >= cycle:
				anim_timer -= cycle
			current_anim_frame = clampi(int(anim_timer / cycle * frames), 0, frames - 1)

		AIState.ATTACK_MELEE:
			var frames: int = P1_FRAMES_PER_DIR
			current_anim_frame = mini(int(anim_timer / MELEE_DURATION * frames), frames - 1)

		AIState.ATTACK_AREA:
			# Animate the area attack ring sprite; freeze main sprite
			var frame_idx: int = mini(
				int((AREA_DURATION - attack_timer) / AREA_DURATION * P2_AREA_TOTAL_FRAMES),
				P2_AREA_TOTAL_FRAMES - 1
			)
			area_attack_sprite.frame = frame_idx
			return  # main sprite stays frozen during area attack

		AIState.HURT:
			current_anim_frame = 0

		AIState.DEATH:
			current_anim_frame = mini(
				int(anim_timer / 1.0 * P1_FRAMES_PER_DIR),
				P1_FRAMES_PER_DIR - 1
			)

	_update_sprite_frame()


func _update_sprite_frame() -> void:
	# All textures now use vframes=1, so frame = column index directly
	sprite.frame = current_anim_frame


func _speed() -> float:
	return SPEED_P2 if current_phase == Phase.TWO else SPEED_P1


# --- Signal Callbacks ---

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hitbox"):
		var dmg: int = 1
		if area.has_meta("damage"):
			dmg = area.get_meta("damage") as int
		take_damage(dmg, area.global_position)
