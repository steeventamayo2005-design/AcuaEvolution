extends Node
# Autoload "Ops": motor de actividad de los módulos circulares.
# Cada módulo construido trabaja solo cada hora de juego: toma insumos del acopio (Flows),
# produce, se desgasta y vende lo que sobra. El estado vive dentro del diccionario del edificio
# (b.st, b.hop, b.mode, b.prio, b.on), así que se guarda con la partida sin código extra.

const DATA_PATH := "res://data/ops_modules.json"

var cfg: Dictionary = {}
var tiers: Array = []
var recipes: Dictionary = {}
var hopups: Dictionary = {}
var events: Array = []          # últimos eventos [{"d": día, "t": texto}]
var stat_rev := 0.0             # $ vendidos en total
var stat_saved := 0.0           # $ de balanceado que no hubo que comprar
var stat_kwh := 0.0             # kWh equivalentes del biogás quemado
var rev_by_item: Dictionary = {}
var day_rev := 0.0

const STATE_NAMES := {
    "idle": "En espera", "producing": "Produciendo", "partial": "Producción parcial",
    "no_input": "Sin insumo", "no_power": "Sin energía", "broken": "Averiado", "off": "Apagado"}
const STATE_COLORS := {
    "idle": Color(0.6, 0.65, 0.7), "producing": Color(0.2, 0.9, 0.35), "partial": Color(1.0, 0.75, 0.2),
    "no_input": Color(0.35, 0.55, 0.9), "no_power": Color(1.0, 0.45, 0.2), "broken": Color(1.0, 0.15, 0.15),
    "off": Color(0.25, 0.25, 0.28)}

func _ready() -> void:
    load_data()

func load_data() -> void:
    if not FileAccess.file_exists(DATA_PATH):
        push_warning("Ops: falta %s" % DATA_PATH)
        return
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    if parsed is Dictionary:
        cfg = parsed.get("cfg", {})
        tiers = parsed.get("tiers", [])
        recipes = parsed.get("recipes", {})
        hopups = parsed.get("hopups", {})

func reset() -> void:
    events = []
    stat_rev = 0.0
    stat_saved = 0.0
    stat_kwh = 0.0
    rev_by_item = {}
    day_rev = 0.0

func c(k: String) -> float:
    return float(cfg.get(k, 0.0))

# ---------------------------------------------------------------- acceso
func has(b: Dictionary) -> bool:
    return recipes.has(b.get("id", ""))

func by_uid(uid: int) -> Dictionary:
    for b in Game.buildings:
        if int(b.get("uid", -1)) == uid:
            return b
    return {}

func ensure(b: Dictionary) -> void:
    if not b.has("st"):
        b["st"] = {"state": "idle", "wear": 0.0, "up": 1.0, "ult": 0.0, "ult_h": 0.0, "made": 0.0, "r": 0.0, "cn": 0.0}
    if not b.has("hop"):
        b["hop"] = []
    if not b.has("mode"):
        b["mode"] = 0
    if not b.has("prio"):
        b["prio"] = 3
    if not b.has("on"):
        b["on"] = true

func level(b: Dictionary) -> int:
    var d: Dictionary = Game.def(b.id)
    if d.has("mod"):
        return clampi(int(Game.module_levels.get(d.mod, 1)), 1, 5)
    return clampi(1 + int(b.get("lvl", 0)), 1, 5)

func tier(b: Dictionary) -> Dictionary:
    return tiers[level(b)] if tiers.size() > level(b) else {"n": "?", "c": "#ffffff", "thru": 1.0, "slots": 1, "collect": 0.3}

func tier_color(b: Dictionary) -> Color:
    return Color.from_string(str(tier(b).c), Color.WHITE)

func state_name(s: String) -> String:
    return STATE_NAMES.get(s, s)

func state_color(s: String) -> Color:
    return STATE_COLORS.get(s, Color.WHITE)

# ---------------------------------------------------------------- hop-ups
func hop_sum(b: Dictionary, key: String) -> float:
    var t := 0.0
    for h in b.get("hop", []):
        t += float(hopups.get(h, {}).get(key, 0.0))
    return t

func hop_prod(b: Dictionary, key: String) -> float:
    var t := 1.0
    for h in b.get("hop", []):
        t *= float(hopups.get(h, {}).get(key, 1.0))
    return t

func hop_flag(b: Dictionary, key: String) -> bool:
    for h in b.get("hop", []):
        if hopups.get(h, {}).get(key, false):
            return true
    return false

func slots(b: Dictionary) -> int:
    return int(tier(b).slots)

