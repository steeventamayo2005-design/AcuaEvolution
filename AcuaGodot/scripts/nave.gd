class_name Nave
extends RefCounted
# Nave de cultivo de tilapia: estructura metálica a dos aguas, ventanas altas, lámparas colgantes,
# 3 tanques, oficina con PC, estanterías, tuberías y detalles de taller.

const LEN := 30.0
const WID := 12.0
const EAVE := 4.6
const RIDGE := 6.4

# ---------- ayudas ----------
static func box(parent: Node, pos: Vector3, size: Vector3, m: Material, collide: bool = true) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = m
    mi.position = pos
    parent.add_child(mi)
    if collide:
        var sb := StaticBody3D.new()
        var cs := CollisionShape3D.new()
        var bs := BoxShape3D.new()
        bs.size = size
        cs.shape = bs
        sb.add_child(cs)
        mi.add_child(sb)
    return mi

static func cyl(parent: Node, pos: Vector3, r: float, h: float, m: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = r
    cm.bottom_radius = r
    cm.height = h
    cm.radial_segments = 16
    mi.mesh = cm
    mi.material_override = m
    mi.position = pos
    mi.rotation_degrees = rot
    parent.add_child(mi)
    return mi

static func ball(parent: Node, pos: Vector3, r: float, m: Material) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = r
    sm.height = r * 2.0
    mi.mesh = sm
    mi.material_override = m
    mi.position = pos
    parent.add_child(mi)
    return mi

static func torus(parent: Node, pos: Vector3, inner: float, outer: float, m: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var tm := TorusMesh.new()
    tm.inner_radius = inner
    tm.outer_radius = outer
    mi.mesh = tm
    mi.material_override = m
    mi.position = pos
    mi.rotation_degrees = rot
    parent.add_child(mi)
    return mi

static func label(parent: Node, text: String, pos: Vector3, px: float = 0.004, fs: int = 36, col: Color = Color.WHITE, rot: Vector3 = Vector3.ZERO) -> Label3D:
    var l := Label3D.new()
    l.text = text
    l.font_size = fs
    l.pixel_size = px
    l.modulate = col
    l.position = pos
    l.rotation_degrees = rot
    parent.add_child(l)
    return l

static func body(parent: Node, pos: Vector3, size: Vector3, meta: Dictionary) -> StaticBody3D:
    var sb := StaticBody3D.new()
    for k in meta:
        sb.set_meta(k, meta[k])
    var cs := CollisionShape3D.new()
    var bs := BoxShape3D.new()
    bs.size = size
    cs.shape = bs
    sb.add_child(cs)
    sb.position = pos
    parent.add_child(sb)
    return sb

# ---------- construcción ----------
static func build(root: Node3D) -> void:
    var n := Node3D.new()
    n.name = "Nave"
    root.add_child(n)
    _structure(n)
    _lights(n)
    _tanks(n)
    _office(n)
    _props(n)

static func _structure(n: Node3D) -> void:
    var floor_m := Mats.pbr("floor", 3.2, Color(0.72, 0.70, 0.65))
    var wall_m := Mats.pbr("wall", 0.8, Color(0.16, 0.43, 0.41), 0.3)
    var steel := Mats.plain(Color(0.11, 0.13, 0.14), 0.45, 0.7)
    var hl := LEN / 2.0
    var hw := WID / 2.0
    box(n, Vector3(0, -0.1, 0), Vector3(LEN, 0.2, WID), floor_m)
    # Muros largos: zócalo, franja alta y ventana (vidrio + follaje exterior) entre ambos
    for sz in [-1.0, 1.0]:
        var z: float = sz * hw
        box(n, Vector3(0, 1.7, z), Vector3(LEN, 3.4, 0.2), wall_m)
        box(n, Vector3(0, 4.45, z), Vector3(LEN, 0.3, 0.2), wall_m)
        var gl := box(n, Vector3(0, 3.85, z), Vector3(LEN, 0.9, 0.03), Mats.glass(), false)
        gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    # Muros de los extremos (frontones triangulares)
    for sx in [-1.0, 1.0]:
        var x: float = sx * hl
        if sx < 0.0:
            # entrada: portón enrollado hacia arriba, abertura de 4,8 m
            box(n, Vector3(x, EAVE / 2.0, -(2.4 + (hw - 2.4) / 2.0)), Vector3(0.2, EAVE, hw - 2.4), wall_m)
            box(n, Vector3(x, EAVE / 2.0, 2.4 + (hw - 2.4) / 2.0), Vector3(0.2, EAVE, hw - 2.4), wall_m)
            box(n, Vector3(x, (3.8 + EAVE) / 2.0, 0), Vector3(0.2, EAVE - 3.8, 4.8), wall_m, false)
        else:
            box(n, Vector3(x, EAVE / 2.0, 0), Vector3(0.2, EAVE, WID), wall_m)
        var pr := MeshInstance3D.new()
        var pm := PrismMesh.new()
        pm.size = Vector3(WID, RIDGE - EAVE, 0.2)
        pr.mesh = pm
        pr.material_override = wall_m
        pr.rotation_degrees.y = 90
        pr.position = Vector3(x, EAVE + (RIDGE - EAVE) / 2.0, 0)
        n.add_child(pr)
    # Techo a dos aguas
    var ang := atan2(RIDGE - EAVE, hw)
    var slope := sqrt(hw * hw + (RIDGE - EAVE) * (RIDGE - EAVE)) + 0.4
    for sz in [-1.0, 1.0]:
        var r := box(n, Vector3(0, (EAVE + RIDGE) / 2.0 + 0.05, sz * hw / 2.0), Vector3(LEN + 0.6, 0.1, slope), wall_m, false)
        r.rotation.x = sz * ang
    # Columnas, cerchas y correas
    var x2 := -hl
    while x2 <= hl + 0.1:
        for sz in [-1.0, 1.0]:
            box(n, Vector3(x2, EAVE / 2.0, sz * (hw - 0.14)), Vector3(0.26, EAVE, 0.26), steel)
        box(n, Vector3(x2, EAVE - 0.2, 0), Vector3(0.14, 0.26, WID - 0.2), steel, false)
        x2 += 5.0
    for zz in [-4.5, -2.0, 2.0, 4.5]:
        var zf: float = zz
        box(n, Vector3(0, RIDGE - (RIDGE - EAVE) * absf(zf) / hw - 0.12, zf), Vector3(LEN, 0.12, 0.12), steel, false)
    cyl(n, Vector3(0, 4.05, 1.0), 0.13, LEN - 0.4, Mats.plain(Color(0.22, 0.2, 0.18), 0.5, 0.7), Vector3(0, 0, 90))
    # Portón enrollado arriba (extremo oeste)
    box(n, Vector3(-hl + 0.32, 3.95, 0.0), Vector3(0.45, 0.35, 4.9), steel, false)
    # Marcas de seguridad en el piso
    var lm := Mats.plain(Color(0.92, 0.92, 0.88), 0.6)
    var xs := -12.0
    while xs < 7.0:
        box(n, Vector3(xs, 0.006, 1.2), Vector3(1.0, 0.01, 0.12), lm, false)
        xs += 1.7
    for k in 3:
        box(n, Vector3(-11.5 + k * 1.9, 0.008, -1.6), Vector3(1.7, 0.01, 0.9), Mats.plain(Color(0.28, 0.46, 0.72), 0.4), false)

static func _lights(n: Node3D) -> void:
    var shade := Mats.plain(Color(0.09, 0.09, 0.1), 0.4, 0.6)
    var bulb := Mats.lamp(Color(1.0, 0.95, 0.85), 5.0)
    var cable := Mats.plain(Color(0.05, 0.05, 0.05), 0.8)
    for sz in [-2.2, 2.2]:
        var zf: float = sz
        var roof_y := RIDGE - (RIDGE - EAVE) * absf(zf) / (WID / 2.0) - 0.15
        var x := -12.5
        while x <= 12.6:
            var ly := 4.4
            var cl := roof_y - ly
            cyl(n, Vector3(x, ly + cl / 2.0, zf), 0.012, cl, cable)
            var cm := CylinderMesh.new()
            cm.top_radius = 0.07
            cm.bottom_radius = 0.26
            cm.height = 0.22
            var sh := MeshInstance3D.new()
            sh.mesh = cm
            sh.material_override = shade
            sh.position = Vector3(x, ly + 0.02, zf)
            n.add_child(sh)
            ball(n, Vector3(x, ly - 0.1, zf), 0.09, bulb)
            var l := OmniLight3D.new()
            l.omni_range = 9.0
            l.light_energy = 0.9
            l.light_color = Color(1.0, 0.93, 0.8)
            l.position = Vector3(x, ly - 0.3, zf)
            n.add_child(l)
            x += 5.0

static func _tanks(n: Node3D) -> void:
    var dc := Mats.pbr("dconc", 1.6, Color(0.3, 0.3, 0.3))
    var steel := Mats.plain(Color(0.55, 0.57, 0.6), 0.35, 0.85)
    var cream := Mats.plain(Color(0.78, 0.74, 0.62), 0.5, 0.2)
    var red := Mats.plain(Color(0.75, 0.08, 0.06), 0.4, 0.3)
    var blue := Mats.plain(Color(0.08, 0.28, 0.7), 0.35)
    var tl := 5.0
    var tw := 2.4
    var th := 1.0
    var tk_ := 0.25
    for k in 3:
        var tk: WaterTank
        if Game.tanks.size() > k:
            tk = Game.tanks[k]
        else:
            tk = WaterTank.new("Tanque %d" % (k + 1), Catalog.SPECIES[[0, 3, 1][k]])
            Game.tanks.append(tk)
        var t := Node3D.new()
        t.position = Vector3(-8.0 + k * 6.0, 0, -4.0)
        n.add_child(t)
        box(t, Vector3(0, 0.1, 0), Vector3(tl, 0.2, tw), dc, false)
        box(t, Vector3(0, th / 2.0, -(tw / 2.0 - tk_ / 2.0)), Vector3(tl, th, tk_), dc, false)
        box(t, Vector3(0, th / 2.0, tw / 2.0 - tk_ / 2.0), Vector3(tl, th, tk_), dc, false)
        box(t, Vector3(-(tl / 2.0 - tk_ / 2.0), th / 2.0, 0), Vector3(tk_, th, tw - 2.0 * tk_), dc, false)
        box(t, Vector3(tl / 2.0 - tk_ / 2.0, th / 2.0, 0), Vector3(tk_, th, tw - 2.0 * tk_), dc, false)
        box(t, Vector3(0, 0.21, 0), Vector3(tl - 2.0 * tk_, 0.02, tw - 2.0 * tk_), Mats.plain(Color(0.07, 0.2, 0.22), 0.6), false)
        var wmat := Mats.water()
        var wp := MeshInstance3D.new()
        var pm := PlaneMesh.new()
        pm.size = Vector2(tl - 2.0 * tk_, tw - 2.0 * tk_)
        wp.mesh = pm
        wp.material_override = wmat
        wp.position = Vector3(0, th - 0.12, 0)
        t.add_child(wp)
        body(t, Vector3(0, th / 2.0, 0), Vector3(tl, th, tw), {"kind": "tank", "idx": k, "prompt": "E · " + tk.name_t})
        # tubería de llenado con válvula roja (E = cambio de agua)
        cyl(t, Vector3(tl / 2.0 - 0.9, 0.7, tw / 2.0 + 0.2), 0.05, 1.4, cream)
        cyl(t, Vector3(tl / 2.0 - 0.9, 1.4, tw / 4.0 + 0.1), 0.05, tw / 2.0 + 0.2, cream, Vector3(90, 0, 0))
        torus(t, Vector3(tl / 2.0 - 0.9, 0.75, tw / 2.0 + 0.27), 0.05, 0.12, red, Vector3(90, 0, 0))
        body(t, Vector3(tl / 2.0 - 0.9, 0.75, tw / 2.0 + 0.27), Vector3(0.35, 0.35, 0.2), {"kind": "valve", "idx": k, "prompt": "E · Cambio de agua ($2)"})
        # aireador con manguera azul (E = encender / apagar)
        var ax := tl / 2.0 - 0.7
        var az := -tw / 2.0 + 0.45
        box(t, Vector3(ax, th + 0.17, az), Vector3(0.5, 0.34, 0.4), steel, false)
        cyl(t, Vector3(ax - 0.3, th + 0.17, az), 0.14, 0.3, Mats.plain(Color(0.2, 0.2, 0.22), 0.4, 0.7), Vector3(0, 0, 90))
        torus(t, Vector3(ax - 0.1, th + 0.55, az), 0.14, 0.19, blue, Vector3(0, 90, 0))
        cyl(t, Vector3(ax - 0.1, th - 0.1, az), 0.05, 0.5, blue)
        body(t, Vector3(ax, th + 0.3, az), Vector3(0.6, 0.6, 0.5), {"kind": "aerator", "idx": k, "prompt": "E · Aireador (encender / apagar)"})
        label(t, "Aireador", Vector3(ax, th + 1.0, az), 0.004, 36).billboard = BaseMaterial3D.BILLBOARD_ENABLED
        var v = load("res://scripts/tank_view.gd").new()
        v.L = tl - 2.0 * tk_
        v.W = tw - 2.0 * tk_
        v.surface_y = th - 0.12
        v.rim_y = th
        v.tank_w = tw
        v.tank_l = tl
        v.water_mat = wmat
        t.add_child(v)
        v.setup(tk)
    # tuberías cremas a lo largo del muro norte, con válvula
    var z0 := -WID / 2.0 + 0.2
    cyl(n, Vector3(-0.5, 1.9, z0), 0.08, 28.0, cream, Vector3(0, 0, 90))
    cyl(n, Vector3(-0.5, 2.2, z0), 0.08, 28.0, cream, Vector3(0, 0, 90))
    var bx := -13.0
    while bx <= 13.1:
        box(n, Vector3(bx, 2.05, z0 - 0.02), Vector3(0.08, 0.5, 0.06), Mats.plain(Color(0.1, 0.1, 0.1), 0.6, 0.6), false)
        bx += 2.8
    torus(n, Vector3(-3.0, 1.9, z0 + 0.14), 0.04, 0.1, red, Vector3(90, 0, 0))

static func _office(n: Node3D) -> void:
    var st := Mats.pbr("stucco", 1.5, Color(0.72, 0.66, 0.52))
    var blk := Mats.plain(Color(0.05, 0.05, 0.06), 0.5, 0.3)
    var wood := Mats.pbr("wood", 1.2, Color(0.5, 0.33, 0.18))
    var x0 := 9.2
    var x1 := 14.8
    var z0 := 0.2
    var z1 := 5.8
    var h := 2.9
    var t := 0.15
    var o := Node3D.new()
    o.name = "Oficina"
    n.add_child(o)
    box(o, Vector3((x0 + x1) / 2.0, 0.01, (z0 + z1) / 2.0), Vector3(x1 - x0, 0.02, z1 - z0), Mats.plain(Color(0.36, 0.31, 0.26), 0.95), false)
    box(o, Vector3((x0 + x1) / 2.0, h + 0.05, (z0 + z1) / 2.0), Vector3(x1 - x0 + 0.3, 0.1, z1 - z0 + 0.3), st)
    box(o, Vector3((x0 + x1) / 2.0, h / 2.0, z0), Vector3(x1 - x0, h, t), st)
    box(o, Vector3((x0 + x1) / 2.0, h / 2.0, z1), Vector3(x1 - x0, h, t), st)
    # muro oeste: tramos sólidos, puerta (1.0-2.1) y ventana (3.3-5.3)
    var wx := x0
    box(o, Vector3(wx, h / 2.0, (z0 + 1.0) / 2.0), Vector3(t, h, 1.0 - z0), st)
    box(o, Vector3(wx, (2.1 + h) / 2.0, 1.55), Vector3(t, h - 2.1, 1.1), st)
    box(o, Vector3(wx, h / 2.0, (2.1 + 3.3) / 2.0), Vector3(t, h, 1.2), st)
    box(o, Vector3(wx, 0.5, 4.3), Vector3(t, 1.0, 2.0), st)
    box(o, Vector3(wx, (2.2 + h) / 2.0, 4.3), Vector3(t, h - 2.2, 2.0), st)
    box(o, Vector3(wx, h / 2.0, (5.3 + z1) / 2.0), Vector3(t, h, z1 - 5.3), st)
    var gl := box(o, Vector3(wx, 1.6, 4.3), Vector3(0.03, 1.2, 2.0), Mats.glass(), false)
    gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    # marcos negros de puerta y ventana
    box(o, Vector3(wx - 0.09, 2.14, 1.55), Vector3(0.1, 0.08, 1.2), blk, false)
    box(o, Vector3(wx - 0.09, 1.05, 1.0), Vector3(0.1, 2.1, 0.08), blk, false)
    box(o, Vector3(wx - 0.09, 1.05, 2.1), Vector3(0.1, 2.1, 0.08), blk, false)
    box(o, Vector3(wx - 0.09, 1.02, 4.3), Vector3(0.1, 0.07, 2.1), blk, false)
    box(o, Vector3(wx - 0.09, 2.22, 4.3), Vector3(0.1, 0.07, 2.1), blk, false)
    box(o, Vector3(wx - 0.09, 1.6, 3.3), Vector3(0.1, 1.2, 0.07), blk, false)
    box(o, Vector3(wx - 0.09, 1.6, 5.3), Vector3(0.1, 1.2, 0.07), blk, false)
    box(o, Vector3(wx - 0.09, 1.6, 4.3), Vector3(0.1, 1.2, 0.06), blk, false)
    box(o, Vector3(wx - 0.12, 2.45, 1.55), Vector3(0.1, 0.3, 1.0), blk, false)
    label(o, "OFICINA", Vector3(wx - 0.19, 2.45, 1.55), 0.0045, 44, Color(0.95, 0.95, 0.95), Vector3(0, -90, 0))
    # marcador de tutorial "!"
    var mk := Node3D.new()
    o.add_child(mk)
    cyl(mk, Vector3(wx + 0.25, 1.75, 4.3), 0.22, 0.02, Mats.lamp(Color(0.95, 0.72, 0.15), 1.0), Vector3(0, 0, 90))
    label(mk, "!", Vector3(wx + 0.23, 1.75, 4.3), 0.006, 60, Color(0.25, 0.18, 0.05), Vector3(0, -90, 0))
    Game.marker = mk
    mk.visible = not Game.flags.has("pc")
    # escritorio, PC, silla, lámpara, planta, corcho
    box(o, Vector3(12.0, 0.75, 0.75), Vector3(2.0, 0.06, 0.85), wood)
    for px in [-0.9, 0.9]:
        for pz in [-0.35, 0.35]:
            box(o, Vector3(12.0 + px, 0.37, 0.75 + pz), Vector3(0.06, 0.74, 0.06), Mats.plain(Color(0.1, 0.1, 0.1), 0.5, 0.6), false)
    box(o, Vector3(12.0, 1.02, 0.5), Vector3(0.78, 0.46, 0.04), Mats.plain(Color(0.05, 0.05, 0.06), 0.3, 0.4), false)
    box(o, Vector3(12.0, 1.02, 0.52), Vector3(0.7, 0.4, 0.02), Mats.lamp(Color(0.12, 0.5, 0.6), 1.4), false)
    box(o, Vector3(12.0, 0.8, 0.5), Vector3(0.1, 0.04, 0.12), Mats.plain(Color(0.1, 0.1, 0.1)), false)
    body(o, Vector3(12.0, 1.0, 0.6), Vector3(0.9, 0.6, 0.5), {"kind": "shop", "prompt": "E · PC de gestión (AquaShop)"})
    box(o, Vector3(12.0, 0.5, 1.5), Vector3(0.5, 0.06, 0.5), Mats.plain(Color(0.12, 0.12, 0.14), 0.7), false)
    box(o, Vector3(12.0, 0.85, 1.75), Vector3(0.5, 0.55, 0.06), Mats.plain(Color(0.12, 0.12, 0.14), 0.7), false)
    cyl(o, Vector3(12.0, 0.25, 1.5), 0.04, 0.5, Mats.plain(Color(0.1, 0.1, 0.1), 0.4, 0.8))
    var lamp_red := Mats.plain(Color(0.7, 0.2, 0.08), 0.4, 0.4)
    cyl(o, Vector3(11.0, 0.95, 0.5), 0.015, 0.4, lamp_red, Vector3(0, 0, 25))
    cyl(o, Vector3(11.12, 1.2, 0.5), 0.015, 0.4, lamp_red, Vector3(0, 0, -35))
    box(o, Vector3(11.0, 0.8, 0.5), Vector3(0.14, 0.03, 0.14), lamp_red, false)
    cyl(o, Vector3(14.3, 0.25, 1.2), 0.2, 0.5, Mats.plain(Color(0.72, 0.38, 0.2), 0.8))
    for i in 6:
        ball(o, Vector3(14.3 + sin(i * 1.05) * 0.18, 0.7 + (i % 3) * 0.17, 1.2 + cos(i * 1.05) * 0.18), 0.17, Mats.plain(Color(0.14, 0.42, 0.14), 0.7))
    box(o, Vector3(10.4, 1.6, z0 + 0.09), Vector3(0.9, 0.6, 0.03), Mats.plain(Color(0.75, 0.52, 0.34), 0.9), false)
    box(o, Vector3(10.25, 1.65, z0 + 0.11), Vector3(0.18, 0.18, 0.01), Mats.plain(Color(0.95, 0.95, 0.92), 0.9), false)
    box(o, Vector3(10.6, 1.5, z0 + 0.11), Vector3(0.18, 0.18, 0.01), Mats.plain(Color(0.95, 0.95, 0.92), 0.9), false)
    var ol := OmniLight3D.new()
    ol.omni_range = 7.0
    ol.light_energy = 1.1
    ol.light_color = Color(1.0, 0.95, 0.85)
    ol.shadow_enabled = true
    ol.position = Vector3(12.0, 2.5, 3.0)
    o.add_child(ol)

static func _rack(parent: Node, pos: Vector3) -> void:
    var post := Mats.plain(Color(0.08, 0.08, 0.09), 0.5, 0.6)
    var wood := Mats.pbr("wood", 1.2, Color(0.5, 0.33, 0.18))
    var r := Node3D.new()
    r.position = pos
    parent.add_child(r)
    for px in [-1.1, 1.1]:
        for pz in [-0.28, 0.28]:
            box(r, Vector3(px, 1.0, pz), Vector3(0.05, 2.0, 0.05), post)
    for y in [0.25, 0.8, 1.35, 1.9]:
        box(r, Vector3(0, y, 0), Vector3(2.3, 0.04, 0.62), wood, false)
    var cb := Mats.plain(Color(0.72, 0.55, 0.30), 0.9)
    var crate := Mats.plain(Color(0.55, 0.10, 0.08), 0.7)
    box(r, Vector3(-0.6, 1.02, 0.0), Vector3(0.7, 0.4, 0.45), cb, false)
    box(r, Vector3(0.45, 1.5, 0.0), Vector3(0.5, 0.28, 0.4), crate, false)
    box(r, Vector3(-0.2, 0.48, 0.0), Vector3(0.45, 0.3, 0.4), crate, false)
    box(r, Vector3(0.6, 0.44, 0.05), Vector3(0.6, 0.38, 0.45), cb, false)
    box(r, Vector3(-0.5, 2.1, 0.0), Vector3(0.6, 0.3, 0.4), cb, false)

static func _props(n: Node3D) -> void:
    var hw := WID / 2.0
    _rack(n, Vector3(4.6, 0, hw - 0.5))
    _rack(n, Vector3(7.0, 0, hw - 0.5))
    # mesa de trabajo + botella de gas + tarima + barriles (cerca del portón)
    var steel := Mats.plain(Color(0.6, 0.63, 0.66), 0.35, 0.8)
    box(n, Vector3(-12.2, 0.85, 4.6), Vector3(1.6, 0.05, 0.8), steel)
    for px in [-0.7, 0.7]:
        for pz in [-0.32, 0.32]:
            box(n, Vector3(-12.2 + px, 0.42, 4.6 + pz), Vector3(0.05, 0.84, 0.05), steel, false)
    if Models.has("gas_cylinder"):
        Models.spawn(n, "gas_cylinder", Vector3(-11.4, 0.0, 3.9))
    else:
        cyl(n, Vector3(-11.4, 0.7, 3.9), 0.15, 1.4, Mats.plain(Color(0.08, 0.28, 0.42), 0.3, 0.6))
        cyl(n, Vector3(-11.4, 1.45, 3.9), 0.06, 0.1, Mats.plain(Color(0.7, 0.7, 0.72), 0.3, 0.9))
    if Models.has("pallet"):
        Models.spawn(n, "pallet", Vector3(-10.0, 0.0, 4.7))
    else:
        box(n, Vector3(-10.0, 0.08, 4.7), Vector3(1.2, 0.14, 1.0), Mats.pbr("wood", 1.2, Color(0.5, 0.33, 0.18)))
    if Models.has("barrel"):
        Models.spawn(n, "barrel", Vector3(-14.3, 0.0, 5.0))
        Models.spawn(n, "barrel", Vector3(-13.6, 0.0, 5.3))
    else:
        cyl(n, Vector3(-14.3, 0.45, 5.0), 0.3, 0.9, Mats.plain(Color(0.45, 0.22, 0.1), 0.7, 0.6))
        cyl(n, Vector3(-13.6, 0.45, 5.3), 0.3, 0.9, Mats.plain(Color(0.12, 0.25, 0.5), 0.6, 0.6))
    # tuberías cremas en el muro sur con válvula roja
    var cream := Mats.plain(Color(0.78, 0.74, 0.62), 0.5, 0.2)
    cyl(n, Vector3(-4.5, 1.4, hw - 0.2), 0.07, 19.0, cream, Vector3(0, 0, 90))
    cyl(n, Vector3(-4.5, 1.72, hw - 0.2), 0.07, 19.0, cream, Vector3(0, 0, 90))
    torus(n, Vector3(-6.0, 1.4, hw - 0.33), 0.04, 0.1, Mats.plain(Color(0.75, 0.08, 0.06), 0.4, 0.3), Vector3(90, 0, 0))
    # salvavidas, pizarra y extintor
    var red := Mats.plain(Color(0.78, 0.1, 0.08), 0.5)
    torus(n, Vector3(1.5, 2.0, hw - 0.14), 0.16, 0.3, red, Vector3(90, 0, 0))
    for a in 4:
        var an := a * PI / 2.0
        box(n, Vector3(1.5 + cos(an) * 0.23, 2.0 + sin(an) * 0.23, hw - 0.14), Vector3(0.12, 0.12, 0.04), Mats.plain(Color(0.95, 0.95, 0.95), 0.6), false)
    box(n, Vector3(-3.0, 1.8, hw - 0.12), Vector3(0.8, 0.55, 0.03), Mats.plain(Color(0.8, 0.78, 0.7), 0.9), false)
    box(n, Vector3(-3.0, 1.8, hw - 0.14), Vector3(0.7, 0.45, 0.01), Mats.plain(Color(0.95, 0.95, 0.93), 0.9), false)
    cyl(n, Vector3(0.0, 1.2, hw - 0.4), 0.08, 0.45, red)
    # estantería ligera junto al portón y bidón de agua
    box(n, Vector3(-14.0, 0.6, -5.2), Vector3(0.8, 1.2, 0.8), Mats.plain(Color(0.7, 0.54, 0.3), 0.9))
