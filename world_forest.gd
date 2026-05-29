extends "res://world_page.gd"

@export var font_path: String = "res://HYPixel11pxU-2.ttf"
@export var player_spawn_uv: Vector2 = Vector2(0.1, 0.85)
@export var effect_texture_path: String = "res://Sprite/特效.png"
@export var slime_sheet_path: String = "res://Sprite/史莱姆.jpg"
@export var bat_sheet_path: String = "res://Sprite/蝙蝠.jpg"
@export var ground_min_y_ratio: float = 0.26
@export var ground_max_y_ratio: float = 0.98
@export var ground_min_value: float = 0.14

const PLAYER_MAX_HP: int = 70
const PLAYER_ATTACK_POWER: int = 10
const ATTACK_COOLDOWN: float = 0.5
const PROJECTILE_SPEED: float = 780.0
const PROJECTILE_RADIUS: float = 10.0
const PLAYER_RADIUS: float = 20.0
const PLAYER_HIT_COOLDOWN: float = 0.5
const GEM_TARGET: int = 3
const HIT_EFFECT_DURATION: float = 0.09
const EFFECT_BLACK_CUTOFF: float = 0.07
const SHEET_COLS: int = 3
const SHEET_ROWS: int = 3
const SLIME_SCALE: float = 0.085
const BAT_SCALE: float = 0.09
const JUMP_DURATION: float = 0.28
const JUMP_HEIGHT: float = 30.0

const SLIME_COUNT: int = 10
const BAT_COUNT: int = 5
const SLIME_HP: int = 20
const SLIME_DAMAGE: int = 4
const SLIME_SPEED: float = 60.0
const BAT_HP: int = 15
const BAT_DAMAGE: int = 6
const BAT_SPEED: float = 110.0
const BAT_GEM_DROP_CHANCE: float = 0.4

var _hp: int = PLAYER_MAX_HP
var _gems_collected: int = 0
var _won: bool = false
var _shot_cooldown_left: float = 0.0
var _player_hit_cooldown_left: float = 0.0
var _aim_dir: Vector2 = Vector2.RIGHT
var _play_rect: Rect2 = Rect2()
var _bat_killed: int = 0
var _bat_drops: int = 0
var _jump_time_left: float = 0.0
var _last_valid_player_pos: Vector2 = Vector2.ZERO
var _ground_image: Image = null

var _monsters: Array[Dictionary] = []
var _projectiles: Array[Dictionary] = []
var _gems: Array[Dictionary] = []
var _effects: Array[Dictionary] = []

var _entity_layer: Node2D = null
var _projectile_layer: Node2D = null
var _effect_layer: Node2D = null
var _status_label: Label = null
var _center_label: Label = null

var _tex_slime: Texture2D = null
var _tex_bat: Texture2D = null
var _tex_gem: Texture2D = null
var _tex_ball: Texture2D = null
var _tex_hit: Texture2D = null
var _slime_frames: SpriteFrames = null
var _bat_frames: SpriteFrames = null
var _player_sprite: AnimatedSprite2D = null


func _ready() -> void:
	super._ready()
	_setup_layers()
	_setup_ui()
	_setup_textures()
	_setup_ground_mask()
	_player_sprite = _player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	_seed_rng()
	_start_round()


func _process(delta: float) -> void:
	super._process(delta)
	_update_aim_direction()
	_shot_cooldown_left = maxf(0.0, _shot_cooldown_left - delta)
	_player_hit_cooldown_left = maxf(0.0, _player_hit_cooldown_left - delta)
	_update_jump_visual(delta)
	_constrain_player_to_ground()
	_update_effects(delta)
	_update_ui()


func _physics_process(delta: float) -> void:
	if is_intro_video_playing():
		return
	if _won:
		return

	_update_projectiles(delta)
	_update_monsters(delta)
	_update_gems()


func _unhandled_input(event: InputEvent) -> void:
	if not _won and not is_intro_video_playing():
		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			if key_event.pressed and not key_event.echo and key_event.keycode == KEY_SPACE:
				_start_jump()
				get_viewport().set_input_as_handled()
				return
		if event is InputEventMouseButton:
			var mouse_event: InputEventMouseButton = event as InputEventMouseButton
			if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
				_update_aim_direction_from_mouse()
				_fire_projectile()
				get_viewport().set_input_as_handled()
				return
	super._unhandled_input(event)


