# A simple Third-Person Camera that can rotate around a central point of observation. The user's
# mouse is only captured when the camera's rotation is being adjusted.
# 
# If it's desired to change the roll of this camera, do so via its parent node; otherwise, the
# mouse inputs for camera rotation will become very disorienting.
# 
# This implementation assumes that the camera controls are the only thing that change the mouse
# mode. If that is ever not the case, it may be worth considering using a different camera for the
# duration; and, one may also consider disabling the unhandled input processing for this node
# (potentially forwarding filtered events, if necessary).
# 
# For consistency, character controllers that use this camera should update last_rotation_was_left
# when they rotate the camera indirectly (via rotation of the camera's parent nodes, for example).
# By updating the value, the camera's horizontal flips (via INPUT_FACE_BEHIND) are less
# disorienting; however, updating the value is not a necessity for the camera to function.
# 
# 
# What follows are semi-shorthand notes created during the design process. These have been left behind
# as a way to gain insight into the implementation; but, they may be outdated.
# 
# Known Possible States
#	1. Idle (not moving, no inputs, rotation not enabled).
#	2. Independent modifier just pressed/held.
#	3. Direct dependent rotation enabled, not rotating.
#	4. Direct independent rotation enabled, not rotating.
#	5. Direct dependent rotation just disabled.
#	6. Direct independent rotation just disabled.
#	7. Dependent rotation enabled, rotating.
#	8. Independent rotation enabled, rotating.
#	9. Automatic camera movement (via _process).
#		Horizontal flip (semi-independent).
#		Release of independent rotation -> return camera to rotation starting point.
#	
#	The camera is considered to be "rotating" when the mouse is captured. The automatic camera
#	movement does not count because it is not controlled by the user. Dependent camera rotation is
#	intended to update the user's directional input (actual behaviour depends on movement
#	controller/parent node implementation); while, independent rotation is handled locally and is
#	intended to be temporary (i.e.: the camera position reverts to where it was prior).
#	Semi-independent rotation is handled locally, but is not reverted through local handling.
# 
# Variables
#	1. Current camera position (horizontal_rotation & vertical_rotation).
#		Controls camera position/allows for external (semi-independent) control.
#	2. Type of camera movement: disabled/automatic/dependent/independent/modified (movement_type).
#		Tracks what type of camera movement is enabled based on the current state/inputs.
#		
#		Rules:
#			disabled - camera is idle
#				can become: automatic/dependent/independent/modified
#				When set
#					sets camera_auto_move_target -> Vector2.INF
#					sets directional_input -> Vector2.INF
#					releases mouse
#						warps mouse to captured_mouse_location
#						sets captured_mouse_location -> Vector2.INF
#			automatic - camera is moving to target automatically
#				can become: disabled/dependent/independent/modified
#				When set
#					sets camera_auto_move_target -> directional_input
#					sets directional_input -> Vector2.INF
#					releases mouse
#						warps mouse to captured_mouse_location
#						sets captured_mouse_location -> Vector2.INF
#			dependent - camera is capable of being dependently rotated by mouse movement
#				can become: disabled/independent/modified
#				When set (from modified)
#					set current position -> directional_input (bypass setters)
#			independent - camera is capable of being independently rotated by mouse movement
#				can become: disabled/automatic/dependent/modified
#				When set (except from automatic)
#					set directional_input -> current position
#				When set (from automatic)
#					set directional_input -> camera_auto_move_target
#			modified - camera is capable of being independently rotated by mouse movement
#				can become: disabled/automatic/dependent/independent
#				When set (except from automatic)
#					set directional_input -> current position
#				When set (from automatic)
#					set directional_input -> camera_auto_move_target
#	3. Camera position at independent rotation start (directional_input).
#		Stores the position of the camera when the mouse is captured during independent rotation.
#	4. Mouse location when initially captured (captured_mouse_location).
#		Stores the position of the mouse when it is captured in order to warp it back after it has
#		been released. This is to prevent the mouse from being released into the middle of the
#		screen regardless of where it was captured from.
#	5. Automatic camera movement target (camera_auto_move_target).
#		Stores the target rotational position that the camera should automatically move towards
#		when independent rotation is released, or the user initiates a horizontal flip.
# 
# Inputs
#	1. Enable drag (INPUT_MOUSE_DRAG_ROTATION; default: BUTTON_RIGHT)
#		Ignored if movement_type: independent.
#		Holding the input enables camera rotation via mouse movement.
#			Sets movement_type: disabled/automatic -> dependent/modified.
#			Does not capture the mouse!
#		Releasing the input disables camera rotation.
#			NOTE: Does NOT disable direct independent rotation (#2).
#			Sets movement_type:
#				dependent -> disabled.
#				modified -> automatic.
#		If rotating with #1, rotating with #2 should be disabled.
#			Has priority over #2 if the mouse hasn't been captured yet, but both inputs are held.
#	2. Enable independent drag (INPUT_INDEPENDENT_MOUSE_DRAG_ROTATION; default: BUTTON_LEFT)
#		Ignored if movement_type: dependent/modified.
#		Holding the input enables camera rotation via mouse movement.
#			Sets movement_type: disabled/automatic -> independent.
#			Does not capture the mouse!
#		Releasing the input disables camera rotation.
#			NOTE: Does NOT disable rotation from #1.
#			Sets movement_type: independent -> disabled/automatic
#		If rotating with #2, rotating with #1 should be disabled.
#			#1 has priority if the mouse hasn't been captured yet, but both inputs are held.
#	3. Independent drag modifier (INPUT_INDEPENDENT_ROTATION_MODIFIER; default: KEY_SHIFT)
#		Allows check via Input.is_action_presssed(INPUT_INDEPENDENT_ROTATION_MODIFIER)
#		Ignored if rotating with #2 (movement_type: independent, and mouse captured).
#		If rotating with #1, and #3 is held, further rotation should be independent.
#			Sets movement_type: dependent -> modified.
#		If rotating with #1, and #3 is released
#			further rotation should snap the camera back to directional_input.
#				Achieved through setting current position values directly (bypass setters).
#			Sets movement_type modified -> dependent
#	4. Horizontal flip (INPUT_FACE_BEHIND; default: BUTTON_MIDDLE)
#		Ignored if rotating with #1 or #2, or movement_type is automatic.
#		When pressed
#			if horizontal_rotation != -180
#				Sets camera_auto_move_target -> <vertical_rotation, -180>
#			else
#				Sets camera_auto_move_target -> <vertical_rotation, 0>
#			Sets movement_type: disabled -> automatic
#	5. Rotation (InputEventMouseMotion; while rotation enabled)
#		Captures the mouse
#			sets captured_mouse_location -> current mouse location
#	6. Zoom in (INPUT_ZOOM_IN; default: BUTTON_WHEEL_UP)
#		When pressed, shortens the camera spring arm length.
#	7. Zoom out (INPUT_ZOOM_OUT; default: BUTTON_WHEEL_DOWN)
#		When pressed, reduces the camera spring arm length.
class_name PointOrbitCamera3D extends Position3D


