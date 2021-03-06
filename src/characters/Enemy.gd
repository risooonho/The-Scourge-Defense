extends Character

class_name Enemy

signal speed_changed(speed, max_speed)
signal dead

var SPEED
var MAX_SPEED

const JUMP_DURATION = 1.0
const MAX_JUMP_HEIGHT = 100
const MAX_KNOCKBACK_HEIGHT = -10

var ATTACK_DIST = 30
var PYLON_ATTACK_DIST = 150
var CHASE_DIST = 250
var PYLON_CHASE_DIST = 350
var prev_jump_height = 100
var jump_vel = 0
var jump_pos = 0
var pos_before_knockback
#var _collision_normal = Vector2()
#var _last_input_direction = Vector2()

onready var anim_player = $AnimationPlayer
onready var tween = $Tween
onready var zombie_resource = preload("res://src/characters/TurnedZombie.tscn")

func _init():
	max_hp = 3
	SPEED = {
		STATES.IDLE: Vector3(0, 0, 0),
		STATES.RUN: Vector3(60, 30, 100),
		STATES.JUMP: Vector3(200, 100, 100),
		STATES.ROLL: Vector3(500, 250, 100),
		STATES.CHASE: Vector3(120, 60, 100),
	}
	
	MAX_SPEED = {
		STATES.RUN: Vector3(200, 100, 100),
		STATES.JUMP: Vector3(200, 100, 100),
		STATES.ROLL: Vector3(500, 250, 100),
	}
	
	_transitions = {
		[STATES.IDLE, EVENTS.RUN]: STATES.RUN,
		[STATES.CHASE, EVENTS.RUN]: STATES.RUN,
		[STATES.IDLE, EVENTS.ATTACK]: STATES.ATTACK,
		[STATES.IDLE, EVENTS.CHASE]: STATES.CHASE,
		[STATES.RUN, EVENTS.IDLE]: STATES.IDLE,
		
		[STATES.IDLE, EVENTS.HURT]: STATES.HURT,
		[STATES.RUN, EVENTS.HURT]: STATES.HURT,	
		[STATES.CHASE, EVENTS.HURT]: STATES.HURT,	
		[STATES.ATTACK, EVENTS.HURT]: STATES.HURT,	
		[STATES.HURT, EVENTS.HURT_END]: STATES.IDLE,

		[STATES.IDLE, EVENTS.DIE]: STATES.DIE,
		[STATES.RUN, EVENTS.DIE]: STATES.DIE,	
		[STATES.ATTACK, EVENTS.DIE]: STATES.DIE,	
		[STATES.HURT, EVENTS.DIE]: STATES.DIE,
		[STATES.CHASE, EVENTS.DIE]: STATES.DIE,	

		[STATES.RUN, EVENTS.CHASE]: STATES.CHASE,	
		
		[STATES.IDLE, EVENTS.KNOCKED_DOWN]: STATES.KNOCKED_DOWN,
		[STATES.RUN, EVENTS.KNOCKED_DOWN]: STATES.KNOCKED_DOWN,	
		[STATES.ATTACK, EVENTS.KNOCKED_DOWN]: STATES.KNOCKED_DOWN,	
		[STATES.HURT, EVENTS.KNOCKED_DOWN]: STATES.KNOCKED_DOWN,	
		[STATES.KNOCKED_DOWN, EVENTS.GET_UP]: STATES.IDLE,		
		
		[STATES.IDLE, EVENTS.ATTACK]: STATES.ATTACK,
		[STATES.RUN, EVENTS.ATTACK]: STATES.ATTACK,	
		[STATES.CHASE, EVENTS.ATTACK]: STATES.ATTACK,	
		[STATES.ATTACK, EVENTS.ATTACK_END]: STATES.IDLE,	
		
#		[STATES.FALL, EVENTS.LAND]: STATES.IDLE,			
	}
	base_damage = 1
	instance_name = "enemy"	



func _ready():
	change_target(Util.primary_target)
	health.setup(self)
	_state = STATES.IDLE
	_speed = SPEED[_state]
#	connect("speed_changed", $DirectionVisualizer, "_on_Move_speed_changed")

func _physics_process(delta):
#	var slide_count = get_slide_count()
#	_collision_normal = get_slide_collision(slide_count - 1).normal if slide_count > 0 else _collision_normal
	if current_target == null or !current_target_wr.get_ref():
		change_target(null)
	if global_position.distance_to(Util.primary_target.global_position) < CHASE_DIST:
		change_target(Util.primary_target)
	if frozen_duration > 0.0:
