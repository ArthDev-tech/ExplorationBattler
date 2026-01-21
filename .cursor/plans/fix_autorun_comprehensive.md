# Fix Auto-Run Detection and Add Comprehensive Debugging

## Critical Issues Found

1. **Process Mode Issue**: Player controller doesn't have `PROCESS_MODE_ALWAYS`, so `_input()` won't be called when game is paused
2. **No Fallback Detection**: Only using `_input()` - if it fails, no detection
3. **Need Input Verification**: Verify autorun action exists and is properly configured

## Solution

### 1. Set Process Mode
Add `process_mode = Node.PROCESS_MODE_ALWAYS` in `_init()` so input works even when paused (for testing/debugging)

### 2. Add Fallback Detection
Add toggle detection in `_physics_process()` using `Input.is_action_just_pressed()` as backup

### 3. Add Comprehensive Debugging
- Log in `_ready()` to verify action exists
- Log any key press in `_input()` to verify it's being called
- Log state checks in `_handle_movement()`
- Log when toggle is detected

### 4. Verify Input Action Keycode
Check if physical_keycode 266 is correct for numpad period - may need to test with alternative key

## Implementation

### File: `scenes/exploration/player/player_controller.gd`

**Add to `_init()`:**
```gdscript
func _init() -> void:
	# Allow input processing even when paused (for debugging)
	process_mode = Node.PROCESS_MODE_ALWAYS
```

**Modify `_ready()`:**
```gdscript
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("[Player] PlayerController ready")
	print("[Player] Autorun action exists: ", InputMap.has_action("autorun"))
	if InputMap.has_action("autorun"):
		var events = InputMap.action_get_events("autorun")
		print("[Player] Autorun action has ", events.size(), " events")
		for i in range(events.size()):
			var evt = events[i]
			if evt is InputEventKey:
				print("[Player] Autorun event ", i, ": physical_keycode=", evt.physical_keycode)
```

**Modify `_input()`:**
```gdscript
func _input(event: InputEvent) -> void:
	# Debug: Log any key press to verify _input() is being called
	if event is InputEventKey and event.pressed:
		print("[Player] Key pressed: keycode=", event.keycode, " physical=", event.physical_keycode, " action_match=", event.is_action("autorun"))
	
	# ... existing mouse motion code ...
	
	# Toggle auto-run on numpad period press
	if event.is_action_pressed("autorun"):
		_auto_run_enabled = not _auto_run_enabled
		print("[Player] Auto-run toggled (input): ", "ON" if _auto_run_enabled else "OFF")
```

**Modify `_physics_process()`:**
```gdscript
func _physics_process(delta: float) -> void:
	# Check for auto-run toggle (fallback if _input() doesn't catch it)
	if Input.is_action_just_pressed("autorun"):
		_auto_run_enabled = not _auto_run_enabled
		print("[Player] Auto-run toggled (physics): ", "ON" if _auto_run_enabled else "OFF")
	
	# Don't process if game is paused
	if get_tree().paused:
		return
	
	# ... rest of existing code ...
```

**Modify `_handle_movement()`:**
```gdscript
func _handle_movement(delta: float) -> void:
	if _current_state != PlayerState.NORMAL:
		if _auto_run_enabled:
			print("[AutoRun] Movement blocked - state: ", _current_state)
		return
	
	if _is_dashing:
		if _auto_run_enabled:
			print("[AutoRun] Movement blocked - dashing")
		return
	
	# ... rest of existing code with logging ...
```

## Testing Strategy

1. Check console for `[Player] PlayerController ready` - verifies script loads
2. Check for autorun action verification - confirms action exists
3. Press numpad period - should see key press log and toggle log
4. If no logs appear, try alternative key (like 'R') to test input system
5. Check state logs when auto-run enabled - see if movement is blocked

## Alternative Key Mapping

If numpad period doesn't work, we can temporarily add 'R' key to autorun action for testing:
```
autorun={
"deadzone": 0.5,
"events": [
  Object(InputEventKey,"physical_keycode":266,...),  # Numpad period
  Object(InputEventKey,"physical_keycode":82,...)     # R key (temporary test)
]
}
```