# Emitted when the spring_length on spring_arm has changed (when the user moves the camera in or out).
# This is exposed for the ability to stop rendering meshes that obstruct the point of observation
# while the camera is near enough to also be obstructed.
# 
# new_distance: float
#	The new length of the camera's spring arm.
signal camera_arm_distance_change(new_distance);

# Emitted when horizontal_rotation needs to change. The intention is that a parent node handles
# this rotation along the axis of gravity. This signal is emitted whenever the user's input would
# rotate the camera.
# 
# In cases where the parent node does not want to rotate (i.e.: camera rotation is desired without
# character rotation), they may have the rotation handled locally via setting horiztonal_rotation.
# 
# If independent is true, then the user intended to rotate the camera only; but, this signal was
# emitted for the sake of a parent node being aware that the camera's horizontal_rotation changed.
# In such a case, the signal may be ignored; as, the camera's rotation was already handled locally.
# In the event that the parent node also wants to rotate while independent is true, the parent
# should undo the local rotation by subtracting rotation_deg from horizontal_rotation.
# 
# Note: it's assumed that the parent node handles re-alignment of its rotation with the camera
# as necessary to match the user's input. See horizontal_rotation for more information.
# 
# rotation_deg: float
#	The change in horizontal rotation, in degrees.
# 
# independent: bool
#	Whether or not the user intended to rotate the camera only. If true, the camera's rotation
#	was already handled locally.
signal horizontal_rotation_change(rotation_deg, independent);

