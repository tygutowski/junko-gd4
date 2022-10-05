extends CharacterBody2D

# This is the emulated dimensions of the screen.
# The game natively runs 1920x1080, but is scaled down to 480x270.
var screen_width = 480.0
var screen_height = 270.0

const MAX_RUN = 100
const RUN_ACCELERATION = 15

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
const MAX_FALL = 275
const JUMP_VELOCITY = -275

var coyote_frame_counter = 0

var max_jumps = 2
var jumps_remaining := max_jumps

var max_health = 4
var health := max_health

var damage = 4

var facing_direction = 1
var walking_direction = 0

var camera_offset = Vector2.ZERO
var camera_in_animation = true
var current_room = null

var currently_attacking = false


@onready var world = get_tree().get_first_node_in_group("world")

@onready var animation_tree = get_node("AnimationTree")
@onready var sprite = get_node("Sprite2d")
@onready var room_point = get_node("RoomPoint")

@onready var animation_camera = world.get_node("AnimationCamera2d")
@onready var player_camera = world.get_node("PlayerCamera2d")

@onready var sword_right = get_node("SwordRight")
@onready var sword_left = get_node("SwordLeft")
@onready var sword_down = get_node("SwordDown")

func set_animation(animation_name, value):
	animation_tree.set("parameters/" + animation_name + "/current", value)

func _ready():
	set_animation("alive_or_dead", 0) # alive
	set_animation("undamaged_or_damaged", 0) # undamaged
	set_animation("ground_or_air", 0) # ground
	set_animation("idle_or_running", 0) # idle
	set_animation("attacking_or_not_attacking", 1)
	sword_right.get_node("Sprite2d").visible = false
	sword_left.get_node("Sprite2d").visible = false
	sword_down.get_node("Sprite2d").visible = false
	sword_right.get_node("SwordArea2d/CollisionShape2d").disabled = true
	sword_left.get_node("SwordArea2d/CollisionShape2d").disabled = true
	sword_down.get_node("SwordArea2d/CollisionShape2d").disabled = true

func _physics_process(delta):
	print(player_camera.global_position)
	camera_follow_player()
	manage_movement(delta)
	manage_animations()
	frame_passes()
	position.x = round(position.x)
	position.y = round(position.y)
	
	if Input.is_action_just_pressed("close"):
		get_tree().quit()

func manage_movement(delta):
	# Vertical Movement
	if is_on_floor():
		set_animation("ground_or_air", 0) # ground
		jumps_remaining = max_jumps
	elif !is_on_floor():
		set_animation("ground_or_air", 1) # air
		# Jumping upward
		if velocity.y <= 0:
			set_animation("jumping_or_falling", 0) # jumping
		# Falling downward
		elif velocity.y > 0: 
			set_animation("jumping_or_falling", 1) # falling
		velocity.y += gravity * delta
	
	# Horizontal Movement
	velocity.x = move_toward(velocity.x, walking_direction * MAX_RUN, RUN_ACCELERATION)
	if velocity.x > 0:
		set_animation("idle_or_running", 1)
	elif velocity.x < 0:
		set_animation("idle_or_running", 1)
	elif velocity.x == 0:
		set_animation("idle_or_running", 0)
	
	walking_direction = Input.get_axis("left", "right")
	
	if Input.is_action_just_pressed("jump") && jumps_remaining > 0:
		velocity.y = JUMP_VELOCITY
		jumps_remaining -= 1
		
	if Input.is_action_just_pressed("attack") && !currently_attacking:
		set_animation("attacking_or_not_attacking", 0)
		if Input.is_action_pressed("down") && !is_on_floor():
			set_animation("attack_direction", 2)
		elif facing_direction == 1:
			set_animation("attack_direction", 0)
		elif facing_direction == -1:
			set_animation("attack_direction", 1)
	
	move_and_slide()


func frame_passes():
	pass

