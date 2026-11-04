class_name MinHeap
extends RefCounted
## Двоичная куча с приоритетом float и значением int (для поиска пути в sim/). Детерминирована.

var _cost := PackedFloat64Array()
var _value := PackedInt32Array()


func is_empty() -> bool:
	return _value.is_empty()


func top_cost() -> float:
	return _cost[0]


func push(cost: float, value: int) -> void:
	_cost.append(cost)
	_value.append(value)
	var i: int = _value.size() - 1
	while i > 0:
		var parent: int = (i - 1) >> 1
		if _cost[parent] <= _cost[i]:
			break
		_swap(i, parent)
		i = parent


## Извлечь значение с наименьшим приоритетом.
func pop() -> int:
	var top: int = _value[0]
	var last: int = _value.size() - 1
	_swap(0, last)
	_cost.resize(last)
	_value.resize(last)
	var i := 0
	while true:
		var left: int = 2 * i + 1
		var right: int = left + 1
		var smallest := i
		if left < last and _cost[left] < _cost[smallest]:
			smallest = left
		if right < last and _cost[right] < _cost[smallest]:
			smallest = right
		if smallest == i:
			break
		_swap(i, smallest)
		i = smallest
	return top


func _swap(a: int, b: int) -> void:
	var c: float = _cost[a]
	_cost[a] = _cost[b]
	_cost[b] = c
	var v: int = _value[a]
	_value[a] = _value[b]
	_value[b] = v
