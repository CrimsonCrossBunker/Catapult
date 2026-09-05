extends VBoxContainer


onready var _root = $"/root/Catapult"
onready var _mods = $"../../../Mods"
onready var _installed_list = $HBox/Installed/InstalledList
onready var _available_list = $HBox/Available/AvailableList
onready var _cbox_show_stock = $ButtonsRow/LeftButtons/ShowStock
onready var _btn_delete = $ButtonsRow/LeftButtons/BtnDelete
onready var _btn_add = $ButtonsRow/RightButtons/BtnAddSelectedMod
onready var _btn_add_all = $ButtonsRow/RightButtons/BtnAddAllMods
onready var _lbl_mod_info = $ModInfo
onready var _lbl_installed = $HBox/Installed/Label
onready var _lbl_repo = $HBox/Available/Label
onready var _dlg_reinstall = $ModReinstallDialog
onready var _dlg_del_multiple = $DeleteMultipleDialog
onready var _ccb_controls = $CCBCatalogControls
onready var _ccb_type = $CCBCatalogControls/Type
onready var _ccb_search = $CCBCatalogControls/Search
onready var _ccb_hint = $CCBActivationHint

var _installed_mods_view := []
var _available_mods_view := []

var _mods_to_delete := []
var _mods_to_install := []
var _ids_to_delete := []
var _ids_to_install := []
var _ids_to_reinstall := []

# Track which game types have had their mod release dates fetched this session
var _fetched_game_types := []


# Reset the session tracking for mod fetching (called when game type changes)
func reset_mod_fetch_session_tracking() -> void:
	_fetched_game_types.clear()


func _ready() -> void:

	_mods.connect("mod_compatibility_checked", self, "_on_mod_compatibility_checked")
	_mods.connect("bn_registry_loaded", self, "_on_bn_registry_loaded")
	_mods.connect("ccb_registry_loaded", self, "_on_ccb_registry_loaded")
	_ccb_type.add_item(tr("str_ccb_all_mods"))
	_ccb_type.add_item(tr("str_type_ccb_maintained"))
	_ccb_type.add_item(tr("str_type_community"))
	_ccb_type.connect("item_selected", self, "_on_ccb_filter_changed")
	_ccb_search.connect("text_changed", self, "_on_ccb_filter_changed")
	$CCBCatalogControls/Refresh.connect("pressed", self, "_on_ccb_refresh")
	$CCBCatalogControls/Website.connect("pressed", self, "_on_ccb_website")
	$CCBCatalogControls/Submit.connect("pressed", self, "_on_ccb_submit")


func _on_ccb_filter_changed(_value) -> void:
	reload_available()
	_lbl_mod_info.bbcode_text = tr("lbl_mod_info")


func _on_ccb_refresh() -> void:
	_mods._fetch_ccb_mods_from_registry()


func _on_ccb_website() -> void:
	OS.shell_open("https://crimsoncrossbunker.github.io/CCB-MOD/")


func _on_ccb_submit() -> void:
	OS.shell_open("https://crimsoncrossbunker.github.io/CCB-MOD/submit.html")


func _on_bn_registry_loaded() -> void:

	reload_available()


func _on_ccb_registry_loaded() -> void:

	reload_available()


func _populate_list_with_mods(mods_array: Array, list: ItemList) -> void:
	
	list.clear()
	for mod in mods_array:
		list.add_item(mod["name"])
		if "location" in mod:
			var tooltip = tr("tooltip_mod_location") % mod["location"]
			list.set_item_tooltip(list.get_item_count() - 1, tooltip)


