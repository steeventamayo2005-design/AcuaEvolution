class_name Salinity
extends RefCounted
# Salinidad, masa de sal, dilución y parámetros del mercado de sal. Datos en res://data/salinidad.json.

static var data: Dictionary = {}

static func load_data() -> void:
    var p := "res://data/salinidad.json"
    if FileAccess.file_exists(p):
        var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
        if parsed is Dictionary:
            data = parsed
    if data.is_empty():
        data = {
            "zones": {"dulce": 0.5, "salada": 35.0},
            "water": {"rho_base": 0.9982, "rho_per_psu": 0.000765},
            "market": {"base_price": 0.35, "mean_reversion": 0.08, "daily_volatility": 0.04, "shortage_prob_day": 0.02,
                "shortage_days_min": 5, "shortage_days_max": 12, "shortage_mult_min": 1.6, "shortage_mult_max": 2.5,
                "quality_start": 0.96, "quality_min": 0.90, "quality_max": 0.99},
            "desal": {"capacity_m3_day": 300.0, "kwh_per_m3": 3.5, "sale_price_per_m3": 0.5, "opex_day": 20.0},
            "fresh_water": {"trucked_price_per_m3": 2.5},
            "silo": {"capacity_kg": 20000.0},
            "buildings": {}}

# Densidad aproximada del agua (kg/L): 35 PSU ≈ 1,025.
static func rho(psu: float) -> float:
    return float(data.water.rho_base) + float(data.water.rho_per_psu) * psu

# Masa de sal (kg) para llevar V m³ de agua de s_from a s_to PSU (g/kg), con pureza de la sal 0..1.
static func salt_mass_kg(volume_m3: float, s_from: float, s_to: float, purity: float = 1.0) -> float:
    if s_to <= s_from:
        return 0.0
    var mass_total := volume_m3 * 1000.0 * rho(s_from)
    return mass_total * (s_to - s_from) / 1000.0 / (1.0 - s_to / 1000.0) / maxf(0.05, purity)

# Fracción de agua dulce a mezclar con agua de fuente s_src para obtener s_to.
static func fresh_fraction(s_src: float, s_to: float) -> float:
    if s_src <= s_to:
        return 0.0
    return clampf(1.0 - s_to / s_src, 0.0, 1.0)

static func fresh_m3_for(volume_m3: float, s_src: float, s_to: float) -> float:
    return volume_m3 * fresh_fraction(s_src, s_to)

# Necesidad de un edificio según la salinidad de la fuente de su zona ("dulce" o "salada").
static func need_for(id: String, zone_water: String, purity: float) -> Dictionary:
    var cfg: Dictionary = data.buildings.get(id, {})
    if cfg.is_empty():
        return {}
    var src: float = data.zones[zone_water]
    var lo: float = cfg.psu_min
    var hi: float = cfg.psu_max
    var target := (lo + hi) / 2.0
    var v: float = cfg.volume_m3
    var ex: float = cfg.exchange_pct_day / 100.0
    var res := {"type": "none", "src": src, "target": target, "lo": lo, "hi": hi, "volume": v,
        "fill_kg": 0.0, "daily_kg": 0.0, "fill_m3": 0.0, "daily_m3": 0.0}
    if src < lo:
        res.type = "salt"
        res.fill_kg = salt_mass_kg(v, src, target, purity)
        res.daily_kg = salt_mass_kg(v * ex, src, target, purity)
    elif src > hi:
        res.type = "fresh"
        res.fill_m3 = fresh_m3_for(v, src, target)
        res.daily_m3 = fresh_m3_for(v * ex, src, target)
    return res
