extends SceneTree


func _init() -> void:
	var script = load("res://scripts/ModsUI.gd")
	var scene = load("res://scenes/Catapult.tscn")
	if script == null or scene == null:
		push_error("MOD UI script or scene failed to load")
		quit(1)
		return
	var instance = scene.instance()
	if instance == null or not instance.has_node("Main/Tabs/Mods/CCBCatalogControls/Type"):
		push_error("MOD catalog controls are missing")
		quit(1)
		return
	instance.free()
	print("PASS: complete launcher scene and MOD controls load")
	quit(0)
