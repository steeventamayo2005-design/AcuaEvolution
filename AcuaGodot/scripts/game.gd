extends Node
# Autoload "Game": estado global, reloj, economía, contratos, procesamiento, SCADA, automatización y radio.

const DOME_R := 120.0
const PLAZA_R := 14.0

var money := 15000.0
var xp := 0.0
var reputation := 50.0
var feed_kg := 5.0
var market_price := 1.2
var level := 1
var day := 0
var time_scale := 1
var minutes := 390.0
var module_levels := {}
var tanks: Array = []
var toast := ""
var flags := {}
var marker: Node3D
var buildings: Array = []
var hatch_dims := {}
var report: Dictionary = {}
var salt_price := 0.35
var salt_quality := 0.96
var salt_stock := 0.0
var salt_shortage_days := 0
var salt_hist: Array = []
var gen := {"sel": {}, "eng": {}, "prog": {}}
var next_uid := 1
var overlay_open := false
var has_tp := false
var pending_tp := Vector3.ZERO
var pending_yaw := 0.0
var server_temp := 30.0
var auto_cool := false
var tank_hist: Array = []
var contracts: Array = []
var sat := {}
var proc_left1 := 0.0
var proc_left2 := 0.0
var radio: Array = []
var ledger := {"in": {}, "out": {}}
var _toast_t := 0.0
var _hist_t := 0.0
var _auto_t := 0.0
var _alert_t := 0.0
var _alert_cd := {}
var _harv_ready := {}

func _ready() -> void:
    Salinity.load_data()
    for m in Catalog.MODULES:
        module_levels[m.id] = 0
    for id in Catalog.BUILDINGS:
        if id.begins_with("hatchery_"):
            var jp := hatchery_path(id)
            if FileAccess.file_exists(jp):
                hatch_dims[id] = HatcheryBuilder.dims(FileAccess.get_file_as_string(jp))
    reset_plan()
    _init_salt()
    _init_runtime()
    report = economy_report()

func hatchery_path(id: String) -> String:
    if id == "hatchery_anadara" or id == "hatchery":
        return "res://data/hatchery_anadara_modulos.json"
    return "res://data/%s.json" % id

func reset_all() -> void:
    money = 15000.0
    xp = 0.0
    reputation = 50.0
    feed_kg = 5.0
    market_price = 1.2
    level = 1
    day = 0
    minutes = 390.0
    flags = {}
    tanks.clear()
    marker = null
    gen = {"sel": {}, "eng": {}, "prog": {}}
    for m in Catalog.MODULES:
        module_levels[m.id] = 0
    next_uid = 1
    has_tp = false
    ledger = {"in": {}, "out": {}}
    Flows.reset()
    Ops.reset()
    reset_plan()
    _init_salt()
    _init_runtime()
    report = economy_report()

func earn(cat: String, v: float) -> void:
    money += v
    ledger["in"][cat] = float(ledger["in"].get(cat, 0.0)) + v

func spend(cat: String, v: float) -> void:
    money -= v
    ledger["out"][cat] = float(ledger["out"].get(cat, 0.0)) + v

func ledger_text() -> String:
    var tin := 0.0
    var tout := 0.0
    var a := ""
    var b := ""
    for k in ledger["in"]:
        tin += float(ledger["in"][k])
        a += "%s %.0f · " % [k, float(ledger["in"][k])]
    for k in ledger["out"]:
        tout += float(ledger["out"][k])
        b += "%s %.0f · " % [k, float(ledger["out"][k])]
    return "Ingresos %.0f $ (%s)\nGastos %.0f $ (%s)\nNeto %+.0f $" % [tin, a.trim_suffix(" · "), tout, b.trim_suffix(" · "), tin - tout]

func uid() -> int:
    next_uid += 1
    return next_uid - 1

func reset_plan() -> void:
    buildings.clear()
    buildings.append({"uid": uid(), "id": "tilapia_nave", "x": -45.0, "y": 25.0, "rot": 0, "cond": false, "lvl": 0, "auto": false})
    buildings.append({"uid": uid(), "id": "grid", "x": 0.0, "y": 100.0, "rot": 0, "cond": false, "lvl": 0, "auto": false})

