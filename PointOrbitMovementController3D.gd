# A 3D movement controller designed to pair with a PointOrbitCamera3D.
# 
# The controller supports various types of movement. It is based on observations of the movement
# controller of an established game. The supported movement types are grounded, falling, gliding,
# and flying.
# 
# As the controller's state changes, the movement_state_change signal is emitted. This is provided
# to assist with animation control. If one wishes to expand upon the supported states of this
# controller, they may interrupt the controller with the provided method or field; which, will
# allow them to take over all visible movement handling until interrupted is no longer true. This
# is already partially required by the movement states represented by MoveState.IDLE_TAKOFF, and
# MoveState.TAKEOFF; as, these are considered interrupting actions. Alternatively, subclasses
# may opt to override the _physics_process_* helper methods to handle each type of behaviour
# themselves (including state changes).
# 
# NOTE: The velocity and input vectors are rotated to match the rotation of the body. As such,
# gravity will always act downwards from the perspective of the user. If this is not desired,
# it may be worth looking for alternatives to this controller.
class_name PointOrbitMovementController3D extends KinematicBody


# Emitted when the movement_state is about to change. This signal is emitted before the change
# occurs; so, subscribers to the signal may retrieve the previous state by getting movement_state.
# 
# It's important to note that MoveState.IDLE_TAKEOFF, and MoveState.TAKEOFF, are interrupting
# states. This means interrupted will be set to true, and the movement controller will cease
# normal functions until set back to false. This is intended to allow external behaviour control
# during the animation of the user's character entering flight; and, as such, a good time to revert
# interrupted to false would be when the takeoff animation concludes.
# 
# next_movement_state: int
#	The next movement_state that will be set on this controller after the signal is emitted.
#	This is one of the MoveState enum constants.
signal movement_state_change(next_movement_state);

# If true, generates actions and events in the InputMap that correspond to the recommended defaults
# for each of the input mappings if they are absent. This choice is propagated down to the camera,
# as well.
#
# If an action already exists, and has an InputEvent associated with it, then no action or event
# will be generated for that particular action -- even if this is set to true.
export var GENERATE_DEFAULT_INPUT_ACTIONS: bool = false;

# The string mapping for the input that moves the user's character forward.
# 
# The recommended default for this would be the W key.
export var INPUT_FORWARD: String = "point_orbit_move_forward";

# The string mapping for the input that moves the user's character backward.
# 
# The recommended default for this would be the S key.
export var INPUT_BACKWARD: String = "point_orbit_move_backward";

# A string used to map the current state of the directional input in directional_input_states.
const INPUT_DIRECTIONAL: String = "point_orbit_move_directional";

# The string mapping for the input that moves the user's character left.
# 
# The recommended default for this would be the Q key.
export var INPUT_STRAFE_LEFT: String = "point_orbit_move_strafe_left";

# The string mapping for the input that moves the user's character right.
# 
# The recommended default for this would be the E key.
export var INPUT_STRAFE_RIGHT: String = "point_orbit_move_strafe_right";

# The string mapping for the input that rotates the user's character left.
# 
# The recommended default for this would be the A key.
export var INPUT_ROTATE_LEFT: String = "point_orbit_move_rotate_left";

# The string mapping for the input that rotates the user's character right.
# 
# The recommended default for this would be the D key.
export var INPUT_ROTATE_RIGHT: String = "point_orbit_move_rotate_right";

# The string mapping for the input that causes the user's character to move forward automatically.
# 
# The recommended default for this would be the Num Lock key.
export var INPUT_AUTO_RUN_TOGGLE: String = "point_orbit_move_auto_run";

# The string mapping for the input that causes the user's character to move backward automatically.
# 
# The recommended default for this would be the / key on the numeric pad.
export var INPUT_AUTO_REVERSE_TOGGLE: String = "point_orbit_move_auto_reverse";

# The string mapping for the input that toggles between walking and running.
# 
# The recommended default for this would be the Period key.
export var INPUT_WALK_TOGGLE: String = "point_orbit_move_toggle_walk";

# The string mapping for the input that causes the user's character to jump.
# 
# The recommended default for this would be the Space key.
export var INPUT_JUMP: String = "point_orbit_move_jump";

# The string mapping for the input that activates gliding.
# 
# While not considered a toggle key, as that could be misconstrued as meaning the user's character
# will glide at every opportunity, pressing this input again, while gliding is activated, will
# disable gliding.
# 
# The recommended default for this would be the Space key.
export var INPUT_GLIDE: String = "point_orbit_move_glide";

# The string mapping for the input that causes the user's character to start flying.
# 
# The recommended default for this would be the Page Up key.
export var INPUT_TAKEOFF: String = "point_orbit_move_takeoff";

# The string mapping for the input that causes the user's character to stop flying or gliding.
# 
# The recommended default for this would be the Page Down key.
export var INPUT_LAND: String = "point_orbit_move_land";

# The string mapping for the input that toggles accepting directional input for vertical control
# while the user's character is flying.
# 
# The recommended default for this would be the Scroll Lock key.
# 
# NOTE: The starting state of lock keys, such as Scroll Lock, are unknown by this implementation;
# so, the toggled state may not match what the user expects for their current state of a lock key
# if used.
export var INPUT_DIRECTIONAL_ALTITUDE_LOCK_TOGGLE: String = "point_orbit_move_toggle_directional_altitude_lock";

# The string mapping for the input that causes the user's character to gain altitude while flying.
# This is essentially a movement input in the positive-y direction.
# 
# The recommended default for this would be the R key.
export var INPUT_RISE: String = "point_orbit_move_ascend";

# The string mapping for the input that causes the user's character to lose altitude while flying.
# This is essentially a movement input in the negative-y direction.
# 
# The recommended default for this would be the F key.
export var INPUT_FALL: String = "point_orbit_move_descend";

# Represents the main categories of MoveState types.
enum MoveCategory {
	# the user's character is on the ground.
	# 
	# The MoveState constants that represent this category are:
	#	IDLE, WALKING, BACK_WALKING, RUNNING, BACK_RUNNING, TURNING_LEFT, and TURNING_RIGHT
	GROUNDED,
	
	# The user's character is falling or jumping.
	# 
	# The MoveState constants that represent this category are:
	#	JUMPING, FALLING, and FREEFALL
	SEMI_GROUNDED,
	
	# The user's character is gliding through the air.
	# 
	# The MoveState constants that represent this category are:
	#	GLIDING, GLIDING_FAST, GLIDING_UPDRAFT, FLYING_GLIDE, FLYING_GLIDE_FAST,
	#	and FLYING_GLIDE_UPDRAFT
	SEMI_FLIGHT,
	
	# The user's character is flying through the air.
	# 
	# The MoveState constants that represent this category are:
	#	FLYING_IDLE, FLYING, BACK_FLYING, ASCENDING, and DESCENDING
	# 
	# Further, while the controller is not directly in flight during them (as they are
	# transitional states), IDLE_TAKEOFF, and TAKEOFF, are considered to be part of
	# this category.
	FLIGHT,
}

# Represents various states that this controller can be in. Generally speaking, these each
# also correspond to an animation.
enum MoveState {
	# The user's character is not moving or flying.
	IDLE,
	
	# The user's character is walking in the direction of their velocity.
	WALKING,
	
	# The user's character is walking backwards in the direction of their velocity.
	BACK_WALKING,
	
	# The user's character is running in the direction of their velocity..
	RUNNING,
	
	# The user's character is running backwards in the direction of their velocity.
	BACK_RUNNING,
	
	# The user's character is turning via INPUT_ROTATE_LEFT while otherwise idle.
	TURNING_LEFT,
	
	# The user's character is turning via INPUT_ROTATE_RIGHT while otherwise idle.
	TURNING_RIGHT,
	
	# The user's character is moving upwards after performing a jump. If the user's character has
	# any non-vertical velocity, then their directional inputs are ignored. This condition prevents
	# them from changing direction mid-jump; but, allows them to start moving slighty if they
	# performed a jump while not moving.
	JUMPING,
	
	# The user's character is falling a 'short' distance. If the user's character has any
	# non-vertical velocity, then their directional inputs are ignored. This condition prevents
	# them from changing direction mid-jump; but, allows them to start moving slighty if they
	# performed a jump while not moving.
	# 
	# 'Short' in this context is arbitrary; but, the distance can be configured indirectly by
	# tweaking the value of freefall_velocity.
	FALLING,
	
	# The user's character is falling uncontrollably. Directional inputs are ignored.
	# 
	# This state is achieved after FALLING for a prolonged period. See FALLING for more information.
	FREEFALL,
	
	# The user's character is gliding in the direction of their velocity. The user's direction
	# will slowly change towards the the camera's input_direction.
	GLIDING,
	
	# The user's character is gliding at a more downwards incline. Updrafts are ignored.
	GLIDING_FAST,
	
	# A state of gliding in which the user's character is gaining altitude. Directional inputs are
	# ignored.
	GLIDING_UPDRAFT,
	
	# Similar to GLIDING; but, when the glide ends, the state will return to FLYING.
	FLYING_GLIDE,
	
	# Similar to GLIDING_FAST; but, when the glide ends, the state will return to FLYING.
	FLYING_GLIDE_FAST,
	
	# Similar to GLIDING_UPDRAFT; but, when the glide ends, the state will return to FLYING.
	FLYING_GLIDE_UPDRAFT,
	
	# The user's character begins FLYING from IDLE. Changing to this state is an interrupting
	# action; and, as such, interrupted must be set back to false for the controller to continue
	# normal function.
	IDLE_TAKEOFF,
	
	# The user's character begins FLYING while not IDLE. Changing to this state is an interrupting
	# action; and, as such, interrupted must be set back to false for the controller to continue
	# normal function.
	TAKEOFF,
	
	# The user's character is otherwise idle while flying.
	FLYING_IDLE,
	
