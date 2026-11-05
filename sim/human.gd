class_name Human
extends RefCounted
## Человек: потребности и автономный выбор действий (utility AI). Люди — world["people"] (ADR-0007),
## у каждого — словарь:
##   id: int; mother_id, father_id, partner_id: int (-1 — нет); pregnant_until: int (тик родов, -1 — нет)
##   hunger, thirst: float — 0 норма .. 100 смерть; energy: float — 100 бодр .. 0; alive: bool
##   spawned: bool; x, z: float — позиция в мировых координатах (высота — по карте)
##   action: String — "idle" | "wander" | "explore" | "drink" | "eat" | "sleep" | "build" | "study"
##   tx, tz: float — цель движения; target_item: int — еда для "eat"; stuck: int — тиков без продвижения
##   faith, love, fear: float 0..100 — вера, любовь и страх к богу; held: bool — в руке бога;
##   touch_tick: int — тик последнего «погладить/шлёпнуть» (не чаще раза в тик)
##   build_kind: String, work: int — что строит (тайны) и сколько тиков уже работает
##   study: String — какой след изучает (sim/studies.gd), "" — ничего
##   wish: String — чего хочет ("" | ключ WISHES), wish_until: int — до какого тика; next_wish: int — когда захочет
##   name: String; sex: "m" | "f"; born_tick: int; start_age: float (лет при born_tick); lifespan: float (лет);
##   skills: {"forage", "build", "fish", "heal"} — множители 0.7..1.3 (кто-то лучше добывает еду, кто-то строит…)
##   cause: String — причина смерти ("" — жив)
## Знание еды — общее: world["knowledge"] ("fruit", "fish"). Вначале не знают ничего: если не догадаются
## сами и бог не подскажет (подкинет еду рядом), умрут от голода (голод 0→100 ≈ 33 ч).
## 1 тик = 1 минута: за тик человечек проходит до WALK_PER_TICK (1 ед/с), game/ показывает это плавно.

const ACTIONS: Array[String] = ["idle", "wander", "explore", "drink", "eat", "sleep", "build", "study"]
## Свободен: ничем важным не занят (может строить, подбирать дела).
const FREE_ACTIONS: Array[String] = ["idle", "wander", "explore"]