func hop_available(b: Dictionary) -> Array:
    var out: Array = []
    for id in hopups:
        var sc: Array = hopups[id].get("scope", [])
        if (sc.has("*") or sc.has(b.id)) and not (b.get("hop", []) as Array).has(id):
            out.append(id)
    return out

func install_hop(b: Dictionary, id: String) -> String:
    ensure(b)
    if not hopups.has(id):
        return ""
    if (b.hop as Array).size() >= slots(b):
        return "No quedan ranuras: mejora el módulo para tener más"
    var cost := float(hopups[id].cost)
    if Game.money < cost:
        return "Dinero insuficiente ($%.0f)" % cost
    Game.spend("mejoras", cost)
    (b.hop as Array).append(id)
    _event(b, "instaló %s" % hopups[id].name)
    return "Instalado: %s" % hopups[id].name

func remove_hop(b: Dictionary, id: String) -> String:
    if not (b.get("hop", []) as Array).has(id):
        return ""
    (b.hop as Array).erase(id)
    Game.earn("mejoras", float(hopups[id].cost) * 0.5)
    return "Quitado %s (recuperas el 50 %%)" % hopups[id].name

# ---------------------------------------------------------------- mejoras, mantenimiento, ability
func upgrade_cost(b: Dictionary) -> int:
    var d: Dictionary = Game.def(b.id)
    if d.has("mod"):
        return Game.module_cost(Game.module_def(d.mod))
    return roundi(float(d.cost) * 0.5 * pow(1.6, level(b) - 1))

func upgrade(b: Dictionary) -> String:
    var d: Dictionary = Game.def(b.id)
    if d.has("mod"):
        return Game.buy_module(Game.module_def(d.mod))
    if level(b) >= 5:
        return "Nivel máximo"
    var cost := upgrade_cost(b)
    if Game.money < cost:
        return "Dinero insuficiente ($%d)" % cost
    Game.spend("mejoras", cost)
    b["lvl"] = int(b.get("lvl", 0)) + 1
    return ""

func maintain_cost(b: Dictionary) -> float:
    return c("maint_base") + c("maint_per_level") * level(b)

func maintain(b: Dictionary) -> String:
    ensure(b)
    var cost := maintain_cost(b)
    if Game.money < cost:
        return "Dinero insuficiente ($%.0f)" % cost
    Game.spend("mantenimiento", cost)
    b.st.wear = 0.0
    if b.st.state == "broken":
        b.st.state = "idle"
    return ""

func ult_ready(b: Dictionary) -> bool:
    ensure(b)
    return float(b.st.ult) >= 100.0 and float(b.st.ult_h) <= 0.0

func fire_ult(b: Dictionary) -> String:
    if not ult_ready(b):
        return "La sobrecarga aún no está cargada"
    b.st.ult = 0.0
    b.st.ult_h = c("ult_hours")
    _event(b, "SOBRECARGA activada: rendimiento x%.0f durante %d h" % [c("ult_thru"), int(c("ult_hours"))])
    return "Sobrecarga activada"

func toggle(b: Dictionary) -> void:
    ensure(b)
    b.on = not b.on

func cycle_mode(b: Dictionary) -> void:
    ensure(b)
    var n := (recipes[b.id].get("modes", []) as Array).size()
    if n > 0:
        b.mode = (int(b.mode) + 1) % n

func shift_prio(b: Dictionary, delta: int) -> void:
    ensure(b)
    b.prio = clampi(int(b.prio) + delta, 1, 5)

# ---------------------------------------------------------------- consumo eléctrico y energía
func kw_mult(b: Dictionary) -> float:
    if not has(b):
        return 1.0
    ensure(b)
    var m := (1.0 + 0.1 * float(level(b) - 1)) * hop_prod(b, "kw")
    if not b.on:
        m *= 0.3
    return m

func uptime(b: Dictionary) -> float:
    if not has(b) or not b.has("st"):
        return 1.0
    return 0.3 + 0.7 * float(b.st.up)

# ---------------------------------------------------------------- ciclo horario
func tick_hour() -> void:
    var procs: Array = []
    for b in Game.buildings:
        if not recipes.has(b.id):
            continue
        ensure(b)
        if recipes[b.id].get("collector", false):
            _collector(b)
        else:
            procs.append(b)
    procs.sort_custom(func(a, z):
        if int(a.prio) != int(z.prio):
            return int(a.prio) < int(z.prio)
        return int(a.uid) < int(z.uid))
    for b in procs:
        _run(b)

