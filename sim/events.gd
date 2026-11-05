class_name Events
extends RefCounted
## События острова (по RNG мира, детерминированно):
##   шторм — раз в 2–4 игровых дня: полчаса непогоды (storm_until), на пляж выносит ветки, иногда — сундук;
##   звезда — раз в 4–7 игровых дней ночью падает в поле или лес: кратер и звёздный камень (starstones).
##     Звёздный камень рука бога «впитывает» — +STAR_MANA маны.
## Мир: next_storm, storm_until, next_star — тики; starstones — [{"x", "z"}].

const STORM_EVERY_MIN := 2 * WorldClock.DAY_TICKS
const STORM_EVERY_MAX := 4 * WorldClock.DAY_TICKS
const STORM_TICKS := 30
const STORM_BRANCHES := 3
const STORM_CHEST_CHANCE := 0.5
const STAR_EVERY_MIN := 4 * WorldClock.DAY_TICKS
const STAR_EVERY_MAX := 7 * WorldClock.DAY_TICKS
const STAR_CRATER_RADIUS := 2.5
const STAR_CRATER_DEPTH := 1.0
const STAR_MANA := 40.0
const STAR_PICK_RADIUS := 2.0
const STAR_FEAR := 20.0
const STAR_SEE := 40.0
const ATTEMPTS := 200


## Раз в тик (из WorldEngine.step).
static func update(w: Dictionary, map: IslandMap) -> void:
	var tick: int = w["tick"]
	if int(w["next_storm"]) < 0:
		w["next_storm"] = tick + _between(w, STORM_EVERY_MIN, STORM_EVERY_MAX)
	if int(w["next_star"]) < 0:
		w["next_star"] = tick + _between(w, STAR_EVERY_MIN, STAR_EVERY_MAX)
	if tick >= int(w["next_storm"]):
		_storm(w, map)
		w["next_storm"] = tick + _between(w, STORM_EVERY_MIN, STORM_EVERY_MAX)
	if tick >= int(w["next_star"]) and WorldClock.is_night(tick):
		_falling_star(w, map)
		w["next_star"] = tick + _between(w, STAR_EVERY_MIN, STAR_EVERY_MAX)


static func storming(w: Dictionary) -> bool:
	return int(w["tick"]) < int(w["storm_until"])


## Впитать звёздный камень рукой у точки. true — был камень.
static func absorb_star(w: Dictionary, point: Vector2) -> bool:
	var stones: Array = w["starstones"]
	for i in stones.size():
		if point.distance_to(Vector2(stones[i]["x"], stones[i]["z"])) <= STAR_PICK_RADIUS:
			stones.remove_at(i)
			w["mana"] = minf(Miracles.MANA_MAX, float(w["mana"]) + STAR_MANA)
			WorldEngine.add_log(w, "бог впитал звёздный камень — сила растёт")
			return true
	return false


static func _storm(w: Dictionary, map: IslandMap) -> void:
	w["storm_until"] = int(w["tick"]) + STORM_TICKS
	var beach := _random_spot(w, map, [IslandMap.Biome.BEACH])
	if beach == Vector2.INF:
		WorldEngine.add_log(w, "налетел шторм")
		return
	for _i in STORM_BRANCHES:
		var p := beach + Vector2(VgiRng.next_float(w) - 0.5, VgiRng.next_float(w) - 0.5) * 4.0
		Items.add(w, "branch", Vector3(p.x, map.height_at_world(p.x, p.y), p.y))
	if VgiRng.next_float(w) < STORM_CHEST_CHANCE:
		Caches.wash_up(w, beach)
		WorldEngine.add_log(w, "шторм! волны выбросили на берег ветки и старый сундук")
	else:
		WorldEngine.add_log(w, "шторм! волны выбросили на берег ветки")


static func _falling_star(w: Dictionary, map: IslandMap) -> void:
	var spot := _random_spot(w, map, [IslandMap.Biome.FIELD, IslandMap.Biome.FOREST])
	if spot == Vector2.INF:
		return
	Craters.add(w, map, Craters.make(spot, STAR_CRATER_RADIUS, STAR_CRATER_DEPTH))
	(w["starstones"] as Array).append({"x": spot.x, "z": spot.y})
	var seen := false
	for h: Dictionary in Human.living(w):
		if Human.position_of(h).distance_to(spot) <= STAR_SEE:
			Human.scare(h, STAR_FEAR)
			seen = seen or h["action"] != "sleep"
	WorldEngine.add_log(w, "с неба упала звезда%s" % (" — люди видели!" if seen else ""))


static func _random_spot(w: Dictionary, map: IslandMap, biomes: Array) -> Vector2:
	var half := map.half_extent()
	for _i in ATTEMPTS:
		var p := Vector2(VgiRng.next_float(w) * (map.size - 6) + 3 - half, VgiRng.next_float(w) * (map.size - 6) + 3 - half)
		if biomes.has(map.biome_at_world(p.x, p.y)) and map.height_at_world(p.x, p.y) > 0.2:
			return p
	return Vector2.INF


static func _between(w: Dictionary, low: int, high: int) -> int:
	return low + int(VgiRng.next_float(w) * (high - low))