func _init_runtime() -> void:
    if tanks.size() == 0:
        for k in 3:
            tanks.append(WaterTank.new("Tanque %d" % (k + 1), Catalog.SPECIES[[0, 3, 1][k]]))
    tank_hist.clear()
    for k in tanks.size():
        tank_hist.append([])
    server_temp = 30.0
    auto_cool = false
    contracts.clear()
    sat = {}
    radio.clear()
    _alert_cd = {}
    _harv_ready = {}
    _gen_contract()
    notify("Radio: bienvenido. Te avisaré cuando haya lotes listos o algo se desajuste.")

func _init_salt() -> void:
    var m: Dictionary = Salinity.data.market
    salt_price = m.base_price
    salt_quality = m.quality_start
    salt_stock = 0.0
    salt_shortage_days = 0
    salt_hist.clear()
    for i in 20:
        salt_hist.append(salt_price)

func flag(k: String) -> void:
    flags[k] = true

# ---------- guardado ----------
func to_dict() -> Dictionary:
    var tk: Array = []
    for t in tanks:
        tk.append(t.to_dict())
    return {"v": 2, "money": money, "xp": xp, "reputation": reputation, "feed_kg": feed_kg, "market_price": market_price,
        "level": level, "day": day, "minutes": minutes, "module_levels": module_levels, "flags": flags,
        "buildings": buildings, "tanks": tk, "gen": gen, "salt_price": salt_price, "salt_quality": salt_quality,
        "salt_stock": salt_stock, "salt_shortage_days": salt_shortage_days, "salt_hist": salt_hist,
        "next_uid": next_uid, "server_temp": server_temp, "auto_cool": auto_cool, "tank_hist": tank_hist,
        "contracts": contracts, "sat": sat, "ledger": ledger, "flows": Flows.to_dict(), "ops": Ops.to_dict()}

func from_dict(d: Dictionary) -> void:
    money = float(d.get("money", 15000.0))
    xp = float(d.get("xp", 0.0))
    reputation = float(d.get("reputation", 50.0))
    feed_kg = float(d.get("feed_kg", 5.0))
    market_price = float(d.get("market_price", 1.2))
    level = int(d.get("level", 1))
    day = int(d.get("day", 0))
    minutes = float(d.get("minutes", 390.0))
    flags = d.get("flags", {})
    var ml: Dictionary = d.get("module_levels", {})
    for m in Catalog.MODULES:
        module_levels[m.id] = int(ml.get(m.id, 0))
    buildings = d.get("buildings", [])
    next_uid = int(d.get("next_uid", 1))
    for b in buildings:
        if not b.has("uid"):
            b["uid"] = uid()
        b["uid"] = int(b["uid"])
        if not b.has("auto"):
            b["auto"] = false
        next_uid = maxi(next_uid, int(b["uid"]) + 1)
    tanks.clear()
    for td in d.get("tanks", []):
        tanks.append(WaterTank.from_dict(td))
    if tanks.size() == 0:
        _init_runtime()
    gen = d.get("gen", {"sel": {}, "eng": {}, "prog": {}})
    salt_price = float(d.get("salt_price", 0.35))
    salt_quality = float(d.get("salt_quality", 0.96))
    salt_stock = float(d.get("salt_stock", 0.0))
    salt_shortage_days = int(d.get("salt_shortage_days", 0))
    salt_hist = d.get("salt_hist", [])
    server_temp = float(d.get("server_temp", 30.0))
    auto_cool = bool(d.get("auto_cool", false))
    tank_hist = d.get("tank_hist", [])
    while tank_hist.size() < tanks.size():
        tank_hist.append([])
    contracts = d.get("contracts", [])
    sat = d.get("sat", {})
    ledger = d.get("ledger", {"in": {}, "out": {}})
    Flows.from_dict(d.get("flows", {}))
    Ops.from_dict(d.get("ops", {}))
    marker = null
    has_tp = false
    report = economy_report()