# Devuelve el factor de rendimiento de esta hora, o -1 si el módulo no puede trabajar.
func _pre(b: Dictionary) -> float:
    var s: Dictionary = b.st
    var old: String = s.state
    var w := float(s.wear)
    var can_auto: bool = (bool(b.get("auto", false)) and Game.scada_online()) or (hop_flag(b, "auto_maint") and Game.scada_online())
    if w >= c("auto_at") and can_auto:
        if maintain(b) == "":
            w = 0.0
    if not b.on:
        s.state = "off"
        s.up = lerpf(float(s.up), 0.0, 1.0 / 24.0)
        _changed(b, old)
        return -1.0
    if w >= 100.0:
        s.state = "broken"
        s.up = lerpf(float(s.up), 0.0, 1.0 / 24.0)
        _changed(b, old)
        return -1.0
    var pe := float(Game.report.get("eff_e", 1.0))
    if pe < 0.5:
        s.state = "no_power"
        s.up = lerpf(float(s.up), 0.0, 1.0 / 24.0)
        _changed(b, old)
        return -1.0
    var f := float(tier(b).thru) + hop_sum(b, "thru")
    if bool(b.get("auto", false)):
        f += 0.1
    f *= 1.0 - clampf((w - 40.0) / 60.0, 0.0, 1.0) * 0.6
    f *= pe
    if float(s.ult_h) > 0.0:
        f *= c("ult_thru")
        s.ult_h = float(s.ult_h) - 1.0
    return f

func _wear_up(b: Dictionary, work: float) -> void:
    var s: Dictionary = b.st
    var k := c("wear_per_hour") * hop_prod(b, "wear") * (0.4 + 0.6 * work)
    if float(s.ult_h) > 0.0:
        k *= c("ult_wear")
    s.wear = minf(100.0, float(s.wear) + k)

func _collector(b: Dictionary) -> void:
    var s: Dictionary = b.st
    var old: String = s.state
    var f := _pre(b)
    if f < 0.0:
        return
    var col := minf(1.0, (float(tier(b).collect) + hop_sum(b, "collect")) * minf(1.0, f))
    var total := 0.0
    for t in Game.tanks:
        var take: float = t.sludge_kg * col
        if take > 0.01:
            t.sludge_kg -= take
            Flows.add("lodo_ras", take, "Colector")
            total += take
        if hop_flag(b, "dead") and t.dead_kg > 0.01:
            Flows.add("mortalidad", t.dead_kg, "Colector")
            total += t.dead_kg
            t.dead_kg = 0.0
            t.dead_fish = 0
    s.made = float(s.made) + total
    s.state = "producing" if total > 0.05 else "idle"
    s.r = 1.0 if total > 0.05 else 0.0
    s.up = lerpf(float(s.up), 1.0, 1.0 / 24.0)
    s.ult = minf(100.0, float(s.ult) + total * c("ult_charge_per_kg"))
    _wear_up(b, float(s.r))
    _changed(b, old)

func _run(b: Dictionary) -> void:
    var rc: Dictionary = recipes[b.id]
    var s: Dictionary = b.st
    var old: String = s.state
    var f := _pre(b)
    if f < 0.0:
        return
    var frac := f / 24.0
    # 1) cuánto se puede procesar esta hora (r = 0..1)
    var r := 1.0
    for slot in rc.get("in", []):
        var need := float(slot.qty) * frac
        if need <= 0.0:
            continue
        var avail := 0.0
        for it in slot.any:
            avail += Flows.amount(it)
        if slot.has("buy") and Game.money > 100.0:
            avail = need
        r = minf(r, avail / need)
    r = minf(r, 1.0)
    if r < 0.01:
        s.state = "no_input"
        s.r = 0.0
        s.up = lerpf(float(s.up), 0.0, 1.0 / 24.0)
        _changed(b, old)
        return
    # 2) consumir insumos (y comprar el faltante si hay alternativa comercial)
    var eff_q := 1.0
    var consumed: Dictionary = {}
    var kg_proc := 0.0
    for slot in rc.get("in", []):
        var amt := float(slot.qty) * frac * r
        var got := 0.0
        for it in slot.any:
            var g := Flows.take(it, amt - got)
            if g > 0.0:
                got += g
                consumed[it] = float(consumed.get(it, 0.0)) + g
            if got >= amt - 0.00001:
                break
        var short := amt - got
        if short > 0.0001 and slot.has("buy"):
            var bw: Dictionary = slot.buy
            Game.spend("insumos", short * float(bw.price))
            eff_q *= 1.0 - (short / amt) * (1.0 - float(bw.eff))
            consumed[bw.item] = float(consumed.get(bw.item, 0.0)) + short
        kg_proc += amt
    # 3) compostaje: completar con carbono para llegar a la relación C:N objetivo
    if rc.has("cn_target"):
        eff_q *= _balance_carbon(b, rc, consumed)
    # 4) producir
    var modes: Array = rc.get("modes", [])
    var mm: Dictionary = {}
    if modes.size() > 0:
        mm = modes[clampi(int(b.mode), 0, modes.size() - 1)].get("mult", {})
    var boost := 1.0 + hop_sum(b, "out")
    for o in rc.get("out", []):
        var q := float(o.qty) * frac * r * eff_q * boost * float(mm.get(o.item, 1.0))
        Flows.add(o.item, q, str(rc.name))
        s.made = float(s.made) + q
    # 5) efectos secundarios, estado y desgaste
    if rc.has("scrub"):
        var k := clampf(float(rc.scrub) * r * minf(f, 2.0), 0.0, 0.3)
        for t in Game.tanks:
            t.nh3 = maxf(0.0, t.nh3 * (1.0 - k))
    s.r = r
    s.state = "producing" if r >= 0.95 else "partial"
    s.up = lerpf(float(s.up), 1.0, 1.0 / 24.0)
    s.ult = minf(100.0, float(s.ult) + kg_proc * c("ult_charge_per_kg"))
    _wear_up(b, r)
    _changed(b, old)

