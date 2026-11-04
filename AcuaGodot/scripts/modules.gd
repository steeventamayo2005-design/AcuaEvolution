class_name Modules
extends RefCounted
# Modelos 3D de los edificios del plano que no son la nave ni los hatcheries.

const SHEDS := ["compostera", "colector_lodo", "alg", "dap", "zoo", "bsf", "lom", "hid", "aco", "aer", "hor", "hob", "scada", "hub", "genetics_lab", "fillet_plant", "meal_plant", "desal"]

static func build(campus: Node3D, pivot: Node3D, b: Dictionary, d: Dictionary, sz: Vector2) -> void:
    var shape: String = d.get("shape", "box")
    var id: String = b.id
    if Ops.has(b):
        var bc = load("res://scripts/beacon.gd").new()
        bc.uid = int(b.get("uid", -1))
        bc.position = Vector3(sz.x / 2.0 - 0.7, 4.6, sz.y / 2.0 - 0.7)
        pivot.add_child(bc)
    if id in SHEDS:
        _shed(pivot, id, d, sz)
        if id == "desal":
            _desal_tanks(pivot, sz)
        return
    match shape:
        "circle":
            _basin_circle(pivot, d, sz)
        "pond", "algae", "raceway":
            _basin_rect(pivot, id, d, sz)
        "solar":
            _solar(pivot, sz)
        "wind":
            _wind(campus, pivot)
        "silo":
            _silo(pivot, id, d, sz)
        _:
            _block(pivot, d, sz)

static func _school(parent: Node3D, kind: String, col: Color, count: int, half: Vector2, water_y: float, depth: float, circ: bool, scl: float) -> void:
    var sc = load("res://scripts/school.gd").new()
    sc.kind = kind
    sc.color = col
    sc.count = count
    sc.half = half
    sc.water_y = water_y
    sc.depth = depth
    sc.circular = circ
    sc.scale_f = scl
    parent.add_child(sc)
    sc.setup()

static func _basin_circle(pivot: Node3D, d: Dictionary, sz: Vector2) -> void:
    var r := minf(sz.x, sz.y) / 2.0
    var conc := Mats.pbr("dconc", 1.6, Color(0.3, 0.3, 0.3))
    var n := 20
    for i in n:
        var a := i * TAU / n
        var seg := Nave.box(pivot, Vector3(cos(a) * (r - 0.2), 0.6, sin(a) * (r - 0.2)), Vector3(TAU * r / n + 0.1, 1.2, 0.4), conc)
        seg.rotation.y = -a + PI / 2.0
    var disc := Nave.cyl(pivot, Vector3(0, 0.06, 0), r - 0.3, 0.1, Mats.plain(Color(0.07, 0.2, 0.22), 0.6))
    disc.name = "Fondo"
    var wm := Mats.water()
    var water := Nave.cyl(pivot, Vector3(0, 1.0, 0), r - 0.35, 0.04, wm)
    water.name = "Agua"
    _school(pivot, "fish", Color(0.95, 0.55, 0.3), 14, Vector2(r - 1.0, r - 1.0), 1.0, 0.7, true, 0.3)

