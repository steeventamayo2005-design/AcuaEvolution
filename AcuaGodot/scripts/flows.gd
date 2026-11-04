extends Node
# Autoload "Flows": inventario de materiales y desechos del sitio.
# Paso 1 de la economía circular: aquí se GENERAN los desechos de los peces.
# Los módulos que los consumen (compost, lombrices, BSF, biodigestor) llegan después.

const DATA_PATH := "res://data/flows_items.json"

var items: Dictionary = {}
var params: Dictionary = {}
var stock: Dictionary = {}        # id -> cantidad en acopio (kg, o m³ para efluente)
var made_today: Dictionary = {}   # id -> generado hoy
var made_total: Dictionary = {}   # id -> generado en toda la partida
var by_source: Dictionary = {}    # "Tanque 1 · lodo_ras" -> total
var sunk_total: Dictionary = {}   # material que salió del sitio (p. ej. a la planta de harina)
var disposed_kg := 0.0            # desechado afuera por falta de espacio de acopio

func _ready() -> void:
    load_data()

func load_data() -> void:
    if not FileAccess.file_exists(DATA_PATH):
        push_warning("Flows: falta %s" % DATA_PATH)
        return
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    if parsed is Dictionary:
        params = parsed.get("params", {})
        items = parsed.get("items", {})

func p(k: String) -> float:
    return float(params.get(k, 0.0))

func reset() -> void:
    stock = {}
    made_today = {}
    made_total = {}
    by_source = {}
    sunk_total = {}
    disposed_kg = 0.0

# ---------------------------------------------------------------- operaciones
func add(item: String, qty: float, src: String = "") -> void:
    if qty <= 0.0:
        return
    stock[item] = float(stock.get(item, 0.0)) + qty
    made_today[item] = float(made_today.get(item, 0.0)) + qty
    made_total[item] = float(made_total.get(item, 0.0)) + qty
    if src != "":
        var k := "%s · %s" % [src, item]
        by_source[k] = float(by_source.get(k, 0.0)) + qty

func take(item: String, qty: float) -> float:
    var got := minf(qty, float(stock.get(item, 0.0)))
    if got > 0.0:
        stock[item] = float(stock[item]) - got
    return got

func amount(item: String) -> float:
    return float(stock.get(item, 0.0))

func sink(item: String, qty: float) -> void:
    if qty > 0.0:
        sunk_total[item] = float(sunk_total.get(item, 0.0)) + qty

# kg orgánicos en acopio (sin contar agua)
func organic_stock() -> float:
    var t := 0.0
    for id in stock:
        if items.get(id, {}).get("organic", false):
            t += float(stock[id])
    return t

# kg de nitrógeno que hay en el acopio (sirve luego para el balance C:N del compost)
func nitrogen_kg() -> float:
    var t := 0.0
    for id in stock:
        var d: Dictionary = items.get(id, {})
        t += float(stock[id]) * float(d.get("ms", 0.0)) * float(d.get("n", 0.0))
    return t

# ---------------------------------------------------------------- fuentes de desecho
# Lodo húmedo (kg) que sale de alimentar `eaten` kg y dejar `uneaten` kg sin comer.
func sludge_wet(eaten: float, uneaten: float) -> float:
    var dry := eaten * p("sludge_dry_per_feed") + uneaten * p("feed_dm")
    return dry / maxf(0.01, p("sludge_ms"))

# Residuos de fileteado. `fillet_only` kg pasaron solo por fileteado (los residuos quedan en el sitio);
# `with_meal` kg pasaron también por la planta de harina (sus residuos se consumen allí).
func from_processing(fillet_only: float, with_meal: float) -> void:
    var waste := 1.0 - p("fillet_yield")
    var split: Dictionary = params.get("residue_split", {})
    for id in split:
        add(id, fillet_only * waste * float(split[id]), "Planta de fileteado")
    sink("residuo_a_harina", with_meal * waste)

# ---------------------------------------------------------------- ciclo diario
# Devuelve {"kg": desechado, "cost": $} si el acopio se desbordó.
func daily() -> Dictionary:
    var res := {"kg": 0.0, "cost": 0.0}
    var over := organic_stock() - p("acopio_cap_kg")
    if over > 0.0:
        var tot := organic_stock()
        for id in stock.keys():
            if items.get(id, {}).get("organic", false):
                stock[id] = float(stock[id]) * (1.0 - over / tot)
        disposed_kg += over
        res.kg = over
        res.cost = over * p("disposal_cost_per_kg")
    made_today = {}
    return res

# ---------------------------------------------------------------- presentación
func text() -> String:
    var s := "Desechos en acopio (%.0f / %.0f kg):\n" % [organic_stock(), p("acopio_cap_kg")]
    var groups := {"waste": "", "product": "", "input": ""}
    for id in items:
        var q := amount(id)
        if q > 0.05:
            var k: String = items[id].get("kind", "waste")
            groups[k] = str(groups.get(k, "")) + "  %s: %.1f %s\n" % [items[id].name, q, items[id].unit]
    s += groups.waste if groups.waste != "" else "  (vacío)\n"
    if groups.product != "":
        s += "Productos en bodega:\n" + groups.product
    if groups.input != "":
        s += "Insumos:\n" + groups.input
    s += "Nitrógeno en acopio: %.2f kg · desechado afuera: %.0f kg" % [nitrogen_kg(), disposed_kg]
    return s

# Tags planos, listos para publicarse más adelante por MQTT.
func tags() -> Dictionary:
    var t := {}
    for id in items:
        t["acua/flujos/%s/stock" % id] = amount(id)
        t["acua/flujos/%s/hoy" % id] = float(made_today.get(id, 0.0))
    t["acua/flujos/acopio/organico_kg"] = organic_stock()
    t["acua/flujos/acopio/n_kg"] = nitrogen_kg()
    return t

# ---------------------------------------------------------------- guardado
func to_dict() -> Dictionary:
    return {"stock": stock, "made_today": made_today, "made_total": made_total,
        "by_source": by_source, "sunk": sunk_total, "disposed": disposed_kg}

func from_dict(d: Dictionary) -> void:
    stock = d.get("stock", {})
    made_today = d.get("made_today", {})
    made_total = d.get("made_total", {})
    by_source = d.get("by_source", {})
    sunk_total = d.get("sunk", {})
    disposed_kg = float(d.get("disposed", 0.0))
