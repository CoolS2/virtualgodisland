class_name WorldEngine
extends RefCounted
## Мир и время. Порт packages/sim/src/engine.ts.
##
## Мир — Dictionary с JSON-совместимыми значениями (это и есть формат сейва):
##   seed: int         — seed острова
##   tick: int         — номер тика
##   last_seen: int    — реальное время последнего обновления, мс. Читается только в catch_up.
##   rng_state: int    — состояние VgiRng (int32)
##   people: Array        — люди (формат — sim/human.gd), next_person_id: int (ADR-0007)
##   knowledge: Array     — какую еду знает племя; bonds: Dictionary — привязанность пар (sim/family.gd)
##   newcomer_due: int, newcomer_arrived: bool — прибытие второго человека после дома
##   log: Array[String] — события для экрана «Пока тебя не было…»
##   items: Array        — предметы (формат — sim/items.gd)
##   next_item_id: int   — следующий свободный id предмета
##   items_spawned: bool — стартовые предметы уже разложены (Items.spawn_initial)
##   mana: float          — мана бога (sim/miracles.gd)
##   craters: Array       — кратеры (sim/craters.gd)
##   mysteries, fire, camp, shrine, cave, raft, fish_eaten — тайны (sim/mysteries.gd)
##   found: Array[String] — найденные людьми следы прошлого (ключи Hints.DISCOVERABLE)
##   studied: Array[String] — изученные следы (sim/studies.gd)
##   felled, shaken, rolled — что рука сделала с деревьями и валунами (sim/flora.gd)

## 1 тик = 1 реальная минута.
const TICK_MS := 60_000
## Офлайн догоняем максимум сутки.
const MAX_OFFLINE_TICKS := 60 * 24

# Скорости потребностей за тик (минуту): голод с 0 до 100 — ~33 ч, жажда — ~28 ч, силы — ~42 ч.
const HUNGER_PER_TICK := 0.05
const THIRST_PER_TICK := 0.06
const ENERGY_PER_TICK := 0.04
## Раз в столько тиков вырастает фрукт (если их меньше FRUIT_MAX).
const FRUIT_REGROW_TICKS := 40
const FRUIT_MAX := 14
## Ветки падают с деревьев (для плота).
const BRANCH_REGROW_TICKS := 60
const BRANCH_MAX := 20
## Журнал хранит только последние записи.
const LOG_MAX := 200


## options: {"name": String, "sex": "m"|"f"} — выбор игрока в новой игре (остальное — случайно по seed).
static func create_world(world_seed: int, now_ms: int, options: Dictionary = {}) -> Dictionary:
	var human := Human.default_state()
	human["id"] = 1
	if options.has("name") and not str(options["name"]).strip_edges().is_empty():
		human["name"] = str(options["name"]).strip_edges().left(Human.NAME_MAX)
	if options.get("sex", "") == "m" or options.get("sex", "") == "f":
		human["sex"] = options["sex"]
		human["sex_chosen"] = true
	return {
		"seed": world_seed,
		"tick": 0,
		"last_seen": now_ms,
		"rng_state": VgiRng.to_i32(world_seed),
		"people": [human],
		"next_person_id": 2,
		"knowledge": [],
		"bonds": {},
		"newcomer_due": -1,
		"newcomer_arrived": false,
		"log": [],
		"items": [],
		"next_item_id": 1,
		"items_spawned": false,
		"mana": Miracles.MANA_START,
		"craters": [],
		"mysteries": [],
		"fire": {}, "camp": {}, "shrine": {}, "house": {}, "cave": {}, "raft": {},
		"fish_eaten": 0,
		"found": [],
		"studied": [],
		"felled": {},
		"shaken": {},
		"rolled": [],
	}


