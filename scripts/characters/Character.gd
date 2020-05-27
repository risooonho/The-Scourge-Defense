extends KinematicBody2D

class_name Character

signal state_changed(state)

var STATES = {
	IDLE = "IDLE",
	RUN = "RUN",
	HURT = "HURT",
	KNOCKED_DOWN = "KNOCKED DOWN",
	DIE = "DIE",
	#player only
	ATTACK_PUNCH = "ATTACK PUNCH",
	ATTACK_AIR_KICK = "ATTACK AIR KICK",
	JUMP = "JUMP",
	ROLL = "ROLL",
	CASTING_TURNING_SPELL = "TURNING SPELL",

	#zombies only
	CHASE = "CHASE",
	ATTACK = "ATTACK",
}

var EVENTS = {
	INVALID = "EVENT INVALID",
	IDLE = "EVENT IDLE",
	RUN = "EVENT RUN",
	ATTACK = "EVENT ATTACK",
	ATTACK_END = "EVENT ATTACK_END",
	HURT = "EVENT HURT",
	HURT_END = "EVENT HURT_END",
	KNOCKED_DOWN = "EVENT KNOCKED DOWN",
	GET_UP = "EVENT GET_UP",
	#player only
	JUMP = "EVENT JUMP",
	ROLL = "EVENT ROLL",
	ROLL_END = "EVENT ROLL_END",
	LAND = "EVENT LAND",
	CASTING_TURNING_SPELL = "EVENT CAST",
	CASTING_SPELL_END = "EVENT CAST END",
	DIE = "EVENT DIE",
	CHASE = "EVENT CHASE",
}

export var instance_name = "sample"
onready var hurt_timer = $Timers/HurtTimer
onready var frozen_timer = $Timers/FrozenTimer
onready var stunned_timer = $Timers/StunnedTimer
onready var timers = $Timers


var current_target = null
var has_been_attacked = false

var is_flipped = false
var is_alive = true

var base_damage = 0
var last_damaged_by
var KNOCKBACK_LENGTH = 90
const BASE_FREEZE_DURATION = 0.1
var frozen_duration = 0.0

var _state = "idle"
var _speed = 0
var _max_speed = 0
var _dir = Vector2(1,0)
var _velocity = Vector2.ZERO
var _air_velocity = Vector2.ZERO
var current_sprite_scale
var current_shadow_scale

var _transitions = {}
var hp = 3
var max_hp = 10000
var current_scale

var prev_state = "IDLE"
var prev_event = "EVENT INVALID"

onready var body = $Body
onready var sprite = $Body/AnimatedSprite
onready var hitboxes = $Body/AnimatedSprite/Hitboxes
onready var hurtboxes = $Body/AnimatedSprite/Hurtboxes
onready var hurt_anim_player = $AnimationPlayer/HurtAnimationPlayer
onready var shadow_sprite = $ShadowSprite

func _ready():
	current_scale = scale
	current_sprite_scale = sprite.scale
	current_shadow_scale = shadow_sprite.scale
	hp = max_hp
	for hurtbox in hurtboxes.get_children():
		hurtbox.setup(self)
		
	for hitbox in hitboxes.get_children():
		hitbox.setup(self)
	
	for timer in timers.get_children():
		if timer.has_method("setup"):
			timer.setup(self)
			
	#connect("state_changed", $StateLabel, "_on_Character_state_changed")

func enter_state():
	pass

func change_state(event):
	var transition = [_state, event]
	if not transition in _transitions:
		return
	
	prev_state = _state
	prev_event = event

	_state = _transitions[transition]
	enter_state()
	
	emit_signal("state_changed", _state)

func _on_hit_enemy(multiplier = 1):
	if frozen_duration == 0.0:
		frozen_duration = BASE_FREEZE_DURATION

func _on_take_damage(damager, dmg = base_damage):
	last_damaged_by = damager
	if not has_been_attacked:
		has_been_attacked = true
		current_target = last_damaged_by
#	print("LAST DAMAGED BY ", damager.instance_name)
	hp -= dmg #TODO add damage
#	print(instance_name, " has been hit with HP left of ", hp)	
	if hp <= 0:
#		print(instance_name, "IS DEAD")
		is_alive = false
		change_state(EVENTS.DIE)
	else:
		stunned_timer.start()
		change_state(EVENTS.HURT)
#		frozen_duration = 1.0
#		frozen_timer.start()

func is_facing(target):
	if is_flipped: #im facing left
		return target.global_position.x < global_position.x
	else: #im facing right
		return target.global_position.x > global_position.x

func flip(val = null):
	if val == null:
		if not is_flipped:
			sprite.scale.x = -current_sprite_scale.x
			is_flipped = true
		else:
			sprite.scale.x = current_sprite_scale.x
			is_flipped = false
	elif val:
		sprite.scale.x = -current_sprite_scale.x
		is_flipped = true
	else:
		sprite.scale.x = current_sprite_scale.x
		is_flipped = false

#	pass
#	var snap = Vector2.DOWN * 16 if is_on_floor() else Vector2.ZERO
#	return body.move_and_slide_with_snap(_air_velocity, snap, Vector2.UP)
#	return body.move_and_collide(vel * delta)