func _setup_layers() -> void:
	_entity_layer = Node2D.new()
	_entity_layer.name = "ForestEntities"
	add_child(_entity_layer)

	_projectile_layer = Node2D.new()
	_projectile_layer.name = "ForestProjectiles"
	add_child(_projectile_layer)

	_effect_layer = Node2D.new()
	_effect_layer.name = "ForestEffects"
	add_child(_effect_layer)


func _setup_ui() -> void:
	_hint.text = "WASD/方向键移动  空格发射光球  Esc 返回"

	_status_label = Label.new()
	_status_label.name = "ForestStatus"
	_status_label.position = Vector2(20, 14)
	_status_label.add_theme_font_size_override("font_size", 20)
	_ui_layer.add_child(_status_label)

	_center_label = Label.new()
	_center_label.name = "ForestCenterText"
	_center_label.visible = false
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center_label.anchors_preset = Control.PRESET_FULL_RECT
	_center_label.add_theme_font_size_override("font_size", 34)
	_ui_layer.add_child(_center_label)

	var font: FontFile = load(font_path) as FontFile
	if font != null:
		_hint.add_theme_font_override("font", font)
		_status_label.add_theme_font_override("font", font)
		_center_label.add_theme_font_override("font", font)

	_center_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82, 1.0))
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86, 1.0))


func _setup_textures() -> void:
	_tex_slime = _make_rect_texture(Vector2i(14, 10), Color(0.35, 0.84, 0.42, 1.0), Color(0.18, 0.45, 0.2, 1.0))
	_tex_bat = _make_rect_texture(Vector2i(12, 8), Color(0.9, 0.25, 0.25, 1.0), Color(0.45, 0.08, 0.08, 1.0))
	_tex_gem = _make_diamond_texture(Vector2i(8, 8), Color(0.6, 0.95, 1.0, 1.0), Color(0.25, 0.52, 0.92, 1.0))
	_tex_ball = _make_rect_texture(Vector2i(8, 8), Color(0.82, 0.63, 1.0, 1.0), Color(0.48, 0.34, 0.88, 1.0))
	_tex_hit = _make_rect_texture(Vector2i(16, 16), Color(1.0, 1.0, 1.0, 0.92), Color(1.0, 0.95, 0.8, 0.95))

	var effect_image: Image = _load_effect_image()
	if effect_image != null:
		_tex_ball = _build_effect_texture(effect_image, Vector2i(34, 34), Color(1.0, 1.0, 1.0, 1.0))
		_tex_hit = _build_effect_texture(effect_image, Vector2i(18, 18), Color(1.0, 1.0, 1.0, 0.92))

	_slime_frames = _build_monster_frames_from_sheet(slime_sheet_path)
	_bat_frames = _build_monster_frames_from_sheet(bat_sheet_path)


func _setup_ground_mask() -> void:
	if _background == null or _background.texture == null:
		return
	_ground_image = _background.texture.get_image()
	if _ground_image == null:
		return
	if _ground_image.get_format() != Image.FORMAT_RGBA8:
		_ground_image = _ground_image.duplicate()
		_ground_image.convert(Image.FORMAT_RGBA8)


func _seed_rng() -> void:
	seed(Time.get_unix_time_from_system())


func _start_round() -> void:
	_clear_round_entities()
	_hp = PLAYER_MAX_HP
	_gems_collected = 0
	_won = false
	_shot_cooldown_left = 0.0
	_player_hit_cooldown_left = 0.0
	_bat_killed = 0
	_bat_drops = 0
	_center_label.visible = false
	_place_player_at_spawn()
	_last_valid_player_pos = _player.global_position
	if _player != null:
		_player.refresh_movement_bounds()
	_spawn_monsters(SLIME_COUNT, BAT_COUNT)
	_update_ui()


func _place_player_at_center() -> void:
	_place_player_at_spawn()


func _place_player_at_spawn() -> void:
	_recompute_play_rect()
	if _player == null:
		return
	var spawn_pos: Vector2 = Vector2(
		_play_rect.position.x + _play_rect.size.x * player_spawn_uv.x,
		_play_rect.position.y + _play_rect.size.y * player_spawn_uv.y
	)
	_player.global_position = spawn_pos
	_last_valid_player_pos = spawn_pos