const WALK_PER_TICK := 60.0
const STEP := 1.0
const REACH := 0.8
const DRINK_PER_TICK := 45.0
## Взял рукой / бросил / шлёпнул / погладил.
const GRAB_FEAR := 15.0
const THROW_FEAR_PER_SPEED := 1.0
const THROW_FEAR_MAX := 30.0
const SEA_FEAR := 20.0
const PET_LOVE := 8.0
const PET_CALM := 5.0
const SLAP_FEAR := 15.0
const SLAP_LOVE := 3.0
## Затухание за тик.
const FEAR_DECAY := 0.1
const LOVE_DECAY := 0.01
const FAITH_DECAY := 0.005
const SCARED := 60.0
## Ночью ложится спать (если сил меньше порога); сон длится до утра.
const NIGHT_SLEEP_SCORE := 0.6
const NIGHT_SLEEP_BELOW := 95.0
## Просыпается раньше, если голод или жажда стали опасными.
const WAKE_NEED := 85.0
## У лагеря спится лучше.
const CAMP_SLEEP_BONUS := 1.5
const CAMP_RADIUS := 4.0
## Бог подкинул еду так близко — человечек пробует и узнаёт, что это съедобно.
const LEARN_RADIUS := 2.5
## Сам догадывается: голодный, незнакомая еда рядом — шанс за тик.
const SELF_LEARN_HUNGER := 50.0
const SELF_LEARN_RADIUS := 4.0
const SELF_LEARN_CHANCE := 0.03
## Возраст: 1 игровой год = 4 игровых дня (8 реальных часов). Первый человечек появляется взрослым.
const TICKS_PER_YEAR := 4 * WorldClock.DAY_TICKS
const START_AGE := 20.0
## С этого возраста — взрослый: строит, заводит пару. Дети гуляют рядом.
const ADULT_AGE := 16.0
const CHILD_WANDER_RADIUS := 5.0
## Взрослые гуляют рядом с парой или с одиноким человеком противоположного пола.
const COMPANION_WANDER_RADIUS := 6.0
const LIFESPAN_MIN := 60.0
const LIFESPAN_MAX := 75.0
const SKILLS: Array[String] = ["forage", "build", "fish", "heal"]
const NAME_MAX := 16
const SKILL_MIN := 0.7
const SKILL_MAX := 1.3
const NAMES := {
	"m": ["Ару", "Тоби", "Мано", "Кеа", "Ило", "Рон", "Дуи", "Тано"],
	"f": ["Ани", "Мира", "Лея", "Нои", "Ката", "Ула", "Сина", "Эва"],
}
const SLEEP_PER_TICK := 2.0
## Ниже порога потребность не рассматривается.
const THIRST_TRIGGER := 40.0
const HUNGER_TRIGGER := 40.0
const ENERGY_TRIGGER := 30.0
const SATED := 5.0
const RESTED := 95.0
## Ценность прогулки: потребность побеждает, когда её доля выше.
const WANDER_SCORE := 0.3
## Желания: раз в сутки взрослый чего-то хочет; исполнил бог за WISH_TICKS — вера и любовь растут, нет — огорчён.
const WISHES := {"fruit": "хочет фруктов", "fish": "хочет рыбы", "pet": "хочет ласки", "rain": "хочет дождя"}
const WISH_EVERY := WorldClock.DAY_TICKS
const WISH_TICKS := 90
## Первое желание — не сразу после появления.
const WISH_FIRST := 40
const WISH_FAITH := 15.0
const WISH_LOVE := 10.0
const WISH_LETDOWN := 3.0
## Исследовать остров (идти к ненайденным следам прошлого, потом — в дальние места) взрослому интереснее,
## чем гулять рядом; ребёнок и тот, кто держится рядом с парой, не исследуют.
const EXPLORE_SCORE := 0.35
## Исследует только открытые места (поле, пляж) — см. _open_ground.
const EXPLORE_MIN := 20.0
const EXPLORE_MAX := 45.0
## Выше не забирается (снег, скалы).
const EXPLORE_MAX_HEIGHT := 12.0
const WANDER_RADIUS := 15.0
const WANDER_ATTEMPTS := 10
const STUCK_LIMIT := 2
const SPAWN_ATTEMPTS := 200
const SPAWN_MAX_HEIGHT := 6.0


static func default_state() -> Dictionary:
	return {
		"hunger": 0.0, "thirst": 0.0, "energy": 100.0, "alive": true,
		"spawned": false, "x": 0.0, "z": 0.0,
		"action": "idle", "tx": 0.0, "tz": 0.0, "target_item": -1, "stuck": 0,
		"faith": 0.0, "love": 0.0, "fear": 0.0, "held": false, "touch_tick": -1,
		"build_kind": "", "work": 0, "study": "", "wish": "", "wish_until": -1, "next_wish": -1,
		"id": 1, "mother_id": -1, "father_id": -1, "partner_id": -1, "pregnant_until": -1,
		"name": "", "sex": "m", "born_tick": 0, "start_age": START_AGE, "lifespan": LIFESPAN_MAX,
		"skills": {"forage": 1.0, "build": 1.0, "fish": 1.0, "heal": 1.0}, "cause": "",
	}


## Один тик поведения всех живых людей (потребности уже изменены WorldEngine.step).
static func update(w: Dictionary, map: IslandMap) -> void:
	for h: Dictionary in (w["people"] as Array).duplicate():
		if not h["spawned"]:
			_spawn(w, map, h)
		if h["alive"]:
			_update_one(w, map, h)


