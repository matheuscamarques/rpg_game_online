/// @function net_sync_remote_player(id, x, y, spr)
/// @description Sincroniza (Cria ou Atualiza) um jogador remoto baseado em dados do servidor.
/// @param {string|real} _p_id  O ID do jogador vindo do servidor
/// @param {real}        _p_x   Posição X alvo
/// @param {real}        _p_y   Posição Y alvo
/// @param {real|undefined} _p_spr O ID da sprite (pode ser undefined se não mudou)

function sync_remote_player(_p_id, _p_x, _p_y, _p_spr) {
    
    // 1. SEGURANÇA DE TIPAGEM (HTML5 FIX)
    var _str_id = string(_p_id);
    
    // 2. ACESSO AO ESCOPO GLOBAL
    // Como isso é um script solto, precisamos apontar explicitamente para o obj_Network
    if (!instance_exists(obj_Network)) return;
    
    var _my_id = obj_Network.my_id;
    var _map   = obj_Network.remote_players_map;

    // 3. IGNORAR O PRÓPRIO JOGADOR (ECO)
    if (_str_id == string(_my_id)) return; 

    // ============================================================
    // CENÁRIO A: ATUALIZAR EXISTENTE
    // ============================================================
    if (ds_map_exists(_map, _str_id)) {
        // Recupera a instância do mapa
        var _inst = _map[? _str_id];
        
        // Verifica se a instância ainda existe no mundo do jogo
        if (instance_exists(_inst)) {
            // Atualiza posição alvo (o Step do boneco fará o lerp)
            _inst.target_x = _p_x;
            _inst.target_y = _p_y;
            
            // Atualiza Sprite (apenas se o servidor mandou)
            if (!is_undefined(_p_spr)) {
                _inst.sprite_index = real(_p_spr);
            }
        } 
        else {
            // Se a instância foi deletada (mudou de sala, etc), remove do mapa
            // para que ela possa ser recriada (spawnada) logo abaixo se necessário,
            // ou apenas limpa a sujeira.
            ds_map_delete(_map, _str_id);
        }
    } 
    
    // ============================================================
    // CENÁRIO B: SPAWNAR NOVO
    // ============================================================
    else {
        // show_debug_message(">>> [SPAWN] Sincronizando novo ID: " + _str_id);
        
        var _new = instance_create_layer(_p_x, _p_y, "Instances", obj_RemotePlayer);
        
        // Configurações iniciais
        _new.network_id = _str_id;
        _new.target_x   = _p_x;
        _new.target_y   = _p_y;
        
        if (!is_undefined(_p_spr)) {
            _new.sprite_index = real(_p_spr);
        }
        
        // Salva no Mapa
        ds_map_add(_map, _str_id, _new);
    }
}