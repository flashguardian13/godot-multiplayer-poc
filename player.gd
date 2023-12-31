extends CharacterBody2D

@export var speed = 400

func _get_input() -> void:
	var input_dir:Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input_dir * speed

func _physics_process(delta):
	if is_multiplayer_authority():
		_get_input()
		move_and_slide()
