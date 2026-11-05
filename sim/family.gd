class_name Family
extends RefCounted
## Семья и поселение (ADR-0007): прибытие второго человека после дома, пары, беременность, рождение детей.

## Через столько тиков после постройки дома к берегу пристаёт лодка с новым человеком (1 игровой день).
const NEWCOMER_DELAY := WorldClock.DAY_TICKS
const NEWCOMER_AGE_MIN := 18.0
const NEWCOMER_AGE_MAX := 26.0
## Привязанность растёт, пока двое взрослых рядом; у дома — вдвое быстрее.
const BOND_RADIUS := 8.0
const BOND_PER_TICK := 0.5
const HOUSE_BOND_BONUS := 2.0
const HOUSE_RADIUS := 10.0
const PAIR_BOND := 100.0
## Беременность: пара с домом, оба не голодны и не хотят пить.
const CONCEIVE_CHANCE := 0.004
const PREGNANCY_TICKS := 2 * WorldClock.DAY_TICKS
const FERTILE_MAX_AGE := 45.0
const WELL_FED := 70.0
## Навыки ребёнка — среднее родителей ± разброс.
const SKILL_SPREAD := 0.1


static func update(w: Dictionary, map: IslandMap) -> void:
	var tick: int = w["tick"]
	if int(w["newcomer_due"]) >= 0 and tick >= int(w["newcomer_due"]):
		w["newcomer_due"] = -1
		_arrive(w, map)
	_grow_bonds(w)
	for h: Dictionary in Human.living(w):
		if int(h["pregnant_until"]) >= 0 and tick >= int(h["pregnant_until"]):
			_give_birth(w, h)
		elif _can_conceive(w, h) and VgiRng.next_float(w) < CONCEIVE_CHANCE:
			h["pregnant_until"] = tick + PREGNANCY_TICKS
			WorldEngine.add_log(w, "%s ждёт ребёнка" % h["name"])


## Дом построен — лодку ждём через сутки (один раз).
static func on_house_built(w: Dictionary) -> void:
	if not w["newcomer_arrived"]:
		w["newcomer_due"] = int(w["tick"]) + NEWCOMER_DELAY


static func bond(w: Dictionary, a: Dictionary, b: Dictionary) -> float:
	return float((w["bonds"] as Dictionary).get(_key(a, b), 0.0))


## Новый человек приплывает к пляжу у дома: пол — противоположный основателю (или первому живому).
static func _arrive(w: Dictionary, map: IslandMap) -> void:
	var people := Human.living(w)
	if people.is_empty():
		return
	w["newcomer_arrived"] = true
	var first: Dictionary = people[0]
	var h := new_person(w, "f" if first["sex"] == "m" else "m")
	var house: Dictionary = w["house"]
	var near := Vector2(house["x"], house["z"]) if not house.is_empty() else Human.position_of(first)
	var shore := Miracles.nearest_beach(map, near)
	h["spawned"] = true
	h["x"] = shore.x
	h["z"] = shore.y
	h["tx"] = shore.x
	h["tz"] = shore.y
	h["start_age"] = lerpf(NEWCOMER_AGE_MIN, NEWCOMER_AGE_MAX, VgiRng.next_float(w))
	WorldEngine.add_log(w, "к берегу %s %s — %s" % ["пристала" if h["sex"] == "f" else "пристал", h["name"],
		"незнакомка на лодке" if h["sex"] == "f" else "незнакомец на лодке"])


## Создать человека (ещё без места) со случайными чертами; добавить в мир.
static func new_person(w: Dictionary, sex: String) -> Dictionary:
	var h := Human.default_state()
	h["id"] = int(w["next_person_id"])
	w["next_person_id"] = h["id"] + 1
	h["sex"] = sex
	h["sex_chosen"] = true
	Human.roll_traits(w, h)
	(w["people"] as Array).append(h)
	return h


static func _grow_bonds(w: Dictionary) -> void:
	var adults := Human.living(w).filter(func(h: Dictionary) -> bool:
		return Human.is_adult(h, int(w["tick"])) and int(h["partner_id"]) < 0)
	var house: Dictionary = w["house"]
	for i in adults.size():
		for j in range(i + 1, adults.size()):
			var a: Dictionary = adults[i]
			var b: Dictionary = adults[j]
			if a["sex"] == b["sex"] or Human.position_of(a).distance_to(Human.position_of(b)) > BOND_RADIUS:
				continue
			var gain := BOND_PER_TICK
			if not house.is_empty() and Human.position_of(a).distance_to(Vector2(house["x"], house["z"])) <= HOUSE_RADIUS:
				gain *= HOUSE_BOND_BONUS
			var value := minf(PAIR_BOND, bond(w, a, b) + gain)
			(w["bonds"] as Dictionary)[_key(a, b)] = value
			if value >= PAIR_BOND:
				a["partner_id"] = b["id"]
				b["partner_id"] = a["id"]
				WorldEngine.add_log(w, "%s и %s стали парой" % [a["name"], b["name"]])


static func _can_conceive(w: Dictionary, h: Dictionary) -> bool:
	if h["sex"] != "f" or int(h["pregnant_until"]) >= 0 or (w["house"] as Dictionary).is_empty():
		return false
	var tick: int = w["tick"]
	if not Human.is_adult(h, tick) or Human.age(h, tick) > FERTILE_MAX_AGE:
		return false
	var partner := Human.find_person(w, h["partner_id"])
	if partner.is_empty() or not partner["alive"]:
		return false
	for p: Dictionary in [h, partner]:
		if p["hunger"] >= WELL_FED or p["thirst"] >= WELL_FED or p["held"]:
			return false
	return true


static func _give_birth(w: Dictionary, mother: Dictionary) -> void:
	mother["pregnant_until"] = -1
	var father := Human.find_person(w, mother["partner_id"])
	var child := new_person(w, "m" if VgiRng.next_float(w) < 0.5 else "f")
	child["mother_id"] = mother["id"]
	child["father_id"] = father.get("id", -1)
	child["start_age"] = 0.0
	child["spawned"] = true
	child["x"] = mother["x"]
	child["z"] = mother["z"]
	child["tx"] = mother["x"]
	child["tz"] = mother["z"]
	for skill: String in Human.SKILLS:
		var parents := float(mother["skills"][skill])
		if not father.is_empty():
			parents = (parents + float(father["skills"][skill])) / 2.0
		child["skills"][skill] = clampf(parents + (VgiRng.next_float(w) * 2.0 - 1.0) * SKILL_SPREAD,
			Human.SKILL_MIN, Human.SKILL_MAX)
	WorldEngine.add_log(w, "у %s родил%s %s" % [mother["name"], "ась дочь" if child["sex"] == "f" else "ся сын", child["name"]])


static func _key(a: Dictionary, b: Dictionary) -> String:
	var x: int = mini(int(a["id"]), int(b["id"]))
	var y: int = maxi(int(a["id"]), int(b["id"]))
	return "%d-%d" % [x, y]
