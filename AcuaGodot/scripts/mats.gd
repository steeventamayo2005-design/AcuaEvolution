class_name Mats
extends RefCounted
# Fábrica de materiales PBR (texturas en res://textures/, generadas con tools/gen_textures.py).

static var _c: Dictionary = {}

static func _tex(n: String) -> Texture2D:
    var p := "res://textures/%s.png" % n
    if ResourceLoader.exists(p):
        return load(p) as Texture2D
    return null

# Material con texturas triplanares en coordenadas de mundo (continuas entre piezas).
static func pbr(key_name: String, tile: float, fallback: Color, metal: float = 0.0, normal_scale: float = 1.0) -> StandardMaterial3D:
    var key := "%s_%s_%s" % [key_name, tile, metal]
    if _c.has(key):
        return _c[key]
    var m := StandardMaterial3D.new()
    var a := _tex(key_name + "_albedo")
    if a != null:
        m.albedo_texture = a
    else:
        m.albedo_color = fallback
    var n := _tex(key_name + "_normal")
    if n != null:
        m.normal_enabled = true
        m.normal_texture = n
        m.normal_scale = normal_scale
    var r := _tex(key_name + "_rough")
    if r != null:
        m.roughness_texture = r
        m.roughness = 1.0
    else:
        m.roughness = 0.8
    m.metallic = metal
    m.uv1_triplanar = true
    m.uv1_world_triplanar = true
    m.uv1_scale = Vector3.ONE / tile
    m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    _c[key] = m
    return m

static func plain(c: Color, rough: float = 0.7, metal: float = 0.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.roughness = rough
    m.metallic = metal
    return m

static func lamp(c: Color, energy: float = 3.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.emission_enabled = true
    m.emission = c
    m.emission_energy_multiplier = energy
    return m

static func glass() -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(0.75, 0.88, 0.92, 0.12)
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.roughness = 0.05
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    return m

static func foliage() -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    var t := _tex("foliage_albedo")
    if t != null:
        m.albedo_texture = t
    else:
        m.albedo_color = Color(0.5, 0.7, 0.5)
    m.albedo_color = Color(1.25, 1.25, 1.25)
    return m

# Agua con normal animada (un material por tanque, se desplaza en TankView).
static func water() -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(0.05, 0.30, 0.34, 0.80)
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.roughness = 0.06
    m.metallic_specular = 0.9
    var n := _tex("water_normal")
    if n != null:
        m.normal_enabled = true
        m.normal_texture = n
        m.normal_scale = 0.5
    m.uv1_scale = Vector3(3, 2, 1)
    return m