func _on_viewport_size_changed() -> void:
	super._on_viewport_size_changed()
	_recompute_play_rect()
	_place_player_at_spawn()
	if _player != null:
		_player.refresh_movement_bounds()


func _constrain_player_to_ground() -> void:
	if _player == null:
		return
	if _is_walkable_world_pos(_player.global_position):
		_last_valid_player_pos = _player.global_position
		return
	_player.global_position = _last_valid_player_pos


func _is_walkable_world_pos(world_pos: Vector2) -> bool:
	if _ground_image == null or _background == null or _background.texture == null:
		return true

	var tex_size: Vector2 = _background.texture.get_size()
	var local: Vector2 = (world_pos - _background.global_position) / _background.scale + tex_size * 0.5
	var x: int = int(round(local.x))
	var y: int = int(round(local.y))
	if x < 0 or y < 0 or x >= int(tex_size.x) or y >= int(tex_size.y):
		return false

	var y_ratio: float = float(y) / maxf(1.0, tex_size.y)
	if y_ratio < ground_min_y_ratio or y_ratio > ground_max_y_ratio:
		return false

	var c: Color = _ground_image.get_pixel(x, y)
	if c.v < ground_min_value:
		return false
	return true


func _recompute_play_rect() -> void:
	if _background == null or _background.texture == null:
		_play_rect = Rect2(Vector2(-640, -360), Vector2(1280, 720))
		return
	var tex_size: Vector2 = _background.texture.get_size()
	var display_size: Vector2 = tex_size * _background.scale
	_play_rect = Rect2(_background.global_position - display_size * 0.5, display_size)


func _spawn_monsters(slimes: int, bats: int) -> void:
	for _i in range(slimes):
		_spawn_monster("slime")
	for _j in range(bats):
		_spawn_monster("bat")


func _spawn_monster(kind: String) -> void:
	var node: Node2D = _create_monster_visual(kind)
	_entity_layer.add_child(node)

	var hp: int = SLIME_HP if kind == "slime" else BAT_HP
	var damage: int = SLIME_DAMAGE if kind == "slime" else BAT_DAMAGE
	var speed: float = SLIME_SPEED if kind == "slime" else BAT_SPEED
	var radius: float = 16.0 if kind == "slime" else 13.0
	var spawn_pos: Vector2 = _random_spawn_position(120.0)
	node.global_position = spawn_pos

	var monster: Dictionary = {
		"kind": kind,
		"node": node,
		"hp": hp,
		"damage": damage,
		"speed": speed,
		"radius": radius,
		"bob_t": randf() * TAU,
		"face_right": true,
	}
	_monsters.append(monster)


func _random_spawn_position(min_player_distance: float) -> Vector2:
	_recompute_play_rect()
	if _player == null:
		return _play_rect.get_center()

	var margin: float = 42.0
	var min_x: float = _play_rect.position.x + margin
	var max_x: float = _play_rect.end.x - margin
	var min_y: float = _play_rect.position.y + margin
	var max_y: float = _play_rect.end.y - margin

	for _attempt in range(80):
		var pos: Vector2 = Vector2(
			randf_range(min_x, max_x),
			randf_range(min_y, max_y)
		)
		if pos.distance_to(_player.global_position) < min_player_distance:
			continue
		return pos
	return _play_rect.get_center()


func _update_aim_direction() -> void:
	var x: int = 0
	var y: int = 0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		x += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		x -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		y += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		y -= 1

	var dir: Vector2 = Vector2(x, y)
	if dir.length_squared() > 0.0:
		_aim_dir = dir.normalized()


func _update_aim_direction_from_mouse() -> void:
	if _player == null:
		return
	var dir: Vector2 = get_global_mouse_position() - _player.global_position
	if dir.length_squared() <= 0.001:
		return
	_aim_dir = dir.normalized()


func _start_jump() -> void:
	if _jump_time_left > 0.0:
		return
	_jump_time_left = JUMP_DURATION


func _update_jump_visual(delta: float) -> void:
	if _player_sprite == null:
		return
	_jump_time_left = maxf(0.0, _jump_time_left - delta)
	if _jump_time_left <= 0.0:
		_player_sprite.position.y = -36.656067
		return
	var t: float = 1.0 - (_jump_time_left / JUMP_DURATION)
	var hop: float = sin(t * PI) * JUMP_HEIGHT
	_player_sprite.position.y = -36.656067 - hop


