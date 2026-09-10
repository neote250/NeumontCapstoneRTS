extends Control
class_name PlayerUI

signal state_requested(new_state: GlobalEnums.WHEEL_SLOT)

#pointer to current model (unit/building) being controlled
var current_controlled:Squad

@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var selection_wheel: SelectionWheel = $CanvasLayer/Selection_Wheel
@onready var testing_data_label: Label = $CanvasLayer/TestingDataLabel

@export var owning_player: RTSController

@onready var resources: Control = $CanvasLayer/SquadInfoPanel/SquadInfoBox/Resources
@onready var memory_shards: Label = $CanvasLayer/SquadInfoPanel/SquadInfoBox/Resources/MemoryShards
@onready var squad_info: VBoxContainer = %SquadInfo
var _squad_rows: Dictionary[Squad, Label] = {}

@onready var toast_label: Label = $CanvasLayer/ToastLabel
@onready var toast_timer: Timer = $ToastTimer

@export var display_builds_progress:Array[BuildProgress]
#@export var build_options: Array[Build]

var build_dict:Dictionary[Build, BuildProgress]

var _watched: Array[Squad] = []

##Ensure controller is set
func _ready() -> void:
	if !owning_player:
		owning_player = get_parent()
	for i: int in display_builds_progress.size():
		display_builds_progress[i].button.toggled.connect(_on_build_toggled.bind(i))
	owning_player.added_squad.connect(_on_squad_added)
	owning_player.removed_squad.connect(_on_squad_removed)
	owning_player.swap_squad.connect(update_player_unit_details)
	owning_player.shards_changed.connect(_on_shards_changed)

	_on_shards_changed(owning_player.memory_shards) 
	for squad: Squad in owning_player.all_squads:
		_watch_squad(squad)
	_build_squad_rows()
	toast_timer.timeout.connect(func() -> void: toast_label.visible = false)
	set_physics_process(_any_squad_building())


func show_toast(text: String) -> void:
	if text.is_empty():
		return                       # NO_CONTROLLER maps to "" — say nothing
	toast_label.text = text
	toast_label.visible = true
	toast_timer.start()              # restarting is correct for back-to-back toasts

func _on_shards_changed(amount: float) -> void:
	memory_shards.text = str(snapped(amount, 0.1))

##Just testing data visuals
func change_testing_data_text(text) -> void:
	if typeof(text) == TYPE_STRING:
		testing_data_label.text = text
	if typeof(text) == TYPE_INT:
		testing_data_label.text = str(text)
	if typeof(text) == TYPE_VECTOR2:
		testing_data_label.text = String.num(text.x) + " " + String.num(text.y)
	if typeof(text) == TYPE_VECTOR3:
		testing_data_label.text = String.num(text.x) + " " + String.num(text.z)

##Reset the upgrade buttons, currently only hides all options and clears build array
func reset_buttons()->void:
	for option in display_builds_progress:
		option.visible = false
		
	build_dict.clear()

###Game manager calls this function to update visible unit details
func update_player_unit_details(_current_squad:Squad) -> void:
	##First hide all buttons
	reset_buttons()
	##Then show a button for each current squad build options and set the current progress
	var index:int = 0
	if !_current_squad.upgrades.is_empty():
		#for each build in the squad, match it to the build_progress bars in the ui
		for upgrade:Build in _current_squad.upgrades:
			if index >= display_builds_progress.size():
				break
			##Visuals
			display_builds_progress[index].visible = true
			display_builds_progress[index].show_build(upgrade)
			
			##Need to have button toggle the squad's upgrade??
			
			
			##Array Stuff
			build_dict[upgrade] = display_builds_progress[index]
			index+=1
		
	##Now that the buttons have been repopulated. Set their state
	_refresh_build_widgets()
	

func _on_build_toggled(toggled_on: bool, index: int) -> void:
	var widget: BuildProgress = display_builds_progress[index]
	var build: Build = widget.connected_build
	if build == null:
		return
	if not toggled_on:
		build.is_building = false          # cancelling never needs permission
		return
	var result: Squad.PurchaseResult = owning_player.current_squad.request_build(build)
	if result != Squad.PurchaseResult.OK:
		widget.button.set_pressed_no_signal(false)   # bounce the button back
		show_toast(REFUSAL_TEXT.get(result, ""))

func _on_any_build_changed(_build: Build, _active: bool, squad: Squad) -> void:
	_refresh_squad_row(squad)      # uses squad.is_building_anything()
	set_physics_process(_any_squad_building())   # stop polling when idle


func _any_squad_building() -> bool:
	for squad: Squad in owning_player.all_squads:
		if squad.is_building_anything():
			return true
	return false

func _build_squad_rows() -> void:
	for child: Node in squad_info.get_children():
		squad_info.remove_child(child)
		child.queue_free()
	_squad_rows.clear()
	for squad: Squad in owning_player.all_squads:
		var row: Label = Label.new()
		squad_info.add_child(row)
		_squad_rows[squad] = row
		_refresh_squad_row(squad)

func _refresh_squad_row(squad: Squad) -> void:
	var row: Label = _squad_rows.get(squad)
	if row == null:
		return
	var mark: String = "  "
	if squad.is_building_anything():
		mark = "▲" if squad.is_build_state_active() else "◦"
	row.text = "%s %s  (%d)" % [mark, squad.name, squad.roster.size()]

const REFUSAL_TEXT: Dictionary = {
	Squad.PurchaseResult.SQUAD_FULL:      "Squad is at full strength",
	Squad.PurchaseResult.NO_SUCH_BUILD:   "This squad cannot recruit",
	Squad.PurchaseResult.ALREADY_BUILDING:"Already recruiting",
	Squad.PurchaseResult.NO_CONTROLLER:   "",   # wild squad — say nothing
}

func _on_squad_state_changed(_new_state: State, squad: Squad) -> void:
	_refresh_squad_row(squad)
	if squad == owning_player.current_squad:
		_refresh_build_widgets()

func _refresh_build_widgets() -> void:
	var progressing: bool = owning_player.current_squad.is_build_state_active()
	for build: Build in build_dict:
		build_dict[build].set_progressing(progressing)



func _watch_squad(squad: Squad) -> void:
	if squad in _watched:
		return                       # cheaper and safer than is_connected() on a bound Callable
	_watched.append(squad)
	squad.roster_changed.connect(_refresh_squad_row)
	squad.state_machine.state_changed.connect(_on_squad_state_changed.bind(squad))
	for upgrade: Build in squad.upgrades:
		upgrade.building_changed.connect(_on_any_build_changed.bind(squad))

func _on_squad_added(squad: Squad, _i: int, _total: int) -> void:
	_watch_squad(squad)
	_build_squad_rows()

func _on_squad_removed(squad: Squad, _i: int, _total: int) -> void:
	_build_squad_rows()
	_watched.erase(squad)



#move _process to here when have time for optimization
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("input_wheel"):
		selection_wheel.open()
	elif event.is_action_released("input_wheel"):
		state_requested.emit(selection_wheel.close())
	

##VISUALS
func _physics_process(delta: float) -> void:
	for build: Build in build_dict:
		build_dict[build].health_bar.health = build.current_progress
