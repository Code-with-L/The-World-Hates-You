extends Node

const SAVE_PATH := "user://the_world_hates_you.cfg"
const WIN_COINS := 100
const LOSE_COINS := 10

var coins: int = 0
var best_time_left: float = 0.0
var runs: int = 0
var wins: int = 0


func _ready() -> void:
	_load()


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	coins = int(cfg.get_value("progress", "coins", 0))
	best_time_left = float(cfg.get_value("progress", "best_time_left", 0.0))
	runs = int(cfg.get_value("progress", "runs", 0))
	wins = int(cfg.get_value("progress", "wins", 0))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "coins", coins)
	cfg.set_value("progress", "best_time_left", best_time_left)
	cfg.set_value("progress", "runs", runs)
	cfg.set_value("progress", "wins", wins)
	cfg.save(SAVE_PATH)


func finish_run(won: bool, time_left: float) -> int:
	var gained := WIN_COINS if won else LOSE_COINS
	coins += gained
	runs += 1
	if won:
		wins += 1
		if best_time_left <= 0.0 or time_left > best_time_left:
			best_time_left = time_left
	_save()
	return gained