# ---------- catálogo de edificios ----------
func def(id: String) -> Dictionary:
    var d: Dictionary = Catalog.BUILDINGS[id].duplicate()
    if hatch_dims.has(id):
        d["w"] = hatch_dims[id].x
        d["d"] = hatch_dims[id].y
    if id == "desal":
        var ds: Dictionary = Salinity.data.desal
        var cap: float = ds.capacity_m3_day
        var kwh: float = ds.kwh_per_m3
        d["m3"] = cap
        d["kw"] = -cap * kwh / 24.0
        d["opex"] = ds.opex_day
        d["income"] = 0.0
        d["desc"] = "Ósmosis inversa: %.0f m³/día a %.1f kWh/m³. Abastece agua dulce a cultivos de agua dulce en zona salada y vende el excedente (%.2f $/m³)." % [cap, kwh, ds.sale_price_per_m3]
    elif id == "salt_silo":
        d["desc"] = "Almacena %.0f kg de sal: compra cuando el precio baja y resiste escaseces." % Salinity.data.silo.capacity_kg
    return d

func size_of(b: Dictionary) -> Vector2:
    var d := def(b.id)
    if b.rot == 1:
        return Vector2(d.d, d.w)
    return Vector2(d.w, d.d)

func module_def(id: String) -> Dictionary:
    for m in Catalog.MODULES:
        if m.id == id:
            return m
    return {}

func count_of(id: String) -> int:
    var n := 0
    for b in buildings:
        if b.id == id:
            n += 1
    return n

# Cuadrantes: x<0,y>0 dulce cálida; x<0,y<0 dulce fría; x>0,y<0 salada cálida; x>0,y>0 salada fría
func zone_of(x: float, y: float) -> Dictionary:
    var water := "dulce" if x < 0.0 else "salada"
    var temp := "calida"
    if (x < 0.0 and y < 0.0) or (x >= 0.0 and y >= 0.0):
        temp = "fria"
    return {"water": water, "temp": temp}

func zone_status(b: Dictionary) -> Dictionary:
    var d := def(b.id)
    if not d.has("water"):
        return {"applies": false, "match": true}
    var z := zone_of(b.x, b.y)
    return {"applies": true, "match": z.water == d.water and z.temp == d.temp, "zone": z}

func mult(b: Dictionary) -> float:
    var s := zone_status(b)
    if not s.applies or s.match:
        return 1.0
    if b.cond:
        return 3.0 if def(b.id).get("rare", false) else 2.0
    return 0.5

func kw_of(b: Dictionary) -> float:
    var k: float = def(b.id).get("kw", 0.0)
    if k < 0.0:
        k *= Ops.kw_mult(b)
    if k < 0.0 and b.cond:
        k -= absf(k) * 0.4 + 4.0
    if k < 0.0 and b.get("auto", false):
        k *= 1.1
    return k

func salinity_need(b: Dictionary) -> Dictionary:
    var d := def(b.id)
    if not d.has("water"):
        return {}
    var z := zone_of(b.x, b.y)
    return Salinity.need_for(b.id, z.water, salt_quality)

func cond_cost(b: Dictionary) -> int:
    return roundi(maxf(2000.0, def(b.id).cost * 0.4))

func cond_total(b: Dictionary) -> Dictionary:
    var cap := float(cond_cost(b))
    var fill := 0.0
    var n := salinity_need(b)
    if not n.is_empty():
        if n.type == "salt":
            fill = n.fill_kg * salt_price
        elif n.type == "fresh":
            fill = n.fill_m3 * float(Salinity.data.fresh_water.trucked_price_per_m3)
    return {"cap": cap, "fill": fill, "total": cap + fill}

# ---------- SCADA, servidor y automatización IA ----------
func server_ok() -> bool:
    return count_of("hub") == 0 or server_temp <= 75.0

func scada_online() -> bool:
    return count_of("scada") > 0 and count_of("hub") > 0 and server_temp <= 75.0

func can_automate() -> bool:
    return scada_online()

func auto_cost(b: Dictionary) -> int:
    var d := def(b.id)
    var pct := 0.8
    if d.cat == "alimento":
        pct = 0.7
    elif d.cat == "hatchery":
        pct = 0.9
    var v: float = d.get("value", d.cost)
    return roundi(maxf(500.0, v * pct))

