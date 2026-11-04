class_name Catalog
extends RefCounted

# VALORES DE PRUEBA: se reemplazan por los datos reales con fuentes (Paquete 1).
const SPECIES := [
    {"id": "roja", "name": "Tilapia roja", "color": Color(0.91, 0.38, 0.24), "growth": 1.0, "opt_temp": 28.0, "price": 3.4},
    {"id": "gris", "name": "Tilapia gris", "color": Color(0.55, 0.60, 0.63), "growth": 0.95, "opt_temp": 28.0, "price": 2.9},
    {"id": "moz", "name": "Tilapia Mozambique", "color": Color(0.37, 0.42, 0.35), "growth": 0.85, "opt_temp": 27.0, "price": 2.6},
    {"id": "nilo", "name": "Tilapia del Nilo", "color": Color(0.44, 0.56, 0.66), "growth": 1.1, "opt_temp": 29.0, "price": 3.0},
    {"id": "azul", "name": "Tilapia azul", "color": Color(0.25, 0.50, 0.77), "growth": 0.9, "opt_temp": 26.0, "price": 3.3},
]

const MODULES := [
    {"id": "bsf", "name": "Mosca soldado negra", "cost": 350},
    {"id": "lom", "name": "Lombrices", "cost": 180},
    {"id": "alg", "name": "Algas", "cost": 220},
    {"id": "dap", "name": "Daphnia", "cost": 160},
    {"id": "zoo", "name": "Zooplancton", "cost": 260},
    {"id": "hid", "name": "Hidroponía", "cost": 400},
    {"id": "aco", "name": "Acuaponía", "cost": 600},
    {"id": "aer", "name": "Aeroponía", "cost": 700},
    {"id": "hor", "name": "Hongo ostra roja", "cost": 250},
    {"id": "hob", "name": "Hongo ostra blanco", "cost": 250},
]

const CATS := [
    ["produccion", "Producción"],
    ["alimento", "Alimento y circularidad"],
    ["energia", "Energía"],
    ["proceso", "Procesamiento"],
    ["agua", "Agua"],
    ["control", "Control y automatización"],
    ["genetica", "Genética"],
    ["hatchery", "Hatcheries"],
]