## Один тик симуляции. Детерминирован: зависит только от мира и карты (карта — из seed).
static func step(w: Dictionary, map: IslandMap) -> void:
	Items.spawn_initial(w, map)
	if is_game_over(w):
		return

	for h: Dictionary in Human.living(w):
		h["hunger"] = minf(100.0, h["hunger"] + HUNGER_PER_TICK)
		h["thirst"] = minf(100.0, h["thirst"] + THIRST_PER_TICK)
		if h["action"] != "sleep":
			h["energy"] = maxf(0.0, h["energy"] - ENERGY_PER_TICK)

	Human.update(w, map)
	Mysteries.update(w, map)
	Family.update(w, map)
	Miracles.regen(w)
	Flora.regrow(w)

	if int(w["tick"]) % FRUIT_REGROW_TICKS == 0 and Items.count_kind(w, "fruit") < FRUIT_MAX:
		Items.grow_fruit(w, map)
	if int(w["tick"]) % BRANCH_REGROW_TICKS == 0 and Items.count_kind(w, "branch") < BRANCH_MAX:
		Items.grow_branch(w, map)

	for h: Dictionary in Human.living(w):
		if h["hunger"] >= 100.0:
			Human.die(w, h, "голод")
		elif h["thirst"] >= 100.0:
			Human.die(w, h, "жажда")
		elif Human.age(h, int(w["tick"])) >= float(h["lifespan"]):
			Human.die(w, h, "старость, %d лет" % int(Human.age(h, int(w["tick"]))))
	w["tick"] = int(w["tick"]) + 1


## Игра окончена: люди уже появлялись, но живых не осталось (основатель не успел завести семью,
## или поселение вымерло — см. GAME_DESIGN «Семья»).
static func is_game_over(w: Dictionary) -> bool:
	var people: Array = w["people"]
	return not people.is_empty() and people[0]["spawned"] and Human.living(w).is_empty()


## Запись в журнал (экран «Пока тебя не было…»): «день N, ЧЧ:ММ: текст». Хранятся последние LOG_MAX.
static func add_log(w: Dictionary, text: String) -> void:
	var tick: int = w["tick"]
	var hour := WorldClock.hour(tick)
	var entries: Array = w["log"]
	entries.append("день %d, %02d:%02d — %s" % [WorldClock.day(tick), int(hour), int(fmod(hour, 1.0) * 60.0), text])
	while entries.size() > LOG_MAX:
		entries.pop_front()


## Догнать симуляцию за время отсутствия. Возвращает число прогнанных тиков.
static func catch_up(w: Dictionary, map: IslandMap, now_ms: int) -> int:
	var last_seen: int = w["last_seen"]
	var elapsed: int = maxi(0, now_ms - last_seen)
	@warning_ignore("integer_division")
	var ticks: int = mini(elapsed / TICK_MS, MAX_OFFLINE_TICKS)
	for _i in ticks:
		step(w, map)
	# остаток не теряем: сдвигаем last_seen ровно на прогнанные тики (или на now при упоре в лимит)
	w["last_seen"] = now_ms if ticks == MAX_OFFLINE_TICKS else last_seen + ticks * TICK_MS
	return ticks


## Мир после JSON.parse: все числа там float — возвращаем целым полям тип int и проверяем структуру.
## Поля, которых не было в старых сейвах (items и др.), получают значения по умолчанию — это и есть миграция.
## Возвращает пустой словарь, если данные не похожи на мир.
static func from_data(data: Variant) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = data
	for key: String in ["seed", "tick", "last_seen", "rng_state", "log"]:
		if not d.has(key):
			return {}
	if typeof(d["log"]) != TYPE_ARRAY:
		return {}
	# v≤7: один человек в "human" → people[0]; его знание еды → знание племени.
	var raw_people: Array = []
	var knowledge: Array = []
	if typeof(d.get("people")) == TYPE_ARRAY:
		raw_people = d["people"]
		knowledge = _knowledge_from_data(d.get("knowledge", []))
	elif typeof(d.get("human")) == TYPE_DICTIONARY:
		var old: Dictionary = d["human"]
		raw_people = [old]
		if typeof(old.get("knows")) == TYPE_ARRAY:
			knowledge = _knowledge_from_data(old["knows"])
		elif old.has("spawned"):
			knowledge = ["fruit", "fish"] # сейвы до «открытия еды» (v≤5): уже ел
	else:
		return {}
	var people: Array = []
	for i in raw_people.size():
		if typeof(raw_people[i]) == TYPE_DICTIONARY:
			people.append(_human_from_data(raw_people[i], i + 1))
	if people.is_empty():
		return {}
	var max_id := 0
	for p: Dictionary in people:
		max_id = maxi(max_id, int(p["id"]))
	var bonds := {}
	if typeof(d.get("bonds")) == TYPE_DICTIONARY:
		for key: Variant in d["bonds"]:
			bonds[str(key)] = float(d["bonds"][key])
	var entries: Array = []
	for entry: Variant in d["log"]:
		entries.append(str(entry))
	var result := {
		"seed": int(d["seed"]),
		"tick": int(d["tick"]),
		"last_seen": int(d["last_seen"]),
		"rng_state": int(d["rng_state"]),
		"people": people,
		"next_person_id": maxi(int(d.get("next_person_id", 0)), max_id + 1),
		"knowledge": knowledge,
		"bonds": bonds,
		"newcomer_due": int(d.get("newcomer_due", -1)),
		"newcomer_arrived": bool(d.get("newcomer_arrived", false)),
		"log": entries,
		"items": Items.from_data(d.get("items", [])),
		"next_item_id": int(d.get("next_item_id", 1)),
		"items_spawned": bool(d.get("items_spawned", false)),
		"mana": float(d.get("mana", Miracles.MANA_START)),
		"craters": Craters.from_data(d.get("craters", [])),
		"mysteries": _strings_from_data(d.get("mysteries", [])),
		"fire": Mysteries.structure_from_data(d.get("fire")),
		"camp": Mysteries.structure_from_data(d.get("camp")),
		"shrine": Mysteries.structure_from_data(d.get("shrine")),
		"house": Mysteries.structure_from_data(d.get("house")),
		"cave": Mysteries.structure_from_data(d.get("cave")),
		"raft": Mysteries.structure_from_data(d.get("raft")),
		"fish_eaten": int(d.get("fish_eaten", 0)),
		"found": _strings_from_data(d.get("found", [])),
		"studied": _strings_from_data(d.get("studied", [])),
	}
	result.merge(Flora.from_data(d))
	return result