# The largest angle this camera will be allowed to aim up or down at.
# This prevents the user from becoming disoriented through flipping the camera.
const MAX_VERTICAL_ANGLE: float = 89.5;

# If true, generates actions and events in the InputMap that correspond to the recommended defaults
# for each of the input mappings if they are absent.
#
# If an action already exists, and has an InputEvent associated with it, then no action or event
# will be generated for that particular action -- even if this is set to true.
export var GENERATE_DEFAULT_INPUT_ACTIONS: bool = false;

# The string mapping for the input that must be held by the user in order to rotate the camera.
# 
# The recommended default for this would be the right mouse button.
export var INPUT_MOUSE_DRAG_ROTATION: String = "point_orbit_camera_mouse_drag_rotation";

# The string mappaing for the input that must be held by the user in order to rotate the camera
# independent of their directional input. This input is considered the direct way to perform
# this type of rotation; and, may be disabled by setting allow_direct_independent_rotation to false.
# 
# As an example, if the user is moving forward in a situation where rotating the camera
# would change the direction of their movement, this input would allow for locally-handled
# camera rotation that emits the horizontal_rotation_change signal with independent being true.
# The actual behaviour is dependent on the movement controller using this camera.
# 
# The recommended default for this would be the left mouse button; however, as many users can
# find this behaviour disorienting, it's recommended to use the modifier input,
# INPUT_INDEPENDENT_ROTATION_MODIFIER, as a default for this type of rotation.
export var INPUT_INDEPENDENT_MOUSE_DRAG_ROTATION: String = "point_orbit_camera_independent_drag_rotation";

# The string mapping for the input that must be held by the user in order to rotate the camera
# independent of their directional input with the input specified by INPUT_MOUSE_DRAG_ROTATION.
# See INPUT_INDEPENDENT_MOUSE_DRAG_ROTATION for an example of what that means.
# 
# The recommended default for this would be the shift key.
export var INPUT_INDEPENDENT_ROTATION_MODIFIER: String = "point_orbit_camera_independent_rotation_modifier";

# The string mapping for the input that, when pressed, will rotate the camera to face the backwards
# direction, or the forward direction if already facing backwards. The rotation happens
# independently of the user's directional input.
# 
# The recommended default for this would be the middle mouse button.
export var INPUT_FACE_BEHIND: String = "point_orbit_camera_face_behind";

# The string mapping for the input that, when pressed, will "zoom" the camera in. This reduces
# the length of the camera spring arm.
# 
# It's recommended to override this input by setting use_scroll_wheel_for_zoom to true; and, the
# generated default input, when GENERATE_DEFAULT_INPUT_ACTIONS is true, is BUTTON_WHEEL_UP.
export var INPUT_ZOOM_IN: String = "point_orbit_camera_zoom_in";

# The string mapping for the input that, when pressed, will "zoom" the camera out. This increases
# the length of the camera spring arm.
# 
# It's recommended to override this input by setting use_scroll_wheel_for_zoom to true; and, the
# generated default input, when GENERATE_DEFAULT_INPUT_ACTIONS is true, is BUTTON_WHEEL_DOWN.
export var INPUT_ZOOM_OUT: String = "point_orbit_camera_zoom_out";

# The type of movement the camera is capable of or currently performing
enum MoveType {
	# Camera is idle and cannot be rotated.
	DISABLED,
	
	# Camera is moving to a target position automatically.
	AUTOMATIC,
	
	# Camera is capable of being dependently rotated by mouse movement while holding
	# INPUT_MOUSE_DRAG_ROTATION.
	DEPENDENT,
	
	# Camera is capable of being independently rotated by mouse movement while holding
	# INPUT_INDEPENDENT_MOUSE_DRAG_ROTATION.
	INDEPENDENT,
	
	# Camera is capable of being independently rotated by mouse movement while holding
	# INPUT_MOUSE_DRAG_ROTATION.
	MODIFIED,
}

# Inverts the camera "zoom" direction. If true, INPUT_ZOOM_IN will behavve as if it were
# INPUT_ZOOM_OUT and vise-versa.
export var invert_zoom_controls: bool = false;

