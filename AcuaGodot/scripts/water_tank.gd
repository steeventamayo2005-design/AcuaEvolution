class_name WaterTank
extends RefCounted

# Simulación pura de un tanque (sin 3D). h = horas de juego transcurridas.
var name_t := ""
var sp: Dictionary
var fish := 0
var avg_w := 0.0
var o2 := 8.0
var temp := 24.0
var target_temp := 26.0
var ph := 7.4
var nh3 := 0.05
var stress := 8.0
var noise := 20.0
var parasites := 2.0
var health := 100.0
var hunger := 20.0
var aeration := 50.0
var stock_n := 200
var sludge_kg := 0.0   # lodo húmedo asentado (heces y alimento sin comer)
var dead_kg := 0.0     # peces muertos sin retirar
var dead_fish := 0
const VOL := 12.0

func _init(n: String, s: Dictionary) -> void:
    name_t = n
    sp = s

func biomass() -> float:
    return fish * avg_w / 1000.0

# Las acciones devuelven un mensaje ("" = sin mensaje).
func sow(s: Dictionary, n: int = 200) -> String:
    if fish > 0:
        return "El tanque ya tiene peces"
    var cost := n * 0.25 * (1.0 - clampf(Genetics.effect("fertility"), 0.0, 0.5))
    if Game.money < cost:
        return "Dinero insuficiente"
    Game.spend("semilla", cost)
    stock_n = n
    sp = s
    fish = n
    avg_w = 20.0
    o2 = 8.0
    nh3 = 0.05
    stress = 8.0
    parasites = 2.0
    health = 100.0
    hunger = 20.0
    Game.flag("sowed")
    return ""

func feed() -> String:
    if fish == 0:
        return "No hay peces"
    var kg := maxf(0.05, biomass() * 0.03)
    var h0 := hunger
    if Game.feed_kg < kg:
        return "Falta balanceado: %.2f kg. Cómpralo en el PC" % kg
    Game.feed_kg -= kg
    var uneaten := kg * Flows.p("uneaten_max") * clampf((30.0 - h0) / 30.0, 0.0, 1.0)
    sludge_kg += Flows.sludge_wet(kg - uneaten, uneaten)
    hunger = maxf(0.0, hunger - 65.0)
    nh3 = minf(3.0, nh3 + kg / VOL * 0.35)
    Game.flag("fed")
    return ""

func water_change() -> String:
    if Game.money < 2.0:
        return "Dinero insuficiente"
    Game.spend("cuidado", 2.0)
    Flows.add("efluente", VOL * Flows.p("water_change_frac"), name_t)
    nh3 *= 0.3
    parasites *= 0.8
    temp += (24.0 - temp) * 0.5
    Game.flag("wchg")
    return ""

func purge() -> String:
    if sludge_kg < 0.5 and dead_kg < 0.01:
        return "No hay lodo ni peces muertos que retirar"
    if Game.money < 1.0:
        return "Dinero insuficiente"
    Game.spend("cuidado", 1.0)
    var msg := "Retirados %.1f kg de lodo" % sludge_kg
    Flows.add("lodo_ras", sludge_kg, name_t)
    if dead_kg > 0.01:
        msg += " y %d peces muertos (%.1f kg)" % [dead_fish, dead_kg]
        Flows.add("mortalidad", dead_kg, name_t)
    msg += " al acopio"
    sludge_kg = 0.0
    dead_kg = 0.0
    dead_fish = 0
    nh3 *= 0.85
    Game.flag("purged")
    return msg

func treat() -> String:
    if Game.money < 10.0:
        return "Dinero insuficiente"
    Game.spend("cuidado", 10.0)
    parasites = maxf(0.0, parasites - 60.0)
    stress = minf(100.0, stress + 5.0)
    return ""

func harvest() -> String:
    if fish == 0:
        return "No hay peces"
    if avg_w < 350.0:
        return "Aún sin talla comercial (350 g)"
    var kg := biomass()
    var dc: Dictionary = Game.deliver_contract(self)
    var rest := kg - float(dc.get("kg", 0.0))
    var msg := ""
    if rest > 0.0:
        var sale: Dictionary = Game.sell_fish(rest, sp)
        Game.earn("ventas", float(sale.rev))
        msg = "Vendidos %.1f kg por $%.2f" % [rest, float(sale.rev)]
        if float(sale.proc) > 0.0:
            msg += " (%.0f kg procesados)" % float(sale.proc)
        if float(sale.factor) < 0.9:
            msg += " · mercado saturado ×%.2f" % float(sale.factor)
    if dc.has("msg"):
        msg = str(dc.msg) + (" · " + msg if msg != "" else "")
    Game.add_xp(kg / 2.0)
    Game.reputation = minf(100.0, Game.reputation + 1.0)
    fish = 0
    avg_w = 0.0
    Game.flag("sold")
    return msg

