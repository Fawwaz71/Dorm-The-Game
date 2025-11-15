extends Control

signal buy_item(item_id: String, quantity: int)
signal exit_shop()

var shop_items: Array[Dictionary] = [
	{"id": "acoustic", "name": "Guitar (Acoustic)", "price": 50, "icon": "res://icon.png"},
	{"id": "guitar", "name": "Guitar (Electric)", "price": 10, "icon": "res://icon.png"},
	{"id": "acoustic2", "name": "Guitar (Acoustic)", "price": 50, "icon": "res://icon.png"},
	{"id": "guitar2", "name": "Guitar (Electric)", "price": 10, "icon": "res://icon.png"},
	{"id": "acoustic3", "name": "Guitar (Acoustic)", "price": 50, "icon": "res://icon.png"},
	{"id": "guitar3", "name": "Guitar (Electric)", "price": 10, "icon": "res://icon.png"},
	{"id": "acoustic4", "name": "Guitar (Acoustic)", "price": 50, "icon": "res://icon.png"},
	{"id": "guitar4", "name": "Guitar (Electric)", "price": 10, "icon": "res://icon.png"}
]

@onready var money_label: Label = $PanelContainer/MarginContainer/VBoxContainer/MoneyLabel
@onready var items_grid: GridContainer = $PanelContainer/MarginContainer/VBoxContainer/GridContainer
@onready var exit_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ExitButton
@onready var buy_button: Button = $PanelContainer/MarginContainer/VBoxContainer/BuyButton

var cart: Dictionary[String, int] = {}
var quantities: Dictionary[String, int] = {}

func _ready() -> void:
	visible = false
	# Ensure cart and quantities are correctly initialized for *unique* IDs
	var unique_ids = {}
	for item in shop_items:
		unique_ids[item.id] = true
	
	for id in unique_ids.keys():
		cart[id] = 0
		quantities[id] = 0 # INITIAL QUANTITY SET TO 0
	
	# Set GridContainer to center horizontally (FIX 2)
	items_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	items_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	_populate_shop_grid()

	exit_button.pressed.connect(_on_press_exit)
	buy_button.pressed.connect(_on_buy_pressed)
	buy_button.visible = false

func _set_small_button_style(btn: Button) -> void:
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(24, 24)
	# NOTE: Removed Control.SIZE_FILL to allow the buttons to shrink to min size
	# so that the HBoxContainer can be centered properly.
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN 
	btn.size_flags_vertical = Control.SIZE_FILL

	var s_normal := StyleBoxFlat.new()
	s_normal.bg_color = Color("#4b4f56")
	s_normal.corner_radius_top_left = 4
	s_normal.corner_radius_top_right = 4
	s_normal.corner_radius_bottom_left = 4
	s_normal.corner_radius_bottom_right = 4
	s_normal.content_margin_left = 4
	s_normal.content_margin_right = 4

	var s_hover := s_normal.duplicate()
	s_hover.bg_color = Color("#6a6f76")

	var s_pressed := s_normal.duplicate()
	s_pressed.bg_color = Color("#2f333a")

	btn.add_theme_stylebox_override("normal", s_normal)
	btn.add_theme_stylebox_override("hover", s_hover)
	btn.add_theme_stylebox_override("pressed", s_pressed)

func _create_item_box(item: Dictionary) -> Panel:
	var panel = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#222A3A") # dark background
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(150, 150)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Use a MarginContainer for padding inside the item box
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)


	# Icon (FIX 1: Ensure icon is added to the VBoxContainer)
	var icon = TextureRect.new()
	var tex = load(item.icon)
	if tex != null and tex is Texture2D:
		icon.texture = tex
	else:
		# Use a default placeholder color if icon is not found
		var placeholder = StyleBoxFlat.new()
		placeholder.bg_color = Color.GRAY
		icon.add_theme_stylebox_override("panel", placeholder)
		push_error("Failed to load texture: " + str(item.icon))

	icon.expand = true
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.custom_minimum_size = Vector2(48, 48)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_EXPAND # Allow icon to take up available vertical space
	vbox.add_child(icon) # <--- ICON ADDED HERE

	# Name
	var title = Label.new()
	title.text = item.name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Price
	var price = Label.new()
	price.text = "$%d" % item.price
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(price)

	# Quantity controls
	var hbox = HBoxContainer.new()
	# Set to shrink to its content size and then center itself within the VBoxContainer (FIX)
	hbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER 
	hbox.add_theme_constant_override("separation", 5) # Small separation for buttons

	var minus_btn = Button.new()
	minus_btn.text = "-"
	_set_small_button_style(minus_btn)
	hbox.add_child(minus_btn)

	var qty_lbl = Label.new()
	qty_lbl.text = str(quantities.get(item.id, 0)) # Set default quantity label to 0
	qty_lbl.custom_minimum_size = Vector2(20, 20)
	# NOTE: The label is already centered within its space, but with the hbox changes,
	# it uses its minimum size, making the whole control block look centered.
	qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER 
	hbox.add_child(qty_lbl)

	var plus_btn = Button.new()
	plus_btn.text = "+"
	_set_small_button_style(plus_btn)
	hbox.add_child(plus_btn)
	vbox.add_child(hbox)

	# Signals for quantity buttons
	plus_btn.pressed.connect(func() -> void:
		quantities[item.id] += 1
		cart[item.id] = quantities[item.id]
		qty_lbl.text = str(quantities[item.id])
		_on_checkout_pressed()
	)
	minus_btn.pressed.connect(func() -> void:
		if quantities[item.id] > 0: # Check > 0 instead of > 1 to allow reset to 0
			quantities[item.id] -= 1
			cart[item.id] = quantities[item.id]
			qty_lbl.text = str(quantities[item.id])
			_on_checkout_pressed()
	)
	return panel


func _populate_shop_grid() -> void:
	for child in items_grid.get_children():
		child.queue_free()
	
	# Keep track of added IDs to handle duplicates correctly
	var added_ids = {}
	for item in shop_items:
		if item.id in added_ids:
			continue # Skip if already added, assuming items are meant to be unique
		added_ids[item.id] = true
		
		var box = _create_item_box(item)
		items_grid.add_child(box)

func _on_checkout_pressed() -> void:
	var total = 0
	# Iterate over items to calculate total price
	# The cart uses the item ID as the key, so calculating based on the unique keys in cart is safer.
	var calculated_total = 0
	for id in cart.keys():
		var quantity = cart[id]
		if quantity > 0:
			# Find the item price (assuming first occurrence is correct)
			var price = 0
			for item in shop_items:
				if item.id == id:
					price = int(item.price)
					break
			calculated_total += quantity * price

	buy_button.text = "BUY ($%d)" % calculated_total
	buy_button.visible = calculated_total > 0

func _on_buy_pressed() -> void:
	for id in cart.keys():
		if cart[id] > 0:
			buy_item.emit(id, cart[id])
	_reset_cart()
	buy_button.visible = false

func _reset_cart() -> void:
	for id in cart.keys():
		cart[id] = 0
		quantities[id] = 0 # RESET QUANTITY SET TO 0
	_populate_shop_grid()

func _on_press_exit() -> void:
	exit_shop.emit()

func set_money_text(value: int) -> void:
	money_label.text = "Money: $" + str(value)
