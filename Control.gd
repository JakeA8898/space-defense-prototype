extends TileMap
var state
var gridCS
var grid
var laser

# board state information
var validShips = []	 # array of grid positions of movable ships
var playerShips = [] # array of ships
var enemyShips = []  # array of ships

# obstacle tile indices
var obstacle_tiles = [12, 13]

# active ship selection information
var selectedShip = null
var selectedRange = []
var attackTiles = [] 

# turn information
var playerTurn = true
var mouseTile = null	# tile under mouse

# async signal to resynchronize turns
signal computer_done

func _ready():
	state = preload("state.gd").new()
	laser = preload("Laser.tscn")
	var ships = get_children()
	for ship in ships:
		# 0: player
		# 1: computer
		if ship.team == 0:
			playerShips.append(ship)
		else:
			enemyShips.append(ship)
	
	draw_moves()
	
func draw_moves():
	del_range(validShips)
	del_range(selectedRange)
	validShips.clear()

	if selectedShip != null:
		# draw selected ship movement range tiles
		selectedRange = range_check(selectedShip.range, world_to_map(selectedShip.position))
		add_range(selectedRange, "YellowTransparency")

	if playerTurn:
		for ship in playerShips:
			if ship.range > 0 or ship.AP > 0:
				validShips.append(world_to_map(ship.position))	
	
		# highlight ships which can move
		if validShips.size() > 0:
			add_range(validShips, "YellowTransparency")
	
func draw_attack(tile = null):
	del_range(attackTiles, true)
	attackTiles.clear()

	if selectedShip == null: return

	if tile == null:
		tile = world_to_map(selectedShip.position)
	
	var shipTile

	var attackRange = range_check(selectedShip.maxRange, tile)
	attackRange.append(tile)
	for ship in enemyShips:
		shipTile = world_to_map(ship.position)
		if world_to_map(ship.position) in attackRange:
			attackTiles.append(shipTile)
	add_range(attackTiles, "RedTransparency", true)


func add_range(moves, tileString, top = false):
	var tile = tile_set.find_tile_by_name(tileString)
	if !top:
		for cell in moves:
			set_cellv(cell, tile)
	else:
		var tileMap = get_node("../TileMapTop")
		for cell in moves:
			tileMap.set_cellv(cell, tile)

func del_range(moves, top = false):
	if !top:
		for cell in moves:
			set_cellv(cell, -1)
	else:
		var tileMap = get_node("../TileMapTop")
		for cell in moves:
			tileMap.set_cellv(cell, -1)


# Receives a request to move a ship
# Ship1 ship, ship to move
# Vector2 target, target space coordinates
# return true if moved, false if blocked
func move(ship, target):
	# target is not in range
	if !target in range_check(ship.range, world_to_map(ship.position)):
		return false
	
	# calculate movement
	var vector = target - world_to_map(ship.position)
	var steps = abs(vector.x) + abs(vector.y)
	var distance = sqrt(vector.x*vector.x + vector.y*vector.y)

	# sound effect
	get_node("../SoundEffect/grid_interact").play();

	# prep movement
	var sprite = ship.get_node("Sprite")
	ship.range -= steps

	# align sprite
	sprite.look_at(map_to_world(target) + Vector2(16,16))
	sprite.rotation_degrees += 90
	
	# move ship
	ship.position = map_to_world(target)
	sprite.offset = Vector2(0, 32*distance)

	# animate movement
	var tween = ship.get_node("Tween")

	# animate sprite
	tween.interpolate_property(sprite, "offset", sprite.offset, Vector2(0,0), 0.2);
	tween.start();

	# wait for animation to complete
	yield(tween, "tween_completed")

	return true	

# handles request for an attack
# Ship ship1, attacking ship
# Ship ship2, attacked ship
# return true if hit, false if miss
func attack(ship1, ship2):
	# target ship is not in range
	if !(world_to_map(ship2.position) in range_check(ship1.maxRange, world_to_map(ship1.position))):
		return false

	# ship must have enough AP
	if ship1.AP < 1: return false

	# calculate distance
	var distance = ship2.position.distance_to(ship1.position)

	# sound effect
	get_node("../SoundEffect/attack_1").play()

	# create the projectile
	var projectile = laser.instance()
	add_child(projectile)
	projectile.position = ship1.position
	
	# align projectile
	var sprite = projectile.get_node("Sprite")
	sprite.look_at(ship2.position + Vector2(16,16))
	sprite.rotation_degrees += 90
	
	# animate projectile
	var tween = projectile.get_node("Tween")
	tween.interpolate_property(projectile, "position", ship1.position, ship2.position, distance/320);
	tween.start();
	
	# wait for animation to complete
	yield(tween, "tween_completed")

	# apply damage
	ship2.call("take_hit", projectile.firepower)
	ship1.AP = max(0, ship1.AP-projectile.cost)

	# handle destroyed ship
	if ship2.HP <= 0:
		# sound effect
		get_node("../SoundEffect/destroy_1").play()

		# remove from team list
		if ship2.team == 0:
			playerShips.remove(playerShips.find(ship2))
		else:
			enemyShips.remove(enemyShips.find(ship2))

		# remove from grid
		remove_child(ship2)

		check_victory()

	# cleanup projectile animation and return to player
	remove_child(projectile)
	
	