func _fire_projectile() -> void:
	if _player == null:
		return
	if _shot_cooldown_left > 0.0:
		return

	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = _tex_ball
	sprite.centered = true
	sprite.global_position = _player.global_position + _aim_dir * 26.0
	_projectile_layer.add_child(sprite)

	var projectile: Dictionary = {
		"node": sprite,
		"dir": _aim_dir,
		"life": 1.4,
	}
	_projectiles.append(projectile)
	_shot_cooldown_left = ATTACK_COOLDOWN


func _update_projectiles(delta: float) -> void:
	var next: Array[Dictionary] = []
	for projectile in _projectiles:
		var node: Sprite2D = projectile["node"] as Sprite2D
		if node == null:
			continue

		var life_left: float = projectile["life"] as float
		var dir: Vector2 = projectile["dir"] as Vector2
		life_left -= delta
		if life_left <= 0.0:
			node.queue_free()
			continue

		node.global_position += dir * PROJECTILE_SPEED * delta
		if not _point_in_rect(node.global_position, _play_rect.grow(-12.0)):
			node.queue_free()
			continue

		var hit_index: int = _find_projectile_hit_monster(node.global_position)
		if hit_index >= 0:
			_damage_monster(hit_index, PLAYER_ATTACK_POWER)
			_spawn_hit_effect(node.global_position)
			node.queue_free()
			continue

		projectile["life"] = life_left
		next.append(projectile)
	_projectiles = next


func _find_projectile_hit_monster(pos: Vector2) -> int:
	for i in range(_monsters.size()):
		var monster: Dictionary = _monsters[i]
		var node: Node2D = monster["node"] as Node2D
		if node == null:
			continue
		var radius: float = monster["radius"] as float
		if pos.distance_to(node.global_position) <= radius + PROJECTILE_RADIUS:
			return i
	return -1


func _damage_monster(index: int, amount: int) -> void:
	if index < 0 or index >= _monsters.size():
		return

	var monster: Dictionary = _monsters[index]
	var hp: int = int(monster["hp"])
	hp -= amount
	monster["hp"] = hp
	_monsters[index] = monster

	if hp > 0:
		return

	var node: Node2D = monster["node"] as Node2D
	var pos: Vector2 = node.global_position if node != null else Vector2.ZERO
	var kind: String = monster["kind"] as String
	if node != null:
		node.queue_free()

	if kind == "bat":
		_bat_killed += 1
		var drops_needed: int = GEM_TARGET - _bat_drops
		var bats_left_after_this: int = BAT_COUNT - _bat_killed
		var force_drop: bool = drops_needed > 0 and drops_needed >= bats_left_after_this + 1
		var roll_drop: bool = randf() < BAT_GEM_DROP_CHANCE
		if force_drop or roll_drop:
			_spawn_gem(pos)
			_bat_drops += 1

	_monsters.remove_at(index)
	_check_win_condition()


func _update_monsters(delta: float) -> void:
	if _player == null:
		return

	var highest_contact_damage: int = 0
	for i in range(_monsters.size()):
		var monster: Dictionary = _monsters[i]
		var node: Node2D = monster["node"] as Node2D
		if node == null:
			continue
		var to_player: Vector2 = _player.global_position - node.global_position
		var dist: float = to_player.length()
		if dist > 0.01:
			var velocity: Vector2 = to_player / dist * (monster["speed"] as float)
			if monster["kind"] == "bat":
				var bob_t: float = monster["bob_t"] as float
				bob_t += delta * 7.0
				monster["bob_t"] = bob_t
				var side: Vector2 = Vector2(-to_player.y, to_player.x).normalized()
				velocity += side * sin(bob_t) * 25.0
				if absf(velocity.x) > 4.0:
					monster["face_right"] = velocity.x > 0.0
				_apply_bat_facing(node, bool(monster["face_right"]))
			node.global_position += velocity * delta
			node.global_position = _clamp_to_rect(node.global_position, _play_rect.grow(-10.0))

		var radius: float = monster["radius"] as float
		if node.global_position.distance_to(_player.global_position) <= radius + PLAYER_RADIUS:
			highest_contact_damage = maxi(highest_contact_damage, int(monster["damage"]))
		_monsters[i] = monster

	if highest_contact_damage > 0 and _player_hit_cooldown_left <= 0.0:
		_hp -= highest_contact_damage
		_spawn_hit_effect(_player.global_position)
		_player_hit_cooldown_left = PLAYER_HIT_COOLDOWN
		if _hp <= 0:
			_start_round()