	# The user's character is flying in the direction of their velocity.
	FLYING,
	
	# Same as FLYING, but backwards.
	BACK_FLYING,
	
	# The user's character is flying directly upwards. Directional flying inputs are still
	# allowed during this state.
	ASCENDING,
	
	# The user's character is flying directly downwards. Directional flying inputs are still
	# allowed during this state.
	DESCENDING,
}

# Represents varying types of automatic movement.
enum AutoMoveState {
	# Not performing automatic movement.
	NONE,
	
	# User's character is automatically moving forward.
	FORWARD,
	
	# User's character is automatically moving backward.
	BACKWARD,
}

# Repreents the state of directional inputs.
enum InputState {
	# The input is not being held by the user.
	NONE,
	
	# The input is being held by the user.
	HELD,
	
	# The input is being held by the user; but, it's being ignored until released.
	# 
	# An argument could be made that this state (and thus the entire enum) is unnecessary; however,
	# since it was implemented this way before realizing this state would never be checked, the
	# decision to leave it has been made to have the input state be more clear during debugging.
	INTERRUPTED,
}

# The default width multiplier of the feet_box which will be multiplied with body_capsule's
# capsule radius to determine the size of the feet_box.
const DEFAULT_FOOT_SIZE_MULTIPLIER: float = 0.75;

# If true, holding the mouse buttons BUTTON_LEFT and BUTTON_RIGHT will result in the user's
# character moving forward (or backward, if invert_directional_movement is true).
# 
# The state of this input is tracked within directional_input_states under INPUT_DIRECTIONAL.
export var use_mouse_left_and_right_as_directional_movement: bool = true;

# Whether or not to invert the direction of INPUT_DIRECTIONAL, if in use. If true, and in use,
# the user's character will move backwards when the user's input mark INPUT_DIRECTIONAL as held.
# 
# Does nothing if use_mouse_left_and_right_as_directional_movement is false.
export var invert_directional_movement: bool = false;

# The height to use for the top of the user character's collision.
export var character_height: float = 2.0;

# The location to place the camera, relative to our origin.
export var camera_position: Vector3 = Vector3(0.0, 1.6, 0.0);

# The top running speed of the user's character (on the ground).
export var running_speed: float = 6.0;

# The top walking speed of the user's character (on the ground).
export var walking_speed: float = 1.5;

# The top flying speed of the user's character.
# 
# The default of 9.0 is fairly slow. With the other defaults, this value would feel better
# as something higher, such as 13.0. The current default is a reference to the game this controller
# was based on.
export var flying_speed: float = 9.0;

# The top gliding speed of the user's character.
export var gliding_speed: float = 10.0;

# The top gliding speed when the user sacrifices the possibilities of getting an updraft or bounce.
export var gliding_fast_speed: float = 11.0

# The speed at which the user's character (and camera) rotate while using
# INPUT_ROTATE_LEFT or INPUT_ROTATE_RIGHT, in degrees per second.
# 
# This value will also be set as the automatic_rotation_speed of the camera.
export var rotation_speed: float = 180.0 / 0.75 setget _set_rotation_speed;

# The speed at which the user's character rotates to match the camera while gliding,
# in degrees per second.
export var gliding_rotation_speed: float = (180.0 / 0.75) * 0.5;

# A percentage multiplier indicating the total movement speed available to the user's
# character while strafing whilst on the ground or flying.
# 
# In flight, MoveState.ASCENDING, and MoveState.DESCENDING, are considered strafing.
export var strafe_movement_speed_percentage: float = 0.8;

# A percentage multiplier indicating the total movement speed available to the user's
# character while moving backwards whilst on the ground or flying.
export var backwards_movement_speed_percentage: float = 0.6;

# The percentage at which movement speed accumulates from user input per frame.
export(float, 0.01, 1.0) var movement_velocity_step: float = 0.2;

# The percentage at which movement speed accumulates while gliding per frame.
export(float, 0.01, 1.0) var gliding_velocity_step: float = 0.1;

# The maximum angle that the user's character can traverse during grounded movement, in degrees.
# This value is relative to the local rotation of this body, and the floor. Surfaces with a normal
# matching Vector3.UP rotated to match this body's rotation will be considered the flattest floor.
# 
# Obstacles at a more extreme angle than this are considered the wall, and obstacles beyond a
# 90 degree rotation from the floor will be considered a ceiling.
export(float, 0.0, 80.0) var max_slope_angle: float = 60.0;

# The minimum floor collision angle that the user must achieve in order to continue gliding fast.
# Impacting the floor while gliding fast at an angle below this one will result in the fast
# glide ending.
# 
# This value is in degrees.
export(float, 0.01, 80.0) var min_slope_angle_for_fast_glide: float = 20.0;

# The maximum height the user's character can teleport upwards when moving on the ground.
# This is intended to handle stairs; but, a step can come in all shapes and sizes!
export var step_height: float = 0.5;

# The minimum traversable distance that must be available above an obstacle for it to be
# considered a step instead of wall, if it is shorter than step_height.
# 
# Note: This is not enforced as a required dimension of the step collision.
export var step_depth: float = 0.5;

# The height of the user character's jump.
export var jump_height: float = 1.25;

# The time (in seconds) it takes for the user's character to reach jump_height after jumping.
export var time_to_max_jump_height: float = 0.3;

# The height the user's character gains from catching an updraft while gliding.
export var updraft_height: float = 10.0;

# The time (in seconds) it takes for the user's character to reach updraft_height after receiving
# an updraft.
export var time_to_max_updraft_height: float = 2.0;

# The current acceleration of gravity that is being applied to the user's character.
# 
# Note that the direction of gravity is always assumed to be Vector3.DOWN in local space;
# but, it will be rotated to match the rotation of this body. If one wishes to change the
# direction of gravity, apply a change of pitch or roll to this body.
# 
# This defaults to the default gravity from ProjectSettings; however, a recommended value
# would be 38.
export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") setget , _get_gravity;

# The downwards velocity applied while gliding. "Gravity" is a bit of a misnomer here; but, it
# doesn't matter too much. This is the constant speed at which gliding will fall downwards. If
# it were an acceleration, like the term 'gravity' implies, then it would just be low-gravity
# falling instead of gliding.
export var glide_gravity: float = 4.0;

# The velocity the user's character has to achieve while falling before movement_state becomes
# MoveState.FREEFALL.
export var freefall_velocity: float = gravity;

# The highest falling velocity that can be achieved by the user's character.
# 
# Human terminal velocity is roughly 60 m/s.
export var terminal_velocity: float = 200.0;

# The velocity applied to the user's character to achieve jump_height distance over the specified
# time_to_max_jump_height, while under the effects of jump_gravity in place of normal gravity.
onready var jump_velocity: float = 2.0 * jump_height / time_to_max_jump_height;

# The magnitute of gravity that is applied to the user's character while jumping in order to
# achieve jump_height at the specified time_to_max_jump_height after jumping.
onready var jump_gravity: float = 2.0 * jump_height / (time_to_max_jump_height * time_to_max_jump_height);

# The velocity applied to the user's character to achieve updraft_height distance over the specified
# time_to_max_updraft_height, while under the effects of updraft_gravity in place of normal gravity.
onready var updraft_velocity: float = 2.0 * updraft_height / time_to_max_updraft_height;

# The magnitute of gravity that is applied to the user's character while riding an updraft in order
# to achieve updraft_height at the specified time_to_max_updraft_height after jumping.
onready var updraft_gravity: float = \
	2.0 * updraft_height / (time_to_max_updraft_height * time_to_max_updraft_height);

# The current status of directional inputs, described by InputState values mapped to the input's
# corresponding INPUT_* export string.
# 
# Note that INPUT_AUTO_RUN_TOGGLE and INPUT_AUTO_REVERSE_TOGGLE are excluded.
onready var directional_input_states := {
	INPUT_FORWARD: InputState.NONE,
	INPUT_BACKWARD: InputState.NONE,
	INPUT_DIRECTIONAL: InputState.NONE,
	INPUT_STRAFE_LEFT: InputState.NONE,
	INPUT_STRAFE_RIGHT: InputState.NONE,
	INPUT_ROTATE_LEFT: InputState.NONE,
	INPUT_ROTATE_RIGHT: InputState.NONE,
#	INPUT_AUTO_RUN_TOGGLE: InputState.NONE,
#	INPUT_AUTO_REVERSE_TOGGLE: InputState.NONE,
	INPUT_JUMP: InputState.NONE,
	INPUT_RISE: InputState.NONE,
	INPUT_FALL: InputState.NONE,
};

