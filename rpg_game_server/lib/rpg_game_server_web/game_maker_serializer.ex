defmodule RpgGameServerWeb.GameMakerSerializer do
  @behaviour Phoenix.Socket.Serializer

  alias Phoenix.Socket.V2.JSONSerializer
  alias Phoenix.Socket.Message
  def fastlane!(msg), do: JSONSerializer.fastlane!(msg)

  def encode!(msg), do: JSONSerializer.encode!(msg)

  def decode!(data, _options) do
    # O "data" chega como binário (ex: "[\"1\",\"1\"...]"), mas é texto UTF-8 válido.
    case Jason.decode!(data) do
      # Protocolo V2: [join_ref, ref, topic, event, payload]
      [join_ref, ref, topic, event, payload | _rest] ->
        %Message{
          join_ref: join_ref,
          ref: ref,
          topic: topic,
          event: event,
          payload: payload
        }

      other ->
        IO.inspect(other, label: ">>> [Serializer] Formato desconhecido")
        raise "Formato de mensagem inválido vindo do GameMaker"
    end
  end
end
