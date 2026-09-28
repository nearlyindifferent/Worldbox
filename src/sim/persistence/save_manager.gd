class_name SaveManager
extends RefCounted
## Versioned, checksummed world persistence.
##
## Slot layout: <root>/<slot>/world.sav, meta.json, thumb.png
## world.sav container (little endian):
##   magic "HMSV" | u32 container_version | u32 schema | u32 raw_len | u32 packed_len
##   | 32-byte SHA-256 of packed payload | packed payload (zstd(var_to_bytes(dict)))
## The payload is a plain Variant tree built by Simulation.to_dict(); no Objects are
## ever encoded (var_to_bytes without objects), so loading cannot instantiate code.
## Writes go to a temp file first and are renamed into place.

const MAGIC := "HMSV"
const CONTAINER_VERSION := 1
const DEFAULT_ROOT := "user://saves"
const AUTOSAVE_SLOTS := ["autosave_1", "autosave_2", "autosave_3"]

var root: String = DEFAULT_ROOT


func _init(p_root: String = DEFAULT_ROOT) -> void:
	root = p_root


func slot_dir(slot: String) -> String:
	return root.path_join(slot)


static func valid_slot_name(slot: String) -> bool:
	if slot.is_empty() or slot.length() > 40:
		return false
	for ch in slot:
		if not (ch.is_valid_identifier() or ch in "0123456789-_"):
			return false
	return true


func save_slot(sim: Simulation, slot: String, thumbnail: Image = null, extra_meta: Dictionary = {}) -> Dictionary:
	if not valid_slot_name(slot):
		return {"ok": false, "msg": "Invalid slot name"}
	var t0 := Time.get_ticks_msec()
	var dir := slot_dir(slot)
	DirAccess.make_dir_recursive_absolute(dir)
	var raw := var_to_bytes(sim.to_dict())
	var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)
	var digest := _sha256(packed)
	var tmp := dir.path_join("world.sav.tmp")
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "msg": "Cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())]}
	f.store_buffer(MAGIC.to_ascii_buffer())
	f.store_32(CONTAINER_VERSION)
	f.store_32(Simulation.SAVE_SCHEMA)
	f.store_32(raw.size())
	f.store_32(packed.size())
	f.store_buffer(digest)
	f.store_buffer(packed)
	f.close()
	var final_path := dir.path_join("world.sav")
	if FileAccess.file_exists(final_path):
		DirAccess.remove_absolute(final_path)
	var err := DirAccess.rename_absolute(tmp, final_path)
	if err != OK:
		return {"ok": false, "msg": "Rename failed: %s" % error_string(err)}
	var humans := sim.count_species(sim.human_species)
	var meta := {
		"slot": slot, "saved_unix": Time.get_unix_time_from_system(), "saved_at": Time.get_datetime_string_from_system(),
		"container_version": CONTAINER_VERSION, "schema": Simulation.SAVE_SCHEMA, "seed": sim.seed_value,
		"shape": sim.shape, "width": sim.world.width, "height": sim.world.height, "tick": sim.tick,
		"date": sim.date_string(), "population": humans, "animals": sim.units.count - humans,
		"cities": sim.cities.size(), "bytes": packed.size() + 52, "engine": Engine.get_version_info()["string"],
	}
	meta.merge(extra_meta, true)
	var mf := FileAccess.open(dir.path_join("meta.json"), FileAccess.WRITE)
	if mf:
		mf.store_string(JSON.stringify(meta, "  "))
		mf.close()
	if thumbnail != null:
		thumbnail.save_png(dir.path_join("thumb.png"))
	return {"ok": true, "msg": "Saved to %s" % slot, "bytes": meta["bytes"], "ms": Time.get_ticks_msec() - t0}


func load_slot(slot: String) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var r := read_payload(slot_dir(slot).path_join("world.sav"))
	if not r["ok"]:
		return r
	var d: Dictionary = r["data"]
	var mig := SaveMigrations.migrate(d)
	if not mig["ok"]:
		return mig
	var sim := Simulation.from_dict(mig["data"])
	return {"ok": true, "sim": sim, "msg": "Loaded %s" % slot, "ms": Time.get_ticks_msec() - t0}


## Validates the container and returns {"ok", "data"|"msg"}. Never trusts lengths blindly.
static func read_payload(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "msg": "Save file not found"}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "msg": "Cannot open save file"}
	var total := f.get_length()
	if total < 52:
		return {"ok": false, "msg": "Save file is truncated"}
	if f.get_buffer(4).get_string_from_ascii() != MAGIC:
		return {"ok": false, "msg": "Not a world save (bad magic)"}
	var cver := f.get_32()
	if cver > CONTAINER_VERSION:
		return {"ok": false, "msg": "Save was made by a newer version (container %d)" % cver}
	var schema := f.get_32()
	var raw_len := f.get_32()
	var packed_len := f.get_32()
	var digest := f.get_buffer(32)
	if packed_len != total - 52 or raw_len <= 0 or raw_len > 1 << 30:
		return {"ok": false, "msg": "Save file is corrupted (length mismatch)"}
	var packed := f.get_buffer(packed_len)
	f.close()
	if _sha256(packed) != digest:
		return {"ok": false, "msg": "Save file is corrupted (checksum mismatch)"}
	var raw := packed.decompress(raw_len, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != raw_len:
		return {"ok": false, "msg": "Save file is corrupted (decompression failed)"}
	var v: Variant = bytes_to_var(raw)
	if typeof(v) != TYPE_DICTIONARY:
		return {"ok": false, "msg": "Save payload is not a world"}
	var d: Dictionary = v
	if int(d.get("schema", -1)) != schema:
		return {"ok": false, "msg": "Save header/payload schema mismatch"}
	return {"ok": true, "data": d}


func read_meta(slot: String) -> Dictionary:
	var p := slot_dir(slot).path_join("meta.json")
	if not FileAccess.file_exists(p):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	return v if typeof(v) == TYPE_DICTIONARY else {}


func thumbnail_path(slot: String) -> String:
	return slot_dir(slot).path_join("thumb.png")


## Metadata of every slot that holds a world, newest first.
func list_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var d := DirAccess.open(root)
	if d == null:
		return out
	for name in d.get_directories():
		if FileAccess.file_exists(slot_dir(name).path_join("world.sav")):
			var m := read_meta(name)
			m["slot"] = name
			out.append(m)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("saved_unix", 0)) > float(b.get("saved_unix", 0)))
	return out


func delete_slot(slot: String) -> bool:
	if not valid_slot_name(slot):
		return false
	var dir := slot_dir(slot)
	for f in ["world.sav", "meta.json", "thumb.png", "world.sav.tmp"]:
		if FileAccess.file_exists(dir.path_join(f)):
			DirAccess.remove_absolute(dir.path_join(f))
	return DirAccess.remove_absolute(dir) == OK


## Oldest-first rotation across AUTOSAVE_SLOTS.
func next_autosave_slot() -> String:
	var oldest := AUTOSAVE_SLOTS[0]
	var oldest_t := INF
	for s: String in AUTOSAVE_SLOTS:
		var m := read_meta(s)
		var t := float(m.get("saved_unix", -1.0))
		if t < oldest_t:
			oldest_t = t
			oldest = s
	return oldest


static func _sha256(data: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data)
	return ctx.finish()
