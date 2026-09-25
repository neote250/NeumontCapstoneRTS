extends Control
class_name PlayerUI
## The local player's heads-up display: the order wheel, the shard readout,
## the squad list, and the build panel. Reads squads, never commands them —
## the one exception is state_requested, which the controller acts on.


#region ─────────────────────────────  signals  ──────────────────────────────

signal state_requested(new_state: GlobalEnums.WHEEL_SLOT)

#endregion


#region ────────────────────────────  constants  ─────────────────────────────

## Why a purchase was refused, in words the player can read. Keyed by the
## result EconomyComponent.request_build() hands back.
const REFUSAL_TEXT: Dictionary = {
	EconomyComponent.PurchaseResult.SQUAD_FULL:      "Squad is at full strength",
	EconomyComponent.PurchaseResult.NO_SUCH_BUILD:   "This squad cannot recruit",
	EconomyComponent.PurchaseResult.ALREADY_BUILDING:"Already recruiting",
	EconomyComponent.PurchaseResult.NO_PURSE:        "",   # wild squad — say nothing
}

#endregion


#region ──────────────────────────  configuration  ───────────────────────────

@export_group("Wiring")
@export var owning_player: RTSController

@export_group("Build Panel")
## Fixed pool of progress widgets, one per visible build slot. See the note in
## the plan about replacing these with a per-squad SquadRow scene.
@export var display_builds_progress: Array[BuildProgress]
@export_group("")

#endregion


#region ─────────────────────────  node references  ──────────────────────────

@onready var selection_wheel: SelectionWheel = $CanvasLayer/Selection_Wheel
@onready var memory_shards: Label = $CanvasLayer/SquadInfoPanel/SquadInfoBox/Resources/MemoryShards
@onready var squad_info: VBoxContainer = %SquadInfo
@onready var toast_label: Label = $CanvasLayer/ToastLabel
@onready var toast_timer: Timer = $ToastTimer
@onready var testing_data_label: Label = $CanvasLayer/TestingDataLabel
## One line for whatever the player most needs to know — see _refresh_status().
@onready var status_label: Label = $CanvasLayer/StatusLabel

## TODO unused — nothing reads these three. Delete, or wire them up.
var current_controlled: Squad
@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var resources: Control = $CanvasLayer/SquadInfoPanel/SquadInfoBox/Resources

#endregion


#region ──────────────────────────────  state  ───────────────────────────────

## One row Label per squad, keyed by the squad itself so it cannot drift.
var _squad_rows: Dictionary[Squad, Label] = {}
## Which widget is showing which build, for the current squad only.
var build_dict: Dictionary[Build, BuildProgress]
## Squads whose signals we have already connected. Cheaper and safer than
## is_connected() on a bound Callable — bind() makes a new object each call.
var _watched: Array[Squad] = []

## The match result once there is one, "" while the round is live. Stored
## because it outranks every other status and has no other home to be read
## from — unlike "am I spectating?", which all_squads already answers.
var _result_text: String = ""

#endregion


#region ────────────────────────────  lifecycle  ─────────────────────────────

func _ready() -> void:
	if !owning_player:
		owning_player = get_parent()

	for i: int in display_builds_progress.size():
		display_builds_progress[i].button.toggled.connect(_on_build_toggled.bind(i))

	owning_player.added_squad.connect(_on_squad_added)
	owning_player.removed_squad.connect(_on_squad_removed)
	owning_player.swap_squad.connect(update_player_unit_details)
	owning_player.shards_changed.connect(_on_shards_changed)
	toast_timer.timeout.connect(func() -> void: toast_label.visible = false)

	_on_shards_changed(owning_player.memory_shards)
	for squad: Squad in owning_player.all_squads:
		_watch_squad(squad)
	_build_squad_rows()
	_refresh_status()
	set_physics_process(_any_squad_building())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("input_wheel"):
		selection_wheel.open()
	elif event.is_action_released("input_wheel"):
		state_requested.emit(selection_wheel.close())


## Only runs while something is under construction — see _on_any_build_changed.
func _physics_process(_delta: float) -> void:
	for build: Build in build_dict:
		build_dict[build].health_bar.health = build.current_progress

#endregion


#region ───────────────────────────  squad wiring  ───────────────────────────

## Connect a squad's signals once. Squads bought mid-match arrive through
## _on_squad_added, so this has to work for latecomers too.
func _watch_squad(squad: Squad) -> void:
	if squad in _watched:
		return
	_watched.append(squad)
	squad.roster_changed.connect(_refresh_squad_row)
	squad.state_machine.state_changed.connect(_on_squad_state_changed.bind(squad))
	for upgrade: Build in squad.economy.upgrades:
		upgrade.building_changed.connect(_on_any_build_changed.bind(squad))


func _on_squad_added(squad: Squad) -> void:
	_watch_squad(squad)
	_build_squad_rows()
	_refresh_status()


func _on_squad_removed(squad: Squad) -> void:
	_build_squad_rows()
	_watched.erase(squad)
	_refresh_status()