# If true, allows the use of INPUT_INDEPENDENT_MOUSE_DRAG_ROTATION as a user input.
export var allow_direct_independent_rotation: bool = false;

# Multiplier for camera rotation via mouse input.
export(float, 0.0, 1.0, 0.1) var mouse_sensitivity: float = 0.3;

# The speed, in degrees per second, that the camera rotates when movement_type is
# MoveType.AUTOMATIC.
export var automatic_rotation_speed: float = 180.0 / 0.75;

# The farthest the camera can move away from the point of observation.
export(float, 0.0, 100.0, 5.0) var max_camera_distance: float = 20.0;

# The camera's default distance from the point of observation.
# 
# The 100.0 in the export hint here is the same as the one above -- for max_camera_distance.
export(float, 0.0, 100.0, 0.5) var default_camera_distance: float = 5.0;

# The arm the camera is attached to -- the zero length position is coincident with the point
# of observation.
onready var spring_arm: SpringArm = SpringArm.new();

# The camera, obviously.
onready var camera: Camera = Camera.new();

# The local rotation left or right around the point of observation (sometimes called the yaw).
# Zero rotation is in line with the positive Z-axis (the default placement for spring arm
# extensions). Generally, this value should be zero unless the user is rotating the camera
# independent of their directional input (see below for a note on exceptions to this).
# 
# This value is not updated if the user is not rotating the camera independently; instead, the
# horizontal_rotation_change signal is emitted. The intention is for a parent node to handle
# rotation with its own transform if the signal is emitted; however, there are exceptions in
# which this value will not be 0.0. It is a requirement of the parent node to handle these cases.
# The recommended way of handling this is to re-align the parent with the camera, while setting
# this value to 0.0, on the start of the next directional input from the user. Even if this is done
# without respecting camera movement that is independent of the user's directional input, the user
# is unlikely to become disoriented.
# 
# This value is in degrees, and kept within [-180, 180). For reference, adding positive values
# will result in the camera looking to the left; and, adding negative values will result in the
# camera looking to the right.
var horizontal_rotation: float setget _set_horizontal_rotation;

# The rotation up or down around the point of observation (sometimes called the pitch). Zero
# rotation leaves the camera's view perpendicular to the vector <0.0, 1.0, 0.0>. To find the
# current vertical input direction, see vertical_rotation_input_direction's getter.
# 
# This value is in degrees, and clamped within [-MAX_VERTICAL_ANGLE, MAX_VERTICAL_ANGLE].
# For reference, adding positive values will result in the camera looking upwards; and,
# adding negative values will result in the camera looking downwards.
var vertical_rotation: float setget _set_vertical_rotation;

# Tracks the last direction the camera was rotated in.
# 
# This is used to prevent consecutive pairs of horizontal flips from spinning through the
# full range of the camera's motion (which is disorienting).
var last_rotation_was_left: bool = false;

# Tracks what type of camera movement is enabled based on the current state/inputs.
# 
# See MoveType enum for more information.
var movement_type: int = MoveType.DISABLED setget _set_movement_type;

# The rotational position of the camera, in degrees, around the point of observation that the
# user's directional inputs are facing. This could also be described as the position prior
# to being moved independent of the user's directional inputs. The x-component represents the
# vertical_rotation; and, the y-component represents the horizontal_rotation. This value is set
# to Vector2.INF when not in use (because the Vector2 type-hint prevents setting it to null);
# and, setting it externally results in undefined behaviour. However, for convenience, the
# getter will always return an accurate value for the current state of the camera (it will never
# return Vector2.INF).
# 
# Even though the horizontal_rotation is very likely to be zero, it is necessary to store it for
# this purpose. This is for a few reasons; but, the most prominent is the possibility that the
# parent node handed horizontal rotation handling back to us. It would be disorienting for the user
# if the camera did not return to the location they moved it from in that context.
# 
# It is the responsibility of a parent node to handle cases where the horizontal directional input
# is not zero. See horizontal_rotation for the recommended approach.
var directional_input: Vector2 = Vector2.INF setget , _get_directional_input;

# The location of the mouse when the user began rotating the camera.
# 
# When the camera is not being manipulated, this will be set to Vector2.INF (because the Vector2
# type-hint prevents setting this field to null).
var captured_mouse_location: Vector2 = Vector2.INF;

