extends Control
class_name BuildProgress
## One row of the build panel: a toggle button and a progress bar, bound to a
## single Build. Purely a view — the UI owns the wiring, this owns the pixels.


#region ─────────────────────────  node references  ──────────────────────────

@onready var button: Button = $Button
@onready var health_bar: HealthBar = $HealthBar

#endregion


#region ──────────────────────────────  state  ───────────────────────────────

## Which Build this widget is currently showing, or null when hidden.
var connected_build: Build = null

#endregion


#region ────────────────────────────  lifecycle  ─────────────────────────────

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	health_bar.init_health(0)
	#if !parent:
		#parent = get_parent() as Squad

#endregion


#region ─────────────────────────────  display  ──────────────────────────────

func show_build(build: Build) -> void:
	connected_build = build
	health_bar.init_health(build.duration)
	health_bar.health = build.current_progress
	button.text = str(build)
	button.set_pressed_no_signal(build.is_building)

##dim the bar when queued but not progressing
func set_progressing(progressing: bool) -> void:
	health_bar.modulate = Color.WHITE if progressing else Color(1, 1, 1, 0.4)

#endregion
