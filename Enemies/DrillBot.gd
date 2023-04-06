extends CharacterBody2D

var SPEED = 20.0
var GRAVITY = 100.0
var direction = 1

func _ready():
	get_node("AnimationPlayer").play("moving")

func _physics_process(_delta):
	if direction == 1:
		get_node("Sprite2D").flip_h = false
	else:
		get_node("Sprite2D").flip_h = true

	if !is_on_floor():
		velocity.y += GRAVITY
	else:
		for child in get_children():
			if child.is_in_group("raycast"):
				child.enabled = true
				child.force_raycast_update()
				if !child.is_colliding():
					turn()
					break
		velocity.y = 0
	velocity.x = SPEED * direction
	move_and_slide()

func turn():
	direction *= -1
