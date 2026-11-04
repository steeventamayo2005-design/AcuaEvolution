class_name Genetics
extends RefCounted
# Mejora genética: selección (barata y lenta) o ingeniería (cara e inmediata). Valores de prueba.

const TRAITS := [
    {"id": "growth", "name": "Crecimiento", "desc": "Más peso por día", "sel": 0.03, "eng": 0.08},
    {"id": "flavor", "name": "Sabor / calidad", "desc": "Mejor precio de venta", "sel": 0.02, "eng": 0.06},
    {"id": "color", "name": "Color", "desc": "Prima de precio (más en tilapia roja)", "sel": 0.02, "eng": 0.07},
    {"id": "fertility", "name": "Fertilidad", "desc": "Alevines más baratos", "sel": 0.03, "eng": 0.08},
    {"id": "sex", "name": "Proporción de machos", "desc": "Machos crecen más: sube el crecimiento", "sel": 0.0, "eng": 0.05},
    {"id": "disease", "name": "Resistencia a patógenos", "desc": "Menos parásitos y mortalidad", "sel": 0.04, "eng": 0.10},
    {"id": "ph", "name": "Tolerancia al pH", "desc": "Menos estrés por pH", "sel": 0.03, "eng": 0.08},
    {"id": "temp", "name": "Tolerancia térmica", "desc": "Banda de temperatura más ancha (°C)", "sel": 0.25, "eng": 0.6},
]
const SEL_MAX := 10
const ENG_MAX := 5
const SEL_DAYS := 4

static func lvl(kind: String, id: String) -> int:
    return int(Game.gen[kind].get(id, 0))

static func effect(id: String) -> float:
    for t in TRAITS:
        if t.id == id:
            return lvl("sel", id) * t.sel + lvl("eng", id) * t.eng
    return 0.0

static func price_mult(sp: Dictionary) -> float:
    var col := effect("color") * (1.0 if sp.id == "roja" else 0.5)
    return 1.0 + effect("flavor") + col

static func sel_cost(id: String) -> int:
    return roundi(120.0 * (lvl("sel", id) + 1))

static func eng_cost(id: String) -> int:
    return roundi(4000.0 * pow(1.5, lvl("eng", id)))

static func has_lab() -> bool:
    for b in Game.buildings:
        if b.id == "genetics_lab":
            return true
    return false

static func start_selection(id: String) -> String:
    if lvl("sel", id) >= SEL_MAX:
        return "Nivel máximo de selección"
    if Game.gen.prog.has(id):
        return "Ya hay un programa en curso para este rasgo"
    var c := sel_cost(id)
    if Game.money < c:
        return "Dinero insuficiente ($%d)" % c
    Game.spend("genetica", c)
    Game.gen.prog[id] = SEL_DAYS
    return ""

static func edit_dna(id: String) -> String:
    if not has_lab():
        return "Necesitas un laboratorio de genética (categoría Genética)"
    if lvl("eng", id) >= ENG_MAX:
        return "Nivel máximo de ingeniería"
    var c := eng_cost(id)
    if Game.money < c:
        return "Dinero insuficiente ($%d)" % c
    Game.spend("genetica", c)
    Game.gen.eng[id] = lvl("eng", id) + 1
    return ""

static func tick() -> void:
    for id in Game.gen.prog.keys():
        Game.gen.prog[id] -= 1
        if Game.gen.prog[id] <= 0:
            Game.gen.prog.erase(id)
            Game.gen.sel[id] = lvl("sel", id) + 1
