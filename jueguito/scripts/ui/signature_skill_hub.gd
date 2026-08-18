extends Control
class_name SignatureSkillHub

signal mastery_requested

const SLOT_SIZE := Vector2(42.0, 42.0)
const HUB_SIZE := Vector2(104.0, 104.0)
const SLOT_EDGE_INSET := 20.0
const MASTERY_ICON := preload("res://assets/ui/hud/generated/mastery_emblem.png")
const SLOT_KEYS := ["Q", "E", "R", "F"]
const SLOT_HINTS := [
	"Insignia superior",
	"Insignia derecha",
	"Insignia inferior",
	"Insignia izquierda",
]

var signature_slots: Array[Button] = []
var mastery_button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout_slots)
	for index in range(4):
		var slot := Button.new()
		slot.name = "SignatureSlot%d" % (index + 1)
		slot.custom_minimum_size = SLOT_SIZE
		slot.text = ""
		slot.tooltip_text = "%s · habilidad insignia" % SLOT_HINTS[index]
		slot.focus_mode = Control.FOCUS_NONE
		slot.z_index = 2
		slot.clip_contents = true
		var normal := _slot_style(Color("0b0d0efa"), Color("6e5833dc"), 1)
		var hover := _slot_style(Color("1b2429ff"), Color("cba85cff"), 1)
		slot.add_theme_stylebox_override("normal", normal)
		slot.add_theme_stylebox_override("hover", hover)
		slot.add_theme_stylebox_override("pressed", hover)
		add_child(slot)
		var placeholder := Label.new()
		placeholder.name = "AbilityPlaceholder"
		placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		placeholder.text = "◇"
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.add_theme_font_size_override("font_size", 14)
		placeholder.add_theme_color_override("font_color", Color("5f4b2d99"))
		slot.add_child(placeholder)
		var key_badge := Label.new()
		key_badge.name = "HotkeyBadge"
		key_badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		key_badge.offset_left = -18.0
		key_badge.offset_top = -16.0
		key_badge.offset_right = -3.0
		key_badge.offset_bottom = -2.0
		key_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_badge.text = SLOT_KEYS[index]
		key_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		key_badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		key_badge.add_theme_font_size_override("font_size", 10)
		key_badge.add_theme_color_override("font_color", Color("e8d7ac"))
		key_badge.add_theme_color_override("font_outline_color", Color("080705"))
		key_badge.add_theme_constant_override("outline_size", 2)
		slot.add_child(key_badge)
		signature_slots.append(slot)
	mastery_button = Button.new()
	mastery_button.name = "MasteryHubButton"
	mastery_button.custom_minimum_size = HUB_SIZE
	mastery_button.flat = true
	mastery_button.icon = MASTERY_ICON
	mastery_button.expand_icon = true
	mastery_button.add_theme_constant_override("icon_max_width", 96)
	mastery_button.tooltip_text = "Abrir Árbol de Maestrías"
	mastery_button.focus_mode = Control.FOCUS_NONE
	mastery_button.z_index = 1
	mastery_button.pressed.connect(func(): mastery_requested.emit())
	add_child(mastery_button)
	_layout_slots()
	queue_redraw()


func _layout_slots() -> void:
	if signature_slots.size() != 4:
		return
	var center := size * 0.5
	var slot_half := SLOT_SIZE * 0.5
	var hub_half := HUB_SIZE * 0.5
	signature_slots[0].position = Vector2(center.x - slot_half.x, SLOT_EDGE_INSET)
	signature_slots[1].position = Vector2(size.x - SLOT_SIZE.x - SLOT_EDGE_INSET, center.y - slot_half.y)
	signature_slots[2].position = Vector2(center.x - slot_half.x, size.y - SLOT_SIZE.y - SLOT_EDGE_INSET)
	signature_slots[3].position = Vector2(SLOT_EDGE_INSET, center.y - slot_half.y)
	mastery_button.position = center - hub_half
	queue_redraw()


func _draw() -> void:
	# El emblema es la unica silueta del nucleo. Las ranuras se montan sobre sus
	# extremos sin aro, placa circular ni conectores adicionales.
	pass


func set_interaction_enabled(enabled: bool) -> void:
	for slot in signature_slots:
		slot.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	mastery_button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func _slot_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 3
	return style
