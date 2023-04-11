extends Sprite2D
var frames = 0
var lifetime = 5

func _physics_process(delta):
	frames += 1
	if frames >= lifetime:
		queue_free()
