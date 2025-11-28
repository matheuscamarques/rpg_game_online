function on_xp_gain(_payload) {
    var _player_id = _payload.player_id;
    var _amount = _payload.amount;
    
    // Check if this XP is for ME
	show_debug_message("MY_ID: " + string(obj_Network.my_id) + " " + "Player_id: " + string(_player_id));
    if (string(_player_id) == string(obj_Network.my_id)) {
        
        // 1. Update internal data
        //global.xp += _amount;
        
        // 2. Visual Feedback (Floating Text)
        // You can use a different color (e.g., Purple or Blue) for XP
        if (instance_exists(obj_Player)) {
            var _txt = instance_create_layer(obj_Player.x, obj_Player.y - 40, "Instances", obj_DamageText);
            _txt.text = "+" + string(_amount) + " XP";
            _txt.color = c_purple; // Cyan/Blue color
            _txt.vsp = -2; // Floats up slower than damage
        }
    }
}