# The current MoveState of this controller. Setting this value will change how the current
# directional inputs, and sometimes physics, are being handled.
# 
# Be warned that setting this to a value that doesn't make sense for the current inputs may
# result in odd behaviour.
# 
# In essence, there are four main categories of movement: Grounded, Semi-Grounded, Semi-Flight,
# and Flight. Generally, each MoveState can freely become another in its own category; but, there
# are exceptions. Changes are not validated; but, known possible changes are listed further below.
# 
# Grounded movement consists of:
#	IDLE, WALKING, BACK_WALKING, RUNNING, BACK_RUNNING, TURNING_LEFT, TURNING_RIGHT.
# 
# Semi-Grounded movement consists of:
#	JUMPING, FALLING, and FREEFALL.
# 
# Semi-Flight movement consists of:
#	GLIDING, GLIDING_FAST, GLIDING_UPDRAFT, FLYING_GLIDE, FLYING_GLIDE_FAST, and FLYING_GLIDE_UPDRAFT.
# 
# Flight movement consists of:
#	FLYING_IDLE, FLYING, BACK_FLYING, ASCENDING, and DESCENDING.
# 
# IDLE_TAKEOFF, and TAKEOFF are transitional states that lead into FLYING_IDLE from Grounded and
# Semi-Grounded movement.
# 
# Traversal between the main categories of movement happens as laid out below:
#	Grounded -> Semi-Grounded:
#		Grounded -> JUMPING, FALLING
# 
#	Grounded -> Flight:
#		IDLE, TURNING_LEFT, TURNING_RIGHT -> IDLE_TAKEOFF -> FLYING_IDLE
#		(any other Grounded state) -> TAKEOFF -> FLYING_IDLE
# 
#	Semi-Grounded -> Grounded:
#		FALLING (-> FREEFALL) -> IDLE
# 
#	Semi-Grounded -> Semi-Flight:
#		FALLING (-> FREEFALL) -> GLIDING
# 
#	Semi-Grounded -> Flight:
#		FALLING (-> FREEFALL) -> TAKEOFF -> FLYING_IDLE
# 
#	Semi-Flight -> Semi-Grounded:
#		(Semi-Flight) -> FALLING
# 
#	Semi-Flight -> Flight:
#		FLYING_GLIDE, FLYING_GLIDE_FAST, FLYING_GLIDE_UPDRAFT -> FLYING_IDLE
# 
#	Flight -> Semi-Grounded:
#		(Flight) -> FALLING
# 
#	Flight -> Semi-Flight:
#		(Flight) -> FLYING_GLIDE
# 
# What follows is the known list of state changes:
#	IDLE -> WALKING, BACK_WALKING, RUNNING, BACK_RUNNING, TURNING_LEFT, TURNING_RIGHT,
#		JUMPING, FALLING, IDLE_TAKEOFF
#	WALKING -> IDLE, RUNNING, TURNING_LEFT, TURNING_RIGHT, JUMPING, FALLING, TAKEOFF
#	BACK_WALKING -> IDLE, BACK_RUNNING, TURNING_LEFT, TURNING_RIGHT, JUMPING, FALLING, TAKEOFF
#	RUNNING -> IDLE, WALKING, TURNING_LEFT, TURNING_RIGHT, JUMPING, FALLING, TAKEOFF
#	BACK_RUNNING -> IDLE, BACK_WALKING, TURNING_LEFT, TURNING_RIGHT, JUMPING, FALLING, TAKEOFF
#	TURNING_LEFT -> IDLE, WALKING, BACK_WALKING, RUNNING, BACK_RUNNING, TURNING_RIGHT, JUMPING,
#		FALLING, IDLE_TAKEOFF
#	TURNING_RIGHT -> IDLE, WALKING, BACK_WALKING, RUNNING, BACK_RUNNING, TURNING_LEFT, JUMPING,
#		FALLING, IDLE_TAKEOFF
#	JUMPING -> FALLING, TAKEOFF
#	FALLING -> IDLE, FREEFALL, GLIDING, TAKEOFF
#	FREEFALL -> IDLE, GLIDING, TAKEOFF
#	GLIDING -> FALLING, GLIDING_FAST, GLIDING_UPDRAFT
#	GLIDING_FAST -> FALLING, GLIDING, GLIDING_UPDRAFT
#	GLIDING_UPDRAFT -> FALLING, GLIDING, GLIDING_FAST
#	FLYING_GLIDE -> FALLING, FLYING_IDLE, FLYING_GLIDE_FAST, FLYING_GLIDE_UPDRAFT
#	FLYING_GLIDE_FAST -> FALLING, FLYING_IDLE, FLYING_GLIDE, FLYING_GLIDE_UPDRAFT
#	FLYING_GLIDE_UPDRAFT -> FALLING, FLYING_IDLE, FLYING_GLIDE, FLYING_GLIDE_FAST
#	IDLE_TAKEOFF -> FLYING_IDLE
#	TAKEOFF -> FLYING_IDLE
#	FLYING_IDLE -> FALLING, FLYING, FLYING_GLIDE, ASCENDING, DESCENDING
#	FLYING -> FALLING, FLYING_IDLE, FLYING_GLIDE, ASCENDING, DESCENDING
#	BACK_FLYING -> FALLING, FLYING_IDLE, FLYING_GLIDE, ASCENDING, DESCENDING
#	ASCENDING -> FALLING, FLYING_IDLE, FLYING, FLYING_GLIDE
#	DESCENDING -> FALLING, FLYING_IDLE, FLYING, FLYING_GLIDE
var movement_state: int = MoveState.FALLING setget _set_movement_state;

# The current AutoMoveState of this controller.
# 
# Automatic movement, when enabled (this value is not AutoMoveState.NONE), can move forwards,
# or backwards, when this value is set to AutoMoveState.FORWARD, or AutoMoveState.BACKWARD,
# respectively.
var automatic_movement_state: int = AutoMoveState.NONE;

# Whether or not to use the default collision.
# 
# Regardless of this setting, the default collision will be generated. When this is false,
# however, it will be disabled.
var use_default_collision: bool = true setget _set_use_default_collision;

# Whether or not the user is walking. If false, then the user's land movement will be based on
# their running speed; otherwise, it will be based on their walking speed.
var is_walking: bool = false;

# If true, then the vertical portion of the user's directional input is ignored while flying.
var directional_altitude_lock: bool = false;

# If this is true, the movement controller stops processing visible actions taken by the user
# (including the effects of gravity); except rotating, which will rotate the camera only.
# 
# For example, if one wishes to use this movement controller while having functionality that it
# does not support (say, a rolling dodge), they could set this value to true and handle that
# functionality directly. When handling is complete, setting this value back to false will
# re-enable normal movement.
var interrupted: bool = false setget _set_interrupted;

# The camera that the user will interact with while providing inputs to this movement controller.
var camera: PointOrbitCamera3D = PointOrbitCamera3D.new();

# The default collision capsule for the body of the user's character.
var body_capsule: CollisionShape = CollisionShape.new();

# A raycast standing in for the leg collision of the user's character.
var leg_ray_cast: RayCast = RayCast.new();

# The default collision box for the feet of the user's character.
var feet_box: CollisionShape = CollisionShape.new();

# The current velocity of the controller. The user's character is moving at this
# speed at the start of the next physics frame.
# 
# This velocity is rotated to match the orientation of this body. To get the velocity without
# the rotation, see _get_zero_rotation_velocity.
var rotated_velocity: Vector3 = Vector3.ZERO;


# Setup children and inputs
func _ready() -> void:
	var action_map := {
		INPUT_FORWARD: KEY_W,
		INPUT_BACKWARD: KEY_S,
		INPUT_STRAFE_LEFT: KEY_Q,
		INPUT_STRAFE_RIGHT: KEY_E,
		INPUT_ROTATE_LEFT: KEY_A,
		INPUT_ROTATE_RIGHT: KEY_D,
		INPUT_AUTO_RUN_TOGGLE: KEY_NUMLOCK,
		INPUT_AUTO_REVERSE_TOGGLE: KEY_KP_DIVIDE,
		INPUT_WALK_TOGGLE: KEY_PERIOD,
		INPUT_JUMP: KEY_SPACE,
		INPUT_GLIDE: KEY_SPACE,
		INPUT_TAKEOFF: KEY_PAGEUP,
		INPUT_LAND: KEY_PAGEDOWN,
		INPUT_DIRECTIONAL_ALTITUDE_LOCK_TOGGLE: KEY_SCROLLLOCK,
		INPUT_RISE: KEY_R,
		INPUT_FALL: KEY_F,
	};
	
	for action in action_map.keys():
		if !InputMap.has_action(action):
			# Add empty versions to avoid errors in _unhandled_input
			InputMap.add_action(action);
		
		if GENERATE_DEFAULT_INPUT_ACTIONS and InputMap.get_action_list(action).empty():
			var event: InputEvent;
			match action_map[action]:
				BUTTON_LEFT:
					event = InputEventMouseButton.new();
					event.button_index = action_map[action];
				_:
					event = InputEventKey.new();
					event.scancode = action_map[action];
			# End match
			
			InputMap.action_add_event(action, event);
	# End for
	
	# Setup camera
	camera.GENERATE_DEFAULT_INPUT_ACTIONS = GENERATE_DEFAULT_INPUT_ACTIONS;
	camera.automatic_rotation_speed = rotation_speed;
	if camera.connect("horizontal_rotation_change", self, "_rotate_horizontally", [true]) != OK:
		assert(false, "Failed to connect camera horizontal_rotation_change signal.");
	
	camera.translation = camera_position;
	add_child(camera);
	
	# Setup body_capsule
	var capsule: CapsuleShape = CapsuleShape.new();
	capsule.radius = step_depth;
	capsule.height = character_height - step_height - (capsule.radius * 2);
	body_capsule.shape = capsule;
	body_capsule.rotation_degrees.x = -90.0;
	body_capsule.translation.y = step_height + ((capsule.height + (capsule.radius * 2)) / 2.0);
	body_capsule.disabled = !use_default_collision;
	add_child(body_capsule);
	
	# Setup leg_ray_cast
	leg_ray_cast.cast_to = Vector3(0.0, -step_height, 0.0);
	leg_ray_cast.translation.y = step_height;
	leg_ray_cast.enabled = use_default_collision;
	leg_ray_cast.add_exception(self);
	add_child(leg_ray_cast);
	
	# Setup feet_box
	var box: BoxShape = BoxShape.new();
	# Half of the largest square that can fit within the radius of the capsule.
	box.extents.x = capsule.radius * sqrt(2.0) * DEFAULT_FOOT_SIZE_MULTIPLIER * 0.5;
	box.extents.z = capsule.radius * sqrt(2.0) * DEFAULT_FOOT_SIZE_MULTIPLIER * 0.5;
	box.extents.y = 0.05;
	feet_box.shape = box;
	feet_box.translation.y = box.extents.y;
	feet_box.disabled = !use_default_collision or _is_in_move_category(MoveCategory.FLIGHT);
	add_child(feet_box);

# Clear out held inputs on lost focus.
func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_WM_FOCUS_OUT:
		for input in directional_input_states.keys():
			directional_input_states[input] = InputState.NONE;
		# End for

