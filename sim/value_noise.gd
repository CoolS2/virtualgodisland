class_name ValueNoise
extends RefCounted
## Сглаженный value noise на сетке cell×cell, значения 0..1. Порт packages/sim/src/noise.ts.

var _grid := PackedFloat64Array()
var _g: int
var _cell: int


func _init(rng: VgiRng, size: int, cell: int) -> void:
	_cell = cell
	_g = ceili(float(size) / cell) + 2
	_grid.resize(_g * _g)
	for i in _grid.size():
		_grid[i] = rng.next()


func sample(x: float, y: float) -> float:
	var fx: float = x / _cell
	var fy: float = y / _cell
	var x0: int = floori(fx)
	var y0: int = floori(fy)
	var tx: float = _smooth(fx - x0)
	var ty: float = _smooth(fy - y0)
	var top: float = _at(x0, y0) * (1.0 - tx) + _at(x0 + 1, y0) * tx
	var bottom: float = _at(x0, y0 + 1) * (1.0 - tx) + _at(x0 + 1, y0 + 1) * tx
	return top * (1.0 - ty) + bottom * ty


## Вне сетки — 0, как `?? 0` в TS (отрицательные индексы в GDScript иначе считались бы с конца).
func _at(gx: int, gy: int) -> float:
	var i: int = gy * _g + gx
	return _grid[i] if i >= 0 and i < _grid.size() else 0.0


static func _smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)
