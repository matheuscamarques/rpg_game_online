defmodule RpgGameServerWeb.GameMakerSerializer do
  @behaviour Phoenix.Socket.Serializer

  alias Phoenix.Socket.V2.JSONSerializer
  alias Phoenix.Socket.Message

  # 1. FASTLANE (Broadcast otimizado): Delegamos para o padrão
  def fastlane!(msg), do: JSONSerializer.fastlane!(msg)

  # 2. ENCODE (Servidor -> Cliente): Delegamos para o padrão
  # O GameMaker entende JSON texto perfeitamente.
  def encode!(msg), do: JSONSerializer.encode!(msg)

  # 3. DECODE (Cliente -> Servidor): IMPLEMENTAÇÃO MANUAL
  # O GameMaker manda o JSON dentro de uma "caixa" binária.
  # O JSONSerializer padrão explode se vê binário.
  # Então nós mesmos abrimos a caixa e montamos a mensagem.
  def decode!(data, _options) do
    # O "data" chega como binário (ex: "[\"1\",\"1\"...]"), mas é texto UTF-8 válido.
    # Usamos o Jason para transformar string em Lista do Elixir.
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

      # Fallback caso venha algo estranho
      other ->
        IO.inspect(other, label: ">>> [Serializer] Formato desconhecido")
        raise "Formato de mensagem inválido vindo do GameMaker"
    end
  end
end
