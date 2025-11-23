defmodule RpgGameServerWeb.UserSocket do
  use Phoenix.Socket

  # Roteia tópicos "room:lobby", "room:match1", etc para o módulo RoomChannel
  channel "room:*", RpgGameServerWeb.Channels.RoomChannel

  # A função connect é o "Handshake".
  # params contém o que vier na query string da URL (ex: token JWT)
  @impl true
  def connect(_params, socket, _connect_info) do
    # Aqui você faria autenticação.
    # Retornar {:ok, socket} aceita todo mundo.
    IO.puts ">>> [SOCKET] Novo cliente conectado via WebSocket!"
    {:ok, socket}
  end

  # id permite desconectar usuários específicos depois. Nil por enquanto.
  @impl true
  def id(_socket), do: nil
end
