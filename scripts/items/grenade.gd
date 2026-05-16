class_name Grenade
extends Node2D
## Throwable stun grenade. Flies in a direction, then explodes after TRAVEL_TIME
## seconds, dealing damage and knockback to all enemies within EXPLOSION_RADIUS.

const TRAVEL_TIME: float = 0.8
const EXPLOSION_RADIUS: float = 48.0
const EXPLOSION_DAMAGE: int = 1
const THROW_SPEED: float = 120.0

const GRENADE_TEXTURE: String = "res://assets/rpg/sprites/items/grenade.png/granada1.png"
const EXPLOSION_TEXTURE: String = "res://assets/rpg/sprites/items/grenade.png/efeito.png"

@export var direction: Vector2 = Vector2.RIGHT
@export var grenade_scale: float = 0.3
@export var explosion_scale: float = 1.5

var _travel_timer: float = 0.0
var _exploding: bool = false
var _explosion_alpha: float = 1.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	sprite.texture = load(GRENADE_TEXTURE)
	sprite.scale = Vector2(grenade_scale, grenade_scale)


func _process(delta: float) -> void:
	if _exploding:
		_explosion_alpha -= delta / 0.4
		_explosion_alpha = maxf(_explosion_alpha, 0.0)
		sprite.modulate.a = _explosion_alpha
		return

	global_position += direction * THROW_SPEED * delta
	_travel_timer += delta
	if _travel_timer >= TRAVEL_TIME:
		_explode()


func _explode() -> void:
	_exploding = true
	sprite.texture = load(EXPLOSION_TEXTURE)
	sprite.scale = Vector2(explosion_scale, explosion_scale)
	sprite.modulate = Color.WHITE

	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for enemy: Node in enemies:
		if enemy is Node2D:
			var dist: float = (enemy as Node2D).global_position.distance_to(global_position)
			if dist <= EXPLOSION_RADIUS and enemy.has_method("take_damage"):
				enemy.take_damage(EXPLOSION_DAMAGE, global_position)

	AudioManager.play_sfx("hit")
	get_tree().create_timer(0.4).timeout.connect(queue_free)
