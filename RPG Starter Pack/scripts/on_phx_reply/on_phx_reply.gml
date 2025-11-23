/// @function net_on_phx_reply(payload)
function on_phx_reply(_payload) {
    if (_payload.status == "ok") {
        show_debug_message(">>> [CANAL] Join confirmado.");
    }
}