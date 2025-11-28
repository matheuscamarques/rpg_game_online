defmodule RpgGameServer.Game.EnemySupervisor do
  # Não precisamos de "use DynamicSupervisor" aqui, pois o PartitionSupervisor
  # lá no application.ex já iniciou os processos reais do DynamicSupervisor.

  # Função auxiliar para criar um mob
  def start_enemy(args) do
    # 1. Definir a especificação do filho (quem vai nascer)
    child_spec = {RpgGameServer.Game.EnemyAI, args}

    # 2. Definir o Roteamento (Routing Key)
    # A tupla {:via, PartitionSupervisor, {NOME, CHAVE}} diz ao Elixir:
    # "Escolha uma partição baseada nesta CHAVE".

    # Usamos args.id (ex: "human_1_500") como chave.
    # Isso garante distribuição uniforme e determinística.Pspa
    via_tuple = {:via, PartitionSupervisor, {__MODULE__, args.id}}

    # 3. Iniciar
    DynamicSupervisor.start_child(via_tuple, child_spec)
  end
end
