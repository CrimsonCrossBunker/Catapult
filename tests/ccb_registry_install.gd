extends SceneTree


# Opt-in test: run a dedicated Godot executable from a temporary directory.
# Never point it at an existing player's portable launcher directory.
func _init() -> void:
	call_deferred("run")


func fail(message: String) -> void:
	push_error(message)
	quit(1)


func run() -> void:
	var paths = get_root().get_node("Paths")
	var settings = get_root().get_node("Settings")
	var fs = get_root().get_node("FS")
	fs._platform = "Windows" if OS.get_name() == "Windows" else "X11"
	var sandbox = OS.get_environment("CCB_TEST_SANDBOX").replace("\\", "/")
	if sandbox.empty() or paths.own_dir.replace("\\", "/") != sandbox:
		fail("Run this test using tests/run_registry_tests.py in an isolated sandbox")
		return
	settings.store("game", "ccb")
	settings.store("active_install_ccb", "registry-acceptance")
	paths._last_active_install_name = "registry-acceptance"
	paths._last_active_install_dir = OS.get_environment("CCB_TEST_GAME")
	Directory.new().make_dir_recursive(paths.cache_dir)
	Directory.new().make_dir_recursive(paths.mods_user)
	var manager = load("res://scripts/ModManager.gd").new()
	get_root().add_child(manager)
	var catalog = get_root().get_node("Helpers").load_json_file(OS.get_environment("CCB_TEST_CATALOG"))
	if not manager._load_ccb_catalog(catalog):
		fail("Catalog failed to load")
		return
	var mod = manager.available["hello_ccb"]
	var name = mod["modinfo"]["name"]
	var file = File.new()
	if file.open(OS.get_environment("CCB_TEST_ZIP"), File.READ) != OK:
		fail("Downloaded ZIP missing")
		return
	var body = file.get_buffer(file.get_len())
	file.close()
	manager._process_downloaded_mod(body, name)
	yield(manager, "_done_installing_mod")
	manager.refresh_installed()
	if not "hello_ccb" in manager.installed:
		fail("Fresh install was not discovered")
		return
	var destination = manager.installed["hello_ccb"]["location"]
	mod["version"] = "acceptance-update"
	manager._process_downloaded_mod(body, name)
	yield(manager, "_done_installing_mod")
	manager.refresh_installed()
	if manager.installed["hello_ccb"].get("package_version") != "acceptance-update":
		fail("Update marker was not installed")
		return
	manager._process_downloaded_mod("corrupt ZIP".to_utf8(), name)
	yield(manager, "_done_installing_mod")
	if not file.file_exists(destination.plus_file("main.lua")):
		fail("Broken update removed the working MOD")
		return
	# A synchronous extraction setup error must complete, not leave the UI
	# waiting for a signal that fired before it subscribed.
	var directory = Directory.new()
	var tmp_backup = paths.tmp_dir + "-acceptance-backup"
	if directory.rename(paths.tmp_dir, tmp_backup) != OK:
		fail("Cannot prepare extraction failure fixture")
		return
	file.open(paths.tmp_dir, File.WRITE)
	file.store_string("block directory creation")
	file.close()
	manager._process_downloaded_mod(body, name)
	yield(manager, "_done_installing_mod")
	directory.remove(paths.tmp_dir)
	directory.rename(tmp_backup, paths.tmp_dir)
	if not file.file_exists(destination.plus_file("main.lua")):
		fail("Extraction setup failure removed the working MOD")
		return
	# Different authors may choose the same display name. Identity is the ID.
	var duplicate = mod.duplicate(true)
	duplicate["modinfo"]["id"] = "same_name_other_id"
	manager.available["same_name_other_id"] = duplicate
	manager._process_downloaded_mod(body, name, "same_name_other_id")
	yield(manager, "_done_installing_mod")
	manager.refresh_installed()
	if not "same_name_other_id" in manager.installed:
		fail("Duplicate display name installed the wrong MOD ID")
		return
	manager.delete_mods(["hello_ccb"])
	yield(manager, "mod_deletion_finished")
	if Directory.new().dir_exists(destination):
		fail("Uninstall left the installed MOD")
		return
	manager.queue_free()
	print("PASS: public ZIP install, update, corrupt-update preservation, uninstall")
	quit(0)
