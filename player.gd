extends CharacterBody3D
@export var WalkSpeed = 5.0
@export var SprintSpeed = 15.0
@export var JUMP_VELOCITY = 4.5
@export var base_gravity: float = 9.8
@export var reduced_gravity: float = 4.0
@export_range(0, 10, 0.01) var MouseSensitivity : float = 3
@export var SprintTime : float = 5
@export var CrouchSpeed: float = 2.5
@export var tauchgeschwindigkeit: float = 3.0  # Geschwindigkeit für Abtauchen
@export var auftauchgeschwindigkeit: float = 3.0  # Geschwindigkeit für Auftauchen
@export var wasseroberfläche: float = 0.0  # Höhe der Wasseroberfläche
@onready var is_on_ship: bool = false
var ship_velocity: Vector3 = Vector3.ZERO
#var schiff_area = "/root/HauptSzene/Path3D/PathFollow3D/visby"
var is_crouching: bool = false
var sprintTimeReset : float
var minPitch = deg_to_rad(-60)
var maxPitch = deg_to_rad(60)
var speed : float
var player_inside_Boot = false
var im_wasser = false  # Wird gesetzt, wenn der Spieler im Wasser ist
# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var direction : Vector3 = Vector3(0,0,0)

signal movement_state_changed(is_moving: bool)
var last_ship_position: Vector3 = Vector3.ZERO  # Deklaration hinzugefügt
var is_moving: bool = false

var input_direction: Vector3 = Vector3.ZERO  # Richtung der Eingabe

func _ready():
	print("Kollisionsmaske Spieler: ", collision_layer)
	sprintTimeReset = SprintTime
	var schiff_area = get_node_or_null("/root/HauptSzene/Path3D/PathFollow3D/visby/Area3D_Visby")
	if schiff_area and schiff_area is Area3D:
		schiff_area.connect("body_entered", Callable(self, "_on_Area3D_body_entered"))
		print("Signal korrekt verbunden.")
	else:
		print("Area3D_Visby nicht gefunden oder falscher Typ!")

		
func _on_area_entered(area):
	if area.name == "Wasser":
		im_wasser = true

func _process(delta: float) -> void:
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	if is_on_floor():  # Nur aktualisieren, wenn der Spieler auf dem Boden ist
		direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	else:
		direction = Vector3.ZERO  # Keine Bewegung in der Luft
	print("Richtung: ", direction)


func _physics_process(delta):
	# Überprüfen, ob der Spieler sich bewegt
	var moving = velocity.length() > 0.1  # Spieler bewegt sich, wenn Geschwindigkeit > 0
	if moving != is_moving:
		is_moving = moving
		emit_signal("movement_state_changed", is_moving)  # Signal senden
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta
	# Dynamic Gravity
	if Input.is_action_pressed("jump") and !is_on_floor():
		gravity = reduced_gravity  # Weniger Gravitation beim Springen
	else:
		gravity = base_gravity
	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	if Input.is_action_just_pressed("klick"):
		if speed != SprintSpeed:
			shoot()
	if Input.is_action_just_pressed("reload"):
		reload()
	if Input.is_action_just_pressed("ChangeWeapon"):
		changeWeapon()
	# Crouching
	if Input.is_action_just_pressed("crouch"):
		is_crouching = !is_crouching
		crouching()
	speed = get_current_speed()
	if is_on_ship:
		gravity = 0  # Gravitation deaktivieren
	else:
		gravity = base_gravity
	handleSprint(delta)
	
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	if is_on_floor():
		direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	else:
		direction = Vector3.ZERO
	print("Richtung: ", direction)
	print("Ist auf dem Boden: ", is_on_floor())
	
	if direction and is_on_floor():
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed

	elif !is_on_floor():
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed

	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	if im_wasser:
		var camera_basis = $Camera3D.global_transform.basis  # Kamerarichtung
		var forward = -camera_basis.z.normalized()  # Vorwärtsrichtung
		var right = camera_basis.x.normalized()  # Rechtsrichtung
		# Bewegung basierend auf Kameraausrichtung
		var move_dir = (forward * -input_dir.y) + (right * input_dir.x)  # Vorwärts und Rückwärts umkehren
		velocity.x = move_dir.x * 3.0  # Geschwindigkeit im Wasser
		velocity.z = move_dir.z * 3.0
		velocity.y = lerp(velocity.y, 2.0, delta * 5)  # Schwimmen
		if Input.is_action_pressed("crouch"):
			velocity.y -= tauchgeschwindigkeit * delta
			# Auftauchen, wenn die Taste losgelassen wird
		else:
			if global_position.y < wasseroberfläche:
				velocity.y += auftauchgeschwindigkeit * delta
	else:
		velocity.y -= gravity * delta  # Normale Gravitation
		
	print("Kollision erkannt: ", is_on_floor())
	if is_on_floor():
		velocity.y = 0  # Stabilisiert die Bewegung auf dem Boden
	else:
		velocity.y -= gravity * delta  # Fällt nur bei Bedarf

	move_and_slide()