# Devuelve el factor de calidad (1.0 si la mezcla está en 20-35).
func _balance_carbon(b: Dictionary, rc: Dictionary, consumed: Dictionary) -> float:
    var cn_t := float(rc.cn_target)
    var C := 0.0
    var N := 0.0
    for it in consumed:
        var d: Dictionary = Flows.items.get(it, {})
        var dry: float = float(consumed[it]) * float(d.get("ms", 0.0))
        var n: float = dry * float(d.get("n", 0.0))
        N += n
        C += n * float(d.get("cn", 0.0))
    var ci: Dictionary = Flows.items[rc.carbon]
    var cN: float = float(ci.ms) * float(ci.n)
    var cC: float = cN * float(ci.cn)
    var den := cC - cn_t * cN
    var q := 0.0
    if den > 0.0 and N > 0.0:
        q = maxf(0.0, (cn_t * N - C) / den)
    var got := Flows.take(rc.carbon, q)
    var short := q - got
    if short > 0.0001 and Game.money > 50.0:
        Game.spend("insumos", short * float(ci.buy))
        got += short
    N += cN * got
    C += cC * got
    var ratio := C / maxf(0.0001, N)
    b.st.cn = ratio
    if ratio >= 20.0 and ratio <= 35.0:
        return 1.0
    return 0.6 if ratio < 20.0 else 0.7

# ---------------------------------------------------------------- ciclo diario: vender y reciclar
func keep(item: String) -> float:
    var k := 0.0
    for b in Game.buildings:
        if not recipes.has(b.id) or recipes[b.id].get("collector", false):
            continue
        if b.has("on") and not b.on:
            continue
        for slot in recipes[b.id].get("in", []):
            if (slot.any as Array).has(item):
                k += float(slot.qty) * 2.0
    return k

func sell_mult(item: String) -> float:
    var best := 0.0
    for b in Game.buildings:
        if not recipes.has(b.id):
            continue
        for o in recipes[b.id].get("out", []):
            if o.item == item:
                best = maxf(best, hop_sum(b, "sell"))
    return c("sell_base") + best

func daily() -> void:
    day_rev = 0.0
    for id in Flows.items:
        var d: Dictionary = Flows.items[id]
        var q := Flows.amount(id)
        if q <= 0.01:
            continue
        if float(d.get("burn", 0.0)) > 0.0:
            stat_kwh += Flows.take(id, q) * float(d.burn)
            continue
        var free := q - keep(id)
        if free <= 0.01:
            continue
        if float(d.get("to_feed", 0.0)) > 0.0:
            var t := Flows.take(id, free)
            Game.feed_kg += t * float(d.to_feed)
            stat_saved += t * float(d.to_feed) * Game.feed_cost()
        elif float(d.get("price", 0.0)) > 0.0:
            var t2 := Flows.take(id, free)
            var rev := t2 * float(d.price) * sell_mult(id)
            Game.earn("subproductos", rev)
            stat_rev += rev
            day_rev += rev
            rev_by_item[id] = float(rev_by_item.get(id, 0.0)) + rev
    if day_rev > 1.0:
        Game.notify("Guía: los módulos circulares vendieron $%.0f hoy." % day_rev)

# ---------------------------------------------------------------- textos para la interfaz
func _event(b: Dictionary, txt: String) -> void:
    events.push_front({"d": Game.day + 1, "t": "%s: %s" % [Game.def(b.id).name, txt]})
    while events.size() > 20:
        events.pop_back()