# Devuelve el costo de energía de este paso.
func step(h: float) -> float:
    if fish == 0:
        return 0.0
    var bio := biomass()
    var dens := bio / VOL
    hunger = clampf(hunger + h * 2.2, 0.0, 100.0)
    o2 += (9.0 - dens * 0.12 - (temp - 26.0) * 0.18 + aeration * 0.035 - nh3 * 0.8 - o2) * clampf(h * 0.6, 0.0, 1.0)
    temp += (target_temp - temp) * clampf(h * 0.3, 0.0, 1.0)
    nh3 = clampf(nh3 + (dens * 0.003 + sludge_kg / VOL * 0.0006 + dead_kg / VOL * 0.01) * h - nh3 * 0.1 * h * (1.0 + aeration / 60.0), 0.0, 3.0)
    ph = clampf(ph - nh3 * 0.004 * h + (7.4 - ph) * 0.02 * h, 5.0, 9.5)
    noise = 10.0 + aeration * 0.45
    var g := clampf(maxf(0.0, 5.0 - o2) * 14.0 + nh3 * 55.0 + maxf(0.0, absf(temp - sp.opt_temp) - Genetics.effect("temp")) * 4.0 \
        + maxf(0.0, noise - 40.0) * 0.8 + maxf(0.0, hunger - 50.0) * 0.5 + parasites * 0.35 + absf(ph - 7.4) * 8.0 * (1.0 - clampf(Genetics.effect("ph"), 0.0, 0.7)), 0.0, 100.0)
    stress += (g - stress) * clampf(h * 0.5, 0.0, 1.0)
    var bad := stress > 45.0 or nh3 > 0.5 or dead_kg > 3.0
    var res := clampf(Genetics.effect("disease"), 0.0, 0.8)
    parasites = clampf(parasites + h * (1.4 * (1.0 - res) if bad else -0.3), 0.0, 100.0)
    var dh := 0.4
    if stress > 45.0:
        dh = -(stress - 45.0) * 0.06 - parasites * 0.02 * (1.0 - res)
    health = clampf(health + h * dh, 0.0, 100.0)
    if (health < 30.0 or hunger >= 95.0) and randf() < h * 0.3:
        var dead := mini(fish, ceili(fish * 0.05))
        fish -= dead
        dead_fish += dead
        dead_kg += dead * avg_w / 1000.0
    if hunger < 65.0 and health > 40.0:
        avg_w = minf(900.0, avg_w * (1.0 + 0.01 * sp.growth * (1.0 + Genetics.effect("growth") + Genetics.effect("sex")) * h * (1.0 - stress / 140.0) * clampf(1.0 - maxf(0.0, absf(temp - sp.opt_temp) - Genetics.effect("temp")) / 10.0, 0.0, 1.0)))
    if fish == 0:
        avg_w = 0.0
    return (absf(target_temp - 24.0) * 0.01 + aeration * 0.002) * h

func to_dict() -> Dictionary:
    return {"name": name_t, "sp": sp.id, "fish": fish, "avg_w": avg_w, "o2": o2, "temp": temp, "tt": target_temp, "ph": ph,
        "nh3": nh3, "stress": stress, "noise": noise, "par": parasites, "hp": health, "hu": hunger, "ae": aeration, "stock": stock_n, "sl": sludge_kg, "dk": dead_kg, "df": dead_fish}

static func from_dict(d: Dictionary) -> WaterTank:
    var s: Dictionary = Catalog.SPECIES[0]
    for x in Catalog.SPECIES:
        if x.id == d.get("sp", "roja"):
            s = x
    var t := WaterTank.new(d.get("name", "Tanque"), s)
    t.fish = int(d.get("fish", 0))
    t.avg_w = float(d.get("avg_w", 0.0))
    t.o2 = float(d.get("o2", 8.0))
    t.temp = float(d.get("temp", 24.0))
    t.target_temp = float(d.get("tt", 26.0))
    t.ph = float(d.get("ph", 7.4))
    t.nh3 = float(d.get("nh3", 0.05))
    t.stress = float(d.get("stress", 8.0))
    t.noise = float(d.get("noise", 20.0))
    t.parasites = float(d.get("par", 2.0))
    t.health = float(d.get("hp", 100.0))
    t.hunger = float(d.get("hu", 20.0))
    t.aeration = float(d.get("ae", 50.0))
    t.stock_n = int(d.get("stock", 200))
    t.sludge_kg = float(d.get("sl", 0.0))
    t.dead_kg = float(d.get("dk", 0.0))
    t.dead_fish = int(d.get("df", 0))
    return t
