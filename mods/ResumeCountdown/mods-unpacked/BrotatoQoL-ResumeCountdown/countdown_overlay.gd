extends CanvasLayer

# Big "3 - 2 - 1" in the middle of the screen while the game is still paused.
# When it reaches 0 the game continues. Pressing pause during the countdown
# opens the pause menu again.

const INPUT_GRACE_MSEC := 200

var seconds := 3
var pause_menu = null

var _start_msec := 0
var _shown := -1
var _label: Label = null
var _tween: Tween = null


func _init() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	layer = 100
	name = "BrotatoQoLResumeCountdown"


func _ready() -> void:
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_label = Label.new()
	_label.anchor_left = 0.5
	_label.anchor_right = 0.5
	_label.anchor_top = 0.5
	_label.anchor_bottom = 0.5
	_label.margin_left = -200
	_label.margin_right = 200
	_label.margin_top = -100
	_label.margin_bottom = 100
	_label.align = Label.ALIGN_CENTER
	_label.valign = Label.VALIGN_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.rect_pivot_offset = Vector2(200, 100)
	var font = load("res://resources/fonts/actual/base/font_100_outline.tres")
	if font != null:
		_label.add_font_override("font", font)
	root.add_child(_label)

	_tween = Tween.new()
	_tween.pause_mode = Node.PAUSE_MODE_PROCESS
	add_child(_tween)

	_start_msec = OS.get_ticks_msec()
	_update()


# Real time, independent of Engine.time_scale
func _process(_delta: float) -> void:
	_update()


func _update() -> void:
	var elapsed := float(OS.get_ticks_msec() - _start_msec) / 1000.0
	var left := int(ceil(seconds - elapsed))
	if left <= 0:
		_finish()
		return
	if left != _shown:
		_shown = left
		_label.text = str(left)
		var _a = _tween.stop_all()
		var _b = _tween.interpolate_property(_label, "rect_scale", Vector2(1.6, 1.6), Vector2.ONE, 0.35, Tween.TRANS_BACK, Tween.EASE_OUT)
		var _c = _tween.interpolate_property(_label, "modulate:a", 0.0, 1.0, 0.15)
		var _d = _tween.start()


func _finish() -> void:
	set_process(false)
	set_process_input(false)
	if is_inside_tree():
		get_tree().paused = false
	queue_free()


func _input(event: InputEvent) -> void:
	if OS.get_ticks_msec() - _start_msec < INPUT_GRACE_MSEC:
		return
	if pause_menu == null or not is_instance_valid(pause_menu):
		return
	var run_data = get_node_or_null("/root/RunData")
	var player_count: int = run_data.get_player_count() if run_data != null else 1
	for player_index in player_count:
		if Utils.is_player_pause_released(event, player_index):
			get_viewport().set_input_as_handled()
			set_process(false)
			set_process_input(false)
			queue_free()
			pause_menu.pause(player_index)
			return