func _input(event):
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x / 1000 * MouseSensitivity
		
		$Camera3D.rotation.x -= event.relative.y / 1000 * MouseSensitivity
		$Camera3D.rotation.x = clamp($Camera3D.rotation.x, minPitch, maxPitch)
		rotation.y = fmod(rotation.y, PI * 2)

func shoot():
	$Camera3D/GunHolder.Shoot()
	
func  reload():
	$Camera3D/GunHolder.Reload()
	
func changeWeapon():
	$Camera3D/GunHolder.ChangeWeapons()

func handleSprint(delta):
	if Input.is_action_pressed("sprint"):
		speed = SprintSpeed
		SprintTime -= delta
		if SprintTime <= 0:
			speed = WalkSpeed
	else:
		speed = WalkSpeed
		if SprintTime < sprintTimeReset:
			SprintTime += delta * 2
	GameManager.UIManagerInstance.UpdateSprintBar(SprintTime, sprintTimeReset)
func check_if_moving() -> bool:
	return input_direction.length() > 0  # Prüft, ob der Spieler aktiv läuft

# Diese Methode wird verwendet, um die Spielerbewegung mit der Bewegung des Schiffs zu synchronisieren.
func sync_player_with_ship(player: CharacterBody3D, delta: float) -> void:
	# Berechne die Geschwindigkeit des Schiffs
	var current_ship_position = global_transform.origin
	ship_velocity = (current_ship_position - last_ship_position) / delta
	last_ship_position = current_ship_position  # Speichere die aktuelle Position für den nächsten Frame
# Berechne die Vorwärtsrichtung des Schiffs korrekt
	var ship_forward = global_transform.basis.z.normalized()
# Debug-Ausgabe der Schiffsdrehung und -richtung
	print("Ship Rotation: ", global_transform.basis.get_euler())  # Ausgabe der Eulerwinkel
	print("Ship Forward Direction: ", ship_forward)
# Berechne die Bewegung des Spielers relativ zum Schiff
	var movement_speed = ship_velocity.length() * 0.1  # Passe die Geschwindigkeit an
# Ausgabe der angepassten Bewegungsgeschwindigkeit des Spielers
	print("Adjusted player movement speed: ", movement_speed)
# Bewege den Spieler relativ zum Schiff
	player.global_transform.origin += ship_velocity * delta

	# Debug-Ausgaben
	print("Spieler-Geschwindigkeit: ", velocity)
	print("Spieler-Position: ", global_transform.origin)
	
func apply_friction() -> void:
	if is_on_ship:
		velocity.x = lerp(velocity.x, 0, 0.5)  # Erhöhte X-Reibung
		velocity.z = lerp(velocity.z, 0, 0.5)  # Erhöhte Z-Reibung

func get_current_speed() -> float:
	if is_crouching:
		return CrouchSpeed
	elif Input.is_action_pressed("sprint"):
		return SprintSpeed
	else:
		return WalkSpeed
func can_stand() -> bool:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	query.transform = global_transform
	query.shape = CapsuleShape3D.new()
	query.shape.height = 1.0  # Normale Höhe des Spielers
	return space_state.intersect_shape(query).size() == 0
func crouching():
	var collider = $CollisionShape3D
	if collider.shape is CapsuleShape3D:
		var shape = collider.shape as CapsuleShape3D
		if not is_crouching and not can_stand():
			print("Nicht genug Platz zum Aufstehen!")
			return  # Verhindere Aufstehen, wenn kein Platz ist
		if is_crouching:
			shape.height = 0.5  # Spieler duckt sich
		else:
			shape.height = 1.0  # Spieler steht auf
			global_position.y = lerp(global_position.y, global_position.y + 0.2, 0.1)  # Sanfte Bewegung
		collider.shape = shape
		print("Shape Height: ", shape.height)

func _on_wasser_body_entered(body: Node3D) -> void:
	if body.name == self.name:
		im_wasser = true
		print("Spieler ist im Wasser.")


func _on_wasser_body_exited(body: Node3D) -> void:
	if body.name == self.name:
		im_wasser = false


func _on_Area3D_body_entered(body: Node) -> void:
	print("Body entered: ", body.name)
	if body.name == "visby" or body.is_in_group("Schiff"):
		is_on_ship = true
		print("Spieler ist jetzt auf dem Schiff.")
	else:
		print("Kein Match für das Schiff gefunden.")

func _on_Area3D_body_exited(body: Node) -> void:
	if body.name == "visby":  # Prüfen, ob das Schiff verlassen wurde
		is_on_ship = false
		print("Spieler hat das Schiff verlassen.")
