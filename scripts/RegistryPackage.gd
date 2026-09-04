extends Reference


# Registry packages contain one MOD, either at the ZIP root or in one folder.
func find_mod(root: String, mod_id: String) -> String:
	if valid_mod(root, mod_id):
		return root
	var matches = []
	for child in FS.list_dir(root):
		var path = root.plus_file(child)
		if Directory.new().dir_exists(path) and valid_mod(path, mod_id):
			matches.append(path)
	return matches[0] if matches.size() == 1 else ""


func valid_mod(path: String, mod_id: String) -> bool:
	var file = File.new()
	if file.file_exists(path.plus_file("modinfo.json")):
		if file.open(path.plus_file("modinfo.json"), File.READ) != OK:
			return false
		var parsed = JSON.parse(file.get_as_text())
		file.close()
		if parsed.error != OK:
			return false
		var entries = parsed.result
		if typeof(entries) == TYPE_DICTIONARY:
			entries = [entries]
		if typeof(entries) != TYPE_ARRAY:
			return false
		var ids = []
		for entry in entries:
			if typeof(entry) == TYPE_DICTIONARY and entry.get("type") == "MOD_INFO":
				ids.append(entry.get("id", entry.get("ident", "")))
		return ids == [mod_id]
	return file.file_exists(path.plus_file("main.lua"))


# The caller downloads and validates before reaching this point. Rename on
# the same volume makes replacement all-or-nothing; keep backups outside mods.
func replace_directory(source: String, destination: String, backup: String) -> int:
	var directory = Directory.new()
	if not directory.dir_exists(source) or directory.dir_exists(backup) or directory.file_exists(backup):
		return ERR_ALREADY_EXISTS
	var had_old = directory.dir_exists(destination)
	if had_old:
		var error = directory.make_dir_recursive(backup.get_base_dir())
		if error != OK:
			return error
		error = directory.rename(destination, backup)
		if error != OK:
			return error
	var error = directory.rename(source, destination)
	if error != OK and had_old:
		var restore_error = directory.rename(backup, destination)
		if restore_error != OK:
			Status.post(tr("msg_ccb_restore_failed") % backup, Enums.MSG_ERROR)
	return error
