class_name GameStart
extends RefCounted
## Передача выбора из стартового меню в игровую сцену.
## new_game: {"name", "sex"} — начать новый мир с этим человеком; пусто — продолжить сохранённый.

static var new_game := {}
