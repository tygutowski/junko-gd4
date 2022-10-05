extends StaticBody2D
class_name Enemy

var health = 20
@onready var junko = get_tree().get_first_node_in_group("junko")

func _ready():
	get_node("AnimationPlayer").current_animation = "RESET"

func _on_area_2d_area_entered(area):
	if(area.is_in_group("junko_attack")):
		take_damage()

func take_damage():
	health -= junko.damage
	if health <= 0:
		die()
	get_node("AnimationPlayer").play("take_damage")

func die():
	get_node("AnimationPlayer").play("die")