static func _update_one(w: Dictionary, map: IslandMap, h: Dictionary) -> void:
	h["fear"] = maxf(0.0, h["fear"] - FEAR_DECAY)
	h["love"] = maxf(0.0, h["love"] - LOVE_DECAY)
	h["faith"] = maxf(0.0, h["faith"] - FAITH_DECAY)
	if h["held"]:
		return # в руке бога ничего не делает
	var start := position_of(h)
	_update_wish(w, h)
	_try_self_learn(w, h)
	match h["action"]:
		"drink":
			if _move(h, map):
				h["thirst"] = maxf(0.0, h["thirst"] - DRINK_PER_TICK)
				if h["thirst"] <= SATED:
					_set_action(h, "idle")
		"eat":
			var item := Items.find(w, h["target_item"])
			if item.is_empty() or item["held"] or not Items.FOOD.has(item["kind"]):
				_set_action(h, "idle")
			else:
				h["tx"] = item["x"]
				h["tz"] = item["z"]
				if _move(h, map):
					(w["items"] as Array).erase(item)
					h["hunger"] = maxf(0.0, h["hunger"] - Items.FOOD[item["kind"]])
					if item["kind"] == "fish":
						w["fish_eaten"] = int(w["fish_eaten"]) + 1
						if int(w["fish_eaten"]) >= Mysteries.FISH_FOR_FISHERMAN:
							Mysteries.solve(w, "fisherman")
					WorldEngine.add_log(w, "%s %s %s" % [h["name"], _verb(h, "съел"), Items.FOOD_NAMES[item["kind"]]])
					fulfil_wish(w, h, item["kind"])
					_set_action(h, "idle")
		"sleep":
			if _move(h, map):
				var near_camp: bool = not (w["camp"] as Dictionary).is_empty() \
					and position_of(h).distance_to(Vector2(w["camp"]["x"], w["camp"]["z"])) <= CAMP_RADIUS
				h["energy"] = minf(100.0, h["energy"] + SLEEP_PER_TICK * (CAMP_SLEEP_BONUS if near_camp else 1.0))
				var night := WorldClock.is_night(int(w["tick"]))
				var urgent: bool = h["hunger"] >= WAKE_NEED or h["thirst"] >= WAKE_NEED
				if urgent or (h["energy"] >= RESTED and not night):
					WorldEngine.add_log(w, "%s %s" % [h["name"], _verb(h, "проснулся")])
					_set_action(h, "idle")
		"build":
			if _move(h, map):
				h["work"] = int(h["work"]) + 1
				if h["work"] >= build_ticks(h, w):
					var kind: String = h["build_kind"]
					var at := Vector2(h["tx"], h["tz"])
					_set_action(h, "idle")
					Mysteries.complete_build(w, kind, at)
		"study":
			h["work"] = int(h["work"]) + 1
			if h["work"] >= Studies.STUDY_TICKS:
				var key: String = h["study"]
				_set_action(h, "idle")
				Studies.complete(w, h, key)
		"wander", "explore":
			if _move(h, map):
				_set_action(h, "idle")
	Exploration.reveal_path(w, map, start, position_of(h))
	_discover(w, map, h)
	if FREE_ACTIONS.has(h["action"]):
		_decide(w, map, h)


## Подошёл к следу прошлого, которого ещё никто не находил, — находка (журнал, world["found"]).
static func _discover(w: Dictionary, map: IslandMap, h: Dictionary) -> void:
	if h["action"] == "sleep":
		return
	var found: Array = w["found"]
	for key: String in Hints.DISCOVERABLE:
		if found.has(key) or not map.relics.has(key):
			continue
		if position_of(h).distance_to(map.relics[key]) <= Hints.DISCOVER_RADIUS:
			found.append(key)
			WorldEngine.add_log(w, "%s %s %s" % [h["name"], "нашла" if h["sex"] == "f" else "нашёл", Hints.discovery_text(key)])


## Исследует ли человек остров сам: взрослый, который ни за кем не идёт.
static func _explorer(w: Dictionary, h: Dictionary) -> bool:
	return is_adult(h, int(w["tick"])) and _leader(w, h).is_empty()


## За кем человек идёт: ребёнок — за матерью; взрослый — за парой (или тем, кто может ею стать),
## если тот старше по id (из двоих ведёт первый появившийся); {} — сам по себе.
static func _leader(w: Dictionary, h: Dictionary) -> Dictionary:
	if not is_adult(h, int(w["tick"])):
		var mother := find_person(w, h["mother_id"])
		return mother if not mother.is_empty() and mother["alive"] else {}
	var companion := _companion(w, h)
	if not companion.is_empty() and int(companion["id"]) < int(h["id"]):
		return companion
	return {}


## Прямой путь от a до b не проходит через море (люди ходят по прямой).
static func _path_clear(map: IslandMap, a: Vector2, b: Vector2) -> bool:
	var steps := ceili(a.distance_to(b) / STEP)
	for i in steps + 1:
		if not _walkable(map, a.lerp(b, float(i) / maxf(1.0, steps))):
			return false
	return true