func reload_installed() -> void:
	
	var hidden_mods = 0
	var show_stock = Settings.read("show_stock_mods")
	var show_obsolete = Settings.read("show_obsolete_mods")
	
	_installed_mods_view.clear()
	
	for id in _mods.installed:
		
		var mod = _mods.installed[id]
		var show: bool
		
		var status = _mods.mod_status(id)
		if status in [0, 1]:
			show = true
		elif status in [3, 4]:
			if show_obsolete:
				if show_stock:
					show = true
				else:
					hidden_mods += 1
		elif status == 2:
			show = show_stock
			if !show:
				hidden_mods += 1
		
		if show:
			_installed_mods_view.append({
				"id": id,
				"name": mod["modinfo"]["name"],
				"location": mod["location"],
				"update_available": false,
				"date_unavailable": false,
			})
			if (show_obsolete) and (status == 3):
				_installed_mods_view[-1]["name"] += " [obsolete]"
			
			# Check for updates (skip stock mods)
			if not mod["is_stock"]:
				# Find this mod in available list by matching modinfo ID
				var available_key = ""
				for key in _mods.available:
					if _mods.available[key]["modinfo"]["id"] == id:
						available_key = key
						break
				
				# Check if this is a GitHub mod
				if available_key != "":
					var mod_location = _mods.available[available_key]["location"]
					if _mods.available[available_key].get("source_type") == "ccb_registry":
						if mod.get("package_version", "") != _mods.available[available_key].get("version", ""):
							_installed_mods_view[-1]["update_available"] = true
							_installed_mods_view[-1]["name"] += " [%s]" % tr("str_update_available")
					elif mod_location.begins_with("https://github.com/"):
						# Get stored download date
						var download_dates = Settings.read("mod_download_dates")
						if download_dates != null and id in download_dates:
							var download_date = download_dates[id]
							# Get latest GitHub release date
							var release_date = _mods._get_mod_latest_release_date(available_key)
							if release_date != "" and release_date > download_date:
								_installed_mods_view[-1]["update_available"] = true
								_installed_mods_view[-1]["name"] += " [%s]" % tr("str_update_available")
						else:
							# No download date found
							_installed_mods_view[-1]["date_unavailable"] = true
							_installed_mods_view[-1]["name"] += " [%s]" % tr("str_date_unavailable")
	
	_installed_mods_view.sort_custom(self, "_sorting_comparison")
	
	_btn_delete.disabled = true
	
	_populate_list_with_mods(_installed_mods_view, _installed_list)
	
	var hidden_str = ""
	if hidden_mods > 0:
		hidden_str = tr("str_installed_mods_hidden") % hidden_mods
	_lbl_installed.text = tr("lbl_installed_mods") % hidden_str
	
	for i in len(_installed_mods_view):
		var id = _installed_mods_view[i]["id"]
		
		if _mods.installed[id]["is_stock"]:
			_installed_list.set_item_custom_fg_color(i, Color(0.5, 0.5, 0.5))
			# TODO: Get color from the theme instead.
		elif _installed_mods_view[i]["update_available"]:
			# Green color for mods with updates available
			_installed_list.set_item_custom_fg_color(i, Color(0.2, 0.8, 0.2))
		elif _installed_mods_view[i]["date_unavailable"]:
			# Orange/yellow color for mods with unknown date
			_installed_list.set_item_custom_fg_color(i, Color(1.0, 0.65, 0.0))