func automate(b: Dictionary) -> String:
    if not scada_online():
        return "Necesitas la Oficina SCADA y el Hub de servidores en línea"
    if b.get("auto", false):
        return "Ya está automatizado"
    var c := auto_cost(b)
    if money < c:
        return "Dinero insuficiente ($%d)" % c
    spend("automatizacion", c)
    b["auto"] = true
    notify("Heimdall: automatización activada en %s." % def(b.id).name)
    return ""

func cool_manual() -> void:
    server_temp = maxf(30.0, server_temp - 30.0)
    say("Ventilas abiertas: servidor a %.0f °C" % server_temp)

func buy_auto_cool() -> String:
    if count_of("hub") == 0:
        return "Primero construye el Hub de servidores"
    if auto_cool:
        return "Ya tienes climatización automática"
    if money < 12000.0:
        return "Dinero insuficiente ($12000)"
    spend("automatizacion", 12000.0)
    auto_cool = true
    return ""

func server_tick(h: float) -> void:
    if count_of("hub") == 0:
        server_temp = 30.0
        return
    if auto_cool:
        server_temp += (42.0 - server_temp) * clampf(h * 0.8, 0.0, 1.0)
    else:
        server_temp = minf(110.0, server_temp + h * 5.0)

func buy_sales_agent() -> String:
    if flags.has("auto_sell"):
        return "Ya tienes agente de ventas"
    if money < 150.0:
        return "Dinero insuficiente ($150)"
    spend("automatizacion", 150.0)
    flag("auto_sell")
    notify("Agente de ventas contratado: cosecha y vende solo los lotes de 350 g o más (comisión 4 %).")
    return ""

func buy_resow() -> String:
    if not flags.has("auto_sell"):
        return "Primero contrata al agente de ventas"
    if flags.has("auto_sow"):
        return "Ya tienes resiembra automática"
    if money < 250.0:
        return "Dinero insuficiente ($250)"
    spend("automatizacion", 250.0)
    flag("auto_sow")
    notify("Resiembra automática activada: repite la siembra tras cada venta.")
    return ""

func _auto_sales() -> void:
    if not flags.has("auto_sell"):
        return
    for t in tanks:
        if t.fish > 0 and t.avg_w >= 350.0:
            var m0 := money
            var msg: String = t.harvest()
            var gain := money - m0
            if gain > 0.0:
                spend("comision agente", gain * 0.04)
            notify("Agente: %s" % msg)
        if t.fish == 0 and flags.has("auto_sow") and t.stock_n > 0:
            t.sow(t.sp, t.stock_n)

func _auto_tick() -> void:
    var nave_auto := false
    for b in buildings:
        if b.id == "tilapia_nave" and b.get("auto", false):
            nave_auto = true
    if not nave_auto or not scada_online():
        return
    for t in tanks:
        if t.fish == 0:
            continue
        if t.o2 < 6.0:
            t.aeration = minf(100.0, t.aeration + 10.0)
        elif t.o2 > 8.5 and t.aeration > 30.0:
            t.aeration -= 5.0
        if t.hunger > 50.0 and feed_kg > 0.1:
            t.feed()
        if t.nh3 > 0.3:
            t.water_change()
        if t.parasites > 30.0:
            t.treat()
        if t.sludge_kg > 60.0 or t.dead_kg > 1.0:
            t.purge()

# ---------- radio / guía ----------
func notify(msg: String) -> void:
    radio.push_front({"t": msg, "age": 0.0})
    while radio.size() > 5:
        radio.pop_back()
    say(msg)

func _alert(key: String, msg: String, cd_ms: int = 90000) -> void:
    var now := Time.get_ticks_msec()
    if now - int(_alert_cd.get(key, -1000000)) < cd_ms:
        return
    _alert_cd[key] = now
    notify(msg)