# handles all user input and consequently the player's turn
func _input(event):
	# block input if not user turn
	if !playerTurn: return

	# mouse movement
	if event is InputEventMouseMotion:
		# currently nothing happens if no ship selected
		if selectedShip == null: return

		var tile = world_to_map(event.position)

		# update if mouse moved over a new tile
		if tile != mouseTile:
			mouseTile = tile
			on_mouse_moved(tile)

	# mouse click (up or down)
	elif event is InputEventMouseButton:
		var tile = world_to_map(event.position)

		# left click down
		if event.button_index == BUTTON_LEFT and event.is_pressed():
			playerTurn = false
			on_left_clicked(tile)
			playerTurn = true

			# update movement tiles
			draw_moves()

	# gridCS._Input(event)

# handles mouse movement
# called when a new tile is hovered over
func on_mouse_moved(tile):
	draw_attack(tile)
		

# handles left clicks
# called when left mouse button is pressed down
func on_left_clicked(tile):

	# if the selected ship is clicked again, deselect it
	if selectedShip != null and world_to_map(selectedShip.position) == tile:
		selectedShip = null
		
		# play sound effect
		get_node("../SoundEffect/grid_interact").play()
		
		return

	# find what was clicked
	# check player ships
	for ship in playerShips:
		# a new ship was clicked
		if tile == world_to_map(ship.position):
			# select ship
			selectedShip = ship

			# play sound effect
			get_node("../SoundEffect/grid_interact").play()

			return
	
	# if no ship is selected, cannot move or attack
	if selectedShip == null: return

	# continue to check enemy ships
	for ship in enemyShips:
		# enemy ship was attacked
		if tile == world_to_map(ship.position):
				# try to attack
				attack(selectedShip, ship)
				return
	
	# lastly, try to move to empty space
	# inner block runs if moved successfully
	if move(selectedShip, tile):
		return
	
	return

# check whether a victory condition is met
func check_victory():
	# no enemy ships; player wins
	if enemyShips.size() == 0:
		State.nextLevel()

		# end and return to level select
		yield(get_tree().create_timer(2), "timeout")
		get_tree().change_scene("res://level_select.tscn")

	# no player ships; player loses
	elif playerShips.size() == 0:
		yield(get_tree().create_timer(2), "timeout")
		get_tree().change_scene("res://level_select.tscn")


# calculate which tiles are within range of a given location
# return an array of Vector2 tile locations
func range_check(rng, tile, mainX = 0, mainY = 0, aduX = 0, aduY = 0):
	var locations = []
	if mainX == 0 and mainY == 0:
		locations += (range_check(rng-1, Vector2(tile.x+1, tile.y),1,0,0,1));
		locations += (range_check(rng-1, Vector2(tile.x-1, tile.y),-1,0,0,1));
		locations += (range_check(rng-1, Vector2(tile.x, tile.y+1),0,1,1,0));
		locations += (range_check(rng-1, Vector2(tile.x, tile.y-1),0,-1,1,0));
	elif rng >= 0:
		# check if space can be moved to
		if !get_cellv(tile) in obstacle_tiles:
			locations.append(tile);
			locations += (range_check(rng-1, Vector2(tile.x-aduX, tile.y-aduY),mainX,mainY,aduX,aduY));
			locations += (range_check(rng-1, Vector2(tile.x+aduX, tile.y+aduY),mainX,mainY,aduX,aduY));
			locations += (range_check(rng-1, Vector2(tile.x+mainX, tile.y+mainY),mainX,mainY,aduX,aduY));
	
	return locations

# handles "end turn" button press
func _on_end_turn():
	if !playerTurn: return

	# end the player's turn
	playerTurn = false
	selectedShip = null
	draw_moves()

	# run the computer's turn
	comp_turn()
	check_victory()

	# wait for all ships to finish their turns
	yield(self, "computer_done")

	# restore per-turn ship points
	for ship in playerShips:
		ship.AP = ship.maxAP
		ship.range = ship.maxRange

	for ship in enemyShips:
		ship.AP = ship.maxAP
		ship.range = ship.maxRange

	# enable player's next turn
	playerTurn = true
	draw_moves()

# responsible for playing the computer's turn
func comp_turn():
	for ship in enemyShips:
		while ship.range > 0:
			ship.call("PlayTurn")

			# wait for movement and pause
			yield(get_tree().create_timer(0.4), "timeout")

	# let parent function know it can continue
	emit_signal("computer_done")