# A target destination for the camera to return to after being released from independent control.
# The camera returns to this target with independent rotation.
# 
# The target values are in degrees. The x-component represents vertical rotation, and the
# y-component represents horizontal rotation.
# 
# When the camera does not have a move target, this will be set to Vector2.INF (because the Vector2
# type-hint prevents setting this field to null).
# 
# While possible to hijack control of the camera from the user by setting this, the user can
# retake control at any moment by performing their own input. As that would be disorienting for
# the user, it's recommended to achieve that effect through a different means.
var camera_auto_move_target: Vector2 = Vector2.INF;


# Check if input actions exist. If they don't, add empty versions to avoid errors in _unhandled_input.
# Setup spring arm and camera children.
func _ready() -> void:
	var action_map := {
		INPUT_MOUSE_DRAG_ROTATION: BUTTON_RIGHT,
		INPUT_INDEPENDENT_MOUSE_DRAG_ROTATION: BUTTON_LEFT,
		INPUT_INDEPENDENT_ROTATION_MODIFIER: KEY_SHIFT,
		INPUT_FACE_BEHIND: BUTTON_MIDDLE,
		INPUT_ZOOM_IN: BUTTON_WHEEL_UP,
		INPUT_ZOOM_OUT: BUTTON_WHEEL_DOWN,
	};
	
	for action in action_map.keys():
		if !InputMap.has_action(action):
			InputMap.add_action(action);
		
		if GENERATE_DEFAULT_INPUT_ACTIONS and InputMap.get_action_list(action).empty():
			var event: InputEvent;
			match action_map[action]:
				KEY_SHIFT:
					event = InputEventKey.new();
					event.scancode = KEY_SHIFT;
				_:
					event = InputEventMouseButton.new();
					event.button_index = action_map[action];
			# End match
			
			InputMap.action_add_event(action, event);
	# End for
	
	camera.name = "Camera";
	spring_arm.name = "SpringArm";
	spring_arm.spring_length = default_camera_distance;
	if get_parent() is PhysicsBody:
		spring_arm.add_excluded_object(get_parent().get_rid());
	
	spring_arm.add_child(camera, true);
	add_child(spring_arm, true);
	
	camera.current = true;

# Set movement_type to MoveType.DISABLED if the application loses focus.
func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_WM_FOCUS_OUT and _mouse_is_captured():
		self.movement_type = MoveType.DISABLED;

# Perform automatic camera movement if necessary.
func _process(delta: float) -> void:
	if movement_type == MoveType.AUTOMATIC and _has_auto_move_target():
		delta = min(delta, 0.1); # Prevent lag from moving the camera in large amounts at once.
		
		var move_amount: float = automatic_rotation_speed * delta;
		self.vertical_rotation = move_toward(vertical_rotation, camera_auto_move_target.x, move_amount);
		
		var horizontal_move_target = camera_auto_move_target.y;
		if horizontal_move_target == -180.0 and horizontal_rotation == 0.0:
			# We are probably doing a horizontal flip to face behind.
			horizontal_move_target = 180.0 if last_rotation_was_left else -180.0;
		elif horizontal_move_target == 0.0 and horizontal_rotation == -180.0:
			# We are probably doing a horizontal flip to face forward.
			if last_rotation_was_left:
				# Avoid setter becaue it will not only wrap the value, but also perform a rotation.
				horizontal_rotation = 180.0;
		else:
			# Check if horizontal rotation will cross wrap threshold.
			if abs(horizontal_rotation - horizontal_move_target) > 180.0:
				horizontal_move_target -= sign(horizontal_move_target) * 360.0;
		
		self.horizontal_rotation = move_toward(horizontal_rotation, horizontal_move_target, move_amount);
		
		if _current_position_matches(camera_auto_move_target):
			self.movement_type = MoveType.DISABLED;