static func _basin_rect(pivot: Node3D, id: String, d: Dictionary, sz: Vector2) -> void:
    var conc := Mats.pbr("dconc", 1.6, Color(0.3, 0.3, 0.3))
    var t := 0.3
    var hgt := 1.0
    Nave.box(pivot, Vector3(0, 0.05, 0), Vector3(sz.x, 0.1, sz.y), Mats.plain(Color(0.07, 0.2, 0.22), 0.6), false)
    Nave.box(pivot, Vector3(0, hgt / 2.0, -sz.y / 2.0 + t / 2.0), Vector3(sz.x, hgt, t), conc)
    Nave.box(pivot, Vector3(0, hgt / 2.0, sz.y / 2.0 - t / 2.0), Vector3(sz.x, hgt, t), conc)
    Nave.box(pivot, Vector3(-sz.x / 2.0 + t / 2.0, hgt / 2.0, 0), Vector3(t, hgt, sz.y - 2.0 * t), conc)
    Nave.box(pivot, Vector3(sz.x / 2.0 - t / 2.0, hgt / 2.0, 0), Vector3(t, hgt, sz.y - 2.0 * t), conc)
    var wm := Mats.water()
    if id == "alg" or id == "dap" or id == "zoo":
        wm.albedo_color = Color(0.2, 0.5, 0.2, 0.85) if id == "alg" else Color(0.5, 0.4, 0.2, 0.85)
    elif id == "macroalgas_ulva":
        wm.albedo_color = Color(0.1, 0.35, 0.2, 0.8)
    var wp := MeshInstance3D.new()
    var pm := PlaneMesh.new()
    pm.size = Vector2(sz.x - 2.0 * t, sz.y - 2.0 * t)
    wp.mesh = pm
    wp.material_override = wm
    wp.position = Vector3(0, hgt - 0.1, 0)
    pivot.add_child(wp)
    var half := Vector2((sz.x - 2.0 * t) / 2.0 - 0.8, (sz.y - 2.0 * t) / 2.0 - 0.6)
    match id:
        "kreisel_medusas":
            _school(pivot, "jelly", Color(0.6, 0.5, 0.95), 10, half, hgt - 0.1, 0.5, false, 0.8)
        "estanque_camaron":
            _school(pivot, "shrimp", Color.WHITE, 26, half, hgt - 0.1, 0.55, false, 0.6)
        "macroalgas_ulva":
            _school(pivot, "algae", Color(0.25, 0.75, 0.22), 18, half, hgt - 0.1, 0.55, false, 1.0)
        "raceway_trucha":
            _school(pivot, "fish", Color(0.62, 0.72, 0.82), 22, half, hgt - 0.1, 0.6, false, 0.3)

static func _solar(pivot: Node3D, sz: Vector2) -> void:
    var panel := Mats.plain(Color(0.08, 0.14, 0.32), 0.15, 0.7)
    panel.emission_enabled = true
    panel.emission = Color(0.05, 0.1, 0.3)
    var rows := maxi(2, int(sz.y / 3.0))
    for i in rows:
        var z := -sz.y / 2.0 + (i + 0.5) * sz.y / rows
        var p := Nave.box(pivot, Vector3(0, 1.4, z), Vector3(sz.x - 1.0, 0.06, 2.0), panel)
        p.rotation_degrees.x = -28.0
        Nave.box(pivot, Vector3(-sz.x / 2.0 + 1.0, 0.6, z), Vector3(0.12, 1.2, 0.12), Mats.plain(Color(0.6, 0.6, 0.62), 0.4, 0.8), false)
        Nave.box(pivot, Vector3(sz.x / 2.0 - 1.0, 0.6, z), Vector3(0.12, 1.2, 0.12), Mats.plain(Color(0.6, 0.6, 0.62), 0.4, 0.8), false)

static func _wind(campus: Node3D, pivot: Node3D) -> void:
    var white := Mats.plain(Color(0.94, 0.95, 0.97), 0.4)
    Nave.cyl(pivot, Vector3(0, 14.0, 0), 0.4, 28.0, white)
    Nave.box(pivot, Vector3(0, 28.4, 0.4), Vector3(0.9, 0.9, 2.2), white, false)
    var hub := Node3D.new()
    hub.position = Vector3(0, 28.4, 1.6)
    pivot.add_child(hub)
    Nave.ball(hub, Vector3.ZERO, 0.5, white)
    for i in 3:
        var arm := Node3D.new()
        arm.rotation.z = i * TAU / 3.0
        hub.add_child(arm)
        Nave.box(arm, Vector3(0, 7.0, 0), Vector3(0.7, 14.0, 0.12), white, false)
    campus.winds.append(hub)