func manage_animations():
	if (walking_direction > 0 && sprite.flip_h != false):
		facing_direction = 1
		sprite.flip_h = false
	elif (walking_direction < 0 && sprite.flip_h != true):
		facing_direction = -1
		sprite.flip_h = true

#####################################################################
## Camera Manager
## This determines what happens when the player walks into a new Room.
## There are two Camera2Ds, PlayerCamera, and RoomTransitionCamera
######################################################################

func camera_follow_player():
	if(!camera_in_animation):
		player_camera.global_position = global_position + camera_offset # pans from player to offset
		player_camera.global_position.x = round(global_position.x)
		player_camera.global_position.y = round(global_position.y)

func get_room():
	return current_room

func pan_camera(room):
	current_room = room
	animation_tree.set("parameters/TimeScale/scale", 0) # pause junko's animation
	set_physics_process(false) # freeze the game
	camera_in_animation = true
	# and set it as the current camera
	animation_camera.current = true
	# defines where initial camera center is
	# bug with godot doesnt define where camera's position is, even if its out of bounds
	player_camera.global_position.x = clamp(player_camera.global_position.x, player_camera.limit_left + screen_width/2, player_camera.limit_right - screen_width/2)
	player_camera.global_position.y = clamp(player_camera.global_position.y, player_camera.limit_top + screen_height/2, player_camera.limit_bottom - screen_height/2)
	# set the animation camera's poto_roomsition to the current camera
	animation_camera.global_position = player_camera.global_position
	# then sets the new limits
	var topleft = room.get_node("TopLeft")
	var bottomright = room.get_node("BottomRight")
	player_camera.limit_top = topleft.global_position.y
	player_camera.limit_bottom = bottomright.global_position.y
	player_camera.limit_left = topleft.global_position.x
	player_camera.limit_right = bottomright.global_position.x
	# and determines where the new camera center is (destination)
	player_camera.global_position.x = clamp(global_position.x, player_camera.limit_left + screen_width/2, player_camera.limit_right - screen_width/2)
	player_camera.global_position.y = clamp(global_position.y, player_camera.limit_top + screen_height/2, player_camera.limit_bottom - screen_height/2)
	#yield(get_tree(), "idle_frame")
	# moves animation_camera to player_camera
	var tween = create_tween()
	print("Play GP: " + str(player_camera.global_position))
	print("Anim GP: " + str(animation_camera.global_position))
	tween.tween_property(animation_camera, "global_position",
		player_camera.global_position, .7)
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	print("Play GP: " + str(player_camera.global_position))
	print("Anim GP: " + str(animation_camera.global_position))
	camera_in_animation = false
	player_camera.current = true
	set_physics_process(true)
	animation_tree.set("parameters/TimeScale/scale", 1)

# Snaps the camera to a specific room. This is used for initializing the camera
# when loading from a menu or from a save.
func snap_camera(room):
	current_room = room
	player_camera.global_position.x = clamp(player_camera.global_position.x, player_camera.limit_left + screen_width/2, player_camera.limit_right - screen_width/2)
	player_camera.global_position.y = clamp(player_camera.global_position.y, player_camera.limit_top + screen_height/2, player_camera.limit_bottom - screen_height/2)
	var topleft = room.get_node("TopLeft")
	var bottomright = room.get_node("BottomRight")
	player_camera.limit_top = topleft.global_position.y
	player_camera.limit_bottom = bottomright.global_position.y
	player_camera.limit_left = topleft.global_position.x
	player_camera.limit_right = bottomright.global_position.x
	player_camera.global_position.x = clamp(global_position.x, player_camera.limit_left + screen_width/2, player_camera.limit_right - screen_width/2)
	player_camera.global_position.y = clamp(global_position.y, player_camera.limit_top + screen_height/2, player_camera.limit_bottom - screen_height/2)
	animation_camera.global_position = player_camera.global_position
	camera_in_animation = false
	player_camera.current = true
