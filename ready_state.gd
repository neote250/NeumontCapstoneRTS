extends State


func Enter() -> void:
	super()
	parent.velocity = Vector3.ZERO

func Exit() -> void:
	pass

func State_Input(event:InputEvent) -> State:
	return null

func State_Update(_delta: float) -> State:
	return null


func State_Physics_Update(_delta: float) -> State:
	return null
