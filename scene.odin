package main

game_state : Game_State = .main
menu_option_text_id_0: int
menu_option_text_id_1: int

Game_State :: enum {
	main
}

enter_main :: proc()
{
	game_state = .main
}

exit_main :: proc()
{
}

