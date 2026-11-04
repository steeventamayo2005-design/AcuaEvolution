class_name HatcheryBuilder
extends RefCounted
# Genera un hatchery (muros, puertas y letreros) a partir de un JSON de salas.
# Si las salas traen "col" ("W" u "E") se usan tal cual; si no, se usan las listas del hatchery de Anadara.

const WEST := ["recepcion", "maduracion", "desove", "recuperacion", "prelarvicultura", "larvicultura", "asentamiento", "nursery", "pre_engorde", "empaque"]
const EAST := ["lab", "qclab", "algas", "artemia", "colectores_prep", "criopreservacion", "ras", "aireacion", "cip", "tratamiento", "reservorios", "generador", "electrica", "bodega"]
const COL_W := 22.0
const CORR := 3.0
const DOOR := 1.8

static func type_color(t: String) -> Color:
    match t:
        "bio": return Color(0.55, 0.75, 0.6)
        "feed": return Color(0.7, 0.8, 0.4)
        "power": return Color(0.85, 0.75, 0.4)
        "water": return Color(0.5, 0.75, 0.85)
        "ras": return Color(0.65, 0.6, 0.8)
    return Color(0.7, 0.75, 0.8)

static func _split(list: Array) -> Dictionary:
    var by_id := {}
    var west: Array = []
    var east: Array = []
    var has_col := false
    for r in list:
        by_id[r.id] = r
        if r.has("col"):
            has_col = true
    if has_col:
        for r in list:
            if r.id == "acceso":
                continue
            if r.col == "W":
                west.append(r.id)
            else:
                east.append(r.id)
    else:
        for id in WEST:
            if by_id.has(id):
                west.append(id)
        for id in EAST:
            if by_id.has(id):
                east.append(id)
    return {"by_id": by_id, "west": west, "east": east}

static func _depth(by_id: Dictionary, ids: Array) -> float:
    var s := 0.0
    for id in ids:
        var r = by_id[id]
        s += maxf(4.0, r.w * r.d / COL_W)
    return s

static func dims(json_text: String) -> Vector2:
    var sp := _split(JSON.parse_string(json_text))
    return Vector2(COL_W * 2.0 + CORR, 8.0 + maxf(_depth(sp.by_id, sp.west), _depth(sp.by_id, sp.east)))

static func build(parent: Node3D, json_text: String, origin: Vector3) -> Vector3:
    var sp := _split(JSON.parse_string(json_text))
    var by_id: Dictionary = sp.by_id
    var root := Node3D.new()
    root.name = "Hatchery"
    root.position = origin
    parent.add_child(root)
    var wall := Mats.pbr("stucco", 1.5, Color(0.92, 0.94, 0.95))
    var total_w := COL_W * 2.0 + CORR
    var acc_d := 8.0
    _room(root, "acceso", "ACC-00 · Acceso y Descontaminación", "control", 0.0, 0.0, total_w, acc_d, 3.6, wall, "N")
    var zw := acc_d
    var ze := acc_d
    for id in sp.west:
        var r = by_id[id]
        var d := maxf(4.0, r.w * r.d / COL_W)
        _room(root, id, "%s · %s" % [r.code, r.name], r.type, 0.0, zw, COL_W, d, r.h, wall, "E")
        zw += d
    for id in sp.east:
        var r = by_id[id]
        var d := maxf(4.0, r.w * r.d / COL_W)
        _room(root, id, "%s · %s" % [r.code, r.name], r.type, COL_W + CORR, ze, COL_W, d, r.h, wall, "W")
        ze += d
    return origin + Vector3(total_w / 2.0, 0.1, 2.0)

static func _room(root: Node3D, id: String, label: String, type: String, x0: float, z0: float, w: float, d: float, h: float, wall: Material, door_side: String) -> void:
    var g := Node3D.new()
    g.name = id
    root.add_child(g)
    var fm := StandardMaterial3D.new()
    fm.albedo_color = type_color(type)
    fm.roughness = 0.4
    _box(g, Vector3(x0 + w / 2.0, -0.05, z0 + d / 2.0), Vector3(w, 0.1, d), fm)
    var nd := -1.0
    if door_side == "N":
        nd = w / 2.0
    _seg(g, x0, z0, x0 + w, z0, h, wall, nd, true)
    _seg(g, x0, z0 + d, x0 + w, z0 + d, h, wall, nd, true)
    if door_side == "E":
        _seg(g, x0, z0, x0, z0 + d, h, wall, -1.0, false)
        _seg(g, x0 + w, z0, x0 + w, z0 + d, h, wall, d / 2.0, false)
    elif door_side == "W":
        _seg(g, x0 + w, z0, x0 + w, z0 + d, h, wall, -1.0, false)
        _seg(g, x0, z0, x0, z0 + d, h, wall, d / 2.0, false)
    else:
        _seg(g, x0, z0, x0, z0 + d, h, wall, -1.0, false)
        _seg(g, x0 + w, z0, x0 + w, z0 + d, h, wall, -1.0, false)
    var l := Label3D.new()
    l.text = label
    l.font_size = 48
    l.pixel_size = 0.008
    l.modulate = Color(0.1, 0.2, 0.25)
    l.position = Vector3(x0 + w / 2.0, h - 0.5, z0 + 0.3)
    g.add_child(l)

static func _seg(g: Node3D, x0: float, z0: float, x1: float, z1: float, h: float, m: Material, door_at: float, along_x: bool) -> void:
    if door_at < 0.0:
        _piece(g, x0, z0, x1, z1, 0.0, h, m)
        return
    var length := (x1 - x0) if along_x else (z1 - z0)
    var a := maxf(0.0, door_at - DOOR / 2.0)
    var b := minf(length, door_at + DOOR / 2.0)
    if along_x:
        _piece(g, x0, z0, x0 + a, z1, 0.0, h, m)
        _piece(g, x0 + b, z0, x1, z1, 0.0, h, m)
        _piece(g, x0 + a, z0, x0 + b, z1, 2.2, h, m)
    else:
        _piece(g, x0, z0, x1, z0 + a, 0.0, h, m)
        _piece(g, x0, z0 + b, x1, z1, 0.0, h, m)
        _piece(g, x0, z0 + a, x1, z0 + b, 2.2, h, m)

static func _piece(g: Node3D, x0: float, z0: float, x1: float, z1: float, y0: float, y1: float, m: Material) -> void:
    var t := 0.2
    var sx := absf(x1 - x0)
    var sz := absf(z1 - z0)
    if (sx < 0.01 and sz < 0.01) or (y1 - y0) < 0.01:
        return
    _box(g, Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0), Vector3(maxf(sx, t), y1 - y0, maxf(sz, t)), m)

static func _box(parent: Node3D, pos: Vector3, size: Vector3, m: Material) -> void:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = m
    mi.position = pos
    parent.add_child(mi)
    var sb := StaticBody3D.new()
    var cs := CollisionShape3D.new()
    var bs := BoxShape3D.new()
    bs.size = size
    cs.shape = bs
    sb.add_child(cs)
    mi.add_child(sb)