static func _silo(pivot: Node3D, id: String, d: Dictionary, sz: Vector2) -> void:
    var c: Color = d.get("color", Color(0.6, 0.6, 0.55))
    var r := minf(sz.x, sz.y) / 2.0
    var hgt := 6.0
    if id == "nuclear":
        hgt = 14.0
    Nave.cyl(pivot, Vector3(0, hgt / 2.0, 0), r, hgt, Mats.plain(c, 0.5, 0.2))
    var roof := MeshInstance3D.new()
    var hs := SphereMesh.new()
    hs.radius = r
    hs.height = r
    hs.is_hemisphere = true
    roof.mesh = hs
    roof.material_override = Mats.plain(c.darkened(0.15), 0.4, 0.3)
    roof.position = Vector3(0, hgt, 0)
    pivot.add_child(roof)
    if id == "nuclear":
        for sx in [-1.0, 1.0]:
            var tower := CylinderMesh.new()
            tower.top_radius = 4.0
            tower.bottom_radius = 6.5
            tower.height = 16.0
            var tm := MeshInstance3D.new()
            tm.mesh = tower
            tm.material_override = Mats.plain(Color(0.85, 0.85, 0.83), 0.7)
            tm.position = Vector3(sx * 22.0, 8.0, 0)
            pivot.add_child(tm)

static func _block(pivot: Node3D, d: Dictionary, sz: Vector2) -> void:
    var c: Color = d.get("color", Color(0.55, 0.55, 0.55))
    var hgt := 3.0
    Nave.box(pivot, Vector3(0, hgt / 2.0, 0), Vector3(sz.x, hgt, sz.y), Mats.plain(c, 0.6, 0.2))
    Nave.box(pivot, Vector3(0, hgt + 0.1, 0), Vector3(sz.x + 0.4, 0.2, sz.y + 0.4), Mats.plain(c.darkened(0.35), 0.6, 0.3), false)

static func _desal_tanks(pivot: Node3D, sz: Vector2) -> void:
    for i in 4:
        var x := -sz.x / 2.0 + (i + 0.5) * sz.x / 4.0
        Nave.cyl(pivot, Vector3(x, 2.0, sz.y / 2.0 + 1.6), 0.8, 4.0, Mats.plain(Color(0.85, 0.88, 0.9), 0.3, 0.5))

# ---------------------------------------------------------------- galpón con puerta
static func _shed(pivot: Node3D, id: String, d: Dictionary, sz: Vector2) -> void:
    var wall := Mats.pbr("wall", 0.8, Color(0.16, 0.43, 0.41), 0.3)
    if id == "scada" or id == "genetics_lab" or id == "hub":
        wall = Mats.pbr("stucco", 1.5, Color(0.72, 0.66, 0.52))
    var hgt := 3.6
    var t := 0.25
    var door := 2.4
    Nave.box(pivot, Vector3(0, -0.04, 0), Vector3(sz.x, 0.08, sz.y), Mats.pbr("floor", 3.2, Color(0.7, 0.7, 0.68)), false)
    Nave.box(pivot, Vector3(0, hgt / 2.0, -sz.y / 2.0 + t / 2.0), Vector3(sz.x, hgt, t), wall)
    Nave.box(pivot, Vector3(-sz.x / 2.0 + t / 2.0, hgt / 2.0, 0), Vector3(t, hgt, sz.y), wall)
    Nave.box(pivot, Vector3(sz.x / 2.0 - t / 2.0, hgt / 2.0, 0), Vector3(t, hgt, sz.y), wall)
    var seg := (sz.x - door) / 2.0
    Nave.box(pivot, Vector3(-door / 2.0 - seg / 2.0, hgt / 2.0, sz.y / 2.0 - t / 2.0), Vector3(seg, hgt, t), wall)
    Nave.box(pivot, Vector3(door / 2.0 + seg / 2.0, hgt / 2.0, sz.y / 2.0 - t / 2.0), Vector3(seg, hgt, t), wall)
    Nave.box(pivot, Vector3(0, hgt - 0.6, sz.y / 2.0 - t / 2.0), Vector3(door, 1.2, t), wall, false)
    Nave.box(pivot, Vector3(0, hgt + 0.1, 0), Vector3(sz.x + 0.4, 0.2, sz.y + 0.4), Mats.plain(Color(0.2, 0.25, 0.25), 0.6, 0.5))
    var l := OmniLight3D.new()
    l.omni_range = maxf(sz.x, sz.y) * 0.9
    l.light_energy = 1.1
    l.light_color = Color(1.0, 0.95, 0.85)
    l.position = Vector3(0, hgt - 0.5, 0)
    pivot.add_child(l)
    Nave.box(pivot, Vector3(0, hgt - 0.2, 0), Vector3(sz.x * 0.5, 0.08, 0.5), Mats.lamp(Color(1, 1, 1), 1.0), false)
    _interior(pivot, id, sz)

