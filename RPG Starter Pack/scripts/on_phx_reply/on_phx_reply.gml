/// @function on_phx_reply(payload)
function on_phx_reply(_payload) {
    // Phoenix manda "phx_reply" para confirmar que recebeu msg
    // Geralmente ignoramos, a menos que seja erro
    if (_payload.status == "error") {
        show_debug_message(">>> [ERRO PHOENIX] " + string(_payload));
    }
}