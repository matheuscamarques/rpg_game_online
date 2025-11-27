function export_map_to_json() {
    show_debug_message(">>> INICIANDO GERAÇÃO DO JSON...");

    // 1. BUSCAR AS CAMADAS (LAYERS)
    var _layer_col_id = layer_get_id("Tiles_col");
    var _layer_spw_id = layer_get_id("Tiles_Spawn");

    if (_layer_col_id == -1 || _layer_spw_id == -1) {
        show_error("ERRO: Layers não encontradas!", true);
        return;
    }

    var _map_col = layer_tilemap_get_id(_layer_col_id);
    var _map_spw = layer_tilemap_get_id(_layer_spw_id);

    // 2. DIMENSÕES
    var _width = tilemap_get_width(_map_col);
    var _height = tilemap_get_height(_map_col);
    var _cell_size = tilemap_get_tile_width(_map_col);

    // Estruturas
    var _collision_grid = [];
    var _spawn_zones = {}; 

    // 3. VARREDURA
    for (var _y = 0; _y < _height; _y++) {
        var _row = [];
        for (var _x = 0; _x < _width; _x++) {
            
            // A. COLISÃO
            var _t_col_data = tilemap_get(_map_col, _x, _y);
            var _t_col_index = _t_col_data & tile_index_mask; 
            var _is_wall = (_t_col_index > 0) ? 1 : 0;
            array_push(_row, _is_wall);
            
            // B. SPAWN
            var _t_spw_data = tilemap_get(_map_spw, _x, _y);
            var _t_spw_index = _t_spw_data & tile_index_mask;

            if (_t_spw_index > 0) {
                var _zone_key = string(_t_spw_index);
                
                if (!variable_struct_exists(_spawn_zones, _zone_key)) {
                    _spawn_zones[$ _zone_key] = [];
                }
                
                var _pixel_pos = {
                    x: (_x * _cell_size) + (_cell_size / 2),
                    y: (_y * _cell_size) + (_cell_size / 2)
                };
                
                array_push(_spawn_zones[$ _zone_key], _pixel_pos);
            }
        }
        array_push(_collision_grid, _row);
    }

    // 4. STRINGIFY
    var _final_json = {
        width: _width,
        height: _height,
        cell_size: _cell_size,
        collisions: _collision_grid,
        spawns: _spawn_zones
    };

    var _string_data = json_stringify(_final_json);

    // 5. IMPRESSÃO SEGURA (CHUNK PRINT)
    // Imprime em blocos para evitar que o console corte o texto
    show_debug_message("");
    show_debug_message("▼▼▼▼ COPIE A PARTIR DAQUI ▼▼▼▼");
    
    var _len = string_length(_string_data);
    var _chunk_size = 3000; // Tamanho seguro por linha
    
    for (var i = 1; i <= _len; i += _chunk_size) {
        // string_copy no GM é 1-based
        var _chunk = string_copy(_string_data, i, _chunk_size);
        show_debug_message(_chunk);
    }
    
    show_debug_message("▲▲▲▲ ATÉ AQUI ▲▲▲▲");
    show_debug_message("");
}