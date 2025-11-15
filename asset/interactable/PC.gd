extends StaticBody3D

func interact(player):
	if player.has_method("open_shop_ui"):
		player.open_shop_ui()

	var shop_ui = player.get_node("CanvasLayer/ShopUI")
	if shop_ui:
		if not shop_ui.is_connected("buy_item", Callable(player, "_on_shop_buy")):
			shop_ui.connect("buy_item", Callable(player, "_on_shop_buy"))
		if not shop_ui.is_connected("exit_shop", Callable(player, "_on_shop_exit")):
			shop_ui.connect("exit_shop", Callable(player, "_on_shop_exit"))