# Handle input options.
func _unhandled_input(event: InputEvent) -> void:
	# Safety check
	if movement_type == MoveType.DISABLED or movement_type == MoveType.AUTOMATIC and _mouse_is_captured():
		_capture_mouse(false);
	
	# Enable/Disable dependent drag
	if event.is_action(INPUT_MOUSE_DRAG_ROTATION) \
	and !(movement_type == MoveType.INDEPENDENT and _mouse_is_captured()):
		if event.is_pressed():
			self.movement_type = MoveType.DEPENDENT \
				if !Input.is_action_pressed(INPUT_INDEPENDENT_ROTATION_MODIFIER) else MoveType.MODIFIED;
		else:
			if !_mouse_is_captured() and Input.is_action_pressed(INPUT_INDEPENDENT_MOUSE_DRAG_ROTATION):
				self.movement_type = MoveType.INDEPENDENT;
			elif movement_type == MoveType.MODIFIED and !_current_position_matches(self.directional_input):
				self.movement_type = MoveType.AUTOMATIC;
			else:
				self.movement_type = MoveType.DISABLED;
	
	# Enable/Disable independent drag
	if event.is_action(INPUT_INDEPENDENT_MOUSE_DRAG_ROTATION) \
	and !(movement_type == MoveType.DEPENDENT or movement_type == MoveType.MODIFIED):
		if event.is_pressed():
			self.movement_type = MoveType.INDEPENDENT;
		else:
			# The getter for directional input will retrieve the current position if the camera
			# has not been rotated independently.
			self.movement_type = MoveType.AUTOMATIC if !_current_position_matches(self.directional_input) \
				else MoveType.DISABLED;
	
	# Independent drag modifier
	if event.is_action(INPUT_INDEPENDENT_ROTATION_MODIFIER) and movement_type != MoveType.INDEPENDENT:
		if event.is_pressed() and movement_type == MoveType.DEPENDENT:
			# If the user used modified rotation, then releases this input, does NOT move the mouse,
			# and then presses this input again, the camera's position state and actual local rotation
			# values will likely be out of sync. That means the user will be disoriented when the
			# camera snaps back to their directional input instead of allowing independent rotation
			# from the currently rendered camera position. So, resync the camera position values.
			self.movement_type = MoveType.MODIFIED;
			
			# The update must come after the movement_type change (to keep the state proper).
			_resync_camera_position();
		elif !event.is_pressed() and movement_type == MoveType.MODIFIED:
			self.movement_type = MoveType.DEPENDENT;
	
	# Horizontal flip
	if event.is_action(INPUT_FACE_BEHIND) and !event.is_pressed() \
	and !(_mouse_is_captured() or movement_type == MoveType.AUTOMATIC):
		# Setting the movement_type to automatic via the setter will produce the wrong behaviour;
		# but, fortunately, the only state we have to manage to correct it is the
		# camera_auto_move_target.
		self.movement_type = MoveType.AUTOMATIC;
		camera_auto_move_target = Vector2(vertical_rotation, -180.0 if horizontal_rotation != -180.0 else 0.0);
	
	# Camera rotation via mouse dragging
	if event is InputEventMouseMotion and _user_rotation_is_enabled():
		if !_mouse_is_captured():
			_capture_mouse();
		
		# camera_input.x is left/right (positive is RIGHT)
		# camera_input.y is up/down (positive is DOWN)
		var camera_input: Vector2 = (event as InputEventMouseMotion).relative;
		var rotation_amount: float = -camera_input.x * mouse_sensitivity;
		
		if movement_type == MoveType.DEPENDENT:
			emit_signal("horizontal_rotation_change", rotation_amount, false);
		else:
			self.horizontal_rotation += (rotation_amount);
			emit_signal("horizontal_rotation_change", rotation_amount, true);
		
		self.vertical_rotation += (-camera_input.y * mouse_sensitivity);
	
	# Camera zoom options
	if (event.is_action(INPUT_ZOOM_IN) or event.is_action(INPUT_ZOOM_OUT)) and event.is_pressed():
		var sign_modifier: float = 1.0 if !invert_zoom_controls else -1.0;
		sign_modifier *= 1.0 if event.is_action(INPUT_ZOOM_OUT) else -1.0;
		
		var new_length: float = spring_arm.spring_length;
		new_length = clamp(new_length + (0.5 * sign_modifier), 0.0, max_camera_distance);
		spring_arm.spring_length = new_length;
		emit_signal("camera_arm_distance_change", new_length);