func reload_available() -> void:
	
	# Check if mods are not supported for the current game fork
	var game = Settings.read("game")
	_ccb_controls.visible = game == "ccb"
	_ccb_hint.visible = game == "ccb"
	if game == "tish":
		_available_mods_view.clear()
		_available_list.clear()
		_available_list.add_item("Mods are not supported for There is Still Hope")
		_available_list.set_item_disabled(0, true)
		_available_list.set_item_custom_fg_color(0, Color(0.7, 0.7, 0.7))
		_lbl_repo.text = tr("lbl_mod_repo") % ""
		_btn_add.disabled = true
		_btn_add_all.disabled = true
		return
	elif game == "eod":
		_available_mods_view.clear()
		_available_list.clear()
		_available_list.add_item("Mods are not supported for Era Of Decay")
		_available_list.set_item_disabled(0, true)
		_available_list.set_item_custom_fg_color(0, Color(0.7, 0.7, 0.7))
		_lbl_repo.text = tr("lbl_mod_repo") % ""
		_btn_add.disabled = true
		_btn_add_all.disabled = true
		return
	elif game == "bn" and len(_mods.available) == 0:
		_available_mods_view.clear()
		_available_list.clear()
		_available_list.add_item("Loading mods from mods.cataclysmbn.org...")
		_available_list.set_item_disabled(0, true)
		_available_list.set_item_custom_fg_color(0, Color(0.7, 0.7, 0.7))
		_lbl_repo.text = tr("lbl_mod_repo") % ""
		_btn_add.disabled = true
		_btn_add_all.disabled = true
		return
	elif game == "ccb" and len(_mods.available) == 0:
		_available_mods_view.clear()
		_available_list.clear()
		_available_list.add_item(tr("str_ccb_catalog_empty") if _mods._ccb_registry_ready else tr("msg_ccb_registry_fetching"))
		_available_list.set_item_disabled(0, true)
		_available_list.set_item_custom_fg_color(0, Color(0.7, 0.7, 0.7))
		_lbl_repo.text = tr("lbl_mod_repo") % ""
		_btn_add.disabled = true
		_btn_add_all.disabled = true
		return

	var include_installed = Settings.read("show_installed_mods_in_available")
	var hidden_mods = 0

	_available_mods_view.clear()
	
	for id in _mods.available:
		var mod = _mods.available[id]
		if game == "ccb" and not _mods.matches_ccb_filter(mod, _ccb_type.selected, _ccb_search.text):
			continue
		var show: bool
		
		if _mods.mod_status(id) in [0, 3]:
			show = true
		else:
			show = include_installed
	
		if show:
			_available_mods_view.append({
				"id": id,
				"name": ("[%s] " % [tr("str_type_ccb_maintained") if mod.get("registry_type") == "ccb-maintained" else tr("str_type_community")] if game == "ccb" else "") + mod["modinfo"]["name"],
				"location": mod["location"]
			})
		else:
			hidden_mods += 1
	
	_available_mods_view.sort_custom(self, "_sorting_comparison")
	
	var hidden_str = ""
	if hidden_mods > 0:
		hidden_str = tr("str_mod_repo_hidden") % hidden_mods
	_lbl_repo.text = tr("lbl_mod_repo") % hidden_str
	_btn_add.disabled = true
	
	_populate_list_with_mods(_available_mods_view, _available_list)
	_btn_add_all.disabled = _available_mods_view.empty()
	if game == "ccb" and _available_mods_view.empty():
		_available_list.add_item(tr("str_ccb_no_matches"))
		_available_list.set_item_disabled(0, true)
	
	for i in len(_available_mods_view):
		var id = _available_mods_view[i]["id"]
		if _mods.mod_status(id) in [1, 2, 4]:
			_available_list.set_item_custom_fg_color(i, Color(0.5, 0.5, 0.5))
		elif _mods.available[id].get("source_type") == "ccb_registry":
			var validation_status = _mods.registry_compatibility(_mods.available[id], _mods.read_ccb_version(Paths.game_dir))
			var current_text = _available_list.get_item_text(i)
			if validation_status == "passed":
				_available_list.set_item_custom_fg_color(i, Color(0.2, 0.8, 0.2))
				_available_list.set_item_text(i, "[%s] %s" % [tr("str_validation_passed"), current_text])
			elif validation_status in ["failed", "version-mismatch", "api-mismatch"]:
				_available_list.set_item_custom_fg_color(i, Color(0.8, 0.2, 0.2))
				_available_list.set_item_text(i, "[%s] %s" % [tr("str_ccb_" + validation_status), current_text])
			else:
				_available_list.set_item_custom_fg_color(i, Color(1.0, 0.75, 0.15))
				_available_list.set_item_text(i, "[%s] %s" % [tr("str_validation_not_tested"), current_text])
		else:
			# Apply color and status indicators for all channels (both stable and experimental)
			var mod_release_date = _mods._get_mod_latest_release_date(id)
			var mod_location = _mods.available[id]["location"]
			
			if mod_location.begins_with("https://github.com/") and mod_release_date == "":
				# Still fetching/checking - show in yellow with "CHECKING" prefix
				_available_list.set_item_custom_fg_color(i, Color(1.0, 1.0, 0.0))  # Yellow
				var current_text = _available_list.get_item_text(i)
				_available_list.set_item_text(i, "[CHECKING] " + current_text)
			elif not _mods.is_mod_compatible(id) and mod_release_date != "":
				# Has data and is incompatible - show in red with "OUTDATED" prefix
				_available_list.set_item_custom_fg_color(i, Color(0.8, 0.2, 0.2))  # Red
				var current_text = _available_list.get_item_text(i)
				_available_list.set_item_text(i, "[OUTDATED] " + current_text)
			elif _mods.is_mod_compatible(id) and mod_release_date != "":
				# Has data and is compatible - show in green with "UP-TO-DATE" prefix
				_available_list.set_item_custom_fg_color(i, Color(0.2, 0.8, 0.2))  # Green
				var current_text = _available_list.get_item_text(i)
				_available_list.set_item_text(i, "[UP-TO-DATE] " + current_text)
				
	if _available_list.get_item_count() == 0:
		_btn_add_all.disabled = true
		_btn_add.disabled = true
	else:
		_btn_add_all.disabled = false


