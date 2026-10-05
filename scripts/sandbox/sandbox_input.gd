class_name SandboxInput
extends RefCounted
## Registers the sandbox's input actions in code so the scratchpad works with no
## Input Map setup. Move these into Project Settings > Input Map once the
## controls settle.


static func ensure_actions() -> void:
	_add("move_forward", [_key(KEY_W), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add("move_back", [_key(KEY_S), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_add("move_left", [_key(KEY_A), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_add("move_right", [_key(KEY_D), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_add("shoot", [_mouse(MOUSE_BUTTON_LEFT), _key(KEY_SPACE), _button(JOY_BUTTON_A)])
	_add("autofocus", [_mouse(MOUSE_BUTTON_RIGHT), _key(KEY_T), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	_add("focus_far", [_mouse(MOUSE_BUTTON_WHEEL_UP), _key(KEY_X), _button(JOY_BUTTON_DPAD_RIGHT)])
	_add("focus_near", [_mouse(MOUSE_BUTTON_WHEEL_DOWN), _key(KEY_Z), _button(JOY_BUTTON_DPAD_LEFT)])
	_add("setting_next", [_key(KEY_E), _button(JOY_BUTTON_RIGHT_SHOULDER)])
	_add("setting_prev", [_key(KEY_Q), _button(JOY_BUTTON_LEFT_SHOULDER)])
	_add("value_up", [_key(KEY_R), _key(KEY_UP), _button(JOY_BUTTON_DPAD_UP)])
	_add("value_down", [_key(KEY_F), _key(KEY_DOWN), _button(JOY_BUTTON_DPAD_DOWN)])
	_add("toggle_mouse", [_key(KEY_ESCAPE), _button(JOY_BUTTON_START)])


static func _add(action: StringName, events: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for event in events:
		InputMap.action_add_event(action, event)


static func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


static func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event


static func _button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event


static func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event