# Handle directional movement inputs and physics.
func _physics_process(delta: float) -> void:
	if interrupted:
		_physics_process_while_interrupted(delta);
	else:
		match _get_movement_category():
			MoveCategory.GROUNDED:
				_physics_process_grounded_movement(delta);
			MoveCategory.SEMI_GROUNDED:
				_physics_process_semi_grounded_movement(delta);
			MoveCategory.SEMI_FLIGHT:
				_physics_process_semi_flight_movement(delta);
			MoveCategory.FLIGHT:
				_physics_process_flight_movement(delta);
			_:
				assert(false, "Unknown Movement Category!");
		# End match
		
		if use_default_collision:
			leg_ray_cast.force_raycast_update();
			if leg_ray_cast.is_colliding():
				# If we're hitting our raycast, then some sort of collision has cut our character
				# in half! We need to either clip up through it, or down through it. Let's go up.
				# Might have to add more because the feet would still be clipping if the ray
				# collides with a slope.
				var up: Vector3 = transform.basis.xform(Vector3.UP);
				var normal: Vector3 = leg_ray_cast.get_collision_normal();
				var angle: float = up.angle_to(normal);
				var move_up_amount: float = \
					step_height - leg_ray_cast.to_local(leg_ray_cast.get_collision_point()).length();
				
				# Add a small amount for FLOP errors. <_<
				move_up_amount += 0.0001;
				
				# It's probably a floor and not a ceiling...
				# If we somehow do this with a ceiling, then we're clipping up through it.
				# Anyhow, correct the angle if it's a ceiling.
				if angle > PI * 0.5:
					angle -= PI * 0.5;
				angle = stepify(angle, 0.0001);
				
				if angle != PI * 0.5 and angle != 0.0 and !_is_flying():
					# If this is somehow a 90 degree WALL, then we can't fix it without knowing how
					# tall the wall is. Leave it to the process helpers.
					# half-width of the feet / tan(angle) = extra height to move up...
					# The feet are square, though; so, use the corner (half of the radius of the
					# capsule). Using the corner will likely add a little extra; so, the user might
					# fall for a frame; but, this is already an edge case; so, they can deal.
					move_up_amount += \
						(body_capsule.shape as CapsuleShape).radius * DEFAULT_FOOT_SIZE_MULTIPLIER / tan(angle);
				
				translate(transform.basis.xform((Vector3.UP * move_up_amount) / scale.y));

# _physics_process helper
# 
# Handles movement behaviour when interrupted is true.
func _physics_process_while_interrupted(delta: float) -> void:
	# Allow rotation of the camera
	_rotate_horizontally(_get_input_horizontal_rotation_deg(delta), true);

# _physics_process helper
# 
# Handles movement behaviour when movement_state is within the category represented by
# MoveCategory.GROUNDED
func _physics_process_grounded_movement(delta: float) -> void:
	var next_movement_state: int = movement_state;
	# This doesn't have gravity for this frame (or previous ones).
	var frame_velocity: Vector3 = _get_input_vector();
	
	# frame_velocity.y is zero.
	if frame_velocity.z == 0.0 and frame_velocity.x == 0.0:
		# Not movind at all
		next_movement_state = MoveState.IDLE;
	elif frame_velocity.z > 0.0:
		# Moveing backwards
		next_movement_state = MoveState.BACK_RUNNING if !is_walking else MoveState.BACK_WALKING;
	else:
		# Moving forwards or strafing.
		next_movement_state = MoveState.RUNNING if !is_walking else MoveState.WALKING;
	
	var rotation_amount: float = _get_input_horizontal_rotation_deg(delta);
	if rotation_amount != 0.0 and next_movement_state == MoveState.IDLE:
		next_movement_state = MoveState.TURNING_LEFT if rotation_amount > 0.0 else MoveState.TURNING_RIGHT;
	_rotate_horizontally(rotation_amount);
	
	if _is_held(INPUT_JUMP):
		# This is more or less okay. Velocity in x and z are set to the max movement speed
		# of the current inputs to make the jump feel more responsive.
		var speed_multiplier: float = 1.0;
		var top_speed: float = running_speed if !is_walking else walking_speed;
		if frame_velocity.z > 0.0:
			speed_multiplier = backwards_movement_speed_percentage;
		elif frame_velocity.z == 0.0:
			speed_multiplier = strafe_movement_speed_percentage;
		
		frame_velocity = frame_velocity.normalized() * top_speed * speed_multiplier;
		frame_velocity.y = jump_velocity;
		self.movement_state = MoveState.JUMPING;
		rotated_velocity = transform.basis.xform(frame_velocity);
		return;
	
	# Grounded movement does not handle falling, so we don't tack on vertical movement from the
	# previous frame.
	var frame_gravity: Vector3 = transform.basis.xform(Vector3.DOWN * (self.gravity * delta));
	frame_velocity = transform.basis.xform(frame_velocity);
	
	var result: KinematicCollision = move_and_collide(frame_velocity * delta, true, false);
	if result and result.remainder != Vector3.ZERO:
		# Hit something and can keep going. Stairs or a slope...?
		frame_velocity = _physics_process_grounded_slope_or_step(frame_velocity, result);
	
	# Check step height/gravity down if needed...
	if !(movement_state == MoveState.IDLE \
	and _is_any(next_movement_state, [MoveState.IDLE, MoveState.TURNING_LEFT, MoveState.TURNING_RIGHT])) \
	or _check_gravity_while_idle():
		var down = transform.basis.xform(Vector3.DOWN);
		result = move_and_collide(down * step_height, true, false);
		if result:
			rotated_velocity = frame_velocity;
		else:
			# Nothing to step down to... fall.
			rotated_velocity = frame_velocity + frame_gravity;
			next_movement_state = MoveState.FALLING;
	
	self.movement_state = next_movement_state;

# _physics_process helper
# 
# Handles movement when a collision occurs during grounded horizontal movement.
# Does not apply gravity! This method only moves up steps and slides upwards along slopes.
# 
# The frame_velocity is returned as-is if the movement continued for the full length of result's
# remainder. However, if a collision prevented further movement, or resulted in a change of
# direction, then the new rotated velocity is returned. The new velocity may be zero.
# 
# frame_velocity:
#	The velocity vector for the physics frame's motion (without gravity).
# 
# result:
#	The collision information for the collision with an obstacle that happened while moving around
#	the world without factoring in gravity.
func _physics_process_grounded_slope_or_step(frame_velocity: Vector3, result: KinematicCollision) -> Vector3:
	if !result or result.remainder.length_squared() < 0.0001:
		# We're done (this is a recursive method).
		return frame_velocity;
	
	# Check if it's a slope first.
	var up: Vector3 = transform.basis.xform(Vector3.UP);
	var angle: float = rad2deg(up.angle_to(result.normal));
	
	# This extra tolerance is because the physics engine is weird.
	if angle < max_slope_angle + 0.1:
		# This is a slope. If the angle is any larger, then it's a step or wall.
		# It can't be a downwards slope because we hit it.
		var slide_amount: Vector3 = result.remainder - result.remainder.project(result.normal);
		slide_amount = slide_amount.normalized() * result.remainder.length();
		return _physics_process_grounded_slope_or_step(frame_velocity, move_and_collide(slide_amount));
	
	# While this sorta works, step_depth is not fully enforced because the step_height might go
	# over the height of the step! We could do a shape cast to find the height of the step; but,
	# I think this behaviour actually makes more sense. So, really, step_depth (paired with
	# step_height) is only determining the 'max angle' of stairs that can be climbed.
	var step: Vector3 = transform.basis.xform(Vector3.UP * step_height);
	if !test_move(transform, step):
		# We could move upwards the step's height without hitting something...
		var depth: Vector3 = result.remainder.normalized() * step_depth;
		if !test_move(transform.translated(step), depth):
			# We can clear the step fully.
			if result.remainder.length_squared() < depth.length_squared():
				translate(transform.basis.xform_inv(step + result.remainder) / scale);
				return frame_velocity; # No more movement to do.
			else:
				translate(transform.basis.xform_inv(step + depth) / scale);
				return _physics_process_grounded_slope_or_step(frame_velocity, \
					move_and_collide(result.remainder - depth, true, false) \
				);
		#else:
			# We cannot go up this step; as, it's too thin. It acts as a wall.
	
	# If we hit a ceiling, a wall, or a step that was too thin and acts as a wall,
	# then we can move_and_slide on it.
	return move_and_slide(frame_velocity, transform.basis.xform(Vector3.UP));

