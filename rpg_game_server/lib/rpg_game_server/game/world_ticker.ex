defmodule RpgGameServer.Game.WorldTicker do
  # Nome do Supervisor de Partição
  @supervisor_name RpgGameServer.WorldTickerPartition

  # Roteamento Inteligente:
  # Usamos o ID do mob como chave. O PartitionSupervisor garante que
  # o mob "slime_1" SEMPRE caia no Worker X.
  # Isso é vital para que o :update e o :remove caiam no mesmo buffer.

  def report_movement(data) do
    GenServer.cast(
      {:via, PartitionSupervisor, {@supervisor_name, data.id}},
      {:update, data}
    )
  end

  def get_all_updates() do
    PartitionSupervisor.which_children(@supervisor_name)
    |> Enum.flat_map(&get_updates/1)
  end

  defp get_updates({_id, pid, _type, _modules}) do
    GenServer.call(pid, :get_updates)
  end
end