func _sorting_comparison(a: Dictionary, b: Dictionary) -> bool:
	
	# Apply outdated sorting for all channels (both stable and experimental)
	var a_compatible = _mods.is_mod_compatible(a["id"])
	var b_compatible = _mods.is_mod_compatible(b["id"])
	
	# If one is compatible and the other isn't, compatible comes first
	if a_compatible != b_compatible:
		return a_compatible
	
	# Otherwise, sort alphabetically by name
	return (a["name"].nocasecmp_to(b["name"]) == -1)


func _array_to_text_list(array) -> String:
	
	if typeof(array) == TYPE_STRING:  # Damn you Fuji :)
		return array
	
	var result = ""
	
	if len(array) > 0:
		
		for value in array:
			result += value + ", "
		
		result = result.substr(0, len(result) - 2)
	
	return result


func _make_mod_info_string(mod: Dictionary) -> String:
	
	var result = ""
	var modinfo = mod["modinfo"]
	result += "[b][u]%s[/u][/b] %s" % [tr("str_mod_name") ,modinfo["name"]]
	
	if "id" in modinfo:
		result += " ([b][u]ID:[/u][/b] %s)" % modinfo["id"]
	
	result += "\n"
	
	if "category" in modinfo:
		result += "[b][u]%s[/u][/b] %s\n" % [tr("str_mod_category"), modinfo["category"]]
	
	if "authors" in modinfo:
		result += "[b][u]%s[/u][/b] %s\n" % [tr("str_mod_authors"), _array_to_text_list(modinfo["authors"])]
		
	if "maintainers" in modinfo and len(modinfo["maintainers"]) > 0:
		result += "[b][u]%s[/u][/b] %s\n" % [tr("str_mod_maintainers"), _array_to_text_list(modinfo["maintainers"])]
	if len(modinfo.get("dependencies", [])) > 0:
		result += "[b][u]%s[/u][/b] %s\n" % [tr("str_mod_dependencies"), _array_to_text_list(modinfo["dependencies"])]
	if len(modinfo.get("conflicts", [])) > 0:
		result += "[b][u]%s[/u][/b] %s\n" % [tr("str_mod_conflicts"), _array_to_text_list(modinfo["conflicts"])]

	if mod.get("source_type") == "ccb_registry":
		if mod.get("play_notes", "") != "":
			result += "[b]%s[/b] %s\n" % [tr("str_ccb_play_notes"), str(mod["play_notes"]).replace("[", "[lb]")]
		result += "[b][u]%s[/u][/b] %s\n" % [tr("str_mod_type"), tr("str_type_ccb_maintained") if mod.get("registry_type") == "ccb-maintained" else tr("str_type_community")]
		result += "[b][u]%s[/u][/b] %s\n" % [tr("str_mod_version"), mod.get("version", "")]
		result += "[b][u]%s[/u][/b] %s\n" % [tr("str_ccb_versions"), _array_to_text_list(mod.get("ccb_versions", []))]
		if mod.get("lua_api", null) != null:
			result += "[b][u]%s[/u][/b] %s\n" % [tr("str_lua_api"), str(mod["lua_api"])]
		result += "[b][u]%s[/u][/b] %s\n" % [tr("str_ccb_adapters"), _array_to_text_list(mod.get("ccb_adapters", [])) if len(mod.get("ccb_adapters", [])) > 0 else tr("str_none")]
		result += "[b][u]%s[/u][/b] %s\n" % [tr("str_license"), mod.get("license", "")]
		var validation = mod.get("validation", {})
		var validation_text = tr("str_validation_not_tested")
		if validation.get("status") == "passed":
			validation_text = tr("str_validation_passed")
		elif validation.get("status") == "failed":
			validation_text = tr("str_validation_failed")
		if validation.get("checked_at", null) != null:
			validation_text += " (%s)" % validation["checked_at"]
		if validation.get("ccb_version", null) != null:
			validation_text += " — " + str(validation["ccb_version"])
		result += "[b][u]%s[/u][/b] %s\n" % [tr("str_validation"), validation_text]
		result += "[b][u]%s[/u][/b] %s\n" % [tr("str_ccb_current_compatibility"), tr("str_ccb_" + _mods.registry_compatibility(mod, _mods.read_ccb_version(Paths.game_dir)))]
		if mod.get("issues", "") != "":
			result += "[b][u]%s[/u][/b] [color=#3b93f7][url=%s]%s[/url][/color]\n" % [tr("str_issues"), mod["issues"], mod["issues"]]
	
	# Add mod URL for downloadable mods
	var mod_dict_key = ""
	# Find the dictionary key for this mod in available mods by matching ID
	if "id" in modinfo:
		for key in _mods.available:
			if _mods.available[key]["modinfo"]["id"] == modinfo["id"]:
				mod_dict_key = key
				break
	
	if mod_dict_key != "":
		var mod_entry = _mods.available[mod_dict_key]
		var mod_location = mod_entry["location"]
		var display_url = mod_entry.get("homepage", mod_location)

		# Only show URL for downloadable mods (GitHub URLs)
		if display_url.begins_with("https://github.com/") or display_url.begins_with("http"):
			result += "[b][u]%s[/u][/b] [color=#3b93f7][url=%s]%s[/url][/color]\n" % [tr("str_mod_url"), display_url, display_url]
		
	# Show mod's last release date for all downloadable mods
	if mod_dict_key != "":
		var mod_release_date = _mods._get_mod_latest_release_date(mod_dict_key)
		var is_registry_mod = _mods.available[mod_dict_key].get("source_type") == "bn_registry"
		var mod_location = _mods.available[mod_dict_key]["location"]

		if mod_release_date != "":
			var days_since_mod_release = _mods._calculate_days_since_release(mod_release_date)
			result += "[b][u]Last Updated:[/u][/b] %s (%d days ago)\n" % [mod_release_date, days_since_mod_release]
		elif mod_location.begins_with("https://github.com/") and not is_registry_mod:
			result += "[b][u]Last Updated:[/u][/b] [color=yellow]Fetching from GitHub...[/color]\n"
		else:
			result += "[b][u]Last Updated:[/u][/b] [color=gray]Not available[/color]\n"
	
	# Add stability rating information for all channels (both stable and experimental)
	if "stability" in modinfo:
		var stability_rating = modinfo["stability"]
		var stability_text = ""
		
		match stability_rating:
			-1:
				stability_text = "1 week"
			0:
				stability_text = "1 month"
			1:
				stability_text = "3 months"
			2:
				stability_text = "6 months"
			3:
				stability_text = "9 months"
			4:
				stability_text = "1 year"
			5:
				stability_text = "2 years"
			100:
				if mod_dict_key != "" and _mods.available[mod_dict_key].get("source_type") == "bn_registry":
					stability_text = "officially maintained"
				else:
					stability_text = "forever"
			_:
				stability_text = "unknown"
		
		# Combine stability rating and viability into one field
		if mod_dict_key != "":
			var mod_release_date = _mods._get_mod_latest_release_date(mod_dict_key)
			var is_compatible = _mods.is_mod_compatible(mod_dict_key)
			if mod_release_date != "":
				if is_compatible:
					result += "[b][u]%s[/u][/b] %s - [color=green]Up to Date![/color]\n" % [tr("str_mod_stability"), stability_text]
				else:
					result += "[b][u]%s[/u][/b] %s - [color=red]Potentially Broken/Outdated[/color]\n" % [tr("str_mod_stability"), stability_text]
			else:
				result += "[b][u]%s[/u][/b] %s - [color=yellow]Checking...[/color]\n" % [tr("str_mod_stability"), stability_text]
		else:
			result += "[b][u]%s[/u][/b] %s\n" % [tr("str_mod_stability"), stability_text]
	
	if "description" in modinfo:
		var formatted_description = _format_links_in_text(modinfo["description"])
		result += "[b][u]%s[/u][/b] %s\n" % [tr("str_mod_description"), formatted_description]
	
	# Check if mod is installed and missing download date
	if mod_dict_key != "" and "id" in modinfo:
		var mod_id = modinfo["id"]
		# Check if mod is installed (and not a stock mod)
		if mod_id in _mods.installed and not _mods.installed[mod_id]["is_stock"]:
			var mod_location = _mods.available[mod_dict_key]["location"]
			# Only check for GitHub mods
			if mod_location.begins_with("https://github.com/"):
				var download_dates = Settings.read("mod_download_dates")
				if download_dates == null or not mod_id in download_dates:
					result += "\n[b][color=#FF8C00]No download date recorded. Redownload this mod to enable update checking.[/color][/b]\n"
	
	result = result.rstrip("\n")
	return result