# _physics_process helper
# 
# Handles movement behaviour when movement_state is within the category represented by
# MoveCategory.SEMI_GROUNDED
func _physics_process_semi_grounded_movement(delta: float) -> void:
	var next_movement_state: int = movement_state;
	var velocity: Vector3 = _get_zero_rotation_velocity(false);
	var frame_velocity: Vector3 = Vector3(velocity.x, velocity.y - (self.gravity * delta), velocity.z);
	# Not sure what the max here would be, so we'll just use whatever it currently is or terminal_velocity.
	frame_velocity.y = clamp(frame_velocity.y, -terminal_velocity, max(-terminal_velocity, frame_velocity.y));
	
	if movement_state == MoveState.JUMPING and frame_velocity.y <= 0.0:
		next_movement_state = MoveState.FALLING;
	elif movement_state == MoveState.FALLING and frame_velocity.y <= -freefall_velocity:
		next_movement_state = MoveState.FREEFALL;
	
	var rotation_amount: float = _get_input_horizontal_rotation_deg(delta);
	if rotation_amount != 0.0:
		_rotate_horizontally(rotation_amount, next_movement_state == MoveState.FREEFALL);
		frame_velocity = frame_velocity.rotated(Vector3.UP, deg2rad(-rotation_amount));
	
	# Allow the user to perform one input's worth of horizontal movement if they are
	# jumping/falling straight up/down. walking_speed * movement_velocity_step is the lowest
	# horizontal speed the user can achieve with a single input. It's standing in for zero here to
	# avoid FLOP errors.
	if _get_zero_rotation_velocity().length() < walking_speed * movement_velocity_step:
		frame_velocity += _get_input_vector();
	
	# Gotta rotate it to match our own rotation.
	frame_velocity = transform.basis.xform(frame_velocity);
	
	var up: Vector3 = transform.basis.xform(Vector3.UP);
	var result: KinematicCollision = move_and_collide(frame_velocity * delta, true, false);
	
	if !result:
		# No collision.
		rotated_velocity = frame_velocity;
	elif transform.basis.xform_inv(frame_velocity).y <= 0.0:
		# Check for ending the fall. If we hit the floor, then transition to IDLE.
		var collision_height: float = to_local(result.position).y;
		if collision_height >= step_height:
			# Bounce off the collision if the body_capsule is the thing that's colliding.
			# For reference, this is like smacking into something with your torso instead
			# of your feet/legs. For the sake of feeling, we'll bounce with half-velocity.
			var new_velocity: Vector3 = frame_velocity.bounce(result.normal) * 0.5;
			rotated_velocity = move_and_slide(new_velocity, up, false, 1, deg2rad(max_slope_angle));
		elif rad2deg(up.angle_to(result.normal)) <= max_slope_angle:
			# We hit the floor.
			rotated_velocity = Vector3.ZERO;
			next_movement_state = MoveState.IDLE;
		else:
			# It's not the floor, so we keep falling on the next frame.
			# For now, slide on the surface?
			var new_direction: Vector3 = (frame_velocity - frame_velocity.project(result.normal)).normalized();
			var new_velocity: Vector3 = new_direction * (result.remainder.length() / delta);
			rotated_velocity = move_and_slide(new_velocity, up, false, 1, deg2rad(max_slope_angle), false);
	else:
		# Implies we hit something while moving upwards.
		if rad2deg(up.angle_to(result.normal)) > 90.01:
			# Hit the ceiling, cut vertical velocity.
			rotated_velocity = frame_velocity - frame_velocity.project(up);
		else:
			# Let's make the jump a little higher by keeping the same scale of velocity.
			var new_velocity = (frame_velocity - frame_velocity.project(result.normal)).normalized();
			rotated_velocity = move_and_slide(new_velocity * (result.remainder / delta).length());
	
	self.movement_state = next_movement_state;

# _physics_process helper
# 
# Handles movement behaviour when movement_state is within the category represented by
# MoveCategory.SEMI_FLIGHT
func _physics_process_semi_flight_movement(delta: float) -> void:
	# Rotate camera if turning inputs are held
	_rotate_horizontally(_get_input_horizontal_rotation_deg(delta), true);
	
	var next_movement_state: int = movement_state;
	var velocity: Vector3 = _get_zero_rotation_velocity(false);
	var frame_velocity: Vector3;
	var top_speed: float = gliding_speed if !_is_held(INPUT_FORWARD) else gliding_fast_speed;
	var forward_velocity: float = \
		move_toward(-velocity.z, top_speed, top_speed * gliding_velocity_step);
	
	# Try to consume any camera-only rotation, if it exists.
	if camera.directional_input.y != 0.0 and camera.movement_type != camera.MoveType.AUTOMATIC:
		var rotation_amount: float = camera.consume_rotation(gliding_rotation_speed * delta);
		_rotate_horizontally(rotation_amount);
		velocity = velocity.rotated(Vector3.UP, deg2rad(rotation_amount));
	
	if _is_any(movement_state, [MoveState.GLIDING_UPDRAFT, MoveState.FLYING_GLIDE_UPDRAFT]):
		var z = move_toward(0.0, velocity.z, gliding_speed * gliding_velocity_step * 0.1);
		frame_velocity = Vector3(0.0, velocity.y - (self.gravity * delta), z);
		
		if frame_velocity.y <= 0.0:
			next_movement_state = MoveState.GLIDING if movement_state == MoveState.GLIDING_UPDRAFT \
				else MoveState.FLYING_GLIDE;
	elif _is_any(movement_state, [MoveState.GLIDING, MoveState.FLYING_GLIDE]):
		if _is_held(INPUT_FORWARD):
			next_movement_state = MoveState.GLIDING_FAST if movement_state == MoveState.GLIDING \
				else MoveState.FLYING_GLIDE_FAST;
			
			# gravity here is actually a velocity.
			var y: float = move_toward(velocity.y, -self.gravity, self.gravity * gliding_velocity_step);
			frame_velocity = Vector3(0.0, y, -forward_velocity);
		elif _can_get_updraft():
			next_movement_state = MoveState.GLIDING_UPDRAFT if movement_state == MoveState.GLIDING \
				else MoveState.FLYING_GLIDE_UPDRAFT;
			
			frame_velocity = _physics_process_get_updraft_velocity(delta);
		else:
			# gravity here is actually a velocity.
			var y: float = move_toward(velocity.y, -self.gravity, self.gravity * gliding_velocity_step);
			frame_velocity = Vector3(0.0, y, -forward_velocity);
	elif _is_any(movement_state, [MoveState.GLIDING_FAST, MoveState.FLYING_GLIDE_FAST]):
		# Same as an else case, really. movement_state couldn't be anything else.
		if !_is_held(INPUT_FORWARD):
			next_movement_state = MoveState.GLIDING if movement_state == MoveState.GLIDING_FAST \
				else MoveState.FLYING_GLIDE;
			
			# gravity here is actually a velocity.
			var y: float = move_toward(velocity.y, -self.gravity, self.gravity * gliding_velocity_step);
			frame_velocity = Vector3(0.0, y, -forward_velocity);
		else:
			var left: bool = _is_held(INPUT_STRAFE_LEFT);
			var right: bool = _is_held(INPUT_STRAFE_RIGHT);
			if (left or right) and left != right:
				var rotation_amount: float = gliding_rotation_speed if left else -gliding_rotation_speed;
				rotation_amount *= delta;
				_rotate_horizontally(rotation_amount, false);
				velocity = velocity.rotated(Vector3.UP, deg2rad(rotation_amount));
			
			# gravity here is actually a velocity.
			var y: float = move_toward(velocity.y, -self.gravity, self.gravity * gliding_velocity_step);
			frame_velocity = Vector3(0.0, y, -forward_velocity);
	else:
		assert(false, "Should not be possible!");
	
	frame_velocity = transform.basis.xform(frame_velocity);
	
	var up: Vector3 = transform.basis.xform(Vector3.UP);
	var result: KinematicCollision = move_and_collide(frame_velocity * delta, true, false);
	
	if !result:
		# No collision.
		rotated_velocity = frame_velocity;
	elif transform.basis.xform_inv(frame_velocity).y <= 0.0:
		# Check for ending the glide. If we hit the floor, bounce or transition to IDLE or FLYING_IDLE.
		var angle: float = up.angle_to(result.normal);
		if angle <= deg2rad(max_slope_angle):
			# We hit the floor.
			# warning-ignore:return_value_discarded
			move_and_slide(frame_velocity, up, false, 1, max_slope_angle);
			if _is_any(movement_state, [MoveState.GLIDING, MoveState.FLYING_GLIDE]) \
			and _can_bounce(frame_velocity, result.normal):
				frame_velocity = frame_velocity - frame_velocity.project(up);
				frame_velocity *= 0.8;
				frame_velocity += up * updraft_velocity * (frame_velocity.length() / gliding_speed);
				rotated_velocity = frame_velocity;
			elif _is_any(movement_state, [MoveState.GLIDING_FAST, MoveState.FLYING_GLIDE_FAST]) \
			and up.angle_to(frame_velocity.project(result.normal)) >= deg2rad(90.0 + min_slope_angle_for_fast_glide):
				# Fast gliding down a slope
				rotated_velocity = move_and_slide(frame_velocity, up, false, 1, max_slope_angle);
			else:
				# End the glide.
				rotated_velocity = Vector3.ZERO;
				if camera.directional_input.y != 0.0 and camera.movement_type != camera.MoveType.AUTOMATIC:
					_rotate_horizontally(camera.consume_rotation());
				next_movement_state = MoveState.FALLING if _is_gliding(false) else MoveState.FLYING_IDLE;
		else:
			# It's not the floor, so we keep gliding on the next frame.
			# For now, slide on the surface?
			var new_direction: Vector3 = (frame_velocity - frame_velocity.project(result.normal)).normalized();
			var new_velocity: Vector3 = new_direction * (result.remainder.length() / delta);
			rotated_velocity = move_and_slide(new_velocity, up, false, 0, deg2rad(max_slope_angle));
	else:
		# Implies we hit something while moving upwards. Clip the vertical velocity out.
		rotated_velocity = frame_velocity - frame_velocity.project(up);
	
	self.movement_state = next_movement_state;

# _physics_process_helper
# 
# Returns the initial velocity of an updraft for the current state of the body. This method is
# only called when an updraft starts; but, can be overriden to change the default behaviour
# of in-air updrafts.
# 
# The returned vector should not be rotated to match the body; that will be handled by the caller.
# Implementations should treat the x, y, and z components of the returned vector as their default
# directions laid out by Godot -- negative x, y, and z are left, down, and forward respectively.
# 
# delta:
#	The time between physics frames, in seconds.
func _physics_process_get_updraft_velocity(_delta: float) -> Vector3:
	var velocity: Vector3 = _get_zero_rotation_velocity(false);
	var forward_velocity: float = \
		move_toward(-velocity.z, gliding_speed, gliding_speed * gliding_velocity_step);
	return Vector3(0.0, updraft_velocity, -forward_velocity);