## Куда идти исследовать: ближайший ненайденный след прошлого, иначе — случайное дальнее место.
static func _explore_target(w: Dictionary, map: IslandMap, h: Dictionary) -> Vector2:
	var pos := position_of(h)
	var best := Vector2.INF
	for key: String in Hints.DISCOVERABLE:
		if (w["found"] as Array).has(key) or not map.relics.has(key):
			continue
		var p: Vector2 = map.relics[key]
		if _open_ground(map, p) and p.distance_to(pos) < best.distance_to(pos) and _path_clear(map, pos, p):
			best = p
	if best != Vector2.INF:
		return best
	for _i in WANDER_ATTEMPTS:
		var angle: float = VgiRng.next_float(w) * TAU
		var radius: float = lerpf(EXPLORE_MIN, EXPLORE_MAX, VgiRng.next_float(w))
		var p := pos + Vector2(cos(angle), sin(angle)) * radius
		if _open_ground(map, p) and map.height_at_world(p.x, p.y) <= EXPLORE_MAX_HEIGHT:
			return p
	return Vector2.INF


## Открытое место — поле или пляж. Сам по себе человек ходит только туда (в лес и на гору — за едой, водой,
## за ведущим или если отнесёт бог): так его легко найти глазами.
static func _open_ground(map: IslandMap, p: Vector2) -> bool:
	var biome := map.biome_at_world(p.x, p.y)
	return biome == IslandMap.Biome.FIELD or biome == IslandMap.Biome.BEACH


## Настроение для лица: "dead" | "sleep" | "scared" | "happy" | "ok" | "sad".
static func mood(h: Dictionary) -> String:
	if not h["alive"]:
		return "dead"
	if h["action"] == "sleep":
		return "sleep"
	if h["fear"] >= SCARED:
		return "scared"
	var worst: float = maxf(maxf(h["hunger"], h["thirst"]), 100.0 - h["energy"])
	if worst < 35.0:
		return "happy"
	if worst < 65.0:
		return "ok"
	return "sad"


## Возраст в годах на тике tick.
static func age(h: Dictionary, tick: int) -> float:
	return float(h["start_age"]) + float(tick - int(h["born_tick"])) / TICKS_PER_YEAR


static func is_adult(h: Dictionary, tick: int) -> bool:
	return age(h, tick) >= ADULT_AGE


## Живые люди (появившиеся на острове).
static func living(w: Dictionary) -> Array:
	return (w["people"] as Array).filter(func(h: Dictionary) -> bool: return h["spawned"] and h["alive"])


static func find_person(w: Dictionary, id: int) -> Dictionary:
	for h: Dictionary in w["people"]:
		if int(h["id"]) == id:
			return h
	return {}


## Ближайший живой человек к точке не дальше radius; {} — никого.
static func nearest(w: Dictionary, point: Vector2, radius: float) -> Dictionary:
	var best := {}
	var best_dist := radius
	for h: Dictionary in living(w):
		var d := position_of(h).distance_to(point)
		if d <= best_dist:
			best_dist = d
			best = h
	return best


## Человек в руке бога или {}.
static func held_person(w: Dictionary) -> Dictionary:
	for h: Dictionary in w["people"]:
		if h["held"]:
			return h
	return {}


## С кем гулять рядом: партнёр, иначе ближайший одинокий взрослый противоположного пола; {} — ни с кем.
static func _companion(w: Dictionary, h: Dictionary) -> Dictionary:
	var partner := find_person(w, h["partner_id"])
	if not partner.is_empty() and partner["alive"]:
		return partner
	if int(h["partner_id"]) >= 0:
		return {}
	var best := {}
	var best_dist := INF
	for other: Dictionary in living(w):
		if other["sex"] == h["sex"] or int(other["partner_id"]) >= 0 or not is_adult(other, int(w["tick"])):
			continue
		var d := position_of(other).distance_to(position_of(h))
		if d < best_dist:
			best_dist = d
			best = other
	return best


## Глагол в прошедшем времени по полу: «съел» → «съела», «проснулся» → «проснулась».
static func _verb(h: Dictionary, male: String) -> String:
	if h["sex"] != "f":
		return male
	return male.trim_suffix("ся") + "ась" if male.ends_with("ся") else male + "а"