static func _interior(pivot: Node3D, id: String, sz: Vector2) -> void:
    var steel := Mats.plain(Color(0.6, 0.63, 0.66), 0.35, 0.8)
    var dark := Mats.plain(Color(0.08, 0.08, 0.09), 0.4, 0.5)
    var wood := Mats.pbr("wood", 1.2, Color(0.5, 0.33, 0.18))
    var rows := maxi(2, int((sz.y - 3.0) / 2.2))
    match id:
        "bsf":
            for i in rows:
                var z := -sz.y / 2.0 + 1.6 + i * 2.2
                Nave.box(pivot, Vector3(0, 0.4, z), Vector3(sz.x - 3.0, 0.8, 1.0), Mats.plain(Color(0.4, 0.28, 0.15), 0.9))
                for k in 12:
                    Nave.ball(pivot, Vector3(-sz.x / 2.0 + 2.0 + k * (sz.x - 4.0) / 12.0, 0.9, z), 0.12, Mats.plain(Color(0.9, 0.8, 0.45), 0.6))
        "lom":
            for i in rows:
                Nave.box(pivot, Vector3(0, 0.3, -sz.y / 2.0 + 1.6 + i * 2.0), Vector3(sz.x - 2.0, 0.6, 1.0), Mats.plain(Color(0.25, 0.15, 0.09), 0.95))
        "hid", "aco":
            for i in rows:
                var z := -sz.y / 2.0 + 1.6 + i * 2.2
                for lvl in 3:
                    Nave.box(pivot, Vector3(0, 0.6 + lvl * 0.8, z), Vector3(sz.x - 3.0, 0.1, 0.5), Mats.plain(Color(0.9, 0.92, 0.9), 0.4))
                    for k in 14:
                        Nave.ball(pivot, Vector3(-sz.x / 2.0 + 2.0 + k * (sz.x - 4.0) / 14.0, 0.75 + lvl * 0.8, z), 0.15, Mats.plain(Color(0.2, 0.65, 0.2), 0.7))
        "aer":
            for i in 5:
                Nave.cyl(pivot, Vector3(-sz.x / 2.0 + 1.5 + i * (sz.x - 3.0) / 4.0, 1.4, 0), 0.3, 2.8, Mats.plain(Color(0.85, 0.9, 0.85), 0.4))
                Nave.ball(pivot, Vector3(-sz.x / 2.0 + 1.5 + i * (sz.x - 3.0) / 4.0, 2.9, 0), 0.35, Mats.plain(Color(0.25, 0.7, 0.25), 0.7))
        "hor", "hob":
            var cap := Color(0.9, 0.9, 0.85) if id == "hob" else Color(0.85, 0.4, 0.4)
            for i in 2:
                var z := -sz.y / 2.0 + 1.8 + i * 2.2
                for lvl in 3:
                    Nave.box(pivot, Vector3(0, 0.5 + lvl * 0.7, z), Vector3(sz.x - 2.0, 0.06, 0.8), wood, false)
                    for k in 10:
                        var m := Nave.ball(pivot, Vector3(-sz.x / 2.0 + 1.5 + k * (sz.x - 3.0) / 10.0, 0.58 + lvl * 0.7, z), 0.1, Mats.plain(cap, 0.7))
                        m.scale = Vector3(1.3, 0.6, 1.3)
        "scada":
            for i in 3:
                var x := -sz.x / 2.0 + 2.0 + i * (sz.x - 4.0) / 2.0
                Nave.box(pivot, Vector3(x, 0.4, -sz.y / 2.0 + 1.2), Vector3(2.2, 0.8, 0.9), wood)
                Nave.box(pivot, Vector3(x, 1.2, -sz.y / 2.0 + 1.0), Vector3(1.6, 0.9, 0.06), dark, false)
                Nave.box(pivot, Vector3(x, 1.2, -sz.y / 2.0 + 1.04), Vector3(1.5, 0.8, 0.02), Mats.lamp(Color(0.1, 0.6, 0.7), 1.3), false)
            Nave.box(pivot, Vector3(0, 2.0, -sz.y / 2.0 + 0.3), Vector3(sz.x - 2.0, 1.2, 0.06), Mats.lamp(Color(0.1, 0.5, 0.65), 1.0), false)
        "hub":
            for i in 5:
                var x := -sz.x / 2.0 + 1.2 + i * (sz.x - 2.4) / 4.0
                Nave.box(pivot, Vector3(x, 1.1, -sz.y / 2.0 + 1.0), Vector3(0.9, 2.2, 0.9), dark)
                for k in 6:
                    Nave.box(pivot, Vector3(x, 0.4 + k * 0.32, -sz.y / 2.0 + 0.5), Vector3(0.7, 0.05, 0.02), Mats.lamp(Color(0.2, 1.0, 0.4) if k % 2 == 0 else Color(1.0, 0.7, 0.2), 1.5), false)
            Nave.cyl(pivot, Vector3(sz.x / 2.0 - 1.0, 2.8, 0), 0.5, 0.15, steel, Vector3(90, 0, 0))
        "genetics_lab":
            for i in 2:
                Nave.box(pivot, Vector3(0, 0.45, -sz.y / 2.0 + 1.5 + i * 3.0), Vector3(sz.x - 3.0, 0.9, 1.0), steel)
            for k in 20:
                var a := k * 0.5
                Nave.ball(pivot, Vector3(cos(a) * 0.4, 0.4 + k * 0.1, sz.y / 2.0 - 2.5 + 0.0), 0.06, Mats.lamp(Color(0.8, 0.4, 0.95), 1.5))
                Nave.ball(pivot, Vector3(-cos(a) * 0.4, 0.4 + k * 0.1, sz.y / 2.0 - 2.5), 0.06, Mats.lamp(Color(0.3, 0.9, 0.9), 1.5))
        "fillet_plant":
            Nave.box(pivot, Vector3(0, 0.9, 0), Vector3(sz.x - 3.0, 0.15, 1.2), dark)
            for k in 8:
                var f := Critters.fish(Color(0.75, 0.78, 0.82))
                f.position = Vector3(-sz.x / 2.0 + 2.5 + k * (sz.x - 5.0) / 8.0, 1.05, 0)
                f.scale = Vector3.ONE * 0.4
                pivot.add_child(f)
            Nave.box(pivot, Vector3(0, 0.45, -sz.y / 2.0 + 1.2), Vector3(sz.x - 3.0, 0.9, 1.0), steel)
        "meal_plant":
            for i in 3:
                Nave.cyl(pivot, Vector3(-sz.x / 2.0 + 2.5 + i * (sz.x - 5.0) / 2.0, 1.6, 0), 0.9, 3.2, steel)
            for k in 6:
                Nave.box(pivot, Vector3(-sz.x / 2.0 + 1.5 + k * 0.7, 0.3, sz.y / 2.0 - 2.0), Vector3(0.6, 0.6, 0.4), Mats.plain(Color(0.8, 0.7, 0.5), 0.9), false)
        "desal":
            for i in 3:
                Nave.cyl(pivot, Vector3(-sz.x / 2.0 + 2.0 + i * (sz.x - 4.0) / 2.0, 1.5, 0), 0.7, 3.0, Mats.plain(Color(0.35, 0.55, 0.8), 0.3, 0.5))