# _physics_process helper
# 
# Handles movement behaviour when movement_state is within the category represented by
# MoveCategory.FLIGHT
func _physics_process_flight_movement(delta: float) -> void:
	var frame_velocity: Vector3 = _get_input_vector();
	var next_movement_state: int = MoveState.FLYING_IDLE;
	
	if frame_velocity != Vector3.ZERO and frame_velocity.x == 0.0 and frame_velocity.z == 0.0:
		next_movement_state = MoveState.ASCENDING if frame_velocity.y > 0.0 else MoveState.DESCENDING;
	elif frame_velocity != Vector3.ZERO:
		var backwards: bool = _is_held(INPUT_BACKWARD) \
			or (invert_directional_movement and _is_held(INPUT_DIRECTIONAL));
		next_movement_state = MoveState.BACK_FLYING if backwards else MoveState.FLYING;
	
	self.movement_state = next_movement_state;
	_rotate_horizontally(_get_input_horizontal_rotation_deg(delta));
	
	frame_velocity = transform.basis.xform(frame_velocity);
	var result: KinematicCollision = move_and_collide(frame_velocity * delta, true, false);
	if !result:
		# No collision.
		rotated_velocity = frame_velocity;
	elif result.remainder != Vector3.ZERO:
		# There was a collision; and, we could have moved farther.
		# Project frame_velocity onto the plane of collision...
		# The projetion is shorter than the original vector, but I don't want to scale it.
		# Technically, we're letting the user get a little more movement out of this because
		# we're not taking into account the amount they traveled... but whatever. Could make
		# for an interesting mechanic for the technical/advanced users to exploit (unlikely,
		# since delta is fairly small; but, never know).
		var up = transform.basis.xform(Vector3.UP);
		if true \
		or !(movement_state == MoveState.DESCENDING and up.angle_to(result.normal) <= max_slope_angle):
			# Descending onto the floor shouldn't slide; but, that should be handled by the
			# leg_ray_cast, now.
			var slide_velocity: Vector3 = frame_velocity - frame_velocity.project(result.normal);
			rotated_velocity = move_and_slide(slide_velocity, up);

# Handle user input.
func _unhandled_input(event: InputEvent) -> void:
	if !event.is_action_type() and !use_mouse_left_and_right_as_directional_movement:
		return;
	
	# Change to auto run or auto reverse on release. If the controller is currently interrupted,
	# then this will resume when control is returned to us.
	if (event.is_action(INPUT_AUTO_RUN_TOGGLE) or event.is_action(INPUT_AUTO_REVERSE_TOGGLE)) \
	and !event.is_pressed():
		# Interrupt it immediately if a directional input is held.
		var ignore_input: bool = false;
		for dir_input in directional_input_states.keys():
			var input_state = directional_input_states[dir_input];
			if input_state == InputState.HELD \
			and !_is_any(dir_input, [INPUT_ROTATE_LEFT, INPUT_ROTATE_RIGHT, INPUT_JUMP]):
				ignore_input = true;
				break;
		# End for
		
		if !ignore_input:
			var forwards: bool = event.is_action(INPUT_AUTO_RUN_TOGGLE);
			var input_string: String = INPUT_AUTO_RUN_TOGGLE if forwards else INPUT_AUTO_REVERSE_TOGGLE;
			
			# Not checking if they are toggling auto movement off -- it consumes it either way.
			if _should_consume_camera_rotation(input_string):
				_rotate_horizontally(camera.consume_rotation());
			
			var next_state: int = AutoMoveState.FORWARD \
				if forwards else AutoMoveState.BACKWARD;
			
			self.automatic_movement_state = next_state if automatic_movement_state != next_state \
				else AutoMoveState.NONE;
		else:
			# For safety, disable the automatic movement if there is any.
			self.automatic_movement_state = AutoMoveState.NONE;
		return;
	
	# Check for directional input updates, and store them in directional_input_states.
	if event is InputEventMouseButton and use_mouse_left_and_right_as_directional_movement:
		var mb_event: InputEventMouseButton = event as InputEventMouseButton;
		
		if mb_event.button_index == BUTTON_LEFT or mb_event.button_index == BUTTON_RIGHT:
			if Input.is_mouse_button_pressed(BUTTON_LEFT) and Input.is_mouse_button_pressed(BUTTON_RIGHT):
				directional_input_states[INPUT_DIRECTIONAL] = InputState.HELD;
				self.automatic_movement_state = AutoMoveState.NONE;
				
				if _should_consume_camera_rotation(INPUT_DIRECTIONAL):
					_rotate_horizontally(camera.consume_rotation());
			else:
				directional_input_states[INPUT_DIRECTIONAL] = InputState.NONE;
		return;
	
	var directional_input: String = is_directional_input(event, true, false);
	
	if directional_input:
		if !event.is_echo():
			if event.is_pressed() and is_direct_movement_input(event):
				# Don't have to check interrupted; as, if interrupted were true,
				# the automatic_movement_state would already be AutoMoveState.NONE.
				self.automatic_movement_state = AutoMoveState.NONE;
			
			if event.is_pressed() and _should_consume_camera_rotation(directional_input):
				if _is_gliding():
					# Don't rotate self.
					# warning-ignore:return_value_discarded
					camera.consume_rotation();
				else:
					_rotate_horizontally(camera.consume_rotation());
			
			directional_input_states[directional_input] = \
				InputState.HELD if event.is_pressed() else InputState.NONE;
	
	# Check for inputs that are handled directly in this method (instead of in _physics_process).
	# NOTE: If these inputs are visible changes, then interrupted must be false.
	if event.is_action(INPUT_WALK_TOGGLE) and event.is_pressed():
		is_walking = !is_walking;
	
	if event.is_action(INPUT_DIRECTIONAL_ALTITUDE_LOCK_TOGGLE) and event.is_pressed() and !event.is_echo():
		directional_altitude_lock = !directional_altitude_lock;
	
	# The actions below here are directly visible changes.
	if interrupted or !event.is_pressed():
		return;
	
	if event.is_action(INPUT_GLIDE) and !event.is_echo():
		if _is_gliding():
			self.movement_state = MoveState.FLYING_IDLE if _is_any(movement_state, [
					MoveState.FLYING_GLIDE,
					MoveState.FLYING_GLIDE_FAST,
					MoveState.FLYING_GLIDE_UPDRAFT]) \
				else MoveState.FALLING;
		elif _can_glide():
			self.movement_state = MoveState.GLIDING if !_is_flying() else MoveState.FLYING_GLIDE;
	
	if event.is_action(INPUT_TAKEOFF):
		if _can_fly():
			self.movement_state = MoveState.IDLE_TAKEOFF \
				if _is_any(movement_state, [MoveState.IDLE, MoveState.TURNING_LEFT, MoveState.TURNING_RIGHT]) \
				else MoveState.TAKEOFF;
	
	if event.is_action(INPUT_LAND):
		if _is_flying() or _is_gliding():
			self.movement_state = MoveState.FALLING;

# Interrupts the current actions of the controller. interrupted is set to true
# when calling this method; and, as such, needs to be set back to false when the interruption is
# over.
# 
# ignore_currently_held_directional_inputs_until_re_pressed:
#	If true, the currently held directional inputs will be ignored until the user presses them
#	again.
func interrupt(ignore_currently_held_directional_inputs_until_re_pressed: bool = false) -> void:
	if ignore_currently_held_directional_inputs_until_re_pressed:
		for action in directional_input_states.keys():
			if directional_input_states[action] == InputState.HELD:
				directional_input_states[action] = InputState.INTERRUPTED;
		# End for
	
	self.interrupted = true;

# If return_action_string is false,
#	Returns true if the given event is considered a directional input by this controller; otherwise,
#	returns false.
# else,
#	Returns the action string (such as the value of INPUT_JUMP) for the given event, or an empty
#	string if the given event is not associated with a directional input.
# 
# Note that INPUT_DIRECTIONAL is not detectable through this method; and, even if it feels like it
# might be (due to overlap with INPUT_JUMP), INPUT_GLIDE is NOT a directional input.
# 
# While INPUT_AUTO_RUN_TOGGLE and INPUT_AUTO_REVERSE_TOGGLE are directional inputs, it might be
# desired to ignore them in the context of the call to this method. If that is the case, pass false
# for check_auto_toggle.
# 
# event:
#	The InputEvent that may map to a directional input action for this controller.
# 
# return_action_string:
#	Whether or not to return a string or a bool. If true, the string representing the action of the
#	event is returned, if it's a directional input for this controller; otherwise, an empty string
#	is returned; and, if false, a boolean value is returned, instead.
# 
# check_auto_toggle:
#	If false, INPUT_AUTO_RUN_TOGGLE and INPUT_AUTO_REVERSE_TOGGLE will be excluded.
func is_directional_input(event: InputEvent, return_action_string: bool = false, check_auto_toggle: bool = true):
	var directional_actions: Array = [
			INPUT_FORWARD, INPUT_BACKWARD, INPUT_STRAFE_LEFT, INPUT_STRAFE_RIGHT,
			INPUT_ROTATE_LEFT, INPUT_ROTATE_RIGHT,
			INPUT_AUTO_RUN_TOGGLE, INPUT_AUTO_REVERSE_TOGGLE,
			INPUT_JUMP, INPUT_RISE, INPUT_FALL,
	] if check_auto_toggle else [
			INPUT_FORWARD, INPUT_BACKWARD, INPUT_STRAFE_LEFT, INPUT_STRAFE_RIGHT,
			INPUT_ROTATE_LEFT, INPUT_ROTATE_RIGHT,
			INPUT_JUMP, INPUT_RISE, INPUT_FALL,
	];
	
	for action in directional_actions:
		if event.is_action(action):
			return true if !return_action_string else action;
	# End for
	if return_action_string:
		return "";
	
	return false;

