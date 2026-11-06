class_name Miracles
extends RefCounted
## Чудеса бога: тратят ману (world["mana"]). Человечек, который видит чудо (не спит, не в руке,
## ближе SEE_RADIUS), обретает веру; вера ускоряет рост маны. Всё детерминировано.

const KINDS: Array[String] = ["rain", "fish", "lightning"]
const COST := {"rain": 20.0, "fish": 25.0, "lightning": 30.0}
const MANA_MAX := 100.0
const MANA_START := 50.0
## Рост маны за тик: база + вера × коэффициент (вера 50 → 0.7/тик ≈ 42/час).
const MANA_BASE_REGEN := 0.2
const MANA_FAITH_REGEN := 0.01
## Алтарь (тайна) добавляет к росту маны.
const SHRINE_REGEN := 0.3

const SEE_RADIUS := 30.0
const FAITH_PER_MIRACLE := 10.0
const RAIN_RADIUS := 12.0
const RAIN_THIRST := 30.0
const RAIN_FRUITS := 2
const LIGHTNING_RADIUS := 3.0
const LIGHTNING_DEPTH := 1.5
const LIGHTNING_FEAR := 20.0
## Ударила совсем рядом — страх вдвойне.
const LIGHTNING_DANGER := 6.0


static func regen(w: Dictionary) -> void:
	var faith := 0.0 # вера всех живых: больше верующих — больше маны
	for h: Dictionary in Human.living(w):
		faith += float(h["faith"])
	var shrine := SHRINE_REGEN if not (w["shrine"] as Dictionary).is_empty() else 0.0
	w["mana"] = minf(MANA_MAX, float(w["mana"]) + MANA_BASE_REGEN + faith * MANA_FAITH_REGEN + shrine)


## Сотворить чудо в мировой точке. Результат: {"ok", "reason" ("mana" | "unknown" | ""), "seen", "at": Vector3}.
static func cast(w: Dictionary, map: IslandMap, kind: String, point: Vector2) -> Dictionary:
	if not COST.has(kind):
		return {"ok": false, "reason": "unknown", "seen": false, "at": Vector3.ZERO}
	if float(w["mana"]) < COST[kind]:
		return {"ok": false, "reason": "mana", "seen": false, "at": Vector3.ZERO}
	w["mana"] = float(w["mana"]) - COST[kind]
	# Кто видел: не спит, не в руке, ближе SEE_RADIUS.
	var witnesses: Array = []
	for h: Dictionary in Human.living(w):
		if not h["held"] and h["action"] != "sleep" and Human.position_of(h).distance_to(point) <= SEE_RADIUS:
			witnesses.append(h)
	var at := Vector3(point.x, map.height_at_world(point.x, point.y), point.y)
	match kind:
		"rain":
			for h: Dictionary in Human.living(w):
				if Human.position_of(h).distance_to(point) <= RAIN_RADIUS:
					h["thirst"] = maxf(0.0, h["thirst"] - RAIN_THIRST)
			for _i in RAIN_FRUITS:
				Items.grow_fruit_near(w, map, point, RAIN_RADIUS)
		"fish":
			var shore := nearest_beach(map, point)
			at = Vector3(shore.x, map.height_at_world(shore.x, shore.y), shore.y)
			Items.add(w, "fish", at)
		"lightning":
			Mysteries.on_lightning(w, map, point)
			Craters.add(w, map, Craters.make(point, LIGHTNING_RADIUS, LIGHTNING_DEPTH))
			at.y = map.height_at_world(point.x, point.y)
			for h: Dictionary in Human.living(w):
				if witnesses.has(h):
					Human.scare(h, LIGHTNING_FEAR)
				if Human.position_of(h).distance_to(point) <= LIGHTNING_DANGER:
					Human.scare(h, LIGHTNING_FEAR)
	for h: Dictionary in witnesses:
		Human.add_faith(h, FAITH_PER_MIRACLE)
		if kind == "rain":
			Human.fulfil_wish(w, h, "rain")
	return {"ok": true, "reason": "", "seen": not witnesses.is_empty(), "at": at}


## Ближайшая к точке клетка пляжа (мировые координаты).
static func nearest_beach(map: IslandMap, point: Vector2) -> Vector2:
	var half := map.half_extent()
	var best := point
	var best_dist := INF
	for i in map.biomes.size():
		if map.biomes[i] != IslandMap.Biome.BEACH or not Regions.cell_walkable(map, i):
			continue # только пляж открытых частей острова — куда люди могут дойти
		var p := Vector2(i % map.size - half, floori(float(i) / map.size) - half)
		var d := p.distance_squared_to(point)
		if d < best_dist:
			best_dist = d
			best = p
	return best
