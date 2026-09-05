extends SceneTree


func _init() -> void:
	call_deferred("run")


func fail(message: String) -> void:
	push_error(message)
	quit(1)


func run() -> void:
	var paths = get_root().get_node("Paths")
	var settings = get_root().get_node("Settings")
	get_root().get_node("FS")._platform = "X11"
	var game_path = OS.get_environment("CCB_TEST_GAME")
	if not paths.own_dir.begins_with("/tmp/ccb-godot3") or not game_path.begins_with("/tmp/ccb-"):
		fail("Use an isolated /tmp/ccb-godot3 executable and /tmp/ccb- game directory")
		return
	settings.store("game", "ccb")
	settings.store("active_install_ccb", "catalog-acceptance")
	paths._last_active_install_name = "catalog-acceptance"
	paths._last_active_install_dir = game_path
	Directory.new().make_dir_recursive(paths.cache_dir)
	Directory.new().make_dir_recursive(paths.mods_user)
	var catalog = get_root().get_node("Helpers").load_json_file(OS.get_environment("CCB_TEST_CATALOG"))
	var manager = load("res://scripts/ModManager.gd").new()
	get_root().add_child(manager)
	if not manager._load_ccb_catalog(catalog):
		fail("Catalog rejected")
		return
	# Prove both classes use the same installation path without publishing fake community entries.
	for entry in catalog.mods:
		var id = entry.id
		if id == "hello_ccb":
			manager.available[id]["registry_type"] = "community"
		var archive = OS.get_environment("CCB_TEST_PACKAGES").plus_file(id + "-" + entry.version + ".zip")
		var file = File.new()
		if file.open(archive, File.READ) != OK:
			fail("Missing ZIP: " + archive)
			return
		var body = file.get_buffer(file.get_len())
		file.close()
		manager._process_downloaded_mod(body, manager.available[id].modinfo.name)
		yield(manager, "_done_installing_mod")
		manager.refresh_installed()
		if not id in manager.installed or manager.installed[id].get("package_version") != entry.version:
			fail("Install/discovery failed: " + id)
			return
		print("INSTALLED: " + id + " -> " + manager.installed[id].location)
	manager.queue_free()
	print("PASS: all public catalog packages installed; maintained and community paths exercised")
	quit(0)