# Rotates, horizontally, towards a horizontal_rotation of zero, by the specified amount. The
# rotation can be consumed up to 180 degrees (any higher is not possible, as the rotation
# caused by a call to this method is towards zero).
# 
# Negative values for amount are not allowed and will be clamped to zero. If one wishes to rotate
# the camera horizontally, set horizontal_rotation directly.
# 
# The camera's rotation can be consumed at any point; however, if the camera's rotation is
# consumed during automatic movement, then the movement will be cancelled in-place -- even if
# the actual amount of rotation consumed is zero. Further, if the camera is being rotated
# independently by the user, the directional_input will be updated to the new rotation.
# 
# As it's intended for the caller to be a parent node that rotates in the opposite direction by
# the same amount, the actual rotation amount is returned in a negated form. As an example, if
# the camera rotates 50.2 deg (left), then the return value would be -50.2 deg (right).
# 
# The horizontal_rotation_change signal is not emitted by a call to this method.
# 
# amount:
#	The positive amount of rotation to consume, in degrees.
func consume_rotation(amount: float = 180.0) -> float:
	# We aren't top level, so this is a nice method to have for convenience.
	amount = clamp(amount, 0.0, 180.0);
	var actual_amount: float = -horizontal_rotation;
	
	if amount == 180.0 or abs(horizontal_rotation) <= amount:
		# Avoids FLOP errors
		self.horizontal_rotation = 0.0;
	else:
		if abs(horizontal_rotation) > amount:
			actual_amount = amount;
			actual_amount *= -sign(horizontal_rotation);
		
		self.horizontal_rotation += actual_amount;
	
	if movement_type == MoveType.AUTOMATIC:
		self.movement_type = MoveType.DISABLED;
	
	if movement_type == MoveType.INDEPENDENT or movement_type == MoveType.MODIFIED:
		directional_input = Vector2(vertical_rotation, horizontal_rotation);
	
	return -actual_amount;

# Checks if the camera's movement_type corresponds to a state that is being controlled by the user
# or not, and returns true if so.
func is_under_user_control() -> bool:
	return movement_type != MoveType.DISABLED and movement_type != MoveType.AUTOMATIC;

# Captures or releases the mouse. When the mouse is captured, its previous position in the
# viewport is stored in captured_mouse_location; then, when the mouse is released, it is warped
# to the location stored in captured_mouse_location.
# 
# capture:
#	If true, sets Input.mouse_mode to Input.MOUSE_MODE_CAPTURED if it's not already.
#	If false, sets Input.mouse_mode to Input.MOUSE_MODE_VISIBLE if it's Input.MOUSE_MODE_CAPTURED
func _capture_mouse(capture: bool = true) -> void:
	if capture and !_mouse_is_captured():
		captured_mouse_location = get_viewport().get_mouse_position();
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED;
	elif !capture and _mouse_is_captured():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE;
		# Checking just in case our state is screwy somehow
		if captured_mouse_location != Vector2.INF:
			get_viewport().warp_mouse(captured_mouse_location);
		captured_mouse_location = Vector2.INF;

# Convenience method to check if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
func _mouse_is_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED;

# Clarity method for if the camera can be rotated by the user or not.
func _user_rotation_is_enabled() -> bool:
	return movement_type == MoveType.DEPENDENT \
		or movement_type == MoveType.INDEPENDENT \
		or movement_type == MoveType.MODIFIED;

# Clarity method for when the camera is moving on its own to a certain target rotation.
func _has_auto_move_target() -> bool:
	return camera_auto_move_target != Vector2.INF;

# Helper method to identify if automatic movement is necessary. checks if the current
# vertical_rotation and horizontal_rotation matches the values specified by position.
# 
# position:
#	A vector representing the position to check the current position against. The x-component
#	represents vertical_rotation; and, the y-component represents horizontal_rotation.
func _current_position_matches(position: Vector2) -> bool:
	return vertical_rotation == position.x and horizontal_rotation == position.y;

# A simple method to resync the vertical_rotation and horizontal_rotation values to the actual
# local rotations of the camera tracked by Godot.
# 
# This is generally unnecessary.
func _resync_camera_position() -> void:
	# Bypass setters.
	horizontal_rotation = wrapf(rotation_degrees.y, -180.0, 180.0);
	vertical_rotation = clamp(spring_arm.rotation_degrees.x, -MAX_VERTICAL_ANGLE, MAX_VERTICAL_ANGLE);

