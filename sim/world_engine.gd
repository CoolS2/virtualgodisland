class_name WorldEngine
extends RefCounted
## Мир и время. Порт packages/sim/src/engine.ts.
##
## Мир — Dictionary с JSON-совместимыми значениями (это и есть формат сейва):
##   seed: int         — seed острова
##   tick: int         — номер тика
##   last_seen: int    — реальное время последнего обновления, мс. Читается только в catch_up.
##   rng_state: int    — состояние VgiRng (int32)
##   human: Dictionary — человечек (формат — sim/human.gd)
##   log: Array[String] — события для экрана «Пока тебя не было…»
##   items: Array        — предметы (формат — sim/items.gd)
##   next_item_id: int   — следующий свободный id предмета
##   items_spawned: bool — стартовые предметы уже разложены (Items.spawn_initial)
##   mana: float          — мана бога (sim/miracles.gd)
##   craters: Array       — кратеры (sim/craters.gd)
##   mysteries, fire, camp, shrine, cave, raft, fish_eaten — тайны (sim/mysteries.gd)

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


static func create_world(world_seed: int, now_ms: int) -> Dictionary:
	return {
		"seed": world_seed,
		"tick": 0,
		"last_seen": now_ms,
		"rng_state": VgiRng.to_i32(world_seed),
		"human": Human.default_state(),
		"log": [],
		"items": [],
		"next_item_id": 1,
		"items_spawned": false,
		"mana": Miracles.MANA_START,
		"craters": [],
		"mysteries": [],
		"fire": {}, "camp": {}, "shrine": {}, "house": {}, "cave": {}, "raft": {},
		"fish_eaten": 0,
	}


## Один тик симуляции. Детерминирован: зависит только от мира и карты (карта — из seed).
static func step(w: Dictionary, map: IslandMap) -> void:
	Items.spawn_initial(w, map)
	var h: Dictionary = w["human"]
	if not h["alive"]:
		return

	h["hunger"] = minf(100.0, h["hunger"] + HUNGER_PER_TICK)
	h["thirst"] = minf(100.0, h["thirst"] + THIRST_PER_TICK)
	if h["action"] != "sleep":
		h["energy"] = maxf(0.0, h["energy"] - ENERGY_PER_TICK)

	Human.update(w, map)
	Mysteries.update(w, map)
	Miracles.regen(w)

	if int(w["tick"]) % FRUIT_REGROW_TICKS == 0 and Items.count_kind(w, "fruit") < FRUIT_MAX:
		Items.grow_fruit(w, map)
	if int(w["tick"]) % BRANCH_REGROW_TICKS == 0 and Items.count_kind(w, "branch") < BRANCH_MAX:
		Items.grow_branch(w, map)

	if h["hunger"] >= 100.0:
		Human.die(w, "голод")
	elif h["thirst"] >= 100.0:
		Human.die(w, "жажда")
	elif h["spawned"] and Human.age(h, int(w["tick"])) >= float(h["lifespan"]):
		Human.die(w, "старость, %d лет" % int(Human.age(h, int(w["tick"]))))
	w["tick"] = int(w["tick"]) + 1


## Игра окончена: людей на острове не осталось. Пока человек один — его смерть означает конец
## (если он не успел завести семью и поселение — см. GAME_DESIGN «Семья»).
static func is_game_over(w: Dictionary) -> bool:
	return w["human"]["spawned"] and not w["human"]["alive"]


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
	for key: String in ["seed", "tick", "last_seen", "rng_state", "human", "log"]:
		if not d.has(key):
			return {}
	var h: Variant = d["human"]
	if typeof(h) != TYPE_DICTIONARY or typeof(d["log"]) != TYPE_ARRAY:
		return {}
	var entries: Array = []
	for entry: Variant in d["log"]:
		entries.append(str(entry))
	return {
		"seed": int(d["seed"]),
		"tick": int(d["tick"]),
		"last_seen": int(d["last_seen"]),
		"rng_state": int(d["rng_state"]),
		"human": _human_from_data(h),
		"log": entries,
		"items": Items.from_data(d.get("items", [])),
		"next_item_id": int(d.get("next_item_id", 1)),
		"items_spawned": bool(d.get("items_spawned", false)),
		"mana": float(d.get("mana", Miracles.MANA_START)),
		"craters": Craters.from_data(d.get("craters", [])),
		"mysteries": _mysteries_from_data(d.get("mysteries", [])),
		"fire": Mysteries.structure_from_data(d.get("fire")),
		"camp": Mysteries.structure_from_data(d.get("camp")),
		"shrine": Mysteries.structure_from_data(d.get("shrine")),
		"house": Mysteries.structure_from_data(d.get("house")),
		"cave": Mysteries.structure_from_data(d.get("cave")),
		"raft": Mysteries.structure_from_data(d.get("raft")),
		"fish_eaten": int(d.get("fish_eaten", 0)),
	}


static func _human_from_data(h: Dictionary) -> Dictionary:
	var result := Human.default_state()
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
	var known: Array = []
	if typeof(h.get("knows")) == TYPE_ARRAY:
		for kind: Variant in h["knows"]:
			if Items.FOOD.has(str(kind)) and not known.has(str(kind)):
				known.append(str(kind))
	elif h.has("spawned"):
		# Сейвы до «открытия еды» (v≤5): человечек уже ел — считаем, что фрукты он знает.
		known = ["fruit", "fish"]
	result["knows"] = known
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


static func _mysteries_from_data(data: Variant) -> Array:
	var result: Array = []
	if typeof(data) == TYPE_ARRAY:
		for entry: Variant in data:
			if not result.has(str(entry)):
				result.append(str(entry))
	return result
