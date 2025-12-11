extends Control
class_name BuildProgress

###Signal what you want from this upgrade/build to the squad/player
signal completed(upgrade_button:BuildProgress)#, upgrade:GlobalEnums.UPGRADE_TYPE
###Signal which button was clicked
signal build_selected(option:BuildProgress, toggled:bool)



@onready var button: Button = $Button
@onready var health_bar: HealthBar = $HealthBar

var connected_build





# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	button.toggled.connect(_toggled)
	health_bar.init_health(0)
	#if !parent:
		#parent = get_parent() as Squad

func connect_to_build()->void:
	pass

func _toggled(is_pressed:bool) -> void:
	build_selected.emit(self, is_pressed)

#func _deselected()->void:
	#pass

#func upgrade_finished()->void:
	#completed.emit(self)

func setup(text:String = "something went wrong")->void:
	button.text = text
	#button should already be pressed if it is toggled
	#any buttons currently pressed should be unpressed if it is untoggled


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass
