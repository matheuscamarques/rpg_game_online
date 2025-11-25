defmodule RpgGameServerWeb.UserSocket do
  use Phoenix.Socket
  alias RpgGameServer.SessionTokenCache

  channel "room:*", RpgGameServerWeb.Channels.RoomChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case SessionTokenCache.get(token) do
      nil -> :error
      user ->
        IO.puts(">>> [SOCKET] Usuário #{user.username} (ID: #{user.id}) conectado.")
        socket = assign(socket, :current_user_id, user.id)
        {:ok, socket}
    end
  end

  @impl true
  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.current_user_id}"
end