# Returns true if event corresponds to any action that is considered a directional input
# with the exception of INPUT_ROTATE_LEFT, INPUT_ROTATE_RIGHT, and INPUT_JUMP.
# 
# The reason those inputs are excluded is that they do not fully control the movement
# associated with their states. This is the same reason they do not interrupt automatic
# movement, as well.
# 
# event:
#	The InputEvent that may potentially match a directional input for this movement controller.
func is_direct_movement_input(event: InputEvent) -> bool:
	var action: String = is_directional_input(event, true);
	if action:
		return !_is_any(action, [INPUT_ROTATE_LEFT, INPUT_ROTATE_RIGHT, INPUT_JUMP]);
	
	return false;

# Determines if the movement controller should apply gravity while the movement_state is
# MoveState.IDLE.
# 
# By default, this method merely returns false -- override it to change this behaviour.
func _check_gravity_while_idle() -> bool:
	return false;

# Helper method to determine when the user can glide.
# 
# By default, the user can glide under any circumstance in which they are falling or flying.
# Override this method to change this behaviour.
func _can_glide() -> bool:
	return _is_any(movement_state, [
		MoveState.FALLING, MoveState.FREEFALL,
		MoveState.FLYING_IDLE, MoveState.FLYING, MoveState.BACK_FLYING,
		MoveState.ASCENDING, MoveState.DESCENDING,
	]);

# Determines when the user can achieve an updraft while movement_state is MoveState.GLIDING or
# MoveState.FLYING_GLIDE for the current physics frame.
# 
# By default, this method merely returns false -- override it to change this behaviour.
func _can_get_updraft() -> bool:
#	Example implementation.
#	var up: Vector3 = transform.basis.xform(Vector3.UP);
#	var velocity: Vector3 = rotated_velocity;
#	var horizontal_speed: float = (velocity - velocity.project(up)).length();
#	return randi() % 1000 == 500 and horizontal_speed > 0.75 * gliding_speed;
	return false;

# Determines if the user can bounce off the floor while gliding.
# 
# By default, this method merely returns false -- override it to change this behaviour.
func _can_bounce(_velocity: Vector3, _floor_normal: Vector3) -> bool:
#	Example implementation
#	var up: Vector3 = transform.basis.xform(Vector3.UP);
#	var slide_direction: Vector3 = velocity - velocity.project(floor_normal);
#	var angle: float = up.angle_to(slide_direction);
#	var horizontal_speed: float = (velocity - velocity.project(up)).length();
#	var bounce: bool = angle >= PI * 0.5 and horizontal_speed >= gliding_speed * 0.9 \
#		and velocity.project(up).length() <= glide_gravity;
#
#	if bounce and abs(angle - (PI * 0.5)) < 0.001:
#		bounce = _can_get_updraft();
#
#	return bounce;
	return false;

# Helper method to determine when the user can fly. This method is intending to inform the caller
# when the user can enter MoveState.IDLE_TAKEOFF, or MoveState.TAKEOFF; however, if
# via_input_takeoff is false, then this method will also return true if the user can transition
# back to flight from one of the FLYING_GLIDE variants.
# 
# By default, the user can fly under any circumstance in which they are not already flying
# or gliding. Override this method to change this behaviour.
# 
# via_input_takeoff:
#	Whether or not this method should return true from the perspective of the user entering flight
#	from a grounded state (true), or from a FLYING_GLIDE variant (false).
func _can_fly(via_input_takeoff: bool = true) -> bool:
	return !_is_gliding(via_input_takeoff) and !_is_flying();

# Helper method to determine when the user is gliding. If include_flying_glide is true,
# the alternate form of gliding that reverts to flying when it ends will be included in the check.
# 
# By default, the user is considered to be gliding when movement_state is any of the following:
#	MoveState.GLIDING, MoveState.GLIDING_FAST, or MoveState.GLIDING_UPDRAFT;
# and, if include_flying_glide is true, any of the following states will also be included:
#	MoveState.FLYING_GLIDE, MoveState.FLYING_GLIDE_FAST, or MoveState.FLYING_GLIDE_UPDRAFT.
# Override this method to change this behaviour.
# 
# include_flying_glide:
#	Whether or not to include the FLYING_GLIDE variants within the check. The default is true,
#	as this behaviour is generally desired.
func _is_gliding(include_flying_glide: bool = true) -> bool:
	return _is_any(movement_state, [
		MoveState.GLIDING, MoveState.GLIDING_FAST, MoveState.GLIDING_UPDRAFT,
		MoveState.FLYING_GLIDE, MoveState.FLYING_GLIDE_FAST, MoveState.FLYING_GLIDE_UPDRAFT,
	]) if include_flying_glide == true else _is_any(movement_state, [
		MoveState.GLIDING, MoveState.GLIDING_FAST, MoveState.GLIDING_UPDRAFT,
	]);

# Helper method to determine when the user is flying.
# 
# By default, the user is considered to be flying when movement_state is any of the following:
#	MoveState.IDLE_TAKEOFF, MoveState.TAKEOFF,
#	MoveState.FLYING_IDLE, MoveState.FLYING, MoveState.BACK_FLYING,
#	MoveState.ASCENDING, or MoveState.DESCENDING.
# Override this method to change this behaviour.
func _is_flying() -> bool:
	return _is_any(movement_state, [
		MoveState.IDLE_TAKEOFF, MoveState.TAKEOFF,
		MoveState.FLYING_IDLE, MoveState.FLYING, MoveState.BACK_FLYING,
		MoveState.ASCENDING, MoveState.DESCENDING,
	]);

# Rotates this node, or the camera node via setting its horizontal_rotation, by the amount
# specified by rotation_deg.
# 
# This is also the signal method for the camera's horizontal_rotation_change signal. If
# from_signal is true, then the rotation will be handled from the perspective that the rotation
# is coming from the user's rotation of the camera instead of any movement inputs.
# 
# Otherwise, the rotation will be handled based on the value of camera_only and interrupted. If
# either are true, then only the camera will be rotated; otherwise, this node will be rotated
# instead.
# 
# rotation_deg:
#	The rotation amount, in degrees. Leftwards rotation is positive.
# 
# camera_only:
#	If true, the camera is rotated instead of this node.
# 
# from_signal:
#	If true, it's assumed that this method was triggered by the camera's horizontal_rotation_change
#	signal. Manual calls of this method should pass false for this parameter.
func _rotate_horizontally(rotation_deg: float, camera_only: bool = false, from_signal: bool = false) -> void:
	if rotation_deg == 0.0:
		return;
	
	if interrupted:
		if (from_signal and !camera_only) or !from_signal:
			camera.horizontal_rotation += rotation_deg;
	elif from_signal:
		if camera_only:
			# Independent/modified rotation
			if _is_held(INPUT_DIRECTIONAL):
				# Rotate self, undo camera's rotation.
				rotate(transform.basis.xform(Vector3.UP), deg2rad(rotation_deg));
				camera.horizontal_rotation -= rotation_deg;
				camera.last_rotation_was_left = !camera.last_rotation_was_left;
			# No else case; camera handled it already.
		elif _is_gliding() or movement_state == MoveState.FREEFALL:
			# Camera only
			camera.horizontal_rotation += rotation_deg;
		elif _should_camera_rotation_rotate_body():
			# Rotate self
			rotate(transform.basis.xform(Vector3.UP), deg2rad(rotation_deg));
			camera.last_rotation_was_left = sign(rotation_deg) > 0.0;
		else:
			# Camera only
			camera.horizontal_rotation += rotation_deg;
	elif camera_only:
		# Camera only
		camera.horizontal_rotation += rotation_deg;
	else:
		# Rotate self
		rotate(transform.basis.xform(Vector3.UP), deg2rad(rotation_deg));
		camera.last_rotation_was_left = sign(rotation_deg) > 0.0;

# Checks if any directional input that would cause camera rotation to rotate the body are
# currently being held according to directional_input_states, and returns true if so.
func _should_camera_rotation_rotate_body() -> bool:
	return _is_any(true, [
		_is_held(INPUT_FORWARD), _is_held(INPUT_BACKWARD), _is_held(INPUT_DIRECTIONAL),
		_is_held(INPUT_STRAFE_LEFT), _is_held(INPUT_STRAFE_RIGHT),
		# INPUT_ROTATE_LEFT and INPUT_ROTATE_RIGHT would be treated as their
		# INPUT_STRAFE_LEFT and INPUT_STRAFE_RIGHT counterparts in this context.
		_is_held(INPUT_ROTATE_LEFT), _is_held(INPUT_ROTATE_RIGHT)
	]);

# Returns whether or not the given input_string maps to an input that consumes the camera's
# rotation. In general, almost all of the directional inputs do.
# 
# input_string:
#	One of the INPUT_ variables.
func _should_consume_camera_rotation(input_string: String) -> bool:
	return movement_state != MoveState.FREEFALL \
	and _is_any(input_string, [
		INPUT_FORWARD, INPUT_BACKWARD, INPUT_DIRECTIONAL,
		INPUT_STRAFE_LEFT, INPUT_STRAFE_RIGHT, INPUT_ROTATE_LEFT, INPUT_ROTATE_RIGHT,
		INPUT_AUTO_RUN_TOGGLE, INPUT_AUTO_REVERSE_TOGGLE,
	]) \
	or (input_string == INPUT_JUMP and !_is_any(movement_state, [
		MoveState.IDLE, MoveState.FLYING_IDLE
	]));

# Returns the Y-axis rotation over the given delta time (in seconds) for the current user inputs.
# To avoid large rotations happening in one moment, delta values above 0.1 are treated as if
# they are 0.1.
# 
# Negative values for delta produce undefined behaviour.
# 
# delta:
#	The amount of time, in seconds, to rotate for. Values above 0.1 are reduced to 0.1.
func _get_input_horizontal_rotation_deg(delta: float) -> float:
	if camera.is_under_user_control():
		# The camera is being rotated by the user, rotate keybinds are treated as strafe.
		return 0.0;
	
	# Using min to prevent lag from moving the camera in large amounts at once.
	var camera_rotation: float = rotation_speed * min(delta, 0.1);
	var rotate_left: bool = _is_held(INPUT_ROTATE_LEFT);
	var rotate_right: bool = _is_held(INPUT_ROTATE_RIGHT);
	
	if rotate_left != rotate_right:
		if rotate_right:
			camera_rotation *= -1.0;
		return camera_rotation;
	
	return 0.0;

