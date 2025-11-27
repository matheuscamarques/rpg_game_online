// CLEAN

if (ds_exists(remote_players_map, ds_type_map)) {
    ds_map_destroy(remote_players_map);
}


if (ds_exists(enemies_map, ds_type_map)) { 
	ds_map_destroy(enemies_map);
}

// Destruir socket também é boa prática
if (socket != -1) {
    network_destroy(socket);
}