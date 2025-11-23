if (connected) {
    // "phoenix" é um tópico especial do sistema para heartbeats
    phoenix_send(socket, "phoenix", "heartbeat", {});
}

// Reseta o alarme para daqui 30 segundos
alarm[0] = game_get_speed(gamespeed_fps) * 30;