## Тиков стройки с учётом навыка строителя (не меньше 1).
## С инструментами из тайника (world["bonuses"] has "tools") — вдвое быстрее.
static func build_ticks(h: Dictionary, w: Dictionary = {}) -> int:
	var tools := 0.5 if not w.is_empty() and (w["bonuses"] as Array).has("tools") else 1.0
	return maxi(1, ceili(Mysteries.BUILD_TICKS * tools / float(h["skills"]["build"])))


## Смерть (голод, жажда, старость) — причина в журнал.
static func die(w: Dictionary, h: Dictionary, cause: String) -> void:
	if not h["alive"]:
		return
	h["alive"] = false
	h["cause"] = cause
	h["held"] = false
	_set_action(h, "idle")
	WorldEngine.add_log(w, "%s умер%s: %s" % [h["name"], "ла" if h["sex"] == "f" else "", cause])


## Знает ли племя, что этот вид еды съедобен.
static func knows(w: Dictionary, kind: String) -> bool:
	return (w["knowledge"] as Array).has(kind)


## Племя узнало новую еду. Первая еда — тайна «Еда».
static func learn(w: Dictionary, kind: String, who: Dictionary = {}) -> void:
	if knows(w, kind) or not Items.FOOD.has(kind):
		return
	(w["knowledge"] as Array).append(kind)
	var name: String = who.get("name", "Человек")
	WorldEngine.add_log(w, "%s %s %s — съедобно!" % [name, _verb(who, "попробовал") if not who.is_empty() else "попробовал",
		Items.FOOD_NAMES[kind]])
	Mysteries.solve(w, "food")


## Предмет упал рядом: если это незнакомая еда и кто-то видит — пробует.
static func notice_landed(w: Dictionary, item: Dictionary) -> void:
	if not Items.FOOD.has(item["kind"]):
		return
	for h: Dictionary in living(w):
		if h["held"] or h["action"] == "sleep":
			continue
		if position_of(h).distance_to(Vector2(item["x"], item["z"])) <= LEARN_RADIUS:
			learn(w, item["kind"], h)
			return


static func _try_self_learn(w: Dictionary, h: Dictionary) -> void:
	if h["hunger"] < SELF_LEARN_HUNGER or h["action"] == "sleep":
		return
	for item: Dictionary in w["items"]:
		if Items.FOOD.has(item["kind"]) and not knows(w, item["kind"]) and not item["held"] \
				and position_of(h).distance_to(Vector2(item["x"], item["z"])) <= SELF_LEARN_RADIUS:
			if VgiRng.next_float(w) < SELF_LEARN_CHANCE * float(h["skills"]["forage"]):
				learn(w, item["kind"], h)
			return


static func _sleep_score(w: Dictionary, h: Dictionary) -> float:
	if h["energy"] <= ENERGY_TRIGGER:
		return (100.0 - h["energy"]) / 100.0
	if WorldClock.is_night(int(w["tick"])) and h["energy"] < NIGHT_SLEEP_BELOW:
		return NIGHT_SLEEP_SCORE
	return 0.0


## Начать стройку (тайны): дойти до места и работать BUILD_TICKS тиков.
static func start_build(h: Dictionary, kind: String, at: Vector2) -> void:
	_set_action(h, "build", at.x, at.y)
	h["build_kind"] = kind


## Желание: появляется у взрослого раз в WISH_EVERY (что именно — из того, что можно исполнить), истекает.
static func _update_wish(w: Dictionary, h: Dictionary) -> void:
	var tick: int = w["tick"]
	if not str(h["wish"]).is_empty():
		if tick >= int(h["wish_until"]):
			h["wish"] = ""
			h["next_wish"] = tick + WISH_EVERY
			h["faith"] = maxf(0.0, float(h["faith"]) - WISH_LETDOWN)
			WorldEngine.add_log(w, "%s %s: желание не сбылось" % [h["name"], "огорчена" if h["sex"] == "f" else "огорчён"])
		return
	if not is_adult(h, tick) or h["action"] == "sleep":
		return
	if int(h["next_wish"]) < 0:
		h["next_wish"] = tick + WISH_FIRST + (int(h["id"]) * 37) % WISH_EVERY
	if tick < int(h["next_wish"]):
		return
	var options: Array[String] = ["pet"]
	if knows(w, "fruit"):
		options.append("fruit")
	if knows(w, "fish"):
		options.append("fish")
	if Mysteries.is_solved(w, "food"):
		options.append("rain")
	var kind: String = options[(int(tick / 7.0) + int(h["id"])) % options.size()]
	h["wish"] = kind
	h["wish_until"] = tick + WISH_TICKS
	WorldEngine.add_log(w, "%s %s" % [h["name"], WISHES[kind]])


