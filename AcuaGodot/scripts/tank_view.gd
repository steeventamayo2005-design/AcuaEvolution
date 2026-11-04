extends Node3D
# Peces provisionales, agua animada y cartel de 5 luces sobre el borde del tanque.

var tank: WaterTank
var L := 4.5
var W := 1.9
var surface_y := 0.88
var rim_y := 1.0
var tank_w := 2.4
var tank_l := 5.0
var water_mat: StandardMaterial3D
var _fish: Array = []
var _a: Array = []
var _sp: Array = []
var _r: Array = []
var _y: Array = []
var _last_sp := ""
var _lamps: Array = []

func setup(t: WaterTank) -> void:
    tank = t
    for i in 16:
        var mi := Critters.fish(tank.sp.color)
        add_child(mi)
        _fish.append(mi)
        _a.append(randf() * TAU)
        _sp.append(0.35 + randf() * 0.4)
        _r.append(0.55 + randf() * 0.5)
        _y.append(randf() * 0.3)
    _build_sign()

func _build_sign() -> void:
    var base := Node3D.new()
    base.position = Vector3(-tank_l / 2.0 + 0.9, rim_y, tank_w / 2.0 - 0.15)
    add_child(base)
    var dark := StandardMaterial3D.new()
    dark.albedo_color = Color(0.07, 0.08, 0.09)
    dark.roughness = 0.5
    dark.metallic = 0.4
    var post := MeshInstance3D.new()
    var pm := CylinderMesh.new()
    pm.top_radius = 0.025
    pm.bottom_radius = 0.025
    pm.height = 0.3
    post.mesh = pm
    post.material_override = dark
    post.position.y = 0.15
    base.add_child(post)
    var panel := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = Vector3(0.9, 0.34, 0.04)
    panel.mesh = bm
    panel.material_override = dark
    panel.position.y = 0.42
    panel.rotation_degrees.x = -35
    base.add_child(panel)
    var title := Label3D.new()
    title.text = tank.name_t
    title.font_size = 36
    title.pixel_size = 0.0028
    title.position = Vector3(0, 0.11, 0.025)
    panel.add_child(title)
    var names := ["O2", "NH3", "pH", "T", "Comida"]
    for i in 5:
        var lamp := MeshInstance3D.new()
        var cm := CylinderMesh.new()
        cm.top_radius = 0.05
        cm.bottom_radius = 0.05
        cm.height = 0.02
        lamp.mesh = cm
        lamp.rotation_degrees.x = 90
        lamp.position = Vector3(-0.34 + i * 0.17, -0.03, 0.025)
        var lm := StandardMaterial3D.new()
        lm.emission_enabled = true
        lm.emission_energy_multiplier = 1.6
        lamp.material_override = lm
        panel.add_child(lamp)
        _lamps.append(lm)
        var tl := Label3D.new()
        tl.text = names[i]
        tl.font_size = 22
        tl.pixel_size = 0.0028
        tl.position = Vector3(-0.34 + i * 0.17, -0.11, 0.025)
        panel.add_child(tl)

func _set_lamp(i: int, ok: bool, active: bool) -> void:
    var c := Color(0.25, 0.27, 0.3)
    if active:
        c = Color(0.2, 0.85, 0.4) if ok else Color(0.9, 0.25, 0.25)
    _lamps[i].albedo_color = c
    _lamps[i].emission = c

func _process(dt: float) -> void:
    if tank == null:
        return
    if water_mat != null:
        water_mat.uv1_offset += Vector3(dt * 0.018, dt * 0.011, 0.0)
    var vis := 0
    if tank.fish > 0:
        vis = mini(16, ceili(tank.fish / 18.0))
    var sc := 0.08 + tank.avg_w / 900.0 * 0.13
    if _last_sp != tank.sp.id:
        _last_sp = tank.sp.id
        for f in _fish:
            Critters.recolor(f, tank.sp.color)
    var t := Time.get_ticks_msec() / 1000.0
    for i in _fish.size():
        var mi: Node3D = _fish[i]
        mi.visible = i < vis
        if i >= vis:
            continue
        var an: float = _a[i] + t * _sp[i]
        mi.position = Vector3(cos(an) * (L / 2.0 - 0.5) * _r[i], surface_y - 0.4 - _y[i] + sin(t * 2.0 + i) * 0.04, sin(an) * (W / 2.0 - 0.4) * _r[i])
        mi.rotation.y = -an - PI / 2.0
        mi.scale = Vector3.ONE * sc * 1.6
        Critters.anim(mi, "fish", t, float(i))
    var on := tank.fish > 0
    _set_lamp(0, tank.o2 >= 5.0, on)
    _set_lamp(1, tank.nh3 < 0.3, on)
    _set_lamp(2, tank.ph >= 6.5 and tank.ph <= 8.5, on)
    _set_lamp(3, absf(tank.temp - tank.sp.opt_temp) <= 3.0, on)
    _set_lamp(4, tank.hunger < 50.0, on)
