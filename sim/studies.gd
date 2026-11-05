class_name Studies
extends RefCounted
## Изучение следов прошлого: бог опускает человека рукой рядом со следом — тот садится и изучает его
## STUDY_TICKS тиков. Понял — след изучен (world["studied"]), в списке тайн у связанной тайны появляется подсказка.
## Не дорос (нужно сначала что-то открыть) — говорит, что не понимает.

const STUDY_RADIUS := 4.0
const STUDY_TICKS := 2
## След: что нужно знать, чтобы понять ("" — ничего; иначе тайна или "fire" — огонь на острове),
## что понял (подсказка к тайне) и что узнал сразу (еда).
const NOTES := {
	"fruit_core": {"needs": "", "text": "Огрызок — эти плоды люди ели.", "learn": "fruit"},
	"fish_bones": {"needs": "", "text": "Рыбьи кости — рыбу люди ели.", "learn": "fish"},
	"old_hearth": {"needs": "", "text": "Здесь горел огонь. Огонь приходит с неба — от молнии."},
	"burnt_tree": {"needs": "", "text": "Дерево сожгла молния. Огонь приходит с неба."},
	"ruins": {"needs": "camp", "text": "Здесь стоял дом. Ветки и камни у развалин — и его можно отстроить."},
	"stone_circle": {"needs": "camp", "text": "Здесь молились. Когда вера станет сильной, здесь встанет алтарь."},
	"torch_stub": {"needs": "fire", "text": "Шахта уходит в гору, там темно. Нужен огонь, который можно унести ночью."},
	"raft_wreck": {"needs": "house", "text": "На этом приплыли люди. Много веток у лагеря и любовь — и можно связать плот."},
	"obelisk": {"needs": "shrine", "text": "Руны: «Тот, кто раскроет все тайны, увидит корабль»."},
}


## Человека опустили на землю: если рядом след — изучает ("study"), уже изучен ("known"),
## не может понять ("confused"); "" — следа рядом нет.
static func on_dropped(w: Dictionary, map: IslandMap, h: Dictionary) -> String:
	if not h["alive"] or h["held"]:
		return ""
	var key := nearest_relic(map, Human.position_of(h))
	if key.is_empty():
		return ""
	if (w["studied"] as Array).has(key):
		return "known"
	if not can_understand(w, key):
		return "confused"
	Human.start_study(h, key)
	return "study"


## Ближайший к точке след, который можно изучать; "" — нет в STUDY_RADIUS.
static func nearest_relic(map: IslandMap, point: Vector2) -> String:
	var best := ""
	var best_dist := STUDY_RADIUS
	for key: String in NOTES:
		if not map.relics.has(key):
			continue
		var d := point.distance_to(map.relics[key])
		if d <= best_dist:
			best_dist = d
			best = key
	return best


static func can_understand(w: Dictionary, key: String) -> bool:
	var needs: String = NOTES[key]["needs"]
	match needs:
		"":
			return true
		"fire":
			return not (w["fire"] as Dictionary).is_empty()
		_:
			return Mysteries.is_solved(w, needs)


## Изучение закончено (Human вызывает через STUDY_TICKS): запись, подсказка, знание еды.
static func complete(w: Dictionary, h: Dictionary, key: String) -> void:
	if (w["studied"] as Array).has(key):
		return
	(w["studied"] as Array).append(key)
	var note: Dictionary = NOTES[key]
	WorldEngine.add_log(w, "%s %s: %s" % [h["name"], "поняла" if h["sex"] == "f" else "понял", note["text"]])
	if note.has("learn"):
		Human.learn(w, note["learn"], h)


## Подсказка к тайне из изученных следов; "" — пока нет.
static func hint_for(w: Dictionary, mystery: String) -> String:
	for key: String in w["studied"]:
		if Hints.FOR_MYSTERY.get(key, "") == mystery:
			return NOTES[key]["text"]
	return ""


## Что понял человек у следа (для сообщения на экране).
static func text(key: String) -> String:
	return NOTES[key]["text"] if NOTES.has(key) else ""