func _alerts_tick() -> void:
    for k in tanks.size():
        var t: WaterTank = tanks[k]
        if t.fish == 0:
            _harv_ready[k] = false
            continue
        if t.avg_w >= 350.0 and not _harv_ready.get(k, false):
            _harv_ready[k] = true
            notify("Guía: %s listo para cosechar (%d g, %.0f kg)." % [t.name_t, int(t.avg_w), t.biomass()])
        if t.o2 < 5.0:
            _alert("o2%d" % k, "Guía: oxígeno bajo en %s (%.1f mg/L). Enciende el aireador." % [t.name_t, t.o2])
        if t.nh3 > 0.3:
            _alert("nh%d" % k, "Guía: amoníaco alto en %s. Cambia el agua." % t.name_t)
        if t.stress > 45.0:
            _alert("st%d" % k, "Guía: peces estresados en %s." % t.name_t)
        if t.hunger > 65.0:
            _alert("hu%d" % k, "Guía: los peces de %s tienen hambre." % t.name_t, 60000)
        if t.dead_kg > 1.0:
            _alert("dd%d" % k, "Guía: hay %d peces muertos en %s. Retíralos (Purgar)." % [t.dead_fish, t.name_t])
        if t.sludge_kg > 60.0:
            _alert("sl%d" % k, "Guía: lodo acumulado en %s (%.0f kg). Purga el tanque." % [t.name_t, t.sludge_kg])
        if t.parasites > 30.0:
            _alert("pa%d" % k, "Guía: parásitos en aumento en %s." % t.name_t)
    if count_of("hub") > 0 and server_temp > 65.0 and server_temp <= 75.0:
        _alert("srv", "Guía: el servidor se sobrecalienta (%.0f °C). Abre ventilas desde la tableta." % server_temp, 60000)
    elif count_of("hub") > 0 and server_temp > 75.0:
        _alert("srv2", "Guía: SERVIDOR CAÍDO (ERR: NO_SIGNAL). Enfría ya.", 60000)
    for c in contracts:
        if int(c.due) - day <= 3 and int(c.due) >= day:
            _alert("c%d" % int(c.id), "Guía: el contrato de %s vence en %d día(s)." % [c.client, int(c.due) - day], 600000)

# ---------- mercado, procesamiento y contratos ----------
func sell_fish(kg: float, sp: Dictionary) -> Dictionary:
    var base: float = sp.price * (0.9 + reputation / 500.0) * Genetics.price_mult(sp)
    var s: float = sat.get(sp.id, 0.0)
    var factor := 1.0 / (1.0 + s / 1500.0)
    var rev := 0.0
    var left := kg
    var a := minf(left, minf(proc_left1, proc_left2))
    rev += a * base * 4.0
    proc_left1 -= a
    proc_left2 -= a
    left -= a
    var b := minf(left, proc_left1)
    rev += b * base * 2.5
    proc_left1 -= b
    left -= b
    rev += left * base
    Flows.from_processing(b, a)
    sat[sp.id] = s + kg
    return {"rev": rev * factor, "factor": factor, "proc": a + b}

func _refill_processing() -> void:
    proc_left1 = 400.0 * count_of("fillet_plant")
    proc_left2 = 250.0 * count_of("meal_plant")

func _gen_contract() -> void:
    var sp: Dictionary = Catalog.SPECIES[randi() % Catalog.SPECIES.size()]
    var clients := ["Restaurante El Muelle", "Supermercado Aqua+", "Cooperativa Pescadores", "Hotel Costa Azul", "Laboratorio Marino"]
    var kg := float(randi_range(3, 10)) * 10.0
    var min_w := float(randi_range(3, 6)) * 100.0 + 50.0
    var price: float = sp.price * randf_range(1.4, 2.0)
    contracts.append({"id": uid(), "client": clients[randi() % clients.size()], "sp": sp.id, "sp_name": sp.name,
        "kg": kg, "min_w": min_w, "due": day + randi_range(10, 18), "price": price})

func deliver_contract(t: WaterTank) -> Dictionary:
    for c in contracts:
        if c.sp == t.sp.id and t.avg_w >= float(c.min_w) and t.biomass() >= float(c.kg):
            var rev: float = float(c.kg) * float(c.price)
            earn("contratos", rev)
            reputation = minf(100.0, reputation + 4.0)
            add_xp(float(c.kg) / 4.0)
            contracts.erase(c)
            return {"kg": float(c.kg), "rev": rev, "msg": "Contrato cumplido con %s: +$%.0f y +4 reputación" % [c.client, rev]}
    return {}

