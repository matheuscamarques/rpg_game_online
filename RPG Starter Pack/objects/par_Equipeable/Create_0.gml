equip_head = -1; // Ou "basic_helmet" para testar

// CORREÇÃO: method(self, function() { ... });
draw_equipment = method(self, function() {
    
    // Verifica se tem capacete equipado
    if (equip_head == "basic_helmet") {
        
        var _spr_capacete = -1;

        switch (sprite_index) {
            // IDLE
            case spr_player_idle_down:  _spr_capacete = spr_basic_helmet_idle_down; break;
            case spr_player_idle_up:    _spr_capacete = spr_basic_helmet_idle_up; break;
            case spr_player_idle_left:  _spr_capacete = spr_basic_helmet_idle_left; break;
            case spr_player_idle_right: _spr_capacete = spr_basic_helmet_idle_right; break;

            // WALK
            case spr_player_walk_down:  _spr_capacete = spr_basic_helmet_walk_down; break;
            case spr_player_walk_up:    _spr_capacete = spr_basic_helmet_walk_up; break;
            case spr_player_walk_left:  _spr_capacete = spr_basic_helmet_walk_left; break;
            case spr_player_walk_right: _spr_capacete = spr_basic_helmet_walk_right; break;
        }

        if (_spr_capacete != -1) {
            draw_sprite_ext(
                _spr_capacete, 
                image_index, 
                x, y, 
                image_xscale, image_yscale, image_angle, c_white, image_alpha
            );
        }
    }
});