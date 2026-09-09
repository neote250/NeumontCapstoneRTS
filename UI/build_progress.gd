extends Control
class_name BuildProgress

###Signal what you want from this upgrade/build to the squad/player
###Signal which button was clicked



@onready var button: Button = $Button
@onready var health_bar: HealthBar = $HealthBar

var connected_build: Build = null





# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	health_bar.init_health(0)
	#if !parent:
		#parent = get_parent() as Squad


func show_build(build: Build) -> void:
	connected_build = build
	health_bar.init_health(build.duration)
	health_bar.health = build.current_progress
	button.text = str(build)
	button.set_pressed_no_signal(build.is_building)



##dim the bar when queued but not progressing
func set_progressing(progressing: bool) -> void:
	health_bar.modulate = Color.WHITE if progressing else Color(1, 1, 1, 0.4)
