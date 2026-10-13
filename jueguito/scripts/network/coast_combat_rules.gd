extends RefCounted

const MAX_HEALTH := 100
const REACH := 2.8
const COOLDOWN_MS := 950
const WINDUP_MS := 250
const COMBAT_LOCK_MS := 8000

static func damage_for(primary: String) -> int:
	match primary:
		"": return 6
		ItemCatalog.VIKING_SWORD: return 18
		ItemCatalog.LUMBERJACK_AXE: return 12
	return 0

static func rejection(attacker: Dictionary, target: Dictionary, now: int, check_cooldown := true) -> String:
	if attacker.is_empty() or target.is_empty() or attacker["id"] == target["id"]:
		return "Selecciona otro jugador."
	if not attacker.get("pvp", false) or not target.get("pvp", false):
		return "Ambos jugadores deben activar PvP."
	if int(attacker.get("health", 0)) <= 0 or int(target.get("health", 0)) <= 0:
		return "Ese jugador está reapareciendo."
	if now < int(attacker.get("protected_until", 0)) or now < int(target.get("protected_until", 0)):
		return "La protección de reaparición sigue activa."
	if check_cooldown and now < int(attacker.get("next_attack", 0)):
		return "Espera a terminar el golpe."
	if damage_for(str(attacker.get("primary", ""))) == 0:
		return "Usa la espada, el hacha o las manos; el arco aún no dispara."
	var offset: Vector3 = target["position"] - attacker["position"]
	if offset.length() > REACH or absf(offset.y) > 1.5:
		return "Acércate al jugador para golpear."
	var horizontal := Vector3(offset.x, 0, offset.z)
	var forward := Basis(Vector3.UP, float(attacker["yaw"])) * Vector3.FORWARD
	if horizontal.length_squared() > 0.01 and forward.dot(horizontal.normalized()) < 0.5:
		return "Mira hacia el jugador para golpear."
	return ""