func _on_ShowStock_toggled(button_pressed: bool) -> void:
	
	Settings.store("show_stock_mods", button_pressed)
	reload_installed()


func _on_Tabs_tab_changed(tab: int) -> void:

	if tab != 1:
		return

	_cbox_show_stock.pressed = Settings.read("show_stock_mods")
	_lbl_mod_info.bbcode_text = tr("lbl_mod_info")
	_btn_delete.disabled = true
	_btn_add.disabled = true

	reload_installed()
	reload_available()

	# Fetch mod release dates for all channels to show "Last Updated" information
	# This will also trigger compatibility checking for both stable and experimental channels
	# This also fetches for installed mods to enable update checking
	# Only fetch once per game type per session to avoid hitting GitHub API rate limits
	var current_game = Settings.read("game")
	if len(_mods.available) > 0 and not current_game in _fetched_game_types:
		Status.post("Fetching mod release dates for compatibility and update checking...")
		_mods.fetch_all_mod_release_dates()
		_fetched_game_types.append(current_game)


func _on_mod_compatibility_checked(compatible_count: int, incompatible_count: int) -> void:
	
	# Post status message about mod compatibility
	if incompatible_count > 0:
		Status.post("Mod compatibility check complete: %d compatible, %d potentially incompatible mods (based on individual mod release dates vs stability ratings)" % [compatible_count, incompatible_count], Enums.MSG_WARN)
	else:
		Status.post("Mod compatibility check complete: All %d available mods are compatible (all mods are within their stability windows)" % [compatible_count])
	
	# Reload the available mods list to update visual indicators
	reload_available()
	
	# Reload the installed mods list to show update notifications
	reload_installed()
	
	# Refresh the currently selected mod's description to show updated release date info
	_refresh_selected_mod_description()