# ---------- economía del sitio ----------
func economy_report() -> Dictionary:
    var demand := 0.0
    var srcs: Array = []
    var water_dem := 0.0
    var water_sup := 200.0
    var salt_need := 0.0
    var fresh_need := 0.0
    var desal_n := 0
    if auto_cool and count_of("hub") > 0:
        demand += 10.0
    for b in buildings:
        var d := def(b.id)
        var k := kw_of(b)
        if k < 0.0:
            demand += -k
        elif k > 0.0:
            srcs.append({"cap": k * d.get("cf", 1.0) * Ops.uptime(b), "cost": d.get("kwh", 0.1), "ren": d.get("ren", false)})
        var w: float = d.get("m3", 0.0)
        if w < 0.0:
            water_dem += -w
        else:
            water_sup += w
        if b.id == "desal":
            desal_n += 1
        if b.cond:
            var n := salinity_need(b)
            if not n.is_empty():
                if n.type == "salt":
                    salt_need += n.daily_kg
                elif n.type == "fresh":
                    fresh_need += n.daily_m3
    srcs.sort_custom(func(a, c): return a.cost < c.cost)
    var left := demand
    var energy_cost := 0.0
    var cap := 0.0
    var ren_use := 0.0
    for s in srcs:
        cap += s.cap
        var use := minf(left, s.cap)
        energy_cost += use * 24.0 * s.cost
        if s.ren:
            ren_use += use
        left -= use
    var eff_e := 1.0
    if demand > 0.0:
        eff_e = clampf((demand - left) / demand, 0.0, 1.0)
    var eff_w := 1.0
    if water_dem > 0.0:
        eff_w = clampf(water_sup / water_dem, 0.0, 1.0)
    var income := 0.0
    var opex := 0.0
    var biomass := 0.0
    for b in buildings:
        var d := def(b.id)
        var ox: float = d.get("opex", 0.0)
        if b.get("auto", false):
            ox *= 1.05
        opex += ox
        var inc: float = d.get("income", 0.0)
        if inc > 0.0:
            var am := 1.2 if b.get("auto", false) else 1.0
            income += inc * mult(b) * eff_e * eff_w * am
            if d.has("water"):
                biomass += inc * 0.08 * mult(b)
    for t in tanks:
        biomass += t.biomass() / 1000.0
    var green := 0.0
    var ren_share := 0.0
    if demand > 0.0:
        ren_share = ren_use / demand
    if ren_share >= 0.5:
        green += 60.0
    if total_levels() >= 5:
        green += 40.0
    var desal_cap: float = desal_n * float(Salinity.data.desal.capacity_m3_day)
    var from_desal := minf(fresh_need, desal_cap)
    var fresh_cost := (fresh_need - from_desal) * float(Salinity.data.fresh_water.trucked_price_per_m3)
    var fresh_income := (desal_cap - from_desal) * float(Salinity.data.desal.sale_price_per_m3)
    var salt_cost := salt_need * salt_price
    return {"demand": demand, "cap": cap, "eff_e": eff_e, "water_dem": water_dem, "water_sup": water_sup, "eff_w": eff_w,
        "energy_cost": energy_cost, "income": income, "opex": opex, "biomass": biomass, "green": green, "ren_share": ren_share,
        "salt_need_kg": salt_need, "salt_cost": salt_cost, "fresh_need": fresh_need, "fresh_cost": fresh_cost, "fresh_income": fresh_income,
        "net": income + fresh_income + green - opex - energy_cost - fresh_cost - salt_cost}

