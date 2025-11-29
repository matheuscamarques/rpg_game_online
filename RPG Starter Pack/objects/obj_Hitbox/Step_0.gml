// 1. Validações iniciais (Owner, Authority)...
if (!instance_exists(owner)) {
    // Debug: Saber se morreu porque o dono sumiu
    show_debug_message("[HITBOX " + string(id) + "] Destruída: Owner não existe.");
    instance_destroy();
    exit;
}

if (is_authoritative == false) {
    // Opcional: Descomente se quiser ver se as hitboxes fantasmas estão rodando
    // show_debug_message("[HITBOX " + string(id) + "] Ignorado: Não autoritativo.");
    exit;
}

// 2. Colisão
var _list_now = ds_list_create();
var _hits = instance_place_list(x, y, obj_EnemyParent, _list_now, false);

if (_hits > 0) {
    // Debug: Viu colisão física
    show_debug_message("[HITBOX " + string(id) + "] Colidiu com " + string(_hits) + " objetos.");

    for (var i = 0; i < _hits; i++) {
        var _target_inst = _list_now[| i];
        
        // Debug: Quem é o alvo atual do loop?
        var _debug_info = "  > Alvo GM_ID: " + string(_target_inst);
        
        // Ignora a si mesmo
        if (_target_inst == owner) {
            // show_debug_message(_debug_info + " [SKIP: Sou eu mesmo]");
            continue;
        }

        // --- FILTRO 1: INSTÂNCIA JÁ PROCESSADA? ---
        if (ds_list_find_index(hit_list, _target_inst) == -1) {
            
            // Marca a instância física como atingida
            ds_list_add(hit_list, _target_inst);
            
            // Pega o ID de rede e valida tipagem
            var _net_id = _target_inst.network_id;
            
            // Debug: Passou do filtro físico, verificando rede
            _debug_info += " | Net_ID: " + string(_net_id);

            // --- FILTRO 2: NETWORK ID JÁ PROCESSADO? ---
            if (_net_id != "" && ds_list_find_index(hit_network_ids, _net_id) == -1) {
                
                // Marca o ID de Rede como atingido
                ds_list_add(hit_network_ids, _net_id);
                
                // --- ENVIA O PACOTE ---
                var _payload = {
                    target_id: _net_id,
                    hit_x: x,
                    hit_y: y,
                    atk_x: owner.x,
                    atk_y: owner.y,
                    dmg_type: "slash"
                };
                
                phoenix_send(obj_Network.socket, "room:lobby", "attack_hit", _payload);
                
                // Debug: SUCESSO
                show_debug_message(_debug_info + " >>> [SUCESSO] Pacote enviado!");
            } 
            else {
                // Debug: Falha no filtro de rede (já bateu nesse personagem ou ID vazio)
                show_debug_message(_debug_info + " [SKIP: NetID duplicado ou vazio]");
            }
        } 
        else {
            // Debug: Falha no filtro físico (já bateu nessa instância específica)
            // show_debug_message("  > Alvo GM_ID: " + string(_target_inst) + " [SKIP: Instância já na lista]");
        }
    }
}
ds_list_destroy(_list_now);