# VALORES DE PRUEBA (costos en $, kW, m³/día, $/día). Se reemplazan con datos reales (Paquete 1).
# kw < 0 = consumo, kw > 0 = capacidad instalada. cf = factor de planta. kwh = costo por kWh generado.
const BUILDINGS := {
    "tilapia_nave": {"name": "Nave de tilapia (módulo base)", "cat": "produccion", "w": 30.0, "d": 12.0, "shape": "nave", "cost": 0, "kw": -3.0, "m3": -20.0, "income": 0.0, "opex": 2.0, "water": "dulce", "temp": "calida", "scene": "nave", "value": 30000, "color": Color(0.20, 0.50, 0.45), "desc": "RAS básico con 3 tanques: su ingreso es lo que cosechas y vendes tú (o el agente de ventas)."},
    "estanque_tilapia": {"name": "Estanque circular Ø12 (tilapia)", "cat": "produccion", "w": 12.0, "d": 12.0, "shape": "circle", "cost": 1800, "kw": -3.0, "m3": -8.0, "income": 22.0, "opex": 2.0, "water": "dulce", "temp": "calida", "color": Color(0.12, 0.42, 0.45), "desc": "Estanque comercial con aireación; ingreso estable."},
    "raceway_trucha": {"name": "Raceway trucha/salmón", "cat": "produccion", "w": 30.0, "d": 6.0, "shape": "raceway", "cost": 5200, "kw": -10.0, "m3": -120.0, "income": 60.0, "opex": 5.0, "water": "dulce", "temp": "fria", "color": Color(0.16, 0.45, 0.62), "desc": "Flujo alto de agua fría y muy oxigenada."},
    "estanque_camaron": {"name": "Estanque L. vannamei / cangrejo", "cat": "produccion", "w": 24.0, "d": 12.0, "shape": "pond", "cost": 6500, "kw": -8.0, "m3": -30.0, "income": 70.0, "opex": 6.0, "water": "salada", "temp": "calida", "color": Color(0.20, 0.40, 0.35), "desc": "Crustáceos en agua salada cálida."},
    "kreisel_medusas": {"name": "Campo Kreisel de medusas", "cat": "produccion", "w": 16.0, "d": 8.0, "shape": "pond", "cost": 9000, "kw": -6.0, "m3": -10.0, "income": 55.0, "opex": 5.0, "water": "salada", "temp": "calida", "rare": true, "color": Color(0.35, 0.50, 0.70), "desc": "Cultivo de Aurelia aurita en flujo laminar circular."},
    "macroalgas_ulva": {"name": "Tanques tumble de macroalgas", "cat": "produccion", "w": 20.0, "d": 12.0, "shape": "algae", "cost": 3500, "kw": -4.0, "m3": -25.0, "income": 30.0, "opex": 3.0, "water": "salada", "temp": "calida", "color": Color(0.20, 0.50, 0.18), "desc": "Ulva en rotación por inyección de aire; biorremediación."},
    "bsf": {"name": "Módulo mosca soldado negra", "cat": "alimento", "mod": "bsf", "w": 10.0, "d": 6.0, "shape": "box", "cost": 350, "kw": -2.0, "color": Color(0.45, 0.35, 0.2), "desc": "Convierte residuos en larvas para pellets."},
    "lom": {"name": "Lombricultura", "cat": "alimento", "mod": "lom", "w": 8.0, "d": 4.0, "shape": "beds", "cost": 180, "kw": -0.5, "color": Color(0.35, 0.22, 0.12), "desc": "Lodos del RAS a humus y proteína viva."},
    "alg": {"name": "Cultivo de microalgas", "cat": "alimento", "mod": "alg", "w": 8.0, "d": 6.0, "shape": "pond", "cost": 220, "kw": -3.0, "color": Color(0.15, 0.5, 0.2), "desc": "Alimento vivo y oxígeno."},
    "dap": {"name": "Daphnia", "cat": "alimento", "mod": "dap", "w": 6.0, "d": 4.0, "shape": "pond", "cost": 160, "kw": -1.0, "color": Color(0.55, 0.35, 0.2), "desc": "Zooplancton para alevines."},
    "zoo": {"name": "Zooplancton / copépodos", "cat": "alimento", "mod": "zoo", "w": 6.0, "d": 4.0, "shape": "pond", "cost": 260, "kw": -1.0, "color": Color(0.5, 0.45, 0.25), "desc": "Alimento vivo para larvas."},
    "hid": {"name": "Hidroponía", "cat": "alimento", "mod": "hid", "w": 14.0, "d": 6.0, "shape": "beds", "cost": 400, "kw": -3.0, "color": Color(0.2, 0.55, 0.2), "desc": "Hortalizas y forraje verde."},
    "aco": {"name": "Acuaponía", "cat": "alimento", "mod": "aco", "w": 14.0, "d": 6.0, "shape": "beds", "cost": 600, "kw": -2.0, "color": Color(0.25, 0.6, 0.25), "desc": "Plantas que depuran el efluente del RAS."},
    "aer": {"name": "Aeroponía", "cat": "alimento", "mod": "aer", "w": 10.0, "d": 5.0, "shape": "beds", "cost": 700, "kw": -4.0, "color": Color(0.3, 0.6, 0.3), "desc": "Raíces nebulizadas; alta densidad."},
    "hor": {"name": "Hongo ostra roja", "cat": "alimento", "mod": "hor", "w": 8.0, "d": 5.0, "shape": "box", "cost": 250, "kw": -2.0, "color": Color(0.7, 0.35, 0.3), "desc": "Pleurotus djamor en sala oscura."},
    "hob": {"name": "Hongo ostra blanco", "cat": "alimento", "mod": "hob", "w": 8.0, "d": 5.0, "shape": "box", "cost": 250, "kw": -2.0, "color": Color(0.8, 0.78, 0.7), "desc": "Pleurotus ostreatus sobre bagazo."},
    "compostera": {"name": "Compostera aireada", "cat": "alimento", "w": 12.0, "d": 6.0, "shape": "beds", "cost": 1500, "kw": -1.0, "color": Color(0.4, 0.3, 0.15), "desc": "Convierte lodo, vísceras y mortalidad en compost. Mezcla con carbono (aserrín, bagazo) para mantener la relación C:N cerca de 28."},
    "colector_lodo": {"name": "Colector automático de lodo", "cat": "alimento", "w": 6.0, "d": 4.0, "shape": "box", "cost": 2500, "kw": -1.5, "color": Color(0.45, 0.5, 0.55), "desc": "Filtro de tambor y bomba: retira el lodo de los tanques sin purgar a mano y lo lleva al acopio. Con la red de retiro también saca los peces muertos."},
    "grid": {"name": "Acometida eléctrica (red)", "cat": "energia", "w": 4.0, "d": 4.0, "shape": "box", "cost": 800, "kw": 100.0, "cf": 1.0, "kwh": 0.12, "color": Color(0.5, 0.5, 0.55), "desc": "100 kW de la red; $0,12/kWh."},
    "diesel": {"name": "Generador diésel", "cat": "energia", "w": 5.0, "d": 3.0, "shape": "box", "cost": 6000, "kw": 60.0, "cf": 1.0, "kwh": 0.35, "color": Color(0.55, 0.4, 0.2), "desc": "Respaldo; combustible caro y ruido."},
    "solar": {"name": "Paneles solares (80 kWp)", "cat": "energia", "w": 20.0, "d": 10.0, "shape": "solar", "cost": 52000, "kw": 80.0, "cf": 0.22, "ren": true, "kwh": 0.015, "color": Color(0.12, 0.22, 0.45), "desc": "Factor de planta bajo; costo marginal mínimo."},
    "wind": {"name": "Aerogenerador (60 kW)", "cat": "energia", "w": 6.0, "d": 6.0, "shape": "wind", "cost": 85000, "kw": 60.0, "cf": 0.30, "ren": true, "kwh": 0.02, "color": Color(0.85, 0.87, 0.9), "desc": "Depende del viento."},
    "hydro": {"name": "Turbina hidráulica (40 kW)", "cat": "energia", "w": 8.0, "d": 6.0, "shape": "box", "cost": 90000, "kw": 40.0, "cf": 0.5, "ren": true, "kwh": 0.02, "color": Color(0.3, 0.5, 0.7), "desc": "Aprovecha el desnivel del agua de retorno."},
    "biogas": {"name": "Biodigestor (30 kW)", "cat": "energia", "w": 8.0, "d": 8.0, "shape": "silo", "cost": 40000, "kw": 30.0, "cf": 0.8, "ren": true, "kwh": 0.05, "color": Color(0.45, 0.5, 0.3), "desc": "Gas a partir de lodos y residuos."},
    "nuclear": {"name": "Reactor nuclear modular (5 MW)", "cat": "energia", "w": 30.0, "d": 30.0, "shape": "silo", "cost": 2500000, "kw": 5000.0, "cf": 0.9, "kwh": 0.015, "color": Color(0.75, 0.3, 0.25), "desc": "Muy caro y muy rentable; entrega agua caliente."},
    "salt_silo": {"name": "Silo de sal marina (20 t)", "cat": "agua", "w": 6.0, "d": 6.0, "shape": "silo", "cost": 6000, "kw": -0.5, "color": Color(0.85, 0.85, 0.8), "desc": "Almacena sal para comprar barato y resistir escaseces."},
    "fillet_plant": {"name": "Planta de fileteado y empaque al vacío", "cat": "proceso", "w": 20.0, "d": 12.0, "shape": "box", "cost": 45000, "kw": -20.0, "opex": 60.0, "proc": 1, "cap": 400.0, "pmult": 2.5, "color": Color(0.62, 0.72, 0.78), "desc": "Procesa hasta 400 kg/día de pescado y lo vende x2,5."},
    "meal_plant": {"name": "Planta de harina de pescado y colágeno", "cat": "proceso", "w": 16.0, "d": 12.0, "shape": "box", "cost": 70000, "kw": -25.0, "opex": 80.0, "proc": 2, "cap": 250.0, "pmult": 4.0, "color": Color(0.72, 0.62, 0.45), "desc": "Aprovecha los residuos: hasta 250 kg/día de lo fileteado se vende x4. Requiere la planta de fileteado."},
    "pozo": {"name": "Pozo de captación", "cat": "agua", "w": 4.0, "d": 4.0, "shape": "box", "cost": 4000, "kw": -2.0, "m3": 150.0, "opex": 1.0, "color": Color(0.3, 0.45, 0.6), "desc": "+150 m³/día de agua dulce."},
    "desal": {"name": "Planta desalinizadora (OI)", "cat": "agua", "w": 12.0, "d": 8.0, "shape": "plant", "cost": 120000, "kw": -35.0, "m3": 300.0, "income": 150.0, "opex": 20.0, "color": Color(0.7, 0.72, 0.75), "desc": "+300 m³/día; vende agua dulce como ingreso pasivo."},
    "genetics_lab": {"name": "Laboratorio de genética (ingeniería)", "cat": "genetica", "w": 14.0, "d": 10.0, "shape": "box", "cost": 60000, "kw": -15.0, "opex": 10.0, "color": Color(0.55, 0.35, 0.65), "desc": "Habilita la edición genética (rasgos puros). La selección no lo necesita."},
    "hub": {"name": "Hub de enfriamiento y automatización", "cat": "control", "w": 8.0, "d": 6.0, "shape": "hub", "cost": 8000, "kw": -18.0, "color": Color(0.5, 0.52, 0.55), "desc": "Servidores y PLC; requiere refrigeración."},
    "scada": {"name": "Oficina SCADA / HMI", "cat": "control", "w": 10.0, "d": 8.0, "shape": "box", "cost": 25000, "kw": -5.0, "color": Color(0.6, 0.58, 0.5), "desc": "Monitoreo central de todas las zonas."},
    "hatchery_anadara": {"name": "Hatchery de Anadara (25 salas)", "cat": "hatchery", "w": 47.0, "d": 84.0, "shape": "hatchery", "cost": 25000, "kw": -35.0, "m3": -40.0, "income": 40.0, "opex": 8.0, "water": "salada", "temp": "calida", "scene": "hatchery_anadara", "color": Color(0.25, 0.55, 0.5), "desc": "Dimensiones calculadas desde el diseño de 25 salas. Entra para recorrerlo."},
    "hatchery_peces": {"name": "Hatchery de peces (tilapia)", "cat": "hatchery", "w": 30.0, "d": 20.0, "shape": "hatchery", "cost": 40000, "kw": -25.0, "m3": -25.0, "income": 45.0, "opex": 8.0, "water": "dulce", "temp": "calida", "scene": "hatchery_peces", "color": Color(0.30, 0.50, 0.60), "desc": "Reproducción, incubación, inversión sexual y alevinaje. Entra para recorrerlo (diseño borrador)."},
    "hatchery_camaron": {"name": "Hatchery de camarón", "cat": "hatchery", "w": 30.0, "d": 20.0, "shape": "hatchery", "cost": 55000, "kw": -30.0, "m3": -35.0, "income": 80.0, "opex": 10.0, "water": "salada", "temp": "calida", "scene": "hatchery_camaron", "color": Color(0.50, 0.40, 0.30), "desc": "Nauplios a postlarvas de L. vannamei (diseño borrador)."},
    "hatchery_medusas": {"name": "Hatchery de medusas", "cat": "hatchery", "w": 24.0, "d": 16.0, "shape": "hatchery", "cost": 60000, "kw": -20.0, "m3": -15.0, "income": 70.0, "opex": 9.0, "water": "salada", "temp": "calida", "rare": true, "scene": "hatchery_medusas", "color": Color(0.40, 0.40, 0.65), "desc": "Pólipos, estrobilación y Kreisel (diseño borrador)."},
    "hatchery_macroalgas": {"name": "Hatchery de macroalgas", "cat": "hatchery", "w": 24.0, "d": 16.0, "shape": "hatchery", "cost": 45000, "kw": -20.0, "m3": -30.0, "income": 50.0, "opex": 7.0, "water": "salada", "temp": "calida", "scene": "hatchery_macroalgas", "color": Color(0.25, 0.50, 0.25), "desc": "Cepas, esporulación y tumble (diseño borrador)."},
}
