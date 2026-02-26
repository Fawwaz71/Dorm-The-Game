extends Control

signal buy_item(item_id: String, quantity: int)
signal exit_shop()

var shop_items: Array[Dictionary] = [
	{"id": "acoustic", "name": "Acoustic", "price": 50, "icon": "res://icon.png"},
	{"id": "guitar", "name": "Electric", "price": 100, "icon": "res://asset/interactable/guitar_Image_0.png"},
	{"id": "acoustic2", "name": "Acoustic 2", "price": 55, "icon": "res://icon.png"},
	{"id": "electric2", "name": "Electric 2", "price": 110, "icon": "res://icon.png"},
	{"id": "bass1", "name": "Bass 1", "price": 80, "icon": "res://icon.png"},
	{"id": "keyboard1", "name": "Keys 1", "price": 150, "icon": "res://icon.png"},
	{"id": "drums1", "name": "Drums 1", "price": 200, "icon": "res://icon.png"},
	{"id": "mic1", "name": "Mic 1", "price": 25, "icon": "res://icon.png"}
]

var cart: Dictionary[String,int] = {}
var quantities: Dictionary[String,int] = {}

@onready var money_label: Label = $"TabContainer/Item Shop/VBoxContainer/MoneyLabel"
@onready var items_grid: GridContainer = $"TabContainer/Item Shop/VBoxContainer/ItemsGrid"
@onready var exit_button: Button = $VBoxContainer2/ExitButton
@onready var buy_button: Button = $"TabContainer/Item Shop/VBoxContainer/BuyButton"

func _ready():
	visible = false
	
	# Initialize cart & quantities
	for item in shop_items:
		cart[item.id] = 0
		quantities[item.id] = 0

	# GridContainer styling
	items_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	items_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	_populate_shop_grid()
	
	exit_button.pressed.connect(_on_press_exit)
	buy_button.pressed.connect(_on_buy_pressed)
	buy_button.visible = false


# Small button styling
func _set_small_button_style(btn: Button) -> void:
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(24, 24)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	btn.size_flags_vertical = Control.SIZE_FILL
	
	var s_normal := StyleBoxFlat.new()
	s_normal.bg_color = Color("#4b4f56")
	s_normal.corner_radius_top_left = 4
	s_normal.corner_radius_top_right = 4
	s_normal.corner_radius_bottom_left = 4
	s_normal.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", s_normal)
	
	var s_hover = s_normal.duplicate()
	s_hover.bg_color = Color("#6a6f76")
	btn.add_theme_stylebox_override("hover", s_hover)
	
	var s_pressed = s_normal.duplicate()
	s_pressed.bg_color = Color("#2f333a")
	btn.add_theme_stylebox_override("pressed", s_pressed)


# Create shop item panel
func _create_item_box(item: Dictionary) -> Panel:
	var panel = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#222A3A")
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(95,155)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	# Icon
	var icon = TextureRect.new()
	var tex = load(item.icon)
	if tex and tex is Texture2D:
		icon.texture = tex
	icon.expand = true
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(70,70)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon)

	# Name label
	var title = Label.new()
	title.text = item.name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	vbox.add_child(title)

	# Price label
	var price = Label.new()
	price.text = "$%d" % item.price
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.add_theme_font_size_override("font_size", 12)
	vbox.add_child(price)

	# Quantity controls
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hbox.add_theme_constant_override("separation", 4)

	var minus_btn = Button.new()
	minus_btn.text = "-"
	_set_small_button_style(minus_btn)
	hbox.add_child(minus_btn)

	var qty_lbl = Label.new()
	qty_lbl.text = str(quantities.get(item.id,0))
	qty_lbl.custom_minimum_size = Vector2(20,20)
	qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(qty_lbl)

	var plus_btn = Button.new()
	plus_btn.text = "+"
	_set_small_button_style(plus_btn)
	hbox.add_child(plus_btn)

	vbox.add_child(hbox)

	# Signals
	var item_id = item.id
	plus_btn.pressed.connect(func():
		quantities[item_id] += 1
		cart[item_id] = quantities[item_id]
		qty_lbl.text = str(quantities[item_id])
		_on_checkout_pressed()
	)

	minus_btn.pressed.connect(func():
		if quantities[item_id] > 0:
			quantities[item_id] -= 1
			cart[item_id] = quantities[item_id]
			qty_lbl.text = str(quantities[item_id])
			_on_checkout_pressed()
	)

	return panel


func _populate_shop_grid() -> void:
	for child in items_grid.get_children():
		child.queue_free()

	var added_ids = {}
	for item in shop_items:
		if item.id in added_ids:
			continue
		added_ids[item.id] = true
		items_grid.add_child(_create_item_box(item))


func _on_checkout_pressed() -> void:
	var total = 0
	for id in cart.keys():
		if cart[id] > 0:
			for item in shop_items:
				if item.id == id:
					total += cart[id]*int(item.price)
					break
	buy_button.text = "BUY ($%d)" % total
	buy_button.visible = total > 0


func _on_buy_pressed() -> void:
	for id in cart.keys():
		if cart[id] > 0:
			buy_item.emit(id, cart[id])
	_reset_cart()
	buy_button.visible = false


func _reset_cart() -> void:
	for id in cart.keys():
		cart[id] = 0
		quantities[id] = 0
	_populate_shop_grid()


func _on_press_exit() -> void:
	exit_shop.emit()


func _update_money_label(player_money: int = 0) -> void:
	money_label.text = "Money: $" + str(player_money)
	
func set_money_text(value: int) -> void:
	money_label.text = "Money: $" + str(value)