func salt_market_tick() -> void:
    var m: Dictionary = Salinity.data.market
    var base: float = m.base_price
    salt_price += (base - salt_price) * float(m.mean_reversion) + salt_price * randf_range(-float(m.daily_volatility), float(m.daily_volatility))
    if salt_shortage_days > 0:
        salt_shortage_days -= 1
    elif randf() < float(m.shortage_prob_day):
        salt_shortage_days = randi_range(int(m.shortage_days_min), int(m.shortage_days_max))
        salt_price *= randf_range(float(m.shortage_mult_min), float(m.shortage_mult_max))
        notify("Guía: escasez de sal, el precio se dispara.")
    salt_quality = clampf(salt_quality + randf_range(-0.01, 0.01), float(m.quality_min), float(m.quality_max))
    salt_price = clampf(salt_price, base * 0.5, base * 4.0)
    salt_hist.append(salt_price)
    while salt_hist.size() > 40:
        salt_hist.pop_front()

func _daily() -> void:
    salt_market_tick()
    Genetics.tick()
    for k in sat.keys():
        sat[k] = float(sat[k]) * 0.93
    _refill_processing()
    Ops.daily()
    var disp: Dictionary = Flows.daily()
    if float(disp.kg) > 0.0:
        spend("disposicion de residuos", float(disp.cost))
        notify("Guía: el acopio de residuos se desbordó: se llevaron %.0f kg afuera por $%.0f." % [float(disp.kg), float(disp.cost)])
    for c in contracts.duplicate():
        if day > int(c.due):
            contracts.erase(c)
            reputation = maxf(0.0, reputation - 3.0)
            notify("Guía: venció el contrato de %s (-3 reputación)." % c.client)
    if contracts.size() < 3 and randf() < 0.5:
        _gen_contract()
        notify("Guía: nuevo contrato disponible en el PC de la oficina.")
    report = economy_report()
    var need: float = report.salt_need_kg
    var from_stock := minf(salt_stock, need)
    salt_stock -= from_stock
    var salt_paid := (need - from_stock) * salt_price
    var silo_cap := count_of("salt_silo") * float(Salinity.data.silo.capacity_kg)
    var base: float = Salinity.data.market.base_price
    if salt_price < base * 0.9 and silo_cap > salt_stock:
        var extra := minf(silo_cap - salt_stock, maxf(0.0, (money - 1000.0) / salt_price * 0.5))
        salt_stock += extra
        salt_paid += extra * salt_price
    earn("sitio", float(report.income) + float(report.fresh_income) + float(report.green))
    spend("operacion", float(report.opex))
    spend("energia sitio", float(report.energy_cost))
    spend("agua", float(report.fresh_cost))
    spend("sal", salt_paid)
    say("Día %d: ingresos %.0f $ · bono verde %.0f $ · balance %+.0f $" % [day, report.income + report.fresh_income, report.green, report.net + report.salt_cost - salt_paid])
    SaveGame.save()

# ---------- construcción ----------
func can_place(id: String, x: float, y: float, rot: int) -> String:
    var d := def(id)
    var sz := Vector2(d.w, d.d)
    if rot == 1:
        sz = Vector2(d.d, d.w)
    var r := Rect2(x - sz.x / 2.0, y - sz.y / 2.0, sz.x, sz.y)
    for c in [r.position, r.position + Vector2(sz.x, 0.0), r.position + Vector2(0.0, sz.y), r.end]:
        if c.length() > DOME_R - 2.0:
            return "Fuera del domo"
    var cx := clampf(0.0, r.position.x, r.end.x)
    var cy := clampf(0.0, r.position.y, r.end.y)
    if Vector2(cx, cy).length() < PLAZA_R + 1.0:
        return "Choca con la plaza central"
    for b in buildings:
        var s := size_of(b)
        var rb := Rect2(b.x - s.x / 2.0, b.y - s.y / 2.0, s.x, s.y).grow(1.0)
        if r.intersects(rb):
            return "Se solapa con otro edificio"
    if d.has("mod") or id == "genetics_lab" or id == "scada" or id == "hub":
        for b in buildings:
            if b.id == id:
                return "Ya instalado"
    if d.get("locked", false):
        return "Aún no disponible"
    var price: float = d.cost
    if d.has("mod"):
        price = module_def(d.mod).cost * pow(1.6, module_levels[d.mod])
    if money < price:
        return "Dinero insuficiente ($%.0f)" % price
    return ""

