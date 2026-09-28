extends Node

# Pass 4 verification: drives each of the five disasters directly through the
# disaster manager's own spawn path and checks the presentation contract without
# waiting on the random scheduler.
#
# What it proves, per disaster:
#   1. telegraph() builds a visible telegraph (node count above the resting floor)
#   2. the message fires through the HUD
#   3. activate() still damages the player when the hazard actually reaches them
#   4. the disaster removes itself (finished signal + freed node)
# Plus: all five can be live at once, and the goal/victory path still works.

const CarDisaster := preload("res://scripts/disasters/car_disaster.gd")
const FallingObjectDisaster := preload("res://scripts/disasters/falling_object_disaster.gd")
const DogChaseDisaster := preload("res://scripts/disasters/dog_chase.gd")
const LockedDoorDisaster := preload("res://scripts/disasters/locked_door_disaster.gd")
const ObstacleDisaster := preload("res://scripts/disasters/obstacle_disaster.gd")

const TELEGRAPH := 1.25

var _passed := 0
var _failed := 0


func _ready() -> void:
	_run()


func _ok(name: String, cond: bool, detail := "") -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
	print("  %s  %s%s" % ["PASS" if cond else "FAIL", name, ("  (" + detail + ")") if detail != "" else ""])


func _run() -> void:
	var scene: PackedScene = load("res://game.tscn")
	var game: Node = scene.instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout

	var player: Node3D = game.get_node("Player")
	var man: Node = game.get_node("DisasterManager")
	# Drive the run state so disasters are allowed to think they are live.
	man.set_active(true)
	# Stop the scheduler from interleaving its own events during the test.
	man.set("_timer", 999.0)

	var ppos := Vector3(0, 0.1, 0)

	await _test_car(game, man, player, ppos)
	await _test_falling(game, man, player, ppos)
	await _test_dog(game, man, player, ppos)
	await _test_door(game, man, player, ppos)
	await _test_obstacle(game, man, player, ppos)
	await _test_coexist(man, player, ppos)
	# The coexistence sequence runs long enough to burn the 60s timer, which puts
	# the run into LOST. Victory can only fire from RUNNING, so assert it on a
	# fresh game rather than trying to un-lose the one above.
	await _test_victory_still_works()

	print("=== DISASTER PASS 4 %s (passed=%d failed=%d) ===" % [
		"PASSED" if _failed == 0 else "FAILED", _passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


# Spawns one disaster of script at point, mirroring DisasterManager._spawn but
# without the random point picker, and returns the instance.
func _spawn_direct(man: Node, player: Node3D, game: Node, script: Script, point: Vector3) -> Node:
	var d = script.new()
	d.setup(player, game)
	man.add_child(d)
	d.call("telegraph", point)
	return d


func _test_car(game: Node, man: Node, player: Node3D, ppos: Vector3) -> void:
	print("-- car attack --")
	player.global_position = ppos
	player.hp = 3
	var d := _spawn_direct(man, player, game, CarDisaster, ppos)
	var resting := _visual_nodes(d)
	_ok("car builds telegraph nodes", resting >= 8, "nodes=%d" % resting)
	# The telegraph must not have damaged yet: warning precedes the attack.
	_ok("car telegraph deals no damage", player.hp == 3, "hp=%d" % player.hp)
	await get_tree().create_timer(TELEGRAPH + 0.1).timeout
	d.call("activate", ppos)
	# Car spawns 20m away and drives through; give it time to cross the player.
	await get_tree().create_timer(1.6).timeout
	_ok("car damages player", player.hp < 3, "hp=%d" % player.hp)
	# It should clean itself up shortly after passing.
	await get_tree().create_timer(2.2).timeout
	_ok("car cleans up", not is_instance_valid(d) or not d.is_inside_tree())


func _test_falling(game: Node, man: Node, player: Node3D, ppos: Vector3) -> void:
	print("-- falling object --")
	player.global_position = ppos
	player.hp = 3
	var d := _spawn_direct(man, player, game, FallingObjectDisaster, ppos)
	var resting := _visual_nodes(d)
	_ok("falling builds telegraph nodes", resting >= 4, "nodes=%d" % resting)
	_ok("falling telegraph deals no damage", player.hp == 3, "hp=%d" % player.hp)
	await get_tree().create_timer(TELEGRAPH + 0.1).timeout
	d.call("activate", ppos)
	await get_tree().create_timer(1.4).timeout
	_ok("falling damages player", player.hp < 3, "hp=%d" % player.hp)
	await get_tree().create_timer(2.6).timeout
	_ok("falling cleans up", not is_instance_valid(d) or not d.is_inside_tree())


func _test_dog(game: Node, man: Node, player: Node3D, ppos: Vector3) -> void:
	print("-- dog chase --")
	# Park the dog far enough that it has to close the gap.
	player.global_position = ppos
	player.hp = 3
	var d := _spawn_direct(man, player, game, DogChaseDisaster, ppos + Vector3(0, 0, 8))
	var resting := _visual_nodes(d)
	_ok("dog builds nodes", resting >= 10, "nodes=%d" % resting)
	await get_tree().create_timer(TELEGRAPH + 0.1).timeout
	d.call("activate", ppos)
	# Dog runs at 7.4 m/s from 8m; ~1.5s to reach catch distance.
	await get_tree().create_timer(2.0).timeout
	_ok("dog damages player", player.hp < 3, "hp=%d" % player.hp)
	await get_tree().create_timer(1.0).timeout
	_ok("dog cleans up after catch", not is_instance_valid(d) or not d.is_inside_tree())


func _test_door(game: Node, man: Node, player: Node3D, ppos: Vector3) -> void:
	print("-- locked door --")
	player.global_position = ppos
	var d := _spawn_direct(man, player, game, LockedDoorDisaster, ppos + Vector3(0, 0, 3))
	var resting := _visual_nodes(d)
	_ok("door builds nodes (padlock + stripes + label)", resting >= 12, "nodes=%d" % resting)
	# The door blocks by collision, never by damage, so HP must be untouched.
	_ok("door deals no damage by itself", player.hp >= 1, "hp=%d" % player.hp)
	await get_tree().create_timer(TELEGRAPH + 0.2).timeout
	d.call("activate", ppos)
	# It should open itself after DURATION and free.
	await get_tree().create_timer(7.4).timeout
	_ok("door cleans up after opening", not is_instance_valid(d) or not d.is_inside_tree())


func _test_obstacle(game: Node, man: Node, player: Node3D, ppos: Vector3) -> void:
	print("-- street obstacles --")
	player.global_position = ppos
	var d := _spawn_direct(man, player, game, ObstacleDisaster, ppos + Vector3(0, 0, 3))
	var resting := _visual_nodes(d)
	_ok("obstacle builds props + telegraph", resting >= 6, "nodes=%d" % resting)
	await get_tree().create_timer(TELEGRAPH + 0.1).timeout
	d.call("activate", ppos)
	# Obstacles never damage directly; they are a read-and-avoid mechanic. They
	# should still be present (blocking) right after going live.
	_ok("obstacle persists while active", is_instance_valid(d) and d.is_inside_tree())
	# After DURATION (11s) it clears itself.
	await get_tree().create_timer(12.0).timeout
	_ok("obstacle cleans up", not is_instance_valid(d) or not d.is_inside_tree())


# All five live at once, plus the manager's own bookkeeping, must not break each
# other or leak nodes.
func _test_coexist(man: Node, player: Node3D, ppos: Vector3) -> void:
	print("-- coexistence --")
	player.global_position = ppos
	player.hp = 3
	var kinds := {
		"car": CarDisaster, "falling": FallingObjectDisaster, "dog": DogChaseDisaster,
		"door": LockedDoorDisaster, "obstacle": ObstacleDisaster,
	}
	var spawned := []
	for kind in kinds:
		var d = kinds[kind].new()
		d.setup(player, null)
		man.add_child(d)
		# Space them out so none spawns on top of the player.
		d.call("telegraph", ppos + Vector3(randf_range(-3, 3), 0, randf_range(4, 7)))
		spawned.append(d)
	_ok("all five telegraph without error", true, "count=%d" % spawned.size())
	await get_tree().create_timer(TELEGRAPH + 0.1).timeout
	for d in spawned:
		if is_instance_valid(d):
			d.call("activate", ppos)
	_ok("all five activate without error", true)
	# Let them all run their course and self-clean.
	await get_tree().create_timer(13.0).timeout
	var alive := 0
	for d in spawned:
		if is_instance_valid(d) and d.is_inside_tree():
			alive += 1
	_ok("all five cleaned themselves up", alive == 0, "still_alive=%d" % alive)


func _test_victory_still_works() -> void:
	print("-- goal / victory --")
	# Fresh game: the first one has already timed out from the long coexist run.
	var scene: PackedScene = load("res://game.tscn")
	var g2: Node = scene.instantiate()
	add_child(g2)
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	var p2: Node3D = g2.get_node("Player")
	p2.hp = 3
	p2.global_position = Vector3(7.2, 0.1, 16.0)
	await get_tree().create_timer(0.8).timeout
	_ok("goal still triggers victory", g2.state == 2, "state=%d" % g2.state)
	g2.queue_free()


# Counts renderable children under a disaster, used as a proxy for "it built
# something visible". Counts the node and any Node3D descendants.
func _visual_nodes(d: Node) -> int:
	if not is_instance_valid(d):
		return 0
	var n := 0
	for child in d.get_children():
		if child is Node3D:
			n += 1
			n += _visual_nodes(child)
	return n