# Pulls the current velocity from the velocity vector and removes any rotation from it.
# If horizontal_only is true, then the vertical portion of the velocity is removed.
# 
# horizontal_only:
#	If true, the returned velocity is only the portion along the xz plane.
func _get_zero_rotation_velocity(horizontal_only: bool = true) -> Vector3:
	var zero_rotation_velocity: Vector3 = transform.basis.xform_inv(rotated_velocity);
	if horizontal_only:
		zero_rotation_velocity.y = 0.0;
	return zero_rotation_velocity;

# Creates and returns a vector representing the movement direction of the user's input. The
# returned vector is not rotated to match the current state of this body; but, it is rotated to
# match the camera; and, it is already scaled based on the top speed of the current movement_state.
# Depending on the usage, the returned vector may need to be multiplied by the frame delta.
func _get_input_vector() -> Vector3:
	var input: Vector3 = Vector3.ZERO;
	
	if _is_held(INPUT_FORWARD) or automatic_movement_state == AutoMoveState.FORWARD:
		input += Vector3.FORWARD;
	
	if _is_held(INPUT_BACKWARD) or automatic_movement_state == AutoMoveState.BACKWARD:
		input += Vector3.BACK;
	
	if _is_held(INPUT_DIRECTIONAL):
		input += Vector3.FORWARD if !invert_directional_movement else Vector3.BACK;
	
	if _is_held(INPUT_STRAFE_LEFT):
		input += Vector3.LEFT;
	
	if _is_held(INPUT_STRAFE_RIGHT):
		input += Vector3.RIGHT;
	
	if camera.is_under_user_control():
		if _is_held(INPUT_ROTATE_LEFT):
			input += Vector3.LEFT;
		if _is_held(INPUT_ROTATE_RIGHT):
			input += Vector3.RIGHT;
	
	if _is_flying():
		if _is_held(INPUT_RISE) and !_is_held(INPUT_FALL):
			input += Vector3.UP;
		
		# Apply camera vertical rotation if needed.
		# INPUT_RISE rotates with the camera when moving; but, INPUT_FALL does not (weird).
		if !directional_altitude_lock and (input.x != 0.0 or input.z != 0.0):
			input = input.rotated(Vector3.RIGHT, deg2rad(camera.directional_input.x));
		
		if _is_held(INPUT_FALL) and !_is_held(INPUT_RISE):
			input += Vector3.DOWN;
	
	var speed_multiplier: float = 1.0;
	if input.z > 0.0:
		speed_multiplier = backwards_movement_speed_percentage;
	elif input.z == 0.0:
		speed_multiplier = strafe_movement_speed_percentage;
	
	# Apply speed scalar.
	return _scale_input_vector(input, speed_multiplier);

# Scales the given input to match the currently available top speed and returns it.
# 
# input:
#	The input vector to scale.
# 
# total_speed_multiplier:
#	A multiplier of the top speed to apply during the calculation of the speed scalar.
func _scale_input_vector(input: Vector3, total_speed_multiplier: float = 1.0) -> Vector3:
	if input == Vector3.ZERO:
		return input;
	
	var top_speed: float;
	var velocity_step_multiplier: float = movement_velocity_step;
	var current_speed: float = _get_zero_rotation_velocity(!_is_flying()).length();
	
	if !_is_flying() and !_is_gliding():
		# Grounded or Semi-Grounded.
		top_speed = walking_speed if is_walking else running_speed;
	elif _is_flying():
		top_speed = flying_speed;
	else: # Gliding
		top_speed = gliding_speed;
		velocity_step_multiplier = gliding_velocity_step;
	
	top_speed *= total_speed_multiplier;
	return input.normalized() * move_toward(current_speed, top_speed, top_speed * velocity_step_multiplier);

# Checks if the movement_state corresponds to the given MoveCategory constant represented by
# category; and, returns true if so; false otherwise.
# 
# For the sake of this method, as they are not represented within the main movement categories,
# MoveState.IDLE_TAKEOFF, and MoveState.TAKEOFF are considered to be within MoveCategory.FLIGHT.
# 
# category:
#	A MoveCategory constant.
func _is_in_move_category(category: int) -> bool:
	if category == MoveCategory.GROUNDED:
		return _is_any(movement_state, [
			MoveState.IDLE, MoveState.WALKING, MoveState.BACK_WALKING,
			MoveState.RUNNING, MoveState.BACK_RUNNING,
			MoveState.TURNING_LEFT, MoveState.TURNING_RIGHT
		]);
	elif category == MoveCategory.SEMI_GROUNDED:
		return _is_any(movement_state, [
			MoveState.JUMPING, MoveState.FALLING, MoveState.FREEFALL
		]);
	elif category == MoveCategory.SEMI_FLIGHT:
		return _is_any(movement_state, [
			MoveState.GLIDING, MoveState.GLIDING_FAST, MoveState.GLIDING_UPDRAFT,
			MoveState.FLYING_GLIDE, MoveState.FLYING_GLIDE_FAST, MoveState.FLYING_GLIDE_UPDRAFT
		]);
	elif category == MoveCategory.FLIGHT:
		return _is_any(movement_state, [
			MoveState.IDLE_TAKEOFF, MoveState.TAKEOFF,
			MoveState.FLYING_IDLE, MoveState.FLYING, MoveState.BACK_FLYING,
			MoveState.ASCENDING, MoveState.DESCENDING
		]);
	else:
		return false;

# Checks directional_input_states to determine if the given input_string corresponds to
# InputState.HELD, and returns true if so; false otherwise.
# 
# input_string:
#	One of the INPUT_ variables.
func _is_held(input_string: String) -> bool:
	if directional_input_states.has(input_string):
		return directional_input_states[input_string] == InputState.HELD;
	return false;

# Helper method to match value to any indexed member of the matches array. Returns true if value
# was found within the matches array; false otherwise.
# 
# value: any
#	A value to check for within matches
# 
# matches:
#	An array containing values that may be equal to value.
static func _is_any(value, matches: Array) -> bool:
	for val in matches:
		if val == value:
			return true;
	# End for
	return false;

# Setter for rotation_speed.
# 
# Also sets the automatic_rotation_speed of the camera.
# 
# rotation_speed_:
#	The new value for rotation_speed, and the camera's automatic_rotation_speed.
func _set_rotation_speed(rotation_speed_: float) -> void:
	rotation_speed = rotation_speed_;
	camera.automatic_rotation_speed = rotation_speed;

# Getter for gravity.
# 
# While the movement_state is MoveState.JUMPING, the value returned by this will be scaled to
# match jump_gravity.
# 
# While gliding, the value returned will by this will be scaled to match glide_gravity.
func _get_gravity() -> float:
	if movement_state == MoveState.JUMPING:
		return jump_gravity;
	
	if _is_gliding():
		return glide_gravity \
			if !_is_any(movement_state, [MoveState.GLIDING_UPDRAFT, MoveState.FLYING_GLIDE_UPDRAFT]) \
			else updraft_gravity;
	
	return gravity;

# Would be the getter for movement_category, if it were present. Instead, checks each category
# and returns the one the controller is currently in.
func _get_movement_category() -> int:
	if _is_in_move_category(MoveCategory.GROUNDED):
		return MoveCategory.GROUNDED;
	elif _is_in_move_category(MoveCategory.SEMI_GROUNDED):
		return MoveCategory.SEMI_GROUNDED;
	elif _is_in_move_category(MoveCategory.SEMI_FLIGHT):
		return MoveCategory.SEMI_FLIGHT;
	else: #_is_in_move_category(MoveCategory.FLIGHT):
		return MoveCategory.FLIGHT;

# The setter for movement_state.
# 
# If the new movement category is MoveCategory.FLIGHT, then the feet_box collision is disabled;
# otherwise, it will be re-enabled if use_default_collision is true.
# 
# next_movement_state:
#	The value to change movement_state to. This should be one of the MoveState enum constants.
func _set_movement_state(next_movement_state: int) -> void:
	if movement_state == next_movement_state:
		# Nothing changed.
		return;
	
	if _is_any(next_movement_state, [MoveState.IDLE_TAKEOFF, MoveState.TAKEOFF]):
		interrupt();
	
	emit_signal("movement_state_change", next_movement_state);
	movement_state = next_movement_state;
	
	feet_box.disabled = !use_default_collision or _is_in_move_category(MoveCategory.FLIGHT);

# The setter for use_default_collision.
# 
# Enables or disables the default collision as necessary.
# 
# use_default_collision_:
#	The new value to set use_default_collision to.
func _set_use_default_collision(use_default_collision_: bool) -> void:
	use_default_collision = use_default_collision_;
	
	body_capsule.disabled = !use_default_collision;
	leg_ray_cast.enabled = use_default_collision;
	feet_box.disabled = !use_default_collision or _is_in_move_category(MoveCategory.FLIGHT);

# Setter for interrupted.
# 
# If the current movement_state is MoveState.IDLE_TAKEOFF, or MoveState.TAKEOFF, then it will
# progress to MoveState.FLYING_IDLE if interrupted_ is false.
# 
# interrupted_:
#	The new value for interrupted.
func _set_interrupted(interrupted_: bool) -> void:
	interrupted = interrupted_;
	
	if interrupted:
		self.automatic_movement_state = AutoMoveState.NONE;
	
	if !interrupted and _is_any(movement_state, [MoveState.IDLE_TAKEOFF, MoveState.TAKEOFF]):
		self.movement_state = MoveState.FLYING_IDLE;
