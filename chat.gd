extends Window

func _on_close_requested():
	hide()
	get_tree().paused = false

func _on_go_back_requested():
	hide()
	get_tree().paused = false