func _apply_bat_facing(node: Node2D, face_right: bool) -> void:
	var anim: AnimatedSprite2D = node as AnimatedSprite2D
	if anim == null:
		return
	# 套图默认朝右，向左移动时翻转。
	anim.flip_h = not face_right


func _spawn_gem(pos: Vector2) -> void:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = _tex_gem
	sprite.centered = true
	sprite.global_position = pos
	_entity_layer.add_child(sprite)
	_gems.append({
		"node": sprite,
		"radius": 12.0,
	})


func _update_gems() -> void:
	if _player == null:
		return
	var next: Array[Dictionary] = []
	for gem in _gems:
		var node: Sprite2D = gem["node"] as Sprite2D
		if node == null:
			continue
		var radius: float = gem["radius"] as float
		if node.global_position.distance_to(_player.global_position) <= radius + PLAYER_RADIUS:
			node.queue_free()
			_gems_collected += 1
		else:
			next.append(gem)
	_gems = next
	_check_win_condition()


func _trigger_win() -> void:
	_won = true
	_center_label.visible = true
	_center_label.text = "通关成功！"


func _check_win_condition() -> void:
	if _won:
		return
	if _gems_collected < GEM_TARGET:
		return
	if not _monsters.is_empty():
		return
	_trigger_win()


func _spawn_hit_effect(pos: Vector2) -> void:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = _tex_hit
	sprite.centered = true
	sprite.global_position = pos
	_effect_layer.add_child(sprite)
	_effects.append({
		"node": sprite,
		"life": HIT_EFFECT_DURATION,
	})


func _update_effects(delta: float) -> void:
	var next: Array[Dictionary] = []
	for fx in _effects:
		var node: Sprite2D = fx["node"] as Sprite2D
		if node == null:
			continue
		var life_left: float = fx["life"] as float
		life_left -= delta
		if life_left <= 0.0:
			node.queue_free()
			continue
		var t: float = clampf(life_left / HIT_EFFECT_DURATION, 0.0, 1.0)
		if t > 0.5:
			node.modulate = Color(1.0, 1.0, 1.0, 0.95)
		else:
			node.modulate = Color(1.0, 1.0, 1.0, 0.55)
		fx["life"] = life_left
		next.append(fx)
	_effects = next


func _update_ui() -> void:
	var enemy_count: int = _monsters.size()
	_status_label.text = "HP:%d/50   宝石:%d/3   敌人:%d" % [_hp, _gems_collected, enemy_count]
	if _won:
		_hint.text = "通关成功！Esc 返回世界选择"
	elif _gems_collected >= GEM_TARGET:
		_hint.text = "宝石已集齐，清理剩余敌人！Esc 返回"
	else:
		_hint.text = "WASD/方向键移动  左键开火  空格跳跃  Esc 返回"


func _clear_round_entities() -> void:
	for item in _monsters:
		var node: Node = item.get("node", null) as Node
		if node != null:
			node.queue_free()
	for item in _projectiles:
		var node: Node = item.get("node", null) as Node
		if node != null:
			node.queue_free()
	for item in _gems:
		var node: Node = item.get("node", null) as Node
		if node != null:
			node.queue_free()
	for item in _effects:
		var node: Node = item.get("node", null) as Node
		if node != null:
			node.queue_free()
	_monsters.clear()
	_projectiles.clear()
	_gems.clear()
	_effects.clear()


func _point_in_rect(point: Vector2, rect: Rect2) -> bool:
	return (
		point.x >= rect.position.x
		and point.y >= rect.position.y
		and point.x <= rect.end.x
		and point.y <= rect.end.y
	)


func _clamp_to_rect(point: Vector2, rect: Rect2) -> Vector2:
	return Vector2(
		clampf(point.x, rect.position.x, rect.end.x),
		clampf(point.y, rect.position.y, rect.end.y)
	)


func _make_rect_texture(size: Vector2i, fill: Color, edge: Color) -> Texture2D:
	var image: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(fill)
	for x in range(size.x):
		image.set_pixel(x, 0, edge)
		image.set_pixel(x, size.y - 1, edge)
	for y in range(size.y):
		image.set_pixel(0, y, edge)
		image.set_pixel(size.x - 1, y, edge)
	return ImageTexture.create_from_image(image)


