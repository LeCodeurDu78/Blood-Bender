extends Control
class_name DopingUI

## Roue de sélection des sérums de dopage (Phase 3).
##
## Contrôle entièrement autonome : il se connecte lui-même à l'EventBus et
## n'a besoin d'aucun câblage depuis HUD.gd, il suffit de l'instancier
## quelque part dans HUD.tscn en plein écran (anchors_preset = 15).

const RADIUS_OUTER: float = 130.0
const RADIUS_OUTER_HOVER: float = 142.0
const RADIUS_INNER: float = 46.0
const SEGMENTS_PER_SLICE: int = 24

const COLOR_ADRENALINE: Color = Color(0.85, 0.15, 0.15, 0.85)
const COLOR_COAGULANT: Color = Color(0.7, 0.55, 0.12, 0.85)
const COLOR_SEROTONIN: Color = Color(0.55, 0.1, 0.65, 0.85)
const COLOR_HYPERPRESSION: Color = Color(0.1, 0.55, 0.75, 0.85)
const COLOR_HOVER_BORDER: Color = Color(1.0, 0.95, 0.85, 1.0)
const COLOR_IDLE_BORDER: Color = Color(0, 0, 0, 0.4)
const COLOR_HINT_TEXT: Color = Color(0.9, 0.85, 0.85, 0.85)

# Le mapping angulaire doit rester identique à celui de
# DopingManager._update_hovered_serum() : droite / bas / gauche / haut.
# NB : en coordonnées écran (Y vers le bas), un angle positif tourne dans
# le sens horaire, donc 45°→135° balaie bien le BAS de l'écran, etc.
var _slices: Array = [
	{"name": "Adrénaline Hématique", "angle_from": -45.0, "angle_to": 45.0, "color": COLOR_ADRENALINE},
	{"name": "Coagulant de Fer", "angle_from": 45.0, "angle_to": 135.0, "color": COLOR_COAGULANT},
	{"name": "Sérotonine BERSERK", "angle_from": 135.0, "angle_to": 225.0, "color": COLOR_SEROTONIN},
	{"name": "Hyper-Pression", "angle_from": 225.0, "angle_to": 315.0, "color": COLOR_HYPERPRESSION},
]

var _is_open: bool = false
var _hovered_name: String = "Adrénaline Hématique"


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	EventBus.doping_wheel_opened.connect(_on_wheel_opened)
	EventBus.doping_wheel_closed.connect(_on_wheel_closed)
	EventBus.doping_wheel_hover_changed.connect(_on_hover_changed)


func _on_wheel_opened() -> void:
	_is_open = true
	visible = true
	queue_redraw()


func _on_wheel_closed() -> void:
	_is_open = false
	visible = false


func _on_hover_changed(serum_name: String) -> void:
	_hovered_name = serum_name
	if _is_open:
		queue_redraw()


func _draw() -> void:
	if not _is_open:
		return

	var center: Vector2 = size * 0.5

	for slice in _slices:
		var is_hovered: bool = slice["name"] == _hovered_name
		_draw_slice(center, slice["angle_from"], slice["angle_to"], slice["color"], is_hovered)
		_draw_slice_label(center, slice["angle_from"], slice["angle_to"], slice["name"], is_hovered)

	draw_circle(center, RADIUS_INNER * 0.55, Color(0.02, 0.01, 0.01, 0.85))
	_draw_hint(center)


func _draw_slice(center: Vector2, angle_from_deg: float, angle_to_deg: float, color: Color, is_hovered: bool) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var radius: float = RADIUS_OUTER_HOVER if is_hovered else RADIUS_OUTER

	points.append(center + Vector2(RADIUS_INNER, 0).rotated(deg_to_rad(angle_from_deg)))

	for i in range(SEGMENTS_PER_SLICE + 1):
		var t: float = float(i) / float(SEGMENTS_PER_SLICE)
		var angle_deg: float = lerp(angle_from_deg, angle_to_deg, t)
		points.append(center + Vector2(radius, 0).rotated(deg_to_rad(angle_deg)))

	for i in range(SEGMENTS_PER_SLICE, -1, -1):
		var t: float = float(i) / float(SEGMENTS_PER_SLICE)
		var angle_deg: float = lerp(angle_from_deg, angle_to_deg, t)
		points.append(center + Vector2(RADIUS_INNER, 0).rotated(deg_to_rad(angle_deg)))

	var fill_color: Color = color
	if is_hovered:
		fill_color.a = minf(color.a + 0.1, 1.0)

	draw_colored_polygon(points, fill_color)

	var border_color: Color = COLOR_HOVER_BORDER if is_hovered else COLOR_IDLE_BORDER
	var border_width: float = 3.0 if is_hovered else 1.0
	for i in range(points.size()):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		draw_line(a, b, border_color, border_width)


func _draw_slice_label(center: Vector2, angle_from_deg: float, angle_to_deg: float, text: String, is_hovered: bool) -> void:
	var mid_angle: float = deg_to_rad((angle_from_deg + angle_to_deg) * 0.5)
	var label_radius: float = (RADIUS_INNER + RADIUS_OUTER) * 0.55
	var pos: Vector2 = center + Vector2(label_radius, 0).rotated(mid_angle)

	var font: Font = ThemeDB.fallback_font
	var font_size: int = 15 if is_hovered else 13
	var text_color: Color = Color.WHITE if is_hovered else Color(0.85, 0.85, 0.85, 0.9)

	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, pos - text_size * 0.5, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, text_color)


func _draw_hint(center: Vector2) -> void:
	var font: Font = ThemeDB.fallback_font
	var text: String = "Relâchez pour injecter — Coût : 20 PV"
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
	var pos: Vector2 = center + Vector2(-text_size.x * 0.5, RADIUS_OUTER_HOVER + 26.0)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 13, COLOR_HINT_TEXT)