## Бог исполнил желание (поел нужного, погладили, увидел дождь): вера и любовь растут.
static func fulfil_wish(w: Dictionary, h: Dictionary, kind: String) -> void:
	if h["wish"] != kind:
		return
	h["wish"] = ""
	h["next_wish"] = int(w["tick"]) + WISH_EVERY
	add_faith(h, WISH_FAITH)
	h["love"] = minf(100.0, float(h["love"]) + WISH_LOVE)
	WorldEngine.add_log(w, "%s %s: желание исполнилось" % [h["name"], "счастлива" if h["sex"] == "f" else "счастлив"])


## Сесть изучать след (бог опустил рядом).
static func start_study(h: Dictionary, key: String) -> void:
	_set_action(h, "study")
	h["study"] = key


static func scare(h: Dictionary, amount: float) -> void:
	h["fear"] = minf(100.0, h["fear"] + amount)


## Вера от увиденного чуда: любовь усиливает, страх ослабляет (множитель 0.5..2).
static func add_faith(h: Dictionary, amount: float) -> void:
	var k: float = clampf(1.0 + (h["love"] - h["fear"] * 0.5) / 100.0, 0.5, 2.0)
	h["faith"] = minf(100.0, h["faith"] + amount * k)


## Взять человека рукой (рука пуста). true — взяли.
static func grab(w: Dictionary, h: Dictionary) -> bool:
	if not h["spawned"] or not h["alive"] or h["held"] or Items.held_id(w) >= 0 or not held_person(w).is_empty():
		return false
	h["held"] = true
	scare(h, GRAB_FEAR)
	_set_action(h, "idle")
	return true


## Бросить/отпустить человечка. Упал в море — выносит на ближайший берег. Возвращает траекторию.
static func throw(w: Dictionary, map: IslandMap, h: Dictionary, origin: Vector3, velocity: Vector3) -> PackedVector3Array:
	if not h["held"]:
		return PackedVector3Array()
	velocity = velocity.limit_length(Items.MAX_THROW_SPEED)
	var path := Items.simulate(map, origin, velocity)
	var landing: Vector3 = path[path.size() - 1]
	h["held"] = false
	scare(h, minf(THROW_FEAR_MAX, velocity.length() * THROW_FEAR_PER_SPEED))
	var spot := Vector2(landing.x, landing.z)
	if Items.landed_in_sea(map, landing):
		spot = _nearest_land(map, spot)
		scare(h, SEA_FEAR)
		path.append(Vector3(spot.x, map.height_at_world(spot.x, spot.y), spot.y))
	h["x"] = spot.x
	h["z"] = spot.y
	_set_action(h, "idle")
	Exploration.reveal(w, map, spot)
	return path


## Погладить: любовь растёт, страх уходит. Не чаще раза в тик. true — сработало.
static func pet(w: Dictionary, h: Dictionary) -> bool:
	if not _touchable(w, h):
		return false
	h["love"] = minf(100.0, h["love"] + PET_LOVE)
	h["fear"] = maxf(0.0, h["fear"] - PET_CALM)
	fulfil_wish(w, h, "pet")
	return true


## Шлёпнуть: страх растёт быстрее, чем любовь от поглаживания. Не чаще раза в тик.
static func slap(w: Dictionary, h: Dictionary) -> bool:
	if not _touchable(w, h):
		return false
	scare(h, SLAP_FEAR)
	h["love"] = maxf(0.0, h["love"] - SLAP_LOVE)
	return true


static func _touchable(w: Dictionary, h: Dictionary) -> bool:
	if not h["spawned"] or not h["alive"] or h["held"] or int(h["touch_tick"]) == int(w["tick"]):
		return false
	h["touch_tick"] = int(w["tick"])
	return true