#		match _state: # before being frozen
#			STATES.HURT:
#				sprite.play("hurt")
#				sprite.set_frame(0)
		
		sprite._set_playing(false)
		if _state != STATES.ATTACK:
			yield(get_tree().create_timer(frozen_duration), "timeout")
		sprite._set_playing(true)
		frozen_duration = 0.0

		match _state: # after being frozen
			STATES.HURT, STATES.DIE, STATES.KNOCKED_UP:
				if _state == STATES.DIE:
					sprite.play("die")
					$Sounds/DeathSound.play()
				elif _state == STATES.KNOCKED_UP:
					knock_up()
					sprite.play("hurt")
				elif _state == STATES.HURT:
					$Timers/TargetResetTimer.start()
					knock_up() #TODO REMOVE THIS					
					sprite.play("hurt")
				if not $Sounds/HurtSound.is_playing():
					$Sounds/HurtSound.play()
				$HurtAnimationPlayer.play("hurt")
				if last_damaged_by_wr.get_ref() and last_damaged_by.instance_name == "player":
					if not last_damaged_by.is_flipped:#ie player is at left
						_velocity.x = KNOCKBACK_LENGTH
					else:
						_velocity.x = -KNOCKBACK_LENGTH
					last_damaged_by.camera_shake.start(0, 0.2, 15.0 , 5)
			STATES.ATTACK:
				$Timers/AttackCDTimer.start()
				$Sounds/AttackSound.play()
				
	var event = get_event()
	
	change_state(event)
	
	match _state: #match for velocity
		STATES.RUN:
			_dir = Vector2.LEFT
			continue
		STATES.CHASE:
			if (is_flipped and is_facing(current_target)) or (not is_flipped and not is_facing(current_target)) and abs(global_position.x - current_target.global_position.x) > 20:
				_dir.x = 1
			elif abs(global_position.x - current_target.global_position.x) > 20:
				_dir.x = -1				
			else:
				_dir.x = 0
			
			if current_target != Util.current_pylon:
				var temp_dist = abs(global_position.y - current_target.global_position.y)
				if global_position.y < current_target.global_position.y and temp_dist > 20:
					_dir.y = 1
				elif global_position.y > current_target.global_position.y and temp_dist > 20:
					_dir.y = -1				
				else:
					_dir.y = 0
			else:
				_dir.y = 0
			#_velocity *= 1.2
			continue
		STATES.JUMP, STATES.RUN, STATES.ROLL, STATES.CHASE:
			_velocity.x = _speed.x * _dir.x
			_velocity.y = _speed.y * _dir.y
			continue
		STATES.JUMP, STATES.HURT, STATES.DIE:
			pass

	match _state: #match for flipping
		STATES.IDLE:
			pass
		STATES.CHASE, STATES.ATTACK:
			if current_target != null and current_target_wr.get_ref():
				flip(global_position.x > current_target.global_position.x)
		STATES.HURT, STATES.DIE:
			flip(_velocity.x > 0)
		_:
			flip(_velocity.x < 0)
			
	if is_flipped:
		sprite.set_offset(Vector2(-10,0))
	else:
		sprite.set_offset(Vector2(0,0))

	match _state: #match for movement
		STATES.DIE, STATES.ATTACK:
			pass
		_:
			move_and_slide(_velocity)



func _set_speed(value):
	if _speed == value:
		return
	_speed = value
	emit_signal("speed_changed", _speed, SPEED[STATES.RUN])

func enter_state():
	$StateLabel.text = _state
	
	match _state:
		STATES.IDLE:
			sprite.play("idle")
			continue
		STATES.ROLL, STATES.RUN, STATES.CHASE:
			_speed = SPEED[_state]
			continue
		STATES.ROLL:
			sprite.position.y = 18
			sprite.play("roll")
		STATES.RUN, STATES.CHASE:
			sprite.play("run")
		STATES.ATTACK:
			$Sounds/AttackSound.play()
			sprite.play("attack")
		STATES.JUMP:
			sprite.play("jump")
			tween.interpolate_method(self, "animate_jump", 0, 1, JUMP_DURATION, Tween.TRANS_LINEAR, Tween.EASE_IN)
			tween.start()
		STATES.HURT, STATES.KNOCKED_UP:
			if frozen_duration == 0.0:
				frozen_duration = BASE_FREEZE_DURATION			
	
#			var temp = -40
#			#TODO make better knockback
#			_velocity.x *= temp
#			move_and_slide(_velocity, Vector2(0, -1))
#			_velocity.x /= tem
		STATES.DIE:
			frozen_duration = BASE_FREEZE_DURATION

