extends CharacterBody2D
class_name Enemy

var MAX_HEALTH = 20
var health

func _ready():
	health = MAX_HEALTH

func take_damage(damage):
	health -= damage
	if health <= 0:
		die()
	get_node("AnimationPlayer").play("take_damage")

func die():
	queue_free()
	#get_node("AnimationPlayer").play("die")

