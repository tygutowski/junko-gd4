####################################################
### Determine where rooms exist and what happens 
### when the player walks from one room to another
####################################################

extends Area2D

var player_inside = false
var player_inside_only_this_room = true
@onready var junko = get_tree().get_first_node_in_group("junko")

func _ready():
	set_anchor_points()
	
# Moves all of the points to determine where the rooms
# begin and end
func set_anchor_points():
	var topleft = get_node("TopLeft")
	var botright = get_node("BottomRight")
	var collider = get_node("CollisionShape2d")
	topleft.position = -1 * collider.shape.extents + collider.position
	botright.position = collider.shape.extents + collider.position

# Check all other rooms to see if the player is in this room exclusively
func is_player_in_only_this_room():
	var rooms = get_tree().get_nodes_in_group("room")
	rooms.erase(self)
	for room in rooms:
		if room.player_inside:
			return false
	return true

func find_room():
	var rooms = get_tree().get_nodes_in_group("room")
	for room in rooms:
		if room.player_inside:
			return room

func _on_room_area_2d_body_entered(body):
	if body == junko:
		player_inside = true
		# If this is initializing the rooms
		if(junko.current_room == null):
			junko.snap_camera(self)

# When the player exits the room, find the room they
# went to and pan the camera to that room.
func _on_room_area_2d_body_exited(body):
	if body.is_in_group("junko"):
		player_inside = false
		var room_to_pan_to = find_room()
		if room_to_pan_to != null:
			if room_to_pan_to != junko.get_room():
				junko.pan_camera(room_to_pan_to)