static func _nearest_land(map: IslandMap, p: Vector2) -> Vector2:
	var half := map.half_extent()
	var best := p
	var best_dist := INF
	for i in map.biomes.size():
		var b := map.biomes[i]
		if b == IslandMap.Biome.SEA or b == IslandMap.Biome.RIVER:
			continue
		var c := Vector2(i % map.size - half, floori(float(i) / map.size) - half)
		var d := c.distance_squared_to(p)
		if d < best_dist:
			best_dist = d
			best = c
	return best


static func position_of(h: Dictionary) -> Vector2:
	return Vector2(h["x"], h["z"])


static func _decide(w: Dictionary, map: IslandMap, h: Dictionary) -> void:
	var scores := {
		"drink": h["thirst"] / 100.0 if h["thirst"] >= THIRST_TRIGGER and not map.river.is_empty() else 0.0,
		"eat": h["hunger"] / 100.0 if h["hunger"] >= HUNGER_TRIGGER and _nearest_food(w, map, h) >= 0 else 0.0,
		"sleep": _sleep_score(w, h),
		"explore": EXPLORE_SCORE if _explorer(w, h) else 0.0,
		"wander": WANDER_SCORE,
	}
	var best := "wander"
	for action: String in ["drink", "eat", "sleep", "explore"]: # фиксированный порядок — детерминизм при равенстве
		if scores[action] > scores[best]:
			best = action
	if best == h["action"] and (best == "explore" or (best == "wander" and _leader(w, h).is_empty())):
		return # уже идёт (кто идёт за другим — каждый тик сверяется с ним)
	match best:
		"drink":
			var water := Places.water_near(map, position_of(h), _nearest_river_point(h, map))
			_set_action(h, "drink", water.x, water.y)
		"eat":
			var id := _nearest_food(w, map, h)
			var item := Items.find(w, id)
			_set_action(h, "eat", item["x"], item["z"])
			h["target_item"] = id
		"sleep":
			var bed := position_of(h)
			if not (w["camp"] as Dictionary).is_empty():
				bed = Vector2(w["camp"]["x"], w["camp"]["z"]) + Vector2(1.5, 1.5)
			_set_action(h, "sleep", bed.x, bed.y)
			if is_adult(h, int(w["tick"])):
				WorldEngine.add_log(w, "%s %s спать%s" % [h["name"], "легла" if h["sex"] == "f" else "лёг",
					" в лагере" if not (w["camp"] as Dictionary).is_empty() else ""])
		"explore":
			var target := _explore_target(w, map, h)
			if target != Vector2.INF:
				_set_action(h, "explore", target.x, target.y)
				return
			_wander(w, map, h)
		"wander":
			_wander(w, map, h)


## Погулять рядом: ребёнок — у матери, взрослый — у пары (или того, кто может ею стать), иначе — вокруг себя.
static func _wander(w: Dictionary, map: IslandMap, h: Dictionary) -> void:
	var center := position_of(h)
	var reach := WANDER_RADIUS
	var leader := _leader(w, h)
	if not leader.is_empty():
		# Туда, куда идёт ведущий (а не где он сейчас), — чтобы не отставать, когда он уходит далеко.
		center = Vector2(leader["tx"], leader["tz"])
		reach = CHILD_WANDER_RADIUS if not is_adult(h, int(w["tick"])) else COMPANION_WANDER_RADIUS
	for _i in WANDER_ATTEMPTS:
		var angle: float = VgiRng.next_float(w) * TAU
		var radius: float = VgiRng.next_float(w) * reach
		var p := center + Vector2(cos(angle), sin(angle)) * radius
		# За ведущим — куда угодно на суше; сам — только по открытым местам.
		if (_open_ground(map, p) or (not leader.is_empty() and _walkable(map, p)
				and map.biome_at_world(p.x, p.y) != IslandMap.Biome.RIVER)):
			_set_action(h, "wander", p.x, p.y)
			return


## Идёт к (tx, tz) не дальше WALK_PER_TICK, не заходя в море. true — пришёл.
static func _move(h: Dictionary, map: IslandMap) -> bool:
	var pos := position_of(h)
	var target := Vector2(h["tx"], h["tz"])
	var budget := WALK_PER_TICK
	var progressed := false
	while budget > 0.0 and pos.distance_to(target) > REACH:
		var step: float = minf(minf(STEP, budget), pos.distance_to(target))
		var next := pos + (target - pos).normalized() * step
		if not _walkable(map, next):
			break
		pos = next
		budget -= step
		progressed = true
	h["x"] = pos.x
	h["z"] = pos.y
	if pos.distance_to(target) <= REACH:
		h["stuck"] = 0
		return true
	if not progressed:
		h["stuck"] = int(h["stuck"]) + 1
		if h["stuck"] >= STUCK_LIMIT:
			_set_action(h, "idle")
	return false