func place(id: String, x: float, y: float, rot: int) -> String:
    var err := can_place(id, x, y, rot)
    if err != "":
        return err
    var d := def(id)
    var lvl := 0
    if d.has("mod"):
        var e2 := buy_module(module_def(d.mod))
        if e2 != "":
            return e2
        lvl = 1
    else:
        spend("construccion", d.cost)
    buildings.append({"uid": uid(), "id": id, "x": x, "y": y, "rot": rot, "cond": false, "lvl": lvl, "auto": false})
    flag("built")
    _refill_processing()
    return ""

func demolish(b: Dictionary) -> String:
    if b.id == "tilapia_nave":
        return "La nave base tiene cultivo activo: no se puede demoler"
    var d := def(b.id)
    if d.has("mod"):
        module_levels[d.mod] = 0
    else:
        earn("construccion", d.cost * 0.5)
    buildings.erase(b)
    _refill_processing()
    return ""

func condition(b: Dictionary) -> String:
    var c: Dictionary = cond_total(b)
    if money < c.total:
        return "Dinero insuficiente ($%.0f)" % c.total
    spend("construccion", c.total)
    b.cond = true
    return ""

# ---------- cultivo a pie ----------
func total_levels() -> int:
    var s := 0
    for k in module_levels:
        s += module_levels[k]
    return s

func discount() -> float:
    return minf(0.6, total_levels() * 0.025)

func feed_cost() -> float:
    return market_price * (1.0 - discount())

func module_cost(m: Dictionary) -> int:
    return roundi(m.cost * pow(1.6, module_levels[m.id]))

func add_xp(x: float) -> void:
    xp += x
    while xp >= 100.0 * level:
        xp -= 100.0 * level
        level += 1

func say(s: String) -> void:
    if s == "":
        return
    toast = s
    _toast_t = 3.0

func buy_feed(kg: float) -> String:
    var c := feed_cost() * kg
    if money < c:
        return "Dinero insuficiente"
    spend("alimento", c)
    feed_kg += kg
    if kg >= 10.0:
        flag("bought")
    return ""

func craft_feed(item: String) -> String:
    var d: Dictionary = Flows.items.get(item, {})
    var yield_per_kg := float(d.get("to_feed", 0.0))
    if yield_per_kg <= 0.0:
        return "Ese material no se puede convertir en balanceado"
    var available := maxf(0.0, Flows.amount(item) - Ops.keep(item))
    if available < 0.01:
        return "No hay %s disponible: el inventario está vacío o reservado para otros módulos" % d.get("name", item)
    var used := Flows.take(item, available)
    var produced := used * yield_per_kg
    feed_kg += produced
    Ops.stat_saved += produced * feed_cost()
    flag("crafted_feed")
    return "Convertidos %.2f kg de %s en %.2f kg de balanceado (rendimiento de prueba)" % [used, d.get("name", item), produced]

func buy_module(m: Dictionary) -> String:
    if module_levels[m.id] >= 5:
        return "Nivel máximo"
    var c := module_cost(m)
    if money < c:
        return "Dinero insuficiente"
    spend("modulos", c)
    module_levels[m.id] += 1
    return ""

func _process(dt: float) -> void:
    if _toast_t > 0.0:
        _toast_t -= dt
        if _toast_t <= 0.0:
            toast = ""
    for r in radio:
        r.age = float(r.age) + dt
    var h := dt * time_scale * 0.1
    minutes += h * 60.0
    var d := int(minutes / 1440.0)
    if d > day:
        day = d
        market_price = clampf(market_price * (1.0 + (randf() - 0.5) * 0.08), 0.8, 2.2)
        _daily()
    for t in tanks:
        spend("energia tanques", t.step(h))
    server_tick(h)
    _hist_t += h
    if _hist_t >= 1.0:
        _hist_t = 0.0
        for k in tanks.size():
            tank_hist[k].append(tanks[k].o2)
            while tank_hist[k].size() > 40:
                tank_hist[k].pop_front()
        _auto_tick()
        Ops.tick_hour()
        _auto_sales()
    _alert_t += dt
    if _alert_t >= 2.0:
        _alert_t = 0.0
        _alerts_tick()
