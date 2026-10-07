extends CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var edge_check: RayCast2D = $EdgeCheck

const SPEED = 60.0
var direction := 1.0   # 1 = right, -1 = left


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	# --- Turn around if hitting a wall OR about to walk off an edge ---
	if is_on_wall() or not edge_check.is_colliding():
		direction *= -1.0
		animated_sprite_2d.flip_h = direction < 0
		edge_check.position.x *= -1.0   # flip the raycast to the other side too

	velocity.x = direction * SPEED
	move_and_slide()