static func _walkable(map: IslandMap, p: Vector2) -> bool:
	return map.biome_at_world(p.x, p.y) != IslandMap.Biome.SEA


static func _set_action(h: Dictionary, action: String, tx: float = NAN, tz: float = NAN) -> void:
	h["action"] = action
	h["tx"] = h["x"] if is_nan(tx) else tx
	h["tz"] = h["z"] if is_nan(tz) else tz
	h["target_item"] = -1
	h["stuck"] = 0
	h["build_kind"] = ""
	h["work"] = 0
	h["study"] = ""


static func _spawn(w: Dictionary, map: IslandMap, h: Dictionary) -> void:
	h["spawned"] = true
	roll_traits(w, h)
	var half := map.half_extent()
	for _i in SPAWN_ATTEMPTS:
		var p := Vector2(VgiRng.next_float(w) - 0.5, VgiRng.next_float(w) - 0.5) * map.size * 0.4
		var biome := map.biome_at_world(p.x, p.y)
		if biome == IslandMap.Biome.FIELD and map.height_at_world(p.x, p.y) < SPAWN_MAX_HEIGHT:
			h["x"] = p.x
			h["z"] = p.y
			_set_action(h, "idle")
			return
	# Запасной вариант: первая подходящая клетка суши по порядку.
	for i in map.biomes.size():
		if map.biomes[i] == IslandMap.Biome.FIELD or map.biomes[i] == IslandMap.Biome.FOREST:
			h["x"] = i % map.size - half
			h["z"] = floori(float(i) / map.size) - half
			break
	_set_action(h, "idle")


## Пол, имя, срок жизни, навыки — случайно, но детерминированно (RNG мира).
## Имя и пол, выбранные игроком, сохраняются (RNG всё равно тратится одинаково — детерминизм).
static func roll_traits(w: Dictionary, h: Dictionary) -> void:
	var rolled_sex := "m" if VgiRng.next_float(w) < 0.5 else "f"
	if not h.get("sex_chosen", false):
		h["sex"] = rolled_sex
	var names: Array = NAMES[h["sex"]]
	var rolled_name: String = names[mini(int(VgiRng.next_float(w) * names.size()), names.size() - 1)]
	if str(h["name"]).is_empty():
		h["name"] = rolled_name
	h.erase("sex_chosen")
	h["born_tick"] = int(w["tick"])
	h["start_age"] = START_AGE
	h["lifespan"] = lerpf(LIFESPAN_MIN, LIFESPAN_MAX, VgiRng.next_float(w))
	var skills := {}
	for skill in SKILLS:
		skills[skill] = lerpf(SKILL_MIN, SKILL_MAX, VgiRng.next_float(w))
	h["skills"] = skills


## Ближайшая известная еда, до которой можно дойти по прямой (не через море); -1 — нет.
static func _nearest_food(w: Dictionary, map: IslandMap, h: Dictionary) -> int:
	var pos := position_of(h)
	var best := -1
	var best_dist := INF
	for item: Dictionary in w["items"]:
		if not Items.FOOD.has(item["kind"]) or item["held"] or not knows(w, item["kind"]):
			continue
		var d := pos.distance_squared_to(Vector2(item["x"], item["z"]))
		if d < best_dist and _path_clear(map, pos, Vector2(item["x"], item["z"])):
			best_dist = d
			best = item["id"]
	return best


## Ближайшая к человечку клетка реки (кроме устья в море), в мировых координатах.
static func _nearest_river_point(h: Dictionary, map: IslandMap) -> Vector2:
	var pos := position_of(h)
	var half := map.half_extent()
	var best := pos
	var best_dist := INF
	for k in map.river.size() - 1:
		var i: int = map.river[k]
		var p := Vector2(i % map.size - half, floori(float(i) / map.size) - half)
		var d := pos.distance_squared_to(p)
		if d < best_dist:
			best_dist = d
			best = p
	return best