func _check_mod_compatibility() -> void:
	
	# This function provides immediate compatibility checking based on cached data
	# Used as a fallback when async data isn't available yet
	var compatible_mods = 0
	var incompatible_mods = 0
	var mods_with_data = 0
	var mods_without_data = 0
	
	# Check each available mod for compatibility
	for mod_id in _mods.available:
		var release_date = _mods._get_mod_latest_release_date(mod_id)
		if release_date != "":
			mods_with_data += 1
			if _mods.is_mod_compatible(mod_id):
				compatible_mods += 1
			else:
				incompatible_mods += 1
		else:
			mods_without_data += 1
	
	# Post status message about current compatibility state
	if mods_without_data > 0:
		Status.post("Partial compatibility data: %d compatible, %d incompatible (%d mods pending release date fetch)" % [compatible_mods, incompatible_mods, mods_without_data], Enums.MSG_WARN)
	elif incompatible_mods > 0:
		Status.post("Mod compatibility check: %d compatible, %d potentially incompatible mods (based on individual mod release dates vs stability ratings)" % [compatible_mods, incompatible_mods], Enums.MSG_WARN)
	else:
		Status.post("All %d available mods are compatible (all mods are within their stability windows)" % [compatible_mods])


func _on_InstalledList_multi_selected(index: int, selected: bool) -> void:
	
	var selection = Array(_installed_list.get_selected_items())
	var active_idx: int
	if selected:
		active_idx = index
	elif len(selection) > 0:
		active_idx = selection.max()
	
	var active_id = _installed_mods_view[active_idx]["id"]
	_lbl_mod_info.bbcode_text = _make_mod_info_string(_mods.installed[active_id])
	_lbl_mod_info.scroll_to_line(0)
	
	var only_stock_selected = true
	for idx in selection:
		var mod_id = _installed_mods_view[idx]["id"]
		if not _mods.installed[mod_id]["is_stock"]:
			only_stock_selected = false
			break
			
	if (len(selection) == 0) or (only_stock_selected):
		_btn_delete.disabled = true
	else:
		_btn_delete.disabled = false


