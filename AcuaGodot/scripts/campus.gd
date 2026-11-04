extends Node3D
# Campus 3D continuo: domo, suelo por zonas, plaza con mesa holográfica y todos los edificios del plano.
# Los edificios nuevos aparecen al cerrar la tableta (sync_buildings).

var spawned := {}
var winds: Array = []
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var env: Environment
var lamps: Array = []

func _ready() -> void:
    _environment()
    _ground()
    _dome()
    _plaza()
    sync_buildings()

# ------------------------------------------------------------ entorno y día/noche
func _environment() -> void:
    var we := WorldEnvironment.new()
    env = Environment.new()
    sky_mat = ProceduralSkyMaterial.new()
    var sky := Sky.new()
    sky.sky_material = sky_mat
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.ssao_enabled = true
    env.glow_enabled = true
    env.glow_hdr_threshold = 1.0
    env.adjustment_enabled = true
    env.adjustment_saturation = 1.1
    we.environment = env
    add_child(we)
    sun = DirectionalLight3D.new()
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 140.0
    add_child(sun)

func _process(dt: float) -> void:
    var hour := fmod(Game.minutes / 60.0, 24.0)
    var day_f := clampf(sin((hour - 6.0) / 12.0 * PI), 0.0, 1.0)
    var elev := sin((hour - 6.0) / 24.0 * TAU) * 70.0
    sun.rotation_degrees = Vector3(-maxf(elev, 5.0), -30.0, 0.0)
    sun.light_energy = 0.15 + 1.9 * day_f
    sun.light_color = Color(1.0, 0.82 + 0.15 * day_f, 0.65 + 0.3 * day_f)
    env.ambient_light_energy = 0.25 + 0.6 * day_f
    sky_mat.sky_top_color = Color(0.02, 0.04, 0.1).lerp(Color(0.25, 0.5, 0.85), day_f)
    sky_mat.sky_horizon_color = Color(0.05, 0.07, 0.14).lerp(Color(0.65, 0.78, 0.9), day_f)
    sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
    sky_mat.ground_bottom_color = Color(0.03, 0.04, 0.05).lerp(Color(0.25, 0.3, 0.3), day_f)
    for l in lamps:
        l.light_energy = 2.0 * (1.0 - day_f)
    for w in winds:
        if is_instance_valid(w):
            w.rotate_z(dt * 1.4)

# ------------------------------------------------------------ geometría base
func _ground() -> void:
    var floor_m := Mats.pbr("floor", 3.2, Color(0.55, 0.57, 0.55))
    Nave.box(self, Vector3(0, -0.16, 0), Vector3(700, 0.2, 700), Mats.plain(Color(0.28, 0.4, 0.28), 0.95), false)
    var disc := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = Game.DOME_R
    cm.bottom_radius = Game.DOME_R
    cm.height = 0.12
    cm.radial_segments = 96
    disc.mesh = cm
    disc.material_override = floor_m
    disc.position = Vector3(0, -0.06, 0)
    add_child(disc)
    var body := StaticBody3D.new()
    var cs := CollisionShape3D.new()
    var bs := BoxShape3D.new()
    bs.size = Vector3(700, 0.4, 700)
    cs.shape = bs
    body.add_child(cs)
    body.position = Vector3(0, -0.21, 0)
    add_child(body)
    # zonas de agua teñidas sobre el piso
    _sector(0.0, PI / 2.0, Color(0.62, 0.74, 0.96, 0.22))
    _sector(PI / 2.0, PI, Color(0.78, 0.92, 0.66, 0.22))
    _sector(PI, PI * 1.5, Color(0.70, 0.86, 0.95, 0.22))
    _sector(PI * 1.5, TAU, Color(0.96, 0.86, 0.62, 0.22))

func _sector(a0: float, a1: float, col: Color) -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var n := 24
    for i in n:
        var aa := a0 + (a1 - a0) * i / float(n)
        var ab := a0 + (a1 - a0) * (i + 1) / float(n)
        st.add_vertex(Vector3(0, 0.01, 0))
        st.add_vertex(Vector3(cos(ab) * Game.DOME_R, 0.01, sin(ab) * Game.DOME_R))
        st.add_vertex(Vector3(cos(aa) * Game.DOME_R, 0.01, sin(aa) * Game.DOME_R))
    var mi := MeshInstance3D.new()
    mi.mesh = st.commit()
    var m := StandardMaterial3D.new()
    m.albedo_color = col
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    mi.material_override = m
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)

func _dome() -> void:
    var R := Game.DOME_R
    var mi := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = R
    sm.height = R
    sm.is_hemisphere = true
    sm.radial_segments = 48
    sm.rings = 24
    mi.mesh = sm
    var gm := StandardMaterial3D.new()
    gm.albedo_color = Color(0.8, 0.92, 1.0, 0.07)
    gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    gm.cull_mode = BaseMaterial3D.CULL_DISABLED
    gm.roughness = 0.05
    mi.material_override = gm
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)
    # nervaduras: meridianos y paralelos
    var verts := PackedVector3Array()
    for i in 24:
        var az := i * TAU / 24.0
        for j in 16:
            var e0 := j * (PI / 2.0) / 16.0
            var e1 := (j + 1) * (PI / 2.0) / 16.0
            verts.append(Vector3(cos(az) * cos(e0), sin(e0), sin(az) * cos(e0)) * R)
            verts.append(Vector3(cos(az) * cos(e1), sin(e1), sin(az) * cos(e1)) * R)
    for k in range(1, 8):
        var e := k * (PI / 2.0) / 8.0
        for i in 48:
            var a0 := i * TAU / 48.0
            var a1 := (i + 1) * TAU / 48.0
            verts.append(Vector3(cos(a0) * cos(e), sin(e), sin(a0) * cos(e)) * R)
            verts.append(Vector3(cos(a1) * cos(e), sin(e), sin(a1) * cos(e)) * R)
    var arr := []
    arr.resize(Mesh.ARRAY_MAX)
    arr[Mesh.ARRAY_VERTEX] = verts
    var am := ArrayMesh.new()
    am.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
    var lm := StandardMaterial3D.new()
    lm.albedo_color = Color(1, 1, 1, 0.55)
    lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    var ribs := MeshInstance3D.new()
    ribs.mesh = am
    ribs.material_override = lm
    ribs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(ribs)

