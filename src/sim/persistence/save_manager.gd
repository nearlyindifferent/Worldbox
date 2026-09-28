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
const HEADER_BYTES := 52
## Upper bounds checked before allocating anything a file asks for.
const MAX_RAW_BYTES := 256 * 1024 * 1024
const MAX_PACKED_BYTES := 128 * 1024 * 1024
const RESERVED_NAMES := ["con", "prn", "aux", "nul", "com1", "com2", "com3", "com4", "com5", "com6", "com7", "com8", "com9",
	"lpt1", "lpt2", "lpt3", "lpt4", "lpt5", "lpt6", "lpt7", "lpt8", "lpt9"]
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
	return not RESERVED_NAMES.has(slot.to_lower())


func save_slot(sim: Simulation, slot: String, thumbnail: Image = null, extra_meta: Dictionary = {}) -> Dictionary:
	if not valid_slot_name(slot):
		return {"ok": false, "msg": "Invalid slot name"}
	var t0 := Time.get_ticks_msec()
	var dir := slot_dir(slot)
	DirAccess.make_dir_recursive_absolute(dir)
	# A half-drawn brush stroke is closed so the saved undo history equals the live one.
	sim.editor.end_stroke()
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
	f.flush()
	f.close()
	# Replace without a window where no valid file exists: old -> .bak, tmp -> final,
	# then drop .bak. load_slot recovers from .bak or a complete .tmp after a crash.
	var final_path := dir.path_join("world.sav")
	var bak := dir.path_join("world.sav.bak")
	if FileAccess.file_exists(bak):
		DirAccess.remove_absolute(bak)
	if FileAccess.file_exists(final_path):
		var e1 := DirAccess.rename_absolute(final_path, bak)
		if e1 != OK:
			return {"ok": false, "msg": "Cannot back up previous save: %s" % error_string(e1)}
	var err := DirAccess.rename_absolute(tmp, final_path)
	if err != OK:
		return {"ok": false, "msg": "Rename failed: %s" % error_string(err)}
	if FileAccess.file_exists(bak):
		DirAccess.remove_absolute(bak)
	var humans := sim.count_species(sim.human_species)
	var meta := {
		"slot": slot, "saved_unix": Time.get_unix_time_from_system(), "saved_at": Time.get_datetime_string_from_system(),
		"container_version": CONTAINER_VERSION, "schema": Simulation.SAVE_SCHEMA, "seed": sim.seed_value,
		"shape": sim.shape, "width": sim.world.width, "height": sim.world.height, "tick": sim.tick,
		"date": sim.date_string(), "population": humans, "animals": sim.units.count - humans,
		"cities": sim.cities.size(), "bytes": packed.size() + HEADER_BYTES, "engine": Engine.get_version_info()["string"],
	}
	meta.merge(extra_meta, true)
	var meta_tmp := dir.path_join("meta.json.tmp")
	var mf := FileAccess.open(meta_tmp, FileAccess.WRITE)
	if mf:
		mf.store_string(JSON.stringify(meta, "  "))
		mf.close()
		if FileAccess.file_exists(dir.path_join("meta.json")):
			DirAccess.remove_absolute(dir.path_join("meta.json"))
		DirAccess.rename_absolute(meta_tmp, dir.path_join("meta.json"))
	if thumbnail != null:
		thumbnail.save_png(dir.path_join("thumb.png"))
	return {"ok": true, "msg": "Saved to %s" % slot, "bytes": meta["bytes"], "ms": Time.get_ticks_msec() - t0}


func load_slot(slot: String) -> Dictionary:
	if not valid_slot_name(slot):
		return {"ok": false, "msg": "Invalid slot name"}
	var t0 := Time.get_ticks_msec()
	var dir := slot_dir(slot)
	# Primary file first, then crash-recovery candidates.
	var r := {"ok": false, "msg": "Save file not found"}
	var used := ""
	for name in ["world.sav", "world.sav.bak", "world.sav.tmp"]:
		var p := dir.path_join(name)
		if not FileAccess.file_exists(p):
			continue
		var attempt := read_payload(p)
		if attempt["ok"]:
			r = attempt
			used = name
			break
		if name == "world.sav":
			r = attempt
	if not r["ok"]:
		return r
	var mig := SaveMigrations.migrate(r["data"])
	if not mig["ok"]:
		return mig
	var built := Simulation.from_save(mig["data"])
	if not built["ok"]:
		return built
	var msg := "Loaded %s" % slot
	if used != "world.sav":
		msg += " (recovered from %s)" % used
	return {"ok": true, "sim": built["sim"], "msg": msg, "ms": Time.get_ticks_msec() - t0, "recovered": used != "world.sav"}


## Validates the container and returns {"ok", "data"|"msg"}. Never trusts lengths blindly.
static func read_payload(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "msg": "Save file not found"}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "msg": "Cannot open save file"}
	var total := f.get_length()
	if total < HEADER_BYTES:
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
	if packed_len != total - HEADER_BYTES or raw_len <= 0:
		return {"ok": false, "msg": "Save file is corrupted (length mismatch)"}
	if raw_len > MAX_RAW_BYTES or packed_len > MAX_PACKED_BYTES:
		return {"ok": false, "msg": "Save file is too large to be a world (%d MB)" % (raw_len >> 20)}
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
	if not valid_slot_name(slot):
		return {}
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
		if not valid_slot_name(name):
			continue
		var sd := slot_dir(name)
		if FileAccess.file_exists(sd.path_join("world.sav")) or FileAccess.file_exists(sd.path_join("world.sav.bak")) or FileAccess.file_exists(sd.path_join("world.sav.tmp")):
			var m := read_meta(name)
			m["slot"] = name
			out.append(m)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("saved_unix", 0)) > float(b.get("saved_unix", 0)))
	return out


func delete_slot(slot: String) -> bool:
	if not valid_slot_name(slot):
		return false
	var dir := slot_dir(slot)
	for f in ["world.sav", "meta.json", "thumb.png", "world.sav.tmp", "world.sav.bak", "meta.json.tmp"]:
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