func get_event():
	"""
	Converts the player's input to events. The state machine
	uses these events to trigger transitions from one state to another.
	"""
	var event = EVENTS.INVALID
#	if not $Timers/StunnedTimer.is_stopped():
#		return EVENTS.IDLE

	if not $Timers/AttackCDTimer.is_stopped():
		return EVENTS.IDLE
		
	if current_target == null or not current_target_wr.get_ref():
		return EVENTS.RUN
		
	var temp_dist = global_position.distance_to(current_target.global_position)
	var temp_dist_x = abs(global_position.x - current_target.global_position.x)
	if temp_dist < ATTACK_DIST:# and is_facing(current_target):
		event = EVENTS.ATTACK
	elif current_target == Util.primary_target and temp_dist_x < PYLON_ATTACK_DIST:
		event = EVENTS.ATTACK
	elif temp_dist < CHASE_DIST:
		event = EVENTS.CHASE
	elif current_target == Util.primary_target and temp_dist_x < PYLON_CHASE_DIST:
		event = EVENTS.CHASE
	else:
		event = EVENTS.RUN

	return event

func is_facing(target):
	return false

func _on_AnimatedSprite_animation_finished():
	match sprite.animation:
		"attack":
			change_state(EVENTS.ATTACK_END)
		"roll":
			sprite.position.y = 0		
			change_state(EVENTS.ROLL_END)
		"die":
			emit_signal("dead", self)
			queue_free()

func _on_Tween_tween_completed(object, key):
	print("KEY is ", key)
	match key:
		":animate_jump":
			prev_jump_height = 100
			change_state(EVENTS.LAND)
	
	if key == ":animate_knock_up":
		change_state(EVENTS.KNOCKED_UP_END)

func search_nearest_target():
	pass

func animate_knock_up(progress):
	var max_height = 50
	var knockback_height = (max_height) * pow(sin(progress * PI), 0.7)
	var shadow_scale = 1.0 - (knockback_height/max_height * 0.1)
	
	sprite.position.y = -knockback_height
	shadow_sprite.scale = Vector2(shadow_scale, shadow_scale) * current_shadow_scale

func animate_knock_down(progress):
	var max_height = 20
	var knockback_height = (max_height) * pow(sin(progress * PI), 0.9)
	var shadow_scale = 1.0 - (knockback_height/max_height * 0.1)
	
	sprite.position.y = pos_before_knockback.y - knockback_height
	shadow_sprite.scale = Vector2(shadow_scale, shadow_scale) * current_shadow_scale
	print ("POS Y IS NOW ", sprite.position.y)
	
func animate_jump(progress):
	var jump_height
	jump_height = MAX_JUMP_HEIGHT * pow(sin(progress * PI), 0.7)
	var shadow_scale = 1.0 - (jump_height/MAX_JUMP_HEIGHT * 0.5)
	
	sprite.position.y = -jump_height
	shadow_sprite.scale = Vector2(shadow_scale, shadow_scale) * current_shadow_scale

func knock_up():
	var kn_duration = 0.7
	pos_before_knockback = sprite.position
	$Tween.interpolate_method(self,"animate_knock_up", 0, 1, kn_duration,Tween.TRANS_LINEAR, Tween.EASE_IN)
	$Tween.start()

func knock_down():
	var kn_duration = 0.1
#	$Tween.interpolate_property(sprite, "position", temp, Vector2(temp.x, 0), kn_duration, Tween.TRANS_LINEAR, Tween.EASE_IN)
	$Tween.interpolate_method(self,"animate_knock_down", 0.5, 1, kn_duration,Tween.TRANS_LINEAR, Tween.EASE_IN)
	$Tween.start()	
	
func _on_has_turned():
	var zombie = zombie_resource.instance()
	emit_signal("dead", self)
	print("TURNING")
	zombie.global_position = global_position
	get_parent().call_deferred("add_child", zombie)
	queue_free() #TODO change state to turned

func _on_HurtAnimationPlayer_animation_finished(anim_name):
	if anim_name == "hurt" and _state != STATES.KNOCKED_UP:
		change_state(EVENTS.HURT_END)
	
func _on_AnimatedSprite_frame_changed():
	match sprite.animation:
		"run":
			hitboxes.get_node("BasicAttackHitbox").disable()
		"attack":
			match sprite.get_frame():
				2:
					hitboxes.get_node("BasicAttackHitbox").enable()
				4:
					hitboxes.get_node("BasicAttackHitbox").disable()

func _on_TargetResetTimer_timeout():
	change_target(Util.primary_target)
	has_been_attacked = false
