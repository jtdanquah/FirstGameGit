extends CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var jump_smoke: AnimatedSprite2D = $Jsmoke

func _ready() -> void:
	jump_smoke.visible = false
	
const SPEED = 140
const JUMP_VELOCITY = -400
const JUMP_CUT_MULTIPLIER = 0.15
const ACCELERATION = 5000
const FRICTION = 5500

const JUMP_BUFFER_TIME = 0.12
var jump_buffer_timer := 0.0
const COYOTE_TIME = 0.12
var coyote_timer := 0.0

const LANDING_TIME = 0.0

const DASH_SPEED = 320.0
const DASH_DURATION = 0.3
var dash_direction := 1.0
const DASH_COOLDOWN = 0.8
var dash_cooldown_timer := 0.0


enum State { IDLE, RUN, JUMP, FALL, LANDING, DASH }
var state: State = State.IDLE
var state_timer := 0.0


func _physics_process(delta: float) -> void:
	const FALL_GRAVITY_MULT = 1.5

	if not is_on_floor() and state != State.DASH:
		if velocity.y > 0.0:
			velocity += get_gravity() * FALL_GRAVITY_MULT * delta
		else:
			velocity += get_gravity() * delta

	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer -= delta

	if Input.is_action_just_pressed("Jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer -= delta

	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta

	var direction := Input.get_axis("Left", "Right")
	if Input.is_action_just_pressed("Dash") and state != State.DASH and dash_cooldown_timer <= 0.0:
		dash_direction = -1.0 if animated_sprite_2d.flip_h else 1.0
		_change_state(State.DASH)
		dash_cooldown_timer = DASH_COOLDOWN

	match state:
		State.IDLE:
			_process_idle(direction, delta)
		State.RUN:
			_process_run(direction, delta)
		State.JUMP:
			_process_jump(direction, delta)
		State.FALL:
			_process_fall(direction, delta)
		State.LANDING:
			_process_landing(direction, delta)
		State.DASH:
			_process_dash(delta)

	move_and_slide()
	
	if $ShadowRay. is_colliding():
		$shadow.global_position.y = $ShadowRay.get_collision_point().y
		
		var height_ratio: float = clamp(1.0 - $shadow.position.y / 120.0, 0.2, 1.0)
		$shadow.modulate.a = height_ratio
		
		var shadow_scale: float = max(height_ratio, 0.8)
		$shadow.scale = Vector2(shadow_scale, shadow_scale)


func _change_state(new_state: State) -> void:
	var previous_state := state
	state = new_state
	if new_state != State.DASH:
		animated_sprite_2d.rotation_degrees = 0.0

	# Only fade back in if we were just dashing
	if previous_state == State.DASH and new_state != State.DASH:
		var fade_in := create_tween()
		fade_in.tween_property(animated_sprite_2d, "modulate:a", 1.0, 0.35)

	match new_state:
		State.IDLE:
			animated_sprite_2d.animation = "idle"
		State.RUN:
			animated_sprite_2d.animation = "run"
		State.JUMP:
			animated_sprite_2d.animation = "jump_up"
		State.FALL:
			animated_sprite_2d.animation = "jump_down"
		State.LANDING:
			animated_sprite_2d.animation = "charge"
			state_timer = LANDING_TIME
		State.DASH:
			animated_sprite_2d.animation = "jump_up"
			animated_sprite_2d.rotation_degrees = 15.0 * dash_direction
			state_timer = DASH_DURATION
			velocity.y = 0.0
			velocity.x = dash_direction * DASH_SPEED
			_stretch_sprite()
			var fade_out := create_tween()
			fade_out.tween_property(animated_sprite_2d, "modulate:a", 0.2, 0.1)


func _process_idle(direction: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
	if direction:
		animated_sprite_2d.flip_h = direction < 0
		_change_state(State.RUN)
	elif jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		_start_jump()
	elif not is_on_floor():
		_change_state(State.FALL)


func _process_run(direction: float, delta: float) -> void:
	if direction:
		velocity.x = move_toward(velocity.x, direction * SPEED, ACCELERATION * delta)
		animated_sprite_2d.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		_change_state(State.IDLE)

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		_start_jump()
	elif not is_on_floor():
		_change_state(State.FALL)


func _process_jump(direction: float, delta: float) -> void:
	if direction:
		velocity.x = move_toward(velocity.x, direction * SPEED, ACCELERATION * delta)
		animated_sprite_2d.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

	if Input.is_action_just_released("Jump") and velocity.y < 0.0:
		velocity.y *= JUMP_CUT_MULTIPLIER

	if velocity.y >= 0.0:
		_change_state(State.FALL)


func _process_fall(direction: float, delta: float) -> void:
	if direction:
		velocity.x = move_toward(velocity.x, direction * SPEED, ACCELERATION * delta)
		animated_sprite_2d.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

	if is_on_floor():
		_change_state(State.LANDING)
	elif jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		_start_jump()


func _process_landing(direction: float, delta: float) -> void:
	if direction:
		velocity.x = move_toward(velocity.x, direction * SPEED, ACCELERATION * delta)
		animated_sprite_2d.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

	state_timer -= delta
	if state_timer <= 0.0:
		_change_state(State.IDLE)
	elif direction:
		_change_state(State.RUN)
	elif jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		_start_jump()


func _start_jump() -> void:
	velocity.y = JUMP_VELOCITY
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	_change_state(State.JUMP)

	var smoke := jump_smoke.duplicate()
	smoke.visible = true
	smoke.flip_h = animated_sprite_2d.flip_h
	get_parent().add_child(smoke)
	smoke.global_position = jump_smoke.global_position
	smoke.play("Jsmoke")
	smoke.animation_finished.connect(smoke.queue_free)


func _process_dash(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		_change_state(State.FALL if not is_on_floor() else State.IDLE)


func _stretch_sprite() -> void:
	animated_sprite_2d.scale = Vector2(1.1, 0.9)
	var tween := create_tween()
	tween.tween_property(animated_sprite_2d, "scale", Vector2(1.0, 1.0), 0.1)