func _on_AvailableList_multi_selected(index: int, selected: bool) -> void:
	
	var selection = Array(_available_list.get_selected_items())
	var active_idx: int
	if selected:
		active_idx = index
	elif len(selection) > 0:
		active_idx = selection.max()
	
	var active_id = _available_mods_view[active_idx]["id"]
	_lbl_mod_info.bbcode_text = _make_mod_info_string(_mods.available[active_id])
	_lbl_mod_info.scroll_to_line(0)
	
	var only_non_installable_selected = true
	for idx in selection:
		var mod_id = _available_mods_view[idx]["id"]
		if (not mod_id in _mods.installed) or (_mods.installed[mod_id]["is_obsolete"]):
			only_non_installable_selected = false
			break
			
	if (len(selection) == 0) or (only_non_installable_selected):
		_btn_add.disabled = true
	else:
		_btn_add.disabled = false


func _on_BtnDelete_pressed() -> void:
	
	var selection = _installed_list.get_selected_items()
	_mods_to_delete = []
	var skipped_mods = 0
	
	for index in selection:
		var id = _installed_mods_view[index]["id"]
		if not _mods.installed[id]["is_stock"]:
			_mods_to_delete.append(id)
		else:
			skipped_mods += 1
	
	if skipped_mods == 1:
		Status.post(tr("msg_one_mod_is_stock"))
	elif skipped_mods > 1:
		Status.post(tr("msg_n_mods_are_stock") % skipped_mods)
	
	var num = len(_mods_to_delete)
	if num > 1:
		_dlg_del_multiple.dialog_text = tr("dlg_deleting_n_mods_text") % num
		_dlg_del_multiple.get_cancel().text = tr("btn_cancel")
		_dlg_del_multiple.rect_size = Vector2(250, 100)
		_dlg_del_multiple.popup_centered()
		return
	
	_mods.delete_mods(_mods_to_delete)
	yield(_mods, "mod_deletion_finished")
	reload_installed()
	reload_available()


func _on_DeleteMultipleDialog_confirmed() -> void:
	
	_mods.delete_mods(_mods_to_delete)
	yield(_mods, "mod_deletion_finished")
	reload_installed()
	reload_available()