func _changed(b: Dictionary, old: String) -> void:
    var now: String = b.st.state
    if now == old:
        return
    if now == "broken":
        _event(b, "AVERIADO por desgaste. Hay que mantenerlo.")
        Game.notify("Guía: %s se averió. Mantenlo desde el plano." % Game.def(b.id).name)
    elif now == "no_input":
        _event(b, "se quedó sin insumo")
    elif now == "no_power":
        _event(b, "sin energía suficiente")
    elif old == "no_input" or old == "no_power" or old == "broken" or old == "off":
        _event(b, "vuelve a trabajar")

func io_text(b: Dictionary) -> String:
    var rc: Dictionary = recipes.get(b.id, {})
    if rc.get("collector", false):
        return "Retira el lodo de los tanques y lo lleva al acopio."
    var ins: Array = []
    for slot in rc.get("in", []):
        var names: Array = []
        for it in slot.any:
            names.append(str(Flows.items.get(it, {}).get("name", it)))
        var s := "%.0f %s" % [float(slot.qty), " / ".join(PackedStringArray(names.slice(0, 3)))]
        if slot.has("buy"):
            s += " (compra si falta)"
        ins.append(s)
    var outs: Array = []
    for o in rc.get("out", []):
        outs.append("%.1f %s" % [float(o.qty), str(Flows.items.get(o.item, {}).get("name", o.item))])
    var cn := ""
    if rc.has("cn_target"):
        cn = "\nMezcla con carbono para C:N ≈ %d" % int(rc.cn_target)
    return "Por día (x1): %s\n→ %s%s" % [" + ".join(PackedStringArray(ins)), ", ".join(PackedStringArray(outs)), cn]

func status_text(b: Dictionary) -> String:
    ensure(b)
    var s: Dictionary = b.st
    var t := "Estado: %s · rendimiento x%.2f · desgaste %d %%" % [state_name(s.state), float(tier(b).thru) + hop_sum(b, "thru"), int(float(s.wear))]
    if float(s.ult_h) > 0.0:
        t += "\nSOBRECARGA activa: %d h" % int(float(s.ult_h))
    else:
        t += "\nCarga de sobrecarga: %d / 100" % int(float(s.ult))
    if float(s.cn) > 0.0 and recipes[b.id].has("cn_target"):
        t += " · C:N de la mezcla %.0f" % float(s.cn)
    t += "\nProducido en total: %.0f" % float(s.made)
    return t

func scada_text() -> String:
    var lines: Array = []
    for b in Game.buildings:
        if not recipes.has(b.id):
            continue
        ensure(b)
        lines.append("%s · %s · %s · %d %%" % [Game.def(b.id).name, str(tier(b).n), state_name(b.st.state), int(float(b.st.wear))])
    if lines.size() == 0:
        return ""
    return "Módulos circulares (desgaste):\n" + "\n".join(PackedStringArray(lines)) + "\nVentas hoy $%.0f · total $%.0f · balanceado propio ahorrado $%.0f" % [day_rev, stat_rev, stat_saved]

func alarms() -> String:
    var a := ""
    for b in Game.buildings:
        if not recipes.has(b.id) or not b.has("st"):
            continue
        var n: String = Game.def(b.id).name
        if b.st.state == "broken":
            a += "ALARMA %s: averiado\n" % n
        elif float(b.st.wear) >= c("warn") and b.st.state != "off":
            a += "AVISO %s: desgaste %d %%\n" % [n, int(float(b.st.wear))]
        if b.st.state == "no_input":
            a += "AVISO %s: sin insumo\n" % n
    return a

# Tags planos para MQTT / HMI web (siguiente paso).
func tags() -> Dictionary:
    var t := {}
    for b in Game.buildings:
        if not recipes.has(b.id) or not b.has("st"):
            continue
        var k := "acua/mod/%s" % b.id
        t[k + "/estado"] = b.st.state
        t[k + "/desgaste"] = float(b.st.wear)
        t[k + "/rareza"] = level(b)
        t[k + "/prod_total"] = float(b.st.made)
    return t

# ---------------------------------------------------------------- guardado
func to_dict() -> Dictionary:
    return {"events": events, "rev": stat_rev, "saved": stat_saved, "kwh": stat_kwh, "by_item": rev_by_item}

func from_dict(d: Dictionary) -> void:
    events = d.get("events", [])
    stat_rev = float(d.get("rev", 0.0))
    stat_saved = float(d.get("saved", 0.0))
    stat_kwh = float(d.get("kwh", 0.0))
    rev_by_item = d.get("by_item", {})