func _make_diamond_texture(size: Vector2i, fill: Color, edge: Color) -> Texture2D:
	var image: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var cx: int = size.x / 2
	var cy: int = size.y / 2
	for y in range(size.y):
		for x in range(size.x):
			var dx: int = abs(x - cx)
			var dy: int = abs(y - cy)
			if dx + dy <= cy:
				image.set_pixel(x, y, fill)
	for x in range(size.x):
		for y in range(size.y):
			if image.get_pixel(x, y).a <= 0.0:
				continue
			var border: bool = false
			for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + offset.x
				var ny: int = y + offset.y
				if nx < 0 or ny < 0 or nx >= size.x or ny >= size.y:
					border = true
					break
				if image.get_pixel(nx, ny).a <= 0.0:
					border = true
					break
			if border:
				image.set_pixel(x, y, edge)
	return ImageTexture.create_from_image(image)


func _create_monster_visual(kind: String) -> Node2D:
	var anim: AnimatedSprite2D = AnimatedSprite2D.new()
	anim.centered = true
	anim.sprite_frames = _slime_frames if kind == "slime" else _bat_frames
	anim.scale = Vector2.ONE * (SLIME_SCALE if kind == "slime" else BAT_SCALE)
	if anim.sprite_frames != null and anim.sprite_frames.has_animation(&"idle"):
		anim.play(&"idle")
		return anim

	# Fallback: if sheet failed to load, keep simple block monster.
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = _tex_slime if kind == "slime" else _tex_bat
	sprite.centered = true
	sprite.scale = Vector2.ONE * 1.0
	return sprite


func _build_monster_frames_from_sheet(path: String) -> SpriteFrames:
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		return null

	var image: Image = texture.get_image()
	if image == null:
		return null
	if image.get_format() != Image.FORMAT_RGBA8:
		image = image.duplicate()
		image.convert(Image.FORMAT_RGBA8)

	var cell_w: int = image.get_width() / SHEET_COLS
	var cell_h: int = image.get_height() / SHEET_ROWS
	if cell_w <= 0 or cell_h <= 0:
		return null

	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation(&"idle")
	frames.set_animation_speed(&"idle", 8.0)
	frames.set_animation_loop(&"idle", true)

	# 使用第一行 3 帧作为循环，避免把死亡/特效帧当作常驻动画。
	for col in range(SHEET_COLS):
		var rect: Rect2i = Rect2i(col * cell_w, 0, cell_w, cell_h)
		var frame: Image = image.get_region(rect)
		_remove_white_background(frame)
		frames.add_frame(&"idle", ImageTexture.create_from_image(frame))
	return frames


func _remove_white_background(image: Image) -> void:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var c: Color = image.get_pixel(x, y)
			if c.r > 0.92 and c.g > 0.92 and c.b > 0.92:
				image.set_pixel(x, y, Color(0, 0, 0, 0))


func _load_effect_image() -> Image:
	var texture: Texture2D = load(effect_texture_path) as Texture2D
	if texture == null:
		return null
	var image: Image = texture.get_image()
	if image == null:
		return null
	if image.get_format() != Image.FORMAT_RGBA8:
		image = image.duplicate()
		image.convert(Image.FORMAT_RGBA8)

	# 黑底转透明，方便直接做光球与受击特效。
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var c: Color = image.get_pixel(x, y)
			if c.r <= EFFECT_BLACK_CUTOFF and c.g <= EFFECT_BLACK_CUTOFF and c.b <= EFFECT_BLACK_CUTOFF:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
	return image


func _build_effect_texture(source: Image, target_size: Vector2i, tint: Color) -> Texture2D:
	var rect: Rect2i = source.get_used_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		return _make_rect_texture(target_size, Color(0.82, 0.63, 1.0, 1.0), Color(0.48, 0.34, 0.88, 1.0))
	var cropped: Image = source.get_region(rect)
	cropped.resize(target_size.x, target_size.y, Image.INTERPOLATE_NEAREST)
	for y in range(cropped.get_height()):
		for x in range(cropped.get_width()):
			var c: Color = cropped.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			cropped.set_pixel(x, y, Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a * tint.a))
	return ImageTexture.create_from_image(cropped)