static func _human_from_data(h: Dictionary, fallback_id: int) -> Dictionary:
	var result := Human.default_state()
	result["id"] = int(h.get("id", fallback_id))
	result["mother_id"] = int(h.get("mother_id", -1))
	result["father_id"] = int(h.get("father_id", -1))
	result["partner_id"] = int(h.get("partner_id", -1))
	result["pregnant_until"] = int(h.get("pregnant_until", -1))
	result["hunger"] = float(h.get("hunger", 0.0))
	result["thirst"] = float(h.get("thirst", 0.0))
	result["energy"] = float(h.get("energy", 100.0))
	result["alive"] = bool(h.get("alive", true))
	# Сейвы до этапа 2 без позиции: человечек появится на следующем тике.
	result["spawned"] = bool(h.get("spawned", false))
	result["x"] = float(h.get("x", 0.0))
	result["z"] = float(h.get("z", 0.0))
	var action := str(h.get("action", "idle"))
	result["action"] = action if Human.ACTIONS.has(action) else "idle"
	result["tx"] = float(h.get("tx", result["x"]))
	result["tz"] = float(h.get("tz", result["z"]))
	result["target_item"] = int(h.get("target_item", -1))
	result["stuck"] = int(h.get("stuck", 0))
	result["faith"] = float(h.get("faith", 0.0))
	result["love"] = float(h.get("love", 0.0))
	result["fear"] = float(h.get("fear", 0.0))
	result["held"] = false # рука в сейв не попадает
	result["touch_tick"] = int(h.get("touch_tick", -1))
	result["build_kind"] = str(h.get("build_kind", ""))
	result["work"] = int(h.get("work", 0))
	result["study"] = str(h.get("study", ""))
	if result["action"] == "study" and not Studies.NOTES.has(result["study"]):
		result["action"] = "idle"
	result["name"] = str(h.get("name", "Ару"))
	result["sex"] = "f" if str(h.get("sex", "m")) == "f" else "m"
	result["born_tick"] = int(h.get("born_tick", 0))
	result["start_age"] = float(h.get("start_age", Human.START_AGE))
	result["lifespan"] = float(h.get("lifespan", Human.LIFESPAN_MAX))
	result["cause"] = str(h.get("cause", ""))
	var skills := {}
	var raw: Variant = h.get("skills", {})
	for skill in Human.SKILLS:
		skills[skill] = float((raw as Dictionary).get(skill, 1.0)) if typeof(raw) == TYPE_DICTIONARY else 1.0
	result["skills"] = skills
	return result


static func _knowledge_from_data(data: Variant) -> Array:
	var result: Array = []
	if typeof(data) == TYPE_ARRAY:
		for kind: Variant in data:
			if Items.FOOD.has(str(kind)) and not result.has(str(kind)):
				result.append(str(kind))
	return result


## Список строк без повторов (раскрытые тайны, находки).
static func _strings_from_data(data: Variant) -> Array:
	var result: Array = []
	if typeof(data) == TYPE_ARRAY:
		for entry: Variant in data:
			if not result.has(str(entry)):
				result.append(str(entry))
	return result
