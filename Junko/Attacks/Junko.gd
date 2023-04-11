##################################################
### Character Controller
##################################################
extends CharacterBody2D

# This is the emulated dimensions of the screen.
# The game natively runs 1920x1080, but is scaled down to 480x270.
var screen_width = 320.0
var screen_height = 180.0

var i_frames = 0
var max_i_frames = 60

const MAX_RUN = 75
const RUN_ACCELERATION = 15

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
const MAX_FALL = 200
const JUMP_VELOCITY = -200

var coyote_frame_counter = 0

var max_jumps = 2
var jumps_remaining = max_jumps

var max_health = 4
var health = max_health

var attack_damage = 4

var facing_direction = 1
var walking_direction = 0

var camera_offset = Vector2.ZERO
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
	animation_tree.set("parameters/" + animation_name + "/transition_request", value)

func _ready():
	get_node("HitBox").set_deferred("monitoring", true)
	set_health(max_health)
	set_animation("alive", "alive") # alive
	set_animation("attack_direction", "attack_right") # alive
	set_animation("attacking_or_not_attacking", "not_attacking") # ground
	set_animation("ground_or_air", "ground") # idle
	set_animation("idle_or_running", "idle")
	animation_tree.set("parameters/TimeScale/scale", 1)
	set_animation("jumping_or_falling", "falling")
	set_animation("taking_damage", "undamaged") # undamaged
	sword_right.get_node("Sprite2d").visible = false
	sword_left.get_node("Sprite2d").visible = false
	sword_down.get_node("Sprite2d").visible = false
	sword_right.get_node("SwordArea2d/CollisionShape2d").disabled = true
	sword_left.get_node("SwordArea2d/CollisionShape2d").disabled = true
	sword_down.get_node("SwordArea2d/CollisionShape2d").disabled = true

func _physics_process(delta):
	if i_frames > 0:
		i_frames -= 1
	elif i_frames <= 0:
		get_node("HitBox").set_deferred("monitoring", true)
	camera_follow_player()
	manage_movement(delta)
	manage_animations()
	frame_passes()
	position.x = round(position.x)
	position.y = round(position.y)
	
	if Input.is_action_just_pressed("toggle_fullscreen"):
		print(DisplayServer.window_get_mode())
		if DisplayServer.window_get_mode() == 4:
			DisplayServer.window_set_mode(0)
		else:
			DisplayServer.window_set_mode(4)
	
	if Input.is_action_just_pressed("close"):
		get_tree().quit()

func manage_movement(delta):
	# Vertical Movement
	if is_on_floor():
		set_animation("ground_or_air", "ground") # ground
		jumps_remaining = max_jumps
	elif !is_on_floor():
		set_animation("ground_or_air", "air") # air
		# Jumping upward
		if velocity.y <= 0:
			set_animation("jumping_or_falling", "jumping") # jumping
		# Falling downward
		elif velocity.y > 0: 
			set_animation("jumping_or_falling", "falling") # falling
		velocity.y += gravity * delta
	
	# Horizontal Movement
	velocity.x = move_toward(velocity.x, walking_direction * MAX_RUN, RUN_ACCELERATION)
	if velocity.x > 0:
		set_animation("idle_or_running", "running")
	elif velocity.x < 0:
		set_animation("idle_or_running", "running")
	elif velocity.x == 0:
		set_animation("idle_or_running", "idle")
	
	walking_direction = Input.get_axis("left", "right")
	
	if Input.is_action_just_pressed("jump") && jumps_remaining > 0:
		velocity.y = JUMP_VELOCITY
		jumps_remaining -= 1
		var jump_particles = load("res://Particles/JumpParticles.tscn").instantiate()
		jump_particles.global_position = get_node("feet").global_position
		get_node("../Particles").add_child(jump_particles)
		
	if Input.is_action_just_pressed("attack") && !currently_attacking:
		set_animation("attacking_or_not_attacking", "attacking")
		if Input.is_action_pressed("down") && !is_on_floor():
			set_animation("attack_direction", "attack_down")
		elif facing_direction == 1:
			set_animation("attack_direction", "attack_right")
		elif facing_direction == -1:
			set_animation("attack_direction", "attack_left")
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
	if(!animation_camera.enabled):
		player_camera.global_position = global_position + camera_offset # pans from player to offset
		player_camera.global_position.x = round(global_position.x)
		player_camera.global_position.y = round(global_position.y)

func get_room():
	return current_room

func pan_camera(room):
	current_room = room
	animation_tree.set("parameters/TimeScale/scale", 0) # pause junko's animation
	set_physics_process(false) # freeze the game
	# and set it as the current camera
	animation_camera.enabled = true
	player_camera.enabled = false
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
	var tween = get_tree().create_tween()
	tween.tween_property(animation_camera, "global_position",
		player_camera.global_position, .7)
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	print("Play GP: " + str(player_camera.global_position))
	print("Anim GP: " + str(animation_camera.global_position))
	player_camera.enabled = true
	animation_camera.enabled = false
	set_physics_process(true)
	animation_tree.set("parameters/TimeScale/scale", 1) # was parameters/TimeScale/scale

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
	animation_camera.enabled = false
	player_camera.enabled = true

func take_damage(dir):
	get_node("HitBox").set_deferred("monitoring", false)
	i_frames = max_i_frames
	velocity = dir * 200
	velocity.y -= 100
	set_health(health - 1)

func hit_enemy():
	pass

func hit_side_area(area):
	var enemy = area.get_parent()
	enemy.take_damage(4)
	velocity.x += 2

func hit_enemy_down_area(area):
	var enemy = area.get_parent()
	enemy.take_damage(4)
	velocity.y = JUMP_VELOCITY

func hit_enemy_down_body(body):
	if body is TileMap:
		velocity.y = JUMP_VELOCITY

# If you walk into an enemy hitbox
func _on_hit_box_area_entered(area):
	var ouch_direction = area.global_position.direction_to(global_position).normalized()
	take_damage(ouch_direction)

func set_health(new_health):
	health = new_health
	var healthbar = get_tree().get_first_node_in_group("healthbar")
	for i in max_health:
		healthbar.get_node("health" + str(i+1)).visible = false
	for i in health:
		healthbar.get_node("health" + str(i+1)).visible = true
	# die
	if health <= 0:
		get_tree().reload_current_scene()
