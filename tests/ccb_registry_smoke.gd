extends SceneTree


func fail(message: String) -> void:
	push_error(message)
	quit(1)


func _init() -> void:
	var manager = load("res://scripts/ModManager.gd").new()
	var catalog = {
		"schema_version": 1,
		"mods": [
			{
				"id": "../unsafe",
				"type": "community",
				"name": {"en": "Unsafe"},
				"description": {"en": "Must be rejected"},
				"version": "1",
				"download": "https://example.invalid/unsafe.zip",
				"source": "https://example.invalid/source",
			},
			{
				"id": "registry_smoke",
				"type": "community",
				"name": {"zh-Hans": "注册测试", "en": "Registry smoke test"},
				"description": {"zh-Hans": "测试", "en": "Test"},
				"version": "1.2.3",
				"download": "https://example.invalid/registry_smoke.zip",
				"source": "https://example.invalid/source",
				"issues": "https://example.invalid/issues",
				"authors": ["author"],
				"maintainers": ["maintainer"],
				"ccb_adapters": ["adapter"],
				"ccb_versions": ["0.Ag"],
				"lua_api": 1,
				"dependencies": [],
				"conflicts": ["other_mod"],
				"validation": {"status": "passed", "checked_at": "2026-09-05"},
				"updated_at": "2026-09-05",
				"license": "MIT",
			},
		],
	}

	if not manager._load_ccb_catalog(catalog):
		fail("CCB catalog was rejected")
		return
	if manager.available.size() != 1 or not "registry_smoke" in manager.available:
		fail("CCB catalog entry was not loaded")
		return
	var entry = manager.available["registry_smoke"]
	if not manager.matches_ccb_filter(entry, 2, "adapter") and not manager.matches_ccb_filter(entry, 2, "author"):
		fail("Community author search failed")
		return
	if manager.matches_ccb_filter(entry, 1, "") or manager.matches_ccb_filter(entry, 0, "not-present"):
		fail("CCB category/search filtering failed")
		return
	var maintained = entry.duplicate(true)
	maintained["registry_type"] = "ccb-maintained"
	# Godot 3 treats an empty substring as not found. Empty/whitespace
	# searches must keep every entry in the selected category visible.
	for query in ["", " ", "\t\n"]:
		for kind in [0, 2]:
			if not manager.matches_ccb_filter(entry, kind, query):
				fail("Empty search hid a community MOD")
				return
		for kind in [0, 1]:
			if not manager.matches_ccb_filter(maintained, kind, query):
				fail("Empty search hid a maintained MOD")
				return
		if manager.matches_ccb_filter(entry, 1, query) or manager.matches_ccb_filter(maintained, 2, query):
			fail("Empty search bypassed the selected category")
			return
	if not manager.matches_ccb_filter(maintained, 1, "REGISTRY_SMOKE") or manager.matches_ccb_filter(maintained, 2, ""):
		fail("Maintained category filtering failed")
		return
	if entry.get("source_type") != "ccb_registry":
		fail("CCB source type was not retained")
		return
	if entry.get("registry_type") != "community" or entry.get("version") != "1.2.3":
		fail("CCB catalog metadata was not retained")
		return
	if entry["modinfo"].get("name", "") == "" or entry["modinfo"].get("id") != "registry_smoke":
		fail("CCB launcher MOD info was not generated")
		return
	if entry["modinfo"].get("conflicts", []) != ["other_mod"]:
		fail("CCB conflicts were not retained")
		return
	var game = {"release tag": "0.Ag", "lua api": "1"}
	entry["validation"]["ccb_version"] = "0.Ag"
	if manager.registry_compatibility(entry, game) != "passed":
		fail("Exact game/API validation should pass")
		return
	for scenario in [
		[{"release tag": "different", "lua api": "1"}, "version-mismatch"],
		[{"release tag": "0.Ag", "lua api": "2"}, "api-mismatch"],
		[{}, "not-tested"],
		[{"release tag": "0.Ag"}, "not-tested"],
	]:
		if manager.registry_compatibility(entry, scenario[0]) != scenario[1]:
			fail("Incorrect compatibility for " + str(scenario[0]))
			return
	entry["validation"]["ccb_version"] = "older"
	if manager.registry_compatibility(entry, game) != "not-tested":
		fail("Validation for another game must not imply current compatibility")
		return

	var lua_mod_path = "res://tests/fixtures/lua_mod"
	if manager._find_mod_directory(lua_mod_path) != lua_mod_path:
		fail("root main.lua package was not recognized")
		return
	var installed = manager.parse_mods_dir("res://tests/fixtures/installed")
	if not "registry_smoke" in installed:
		fail("installed Lua registry MOD marker was not recognized")
		return
	if installed["registry_smoke"].get("package_version") != "1.2.3":
		fail("installed registry MOD version was not retained")
		return
	manager.free()
	var releases = load("res://scripts/ReleaseManager.gd").new()
	var builds = []
	get_root().get_node("Settings").store("shorten_release_names", true)
	releases._parse_builds(JSON.print([{
		"name": "0.Ag Candidate 2026-09-05_02:19",
		"tag_name": "0.Ag-Candidate-2026-09-05-0219",
		"assets": [],
	}]).to_utf8(), builds, {"substring": "ccb-linux", "field": "name"})
	if builds[0]["name"] != "0.Ag-Candidate-2026-09-05-0219":
		fail("CCB release tags must remain visible even with shortened names")
		return
	releases.free()
	var package = load("res://scripts/RegistryPackage.gd").new()
	if package.find_mod(lua_mod_path, "registry_smoke") != lua_mod_path:
		fail("Root Lua package rejected")
		return
	var test_root = "user://registry-replace-" + str(OS.get_ticks_usec())
	var directory = Directory.new()
	directory.make_dir_recursive(test_root.plus_file("old"))
	directory.make_dir_recursive(test_root.plus_file("new"))
	var marker = File.new()
	marker.open(test_root.plus_file("old/old.txt"), File.WRITE)
	marker.store_string("old MOD")
	marker.close()
	marker.open(test_root.plus_file("new/new.txt"), File.WRITE)
	marker.store_string("new MOD")
	marker.close()
	if package.replace_directory(test_root.plus_file("missing"), test_root.plus_file("old"), test_root.plus_file("backup")) == OK or not marker.file_exists(test_root.plus_file("old/old.txt")):
		fail("Invalid replacement must retain old MOD")
		return
	if package.replace_directory(test_root.plus_file("new"), test_root.plus_file("old"), test_root.plus_file("backup")) != OK:
		fail("Valid replacement failed")
		return
	if not marker.file_exists(test_root.plus_file("old/new.txt")) or not marker.file_exists(test_root.plus_file("backup/old.txt")):
		fail("Replacement did not retain backup")
		return
	directory.make_dir_recursive(test_root.plus_file("old/nested"))
	if package.replace_directory(test_root.plus_file("old/nested"), test_root.plus_file("old"), test_root.plus_file("rollback")) == OK:
		fail("Expected injected rename failure")
		return
	if not marker.file_exists(test_root.plus_file("old/new.txt")) or directory.dir_exists(test_root.plus_file("rollback")):
		fail("Rename failure did not restore the old MOD")
		return
	get_root().get_node("FS")._rm_dir_internal([test_root])
	quit(0)