#endregion


#region ────────────────────────────  squad list  ────────────────────────────

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


## ▲ building in a build state, ◦ queued but the squad is doing something else.
func _refresh_squad_row(squad: Squad) -> void:
	var row: Label = _squad_rows.get(squad)
	if row == null:
		return
	var mark: String = "  "
	if squad.economy.is_building_anything():
		mark = "▲" if squad.is_build_state_active() else "◦"
	row.text = "%s %s  (%d)" % [mark, squad.name, squad.roster.size()]


func _on_squad_state_changed(_new_state: State, squad: Squad) -> void:
	_refresh_squad_row(squad)
	if squad == owning_player.current_squad:
		_refresh_build_widgets()

#endregion


#region ───────────────────────────  build panel  ────────────────────────────

## The controller swapped squads. Repopulate the panel for the new one.
func update_player_unit_details(current_squad: Squad) -> void:
	reset_buttons()
	# Losing your last squad clears the panel rather than freezing it on a
	# dead one — current_squad is null until another is selected.
	if not is_instance_valid(current_squad):
		return

	var index: int = 0
	for upgrade: Build in current_squad.economy.upgrades:
		if index >= display_builds_progress.size():
			break                       # TODO fixed widget pool; see the plan
		display_builds_progress[index].visible = true
		display_builds_progress[index].show_build(upgrade)
		build_dict[upgrade] = display_builds_progress[index]
		index += 1

	_refresh_build_widgets()


## Hide every widget and forget which build each was showing.
func reset_buttons() -> void:
	for option: BuildProgress in display_builds_progress:
		option.visible = false
	build_dict.clear()


func _on_build_toggled(toggled_on: bool, index: int) -> void:
	var widget: BuildProgress = display_builds_progress[index]
	var build: Build = widget.connected_build
	if build == null:
		return

	if not toggled_on:
		build.is_building = false       # cancelling never needs permission
		return

	var current_squad: Squad = owning_player.current_squad
	if not is_instance_valid(current_squad):
		widget.button.set_pressed_no_signal(false)
		return

	var result: EconomyComponent.PurchaseResult = current_squad.economy.request_build(build)
	if result != EconomyComponent.PurchaseResult.OK:
		widget.button.set_pressed_no_signal(false)   # bounce the button back
		show_toast(REFUSAL_TEXT.get(result, ""))


## Dim the bars when a build is queued but the squad is not in a build state.
func _refresh_build_widgets() -> void:
	var current_squad: Squad = owning_player.current_squad
	if not is_instance_valid(current_squad):
		return
	var progressing: bool = current_squad.is_build_state_active()
	for build: Build in build_dict:
		build_dict[build].set_progressing(progressing)


func _on_any_build_changed(_build: Build, _active: bool, squad: Squad) -> void:
	_refresh_squad_row(squad)
	set_physics_process(_any_squad_building())   # stop polling when idle


func _any_squad_building() -> bool:
	for squad: Squad in owning_player.all_squads:
		if squad.economy.is_building_anything():
			return true
	return false

#endregion


#region ──────────────────────────────  status  ──────────────────────────────

## The match ended. Told by the controller, which was told by the match.
func show_result(winning_team: int, we_won: bool) -> void:
	_result_text = "Victory" if we_won else "Team %d wins" % winning_team
	_refresh_status()

## One line, by priority: the result outranks everything, because once the
## round is over "spectating" is no longer the news. Asked of all_squads rather
## than tracked, so handing a player a squad clears it with no extra wiring.
##
## Spectating is deliberately not phrased as defeat. A player with no squads
## has not lost — a teammate can hand one over, and then this line goes away.
func _refresh_status() -> void:
	if not _result_text.is_empty():
		status_label.text = _result_text
	elif owning_player.all_squads.is_empty():
		status_label.text = "Spectating — a teammate can hand you a squad"
	else:
		status_label.visible = false
		return
	status_label.visible = true

#endregion


#region ───────────────────────  resources and toasts  ───────────────────────

func _on_shards_changed(amount: float) -> void:
	memory_shards.text = str(snapped(amount, 0.1))


func show_toast(text: String) -> void:
	if text.is_empty():
		return                          # NO_PURSE maps to "" — say nothing
	toast_label.text = text
	toast_label.visible = true
	toast_timer.start()                 # restarting is correct for back-to-back toasts

#endregion


#region ──────────────────────────────  debug  ───────────────────────────────

## Scratch readout. Called by rts_controller with the last clicked map position.
func change_testing_data_text(text: Variant) -> void:
	match typeof(text):
		TYPE_STRING:  testing_data_label.text = text
		TYPE_INT:     testing_data_label.text = str(text)
		TYPE_VECTOR2: testing_data_label.text = String.num(text.x) + " " + String.num(text.y)
		TYPE_VECTOR3: testing_data_label.text = String.num(text.x) + " " + String.num(text.z)

#endregion
