function connect_server(){
    // Limpeza de socket anterior
    if (socket != -1) {
        network_destroy(socket);
    }

    // 1. CRIAÇÃO: Continua sendo WebSocket
    socket = network_create_socket(network_socket_ws);

    // Configuração da URL
    var _ip = "127.0.0.1";
    var _port = 4000;
    var _path = "/socket/websocket?vsn=2.0.0";
    var _url = "ws://" + _ip + ":" + string(_port) + _path;

    show_debug_message(">>> [REDE] Tentando conectar (RAW) em: " + _url);
    
    // -----------------------------------------------------------
    // A CORREÇÃO ESTÁ AQUI:
    // Use _raw_async em vez de _async normal.
    // Isso diz ao GM: "Não espere cabeçalhos da YoYo Games, aceite qualquer coisa."
    // -----------------------------------------------------------
    network_connect_raw_async(socket, _url, _port);
}