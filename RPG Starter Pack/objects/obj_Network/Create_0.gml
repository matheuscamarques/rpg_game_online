/// EVENTO: Create

show_debug_message(">>> [SISTEMA] obj_Network iniciado.");

#macro ALARM_HEARTBEAT 0
#macro ALARM_RECONNECT 1
#macro ALARM_JOIN_DELAY 2

// --- CONFIGURAÇÕES ---
retry_delay = 1;
retry_max   = 32;
my_topic    = "room:lobby";
connected   = false;
socket      = -1;
ref_count   = 0;
my_id       = "";
remote_players_map = ds_map_create();
enemies_map = ds_map_create();

connect_server();