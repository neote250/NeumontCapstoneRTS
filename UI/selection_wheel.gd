@tool
extends Control
class_name SelectionWheel
## The radial order menu. Held open on a button, committed on release: close()
## returns the slot under the cursor and the controller turns that into a state.
##
## It returns a WHEEL_SLOT, never a State — which is what lets one wheel serve
## every squad type, since each scene maps the slots to its own orders.


#region ────────────────────────────  constants  ─────────────────────────────

const SPRITE_SIZE: Vector2 = Vector2(32, 32)

#endregion


#region ──────────────────────────  configuration  ───────────────────────────

@export_group("Colours")
@export var bg_color: Color
@export var line_color: Color
@export var highlight_color: Color

@export_group("Geometry")
@export var outer_radius: int = 256
@export var inner_radius: int = 64
@export var line_width: int = 4

@export_group("Slots")
## Option 0 is the centre; the rest ring it clockwise. Each carries the slot
## it commits to, so reordering this array cannot desync icon from meaning.
@export var options: Array[WheelOption]
@export_group("")

#endregion


#region ──────────────────────────────  state  ───────────────────────────────

## Index into options. 0 means the centre is highlighted.
var selection: int = 0

#endregion


#region ───────────────────────  opening and closing  ────────────────────────

func open() -> void:
	show()
	set_process(true)

func close() -> GlobalEnums.WHEEL_SLOT:
	hide()
	set_process(false)
	return options[selection].slot

#endregion


#region ────────────────────────────  per-frame  ─────────────────────────────

func _process(_delta: float) -> void:
	var mouse_position: Vector2 = get_local_mouse_position()
	var mouse_radius: float = mouse_position.length()
	
	if mouse_radius < inner_radius:
		selection = 0
	else:
		var mouse_rads: float = fposmod((mouse_position.angle() + TAU/8) * -1, TAU)
		selection = ceil((mouse_rads / TAU) * (len(options) - 1))
	
	
	queue_redraw()

#endregion


#region ─────────────────────────────  drawing  ──────────────────────────────

func _draw() -> void:
	var offset: Vector2 = SPRITE_SIZE / -2
	
	draw_circle(Vector2.ZERO, outer_radius, bg_color)
	draw_arc(Vector2.ZERO, inner_radius, 0, TAU, 256, line_color, line_width, true)
	
	if len(options) >= 3:
		
		#draw separator lines
		for i : int in range(len(options) - 1):
			var rads: float = (TAU * i / (len(options) - 1)) + TAU/8
			var point: Vector2 = Vector2.from_angle(rads)
			draw_line(point*inner_radius, point*outer_radius, line_color, line_width, true)
	
	if selection == 0:
		draw_circle(Vector2.ZERO, inner_radius, highlight_color)
	
	if options[0].texture:
		draw_texture_rect(
			options[0].texture,
			Rect2(offset, SPRITE_SIZE),
			false
			)
	
	for i: int in range(1, len(options)):
		var start_rads: float = (TAU * (i-1)) / (len(options) - 1)  + TAU/8
		var end_rads: float = (TAU * i) / (len(options) - 1)  + TAU/8
		var mid_rads: float = (start_rads + end_rads)/2.0 * -1
		var radius_mid: float = (inner_radius + outer_radius) / 2.0
		
		if selection == i:
			var points_per_arc: int = 32
			var points_inner: PackedVector2Array = PackedVector2Array()
			var points_outer: PackedVector2Array = PackedVector2Array()
			
			for j: int in range(points_per_arc+1):
				var angle: float = start_rads + j * (end_rads - start_rads) / points_per_arc
				points_inner.append(inner_radius * Vector2.from_angle(TAU - angle))
				points_outer.append(outer_radius * Vector2.from_angle(TAU - angle))
			
			points_outer.reverse()
			draw_polygon(
				points_inner + points_outer,
				PackedColorArray([highlight_color])
			)
		

		
		var draw_pos:Vector2 = radius_mid * Vector2.from_angle(mid_rads) + offset
		if options[i].texture:
			draw_texture_rect(
				options[i].texture,
				Rect2(draw_pos, SPRITE_SIZE),
				false
				)
	
	

#endregion
