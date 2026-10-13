extends Resource
class_name WeatherWind

## Shared authoring data for atmosphere; sailing/physics integration is future work.
@export var direction_xz := Vector2(1.0, 0.35):
	set(value):
		direction_xz = value
		emit_changed()
@export_range(0.0, 30.0, 0.1) var speed_meters_per_second := 6.0:
	set(value):
		speed_meters_per_second = maxf(value, 0.0)
		emit_changed()

func get_velocity() -> Vector3:
	var direction := direction_xz.normalized()
	return Vector3(direction.x, 0.0, direction.y) * maxf(speed_meters_per_second, 0.0)