func _on_BtnAddSelectedMod_pressed() -> void:
	
	var selection = _available_list.get_selected_items()
	_mods_to_install = []
	var num_stock = 0
	var incompatible_mods = []
	var missing_dependencies = []
	var active_conflicts = []

	for index in selection:
		var id = _available_mods_view[index]["id"]
		var status = _mods.mod_status(id)
		if status == 2:
			num_stock += 1
		else:
			_mods_to_install.append(id)
			# Check for incompatible mods in all channels (both stable and experimental)
			if not _mods.is_mod_compatible(id):
				incompatible_mods.append(_mods.available[id]["modinfo"]["name"])

	for mod_id in _mods_to_install:
		var modinfo = _mods.available[mod_id]["modinfo"]
		for dependency in modinfo.get("dependencies", []):
			if not dependency in _mods.installed and not dependency in _mods_to_install:
				missing_dependencies.append("%s → %s" % [modinfo["name"], dependency])
		for conflict in modinfo.get("conflicts", []):
			if conflict in _mods.installed or conflict in _mods_to_install:
				active_conflicts.append("%s ↔ %s" % [modinfo["name"], conflict])

	if num_stock == 1:
		Status.post(tr("msg_mod_install_one_mod_skipped"))
	elif num_stock > 1:
		Status.post(tr("msg_mod_install_n_mods_skipped") % num_stock)

	# Warn about incompatible mods
	if len(incompatible_mods) > 0:
		Status.post(tr("msg_mod_incompatible") % _array_to_text_list(incompatible_mods), Enums.MSG_WARN)
	if len(missing_dependencies) > 0:
		Status.post(tr("msg_mod_missing_dependencies") % _array_to_text_list(missing_dependencies), Enums.MSG_WARN)
	if len(active_conflicts) > 0:
		Status.post(tr("msg_mod_active_conflicts") % _array_to_text_list(active_conflicts), Enums.MSG_WARN)

	_ids_to_install = []	# What to install from scratch.
	_ids_to_delete = []		# What to delete before reinstalling.
	_ids_to_reinstall = []	# What to install again after deleteion.
	for mod_id in _mods_to_install:
		
		var status = _mods.mod_status(mod_id)
		if status == 4:
			_ids_to_delete.append(mod_id + "__")
			_ids_to_reinstall.append(mod_id)
		elif status == 1:
			_ids_to_delete.append(mod_id)
			_ids_to_reinstall.append(mod_id)
		elif status in [0, 3]:
			_ids_to_install.append(mod_id)
		
	if len(_ids_to_reinstall) > 0:
		_dlg_reinstall.open(len(_ids_to_reinstall))
	else:
		_do_mod_installation()


func _on_BtnAddAllMods_pressed() -> void:
	
	for i in _available_list.get_item_count():
		_available_list.select(i, false)
		
	_on_BtnAddSelectedMod_pressed()


func _do_mod_installation() -> void:
	
	if len(_ids_to_delete) > 0:
		var legacy_deletes = []
		for id in _ids_to_reinstall:
			if _mods.available[id].get("source_type") != "ccb_registry":
				legacy_deletes.append(id)
		if not legacy_deletes.empty():
			_mods.delete_mods(legacy_deletes)
			yield(_mods, "mod_deletion_finished")
		_mods.install_mods(_ids_to_install + _ids_to_reinstall)
		yield(_mods, "mod_installation_finished")
	else:
		_mods.install_mods(_ids_to_install)
		yield(_mods, "mod_installation_finished")
	
	reload_installed()
	reload_available()
	if Settings.read("game") == "ccb":
		Status.post(tr("str_ccb_activation_hint"), Enums.MSG_INFO)


func _on_ModReinstallDialog_response_yes() -> void:
	
	_do_mod_installation()


func _on_ModReinstallDialog_response_no() -> void:
	
	_ids_to_reinstall.clear()
	_do_mod_installation()


func _refresh_selected_mod_description() -> void:
	
	# Check if a mod is selected in the installed list
	var installed_selection = _installed_list.get_selected_items()
	if len(installed_selection) > 0:
		var index = installed_selection[0]
		var id = _installed_mods_view[index]["id"]
		_lbl_mod_info.bbcode_text = _make_mod_info_string(_mods.installed[id])
		_lbl_mod_info.scroll_to_line(0)
		return
	
	# Check if a mod is selected in the available list
	var available_selection = _available_list.get_selected_items()
	if len(available_selection) > 0:
		var index = available_selection[0]
		var id = _available_mods_view[index]["id"]
		_lbl_mod_info.bbcode_text = _make_mod_info_string(_mods.available[id])
		_lbl_mod_info.scroll_to_line(0)


func _format_links_in_text(text: String) -> String:
	
	# Regular expression to find URLs (http/https)
	var regex = RegEx.new()
	regex.compile("(https?://[^\\s]+)")
	
	var formatted_text = text
	var matches = regex.search_all(text)
	
	# Process matches in reverse order to maintain correct positions
	for i in range(matches.size() - 1, -1, -1):
		var match_result = matches[i]
		var url = match_result.get_string()
		# Format the URL with BBCode and the same color as other links
		var formatted_url = "[color=#3b93f7][url=%s]%s[/url][/color]" % [url, url]
		formatted_text = formatted_text.substr(0, match_result.get_start()) + formatted_url + formatted_text.substr(match_result.get_end())
	
	return formatted_text


func _on_ModInfo_meta_clicked(meta) -> void:
	
	OS.shell_open(meta)
