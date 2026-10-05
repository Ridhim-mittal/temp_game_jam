extends CharacterBody2D
## Shared base for the Margins monsters (scribble, crumple, crossed-out,
## smudge, eraser, inkwell). Handles the body, the comic outline, health,
## knockback, death, and the "am I standing in light?" question.
##
## A monster script extends this, calls setup() in _ready(), and overrides:
##   _tick(delta)                 behaviour, called every physics frame
##   paint(c)                     draw the art on `c` (origin = feet, faces +X)
##   _blocks(hit_dir, from_pos)   return true to shrug off a hit
##
## Light: any node in the group "light" with a `lights(point) -> bool` method
## counts (see scripts/world/light_zone.gd). When the real lamp / ember
## exists, add it to that group and every monster reacts to it.

const ComicText = preload("res://scripts/effects/comic_text.gd")
const OutlineShader = preload("res://shaders/character_outline.gdshader")
const ArtScript = preload("res://scripts/enemies/enemy_art.gd")
const INK := Color(0.05, 0.03, 0.1)
const PALE := Color(0.98, 0.96, 0.9)
const DANGER := Color(1.0, 0.86, 0.2)

## Half ink bottles taken from the player on contact. 0 = this monster's default
## (damage_default(), overridden per monster).
@export var contact_damage := 0.0  # half ink bottles (0 = damage_default())
@export var gravity := 2000.0
@export var knockback_speed := 260.0

var health := 1
var dead := false
var facing := -1
var time := 0.0
var stun := 0.0
var art: Node2D
var outline: CanvasGroup
var body_size := Vector2(40, 40)
var _player: Node2D


## Damage this monster deals; read by player.gd.
func get_damage() -> float:
	return contact_damage if contact_damage > 0.0 else damage_default()


## Per-monster default damage (HP). Override in the monster script.
func damage_default() -> float:
	return 1.0  # half a bottle


func setup(size: Vector2, hp: int) -> void:
	body_size = size
	health = hp
	collision_layer = 4  # enemy
	collision_mask = 1 | 16  # world + sketch platforms / shadow ink (lights.gd)
	add_to_group("enemy")
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	add_child(cs)
	outline = CanvasGroup.new()
	var mat := ShaderMaterial.new()
	mat.shader = OutlineShader
	mat.set_shader_parameter("pop_color", DANGER)
	mat.set_shader_parameter("ink_width", 2.0)
	mat.set_shader_parameter("pop_width", 5.0)
	outline.material = mat
	outline.fit_margin = 16.0
	outline.position = Vector2(0, size.y * 0.5)  # art origin at the feet
	add_child(outline)
	art = Node2D.new()
	art.set_script(ArtScript)
	art.painter = self
	outline.add_child(art)
	time = randf() * 10.0


func _physics_process(delta: float) -> void:
	if dead:
		return
	time += delta
	_player = get_tree().get_first_node_in_group("player")
	if _player and _player.dead:
		_player = null
	if stun > 0.0:
		stun -= delta
		velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
		_fall(delta)
		move_and_slide()
	else:
		_tick(delta)
	art.scale.x = facing


func _tick(_delta: float) -> void:
	pass


func paint(_c: CanvasItem) -> void:
	pass


func _blocks(_hit_dir: Vector2, _from_pos: Vector2) -> bool:
	return false


func _on_hurt() -> void:
	pass


# ----------------------------------------------------------------- helpers

func _fall(delta: float) -> void:
	velocity.y = minf(velocity.y + gravity * delta, 900.0)


## Vector to the player, or ZERO when there is none.
func to_player() -> Vector2:
	return _player.global_position - global_position if _player else Vector2.ZERO


func face_player() -> void:
	var dx := to_player().x
	if absf(dx) > 4.0:
		facing = 1 if dx > 0.0 else -1


func light_at(point: Vector2) -> Node2D:
	for l in get_tree().get_nodes_in_group("light"):
		if l.has_method("lights") and l.lights(point):
			return l
	return null


func is_lit() -> bool:
	return light_at(global_position) != null


## Harmful monsters are in the "enemy" group; the player's hurtbox checks it.
func set_harmful(on: bool) -> void:
	if on and not dead:
		add_to_group("enemy")
	elif is_in_group("enemy"):
		remove_from_group("enemy")


func hitting_wall() -> bool:
	return is_on_wall() and get_wall_normal().x * facing < 0.0


func at_ledge() -> bool:
	var from := global_position + Vector2(facing * (body_size.x * 0.5 + 4.0), 0.0)
	var to := from + Vector2(0.0, body_size.y * 0.5 + 16.0)
	var query := PhysicsRayQueryParameters2D.create(from, to, 1, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func pop(text: String, color := DANGER, offset := Vector2(0, -50), size := 26) -> void:
	var p := ComicText.new()
	p.text = text
	p.color = color
	p.font_size = size
	p.position = global_position + offset
	get_tree().current_scene.add_child(p)


# ------------------------------------------------------------------ damage

## Stunned for at least `seconds` (the weapons' specials: player.gd).
func stun_for(seconds: float) -> void:
	if not dead:
		stun = maxf(stun, seconds)


func take_hit(damage: int, hit_dir: Vector2, from_pos: Vector2) -> void:
	if dead:
		return
	if _blocks(hit_dir, from_pos):
		return
	health -= damage
	Sfx.play("boss_hit" if is_in_group("boss") else "ink_enemy_hit", -3.0)
	art.modulate = Color(4, 4, 4)
	create_tween().tween_property(art, "modulate", Color.WHITE, 0.15)
	var kx := signf(global_position.x - from_pos.x)
	if kx == 0.0:
		kx = 1.0
	velocity.x = kx * knockback_speed * (0.5 if hit_dir.y > 0.0 else 1.0)
	velocity.y = -120.0 if hit_dir.y <= 0.0 else 0.0
	stun = 0.25
	_on_hurt()
	if health <= 0:
		_die(kx)


func _die(kx: float) -> void:
	dead = true
	Sfx.play("ink_splat")
	set_harmful(false)
	set_deferred("collision_layer", 0)
	var t := create_tween().set_parallel()
	t.tween_property(self, "rotation", kx * 2.5, 0.4)
	t.tween_property(self, "position", position + Vector2(kx * 60.0, -50.0), 0.4).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 0.0, 0.4)
	t.chain().tween_callback(queue_free)


# ----------------------------------------------------------- draw helpers

static func ell(center: Vector2, rx: float, ry: float, n := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(center + Vector2(cos(TAU * i / n) * rx, sin(TAU * i / n) * ry))
	return pts


static func pts(a: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, a.size(), 2):
		out.append(Vector2(a[i], a[i + 1]))
	return out


func draw_eye(c: CanvasItem, at: Vector2, r: float, look := Vector2(0.3, 0.0)) -> void:
	c.draw_circle(at, r + 1.2, INK)
	c.draw_circle(at, r, PALE)
	c.draw_circle(at + look.limit_length(1.0) * r * 0.45, r * 0.45, INK)
