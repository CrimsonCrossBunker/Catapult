extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
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
	# Wire the real scene's view without starting the application's network
	# requests, game discovery, or update checker.
	var ui = instance.get_node("Main/Tabs/Mods")
	ui._mods = instance.get_node("Mods")
	for binding in [
		["_ccb_controls", "CCBCatalogControls"],
		["_ccb_type", "CCBCatalogControls/Type"],
		["_ccb_search", "CCBCatalogControls/Search"],
		["_ccb_hint", "CCBActivationHint"],
		["_available_list", "HBox/Available/AvailableList"],
		["_lbl_repo", "HBox/Available/Label"],
		["_btn_add", "ButtonsRow/RightButtons/BtnAddSelectedMod"],
		["_btn_add_all", "ButtonsRow/RightButtons/BtnAddAllMods"],
	]:
		ui.set(binding[0], ui.get_node(binding[1]))
	for title in ["All", "Maintained", "Community"]:
		ui._ccb_type.add_item(title)
	var catalog = {"schema_version": 1, "mods": []}
	for id in ["field_journal", "hello_ccb", "pocket_alarm", "scrap_multitool", "community_fixture"]:
		catalog.mods.append({
			"id": id,
			"type": "community" if id == "community_fixture" else "ccb-maintained",
			"name": {"en": id}, "description": {"en": "Test fixture"},
			"version": "0.1.0", "download": "https://example.invalid/" + id + ".zip",
			"source": "https://example.invalid/source",
		})
	if not ui._mods._load_ccb_catalog(catalog):
		instance.free()
		push_error("UI fixture catalog was rejected")
		quit(1)
		return
	var settings = get_root().get_node("Settings")
	var original_settings = settings._current.duplicate(true)
	settings._current["game"] = "ccb"
	settings._current["show_installed_mods_in_available"] = false
	var passed = true
	# Defaults, whitespace, each category, no match, then clearing search.
	for scenario in [[0, "", 5], [0, " \t", 5], [1, "", 4], [2, "", 1], [0, "HELLO_CCB", 1], [0, "missing", 0], [0, "", 5]]:
		ui._ccb_type.select(scenario[0])
		ui._ccb_search.text = scenario[1]
		ui.reload_available()
		if ui._available_mods_view.size() != scenario[2] or ui._available_list.get_item_count() != max(1, scenario[2]):
			push_error("Visible MOD list mismatch: " + str(scenario))
			passed = false
		elif scenario[2] > 0 and ui._available_list.is_item_disabled(0):
			push_error("Visible MOD entry should be selectable")
			passed = false
		if ui._btn_add_all.disabled != (scenario[2] == 0):
			push_error("Install-all state does not match visible MODs")
			passed = false
	settings._current = original_settings
	instance.free()
	if not passed:
		quit(1)
		return
	print("PASS: real MOD list renders default/category/search/clear states")
	quit(0)