# Setter for horizontal_rotation.
func _set_horizontal_rotation(rotation_deg: float) -> void:
	rotation_deg = wrapf(rotation_deg, -180.0, 180.0);
	if rotation_deg == -180.0 and horizontal_rotation > 0.0:
		last_rotation_was_left = sign(-rotation_deg - horizontal_rotation) > 0.0;
	else:
		last_rotation_was_left = sign(rotation_deg - horizontal_rotation) > 0.0;
	horizontal_rotation = rotation_deg;
	rotation_degrees.y = horizontal_rotation;

# Setter for vertical_rotation.
func _set_vertical_rotation(rotation_deg: float) -> void:
	vertical_rotation = clamp(rotation_deg, -MAX_VERTICAL_ANGLE, MAX_VERTICAL_ANGLE);
	spring_arm.rotation_degrees.x = vertical_rotation;

# Setter for movement_type. When the movement_type is updated, certain state changes may happen;
# but, setting movement_type to its current value does nothing.
# 
# move_type:
#	One of the MoveType enum constants.
func _set_movement_type(move_type: int) -> void:
	if movement_type == move_type:
		# Nothing to do. Shouldn't happen under normal circumstances.
		return;
	
	# Assert the previous state is "valid".
	# It doesn't matter what the previous state actually is (that's why we're only asserting); but,
	# this can help discover unknown states of the camera.
	assert(_movement_type_change_is_known(move_type));
	
	match move_type:
		MoveType.DISABLED:
			camera_auto_move_target = Vector2.INF;
			directional_input = Vector2.INF;
			_capture_mouse(false);
		MoveType.AUTOMATIC:
			# Using the getter here to prevent invalid values.
			camera_auto_move_target = self.directional_input;
			directional_input = Vector2.INF;
			_capture_mouse(false);
		MoveType.DEPENDENT:
			if movement_type == MoveType.MODIFIED:
				# Bypass setters so the camera doesn't move until the next
				# rotation/directional input.
				vertical_rotation = directional_input.x;
				horizontal_rotation = directional_input.y;
		MoveType.INDEPENDENT, MoveType.MODIFIED:
			if movement_type != MoveType.AUTOMATIC:
				directional_input = Vector2(vertical_rotation, horizontal_rotation);
			else:
				directional_input = camera_auto_move_target;
				camera_auto_move_target = Vector2.INF;
		_:
			assert(false, "Unhandled MoveType: %s" % move_type);
	# End match
	
	movement_type = move_type;

# Just a method for convenience.
func _movement_type_change_is_known(next_move_type: int) -> bool:
	var types: Array;
	match next_move_type:
		MoveType.DISABLED: # <- automatic/dependent/independent/modified
			types = [MoveType.AUTOMATIC, MoveType.DEPENDENT, MoveType.INDEPENDENT, MoveType.MODIFIED];
		MoveType.AUTOMATIC: # <- disabled/independent/modified
			types = [MoveType.DISABLED, MoveType.INDEPENDENT, MoveType.MODIFIED];
		MoveType.DEPENDENT: # <- disabled/automatic/independent/modified
			types = [MoveType.DISABLED, MoveType.AUTOMATIC, MoveType.INDEPENDENT, MoveType.MODIFIED];
		MoveType.INDEPENDENT: # <- disabled/automatic/dependent/modified
			types = [MoveType.DISABLED, MoveType.AUTOMATIC, MoveType.DEPENDENT, MoveType.MODIFIED];
		MoveType.MODIFIED: # <- disabled/automatic/dependent
			types = [MoveType.DISABLED, MoveType.AUTOMATIC, MoveType.DEPENDENT, MoveType.INDEPENDENT];
		_:
			assert(false, "Unhandled MoveType: %s" % movement_type);
			return false;
	# End match
	
	for type in types:
		if movement_type == type:
			return true;
	# End for
	return false;

# Getter for directional_input.
func _get_directional_input() -> Vector2:
	return Vector2(vertical_rotation, horizontal_rotation) if directional_input == Vector2.INF \
		else directional_input;
