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
	quit(0)