func _plaza() -> void:
    var pr := Game.PLAZA_R
    var disc := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = pr
    cm.bottom_radius = pr
    cm.height = 0.05
    cm.radial_segments = 48
    disc.mesh = cm
    disc.material_override = Mats.plain(Color(0.93, 0.93, 0.9), 0.4)
    disc.position = Vector3(0, 0.02, 0)
    add_child(disc)
    var cols := [Color(0.5, 0.75, 0.25), Color(0.2, 0.55, 0.75), Color(0.9, 0.6, 0.2)]
    for i in 3:
        var tm := TorusMesh.new()
        tm.inner_radius = pr * (0.5 + i * 0.17)
        tm.outer_radius = tm.inner_radius + 0.25
        var t := MeshInstance3D.new()
        t.mesh = tm
        t.material_override = Mats.lamp(cols[i], 0.8)
        t.position = Vector3(0, 0.06, 0)
        add_child(t)
    # mesa holográfica de planificación (E = abrir tableta)
    var table := Node3D.new()
    add_child(table)
    Nave.cyl(table, Vector3(0, 0.5, 0), 0.9, 1.0, Mats.plain(Color(0.12, 0.14, 0.16), 0.3, 0.6))
    Nave.cyl(table, Vector3(0, 1.02, 0), 0.95, 0.06, Mats.lamp(Color(0.2, 0.7, 0.8), 1.2))
    var holo := Nave.ball(table, Vector3(0, 1.7, 0), 0.5, Mats.lamp(Color(0.3, 0.85, 0.95), 1.0))
    holo.scale = Vector3(1.0, 0.6, 1.0)
    Nave.label(table, "Mesa de planificación\nE · abrir tableta", Vector3(0, 2.6, 0), 0.006, 48, Color(0.8, 0.95, 1.0)).billboard = BaseMaterial3D.BILLBOARD_ENABLED
    Nave.body(table, Vector3(0, 1.0, 0), Vector3(2.0, 2.0, 2.0), {"kind": "table", "prompt": "E · Tableta de planificación (Tab)"})
    # farolas
    for i in 8:
        var a := i * TAU / 8.0
        var p := Vector3(cos(a) * (pr + 4.0), 0.0, sin(a) * (pr + 4.0))
        Nave.cyl(self, p + Vector3(0, 2.0, 0), 0.08, 4.0, Mats.plain(Color(0.15, 0.15, 0.17), 0.5, 0.6))
        Nave.ball(self, p + Vector3(0, 4.1, 0), 0.22, Mats.lamp(Color(1.0, 0.92, 0.7), 3.0))
        var l := OmniLight3D.new()
        l.omni_range = 18.0
        l.light_color = Color(1.0, 0.9, 0.7)
        l.position = p + Vector3(0, 4.0, 0)
        add_child(l)
        lamps.append(l)

# ------------------------------------------------------------ edificios
func sync_buildings() -> void:
    var alive := {}
    for b in Game.buildings:
        var u := int(b.uid)
        alive[u] = true
        if not spawned.has(u):
            spawned[u] = _spawn(b)
    for u in spawned.keys():
        if not alive.has(u):
            if is_instance_valid(spawned[u]):
                spawned[u].queue_free()
            spawned.erase(u)

func _spawn(b: Dictionary) -> Node3D:
    var pivot := Node3D.new()
    pivot.position = Vector3(b.x, 0.0, b.y)
    if b.rot == 1:
        pivot.rotation_degrees.y = 90.0
    add_child(pivot)
    var d: Dictionary = Game.def(b.id)
    var sz: Vector2 = Vector2(d.w, d.d)
    if b.id == "tilapia_nave":
        Nave.build(pivot)
    elif b.id.begins_with("hatchery_"):
        var jp: String = Game.hatchery_path(b.id)
        if FileAccess.file_exists(jp):
            HatcheryBuilder.build(pivot, FileAccess.get_file_as_string(jp), Vector3(-sz.x / 2.0, 0.0, -sz.y / 2.0))
        Nave.label(pivot, d.name, Vector3(0, 6.0, -sz.y / 2.0 - 1.0), 0.02, 64, Color(1, 1, 1)).billboard = BaseMaterial3D.BILLBOARD_ENABLED
    else:
        Modules.build(self, pivot, b, d, sz)
        Nave.label(pivot, d.name, Vector3(0, minf(8.0, 3.5 + sz.y * 0.1), 0), 0.012, 48, Color(1, 1, 1)).billboard = BaseMaterial3D.BILLBOARD_ENABLED
    return pivot
