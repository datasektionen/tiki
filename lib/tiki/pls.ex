defmodule Tiki.Pls do
  use GenServer

  # 5 hours
  @ttl 1000 * 60 * 60 * 5

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc """
  Gets a list of pls permissions for tiki for the given user.
  """
  def get_permissions(user) do
    GenServer.call(__MODULE__, {:get_permissions, user})
  end

  @doc """
  Invalidates the permissions for the given user.
  """
  def clear() do
    GenServer.cast(__MODULE__, :clear)
  end

  def init(_) do
    :ets.new(:tiki_pls, [:named_table, :set, :protected])
    {:ok, %{timers: %{}}}
  end

  def handle_call({:get_permissions, user}, _from, state) do
    kth_id = user.kth_id

    case :ets.lookup(:tiki_pls, kth_id) do
      [{^kth_id, permissions}] ->
        {:reply, permissions, state}

      [] ->
        permissions = fetch_permissions(user)

        :ets.insert(:tiki_pls, {user.kth_id, permissions})
        timer = Process.send_after(self(), {:invalidate, kth_id}, @ttl)

        {:reply, permissions, %{state | timers: Map.put(state.timers, kth_id, timer)}}
    end
  end

  def handle_cast(:clear, %{timers: timers}) do
    for {_, timer} <- timers do
      Process.cancel_timer(timer)
    end

    :ets.delete(:tiki_pls)
    :ets.new(:tiki_pls, [:named_table, :set, :protected])
    {:noreply, %{timers: %{}}}
  end

  def handle_info({:invalidate, kth_id}, state) do
    :ets.delete(:tiki_pls, kth_id)
    {:noreply, state}
  end

  defp fetch_permissions(user) do
    resp =
      Req.get(pls_url() <> "/api/user/#{user.kth_id}/tiki",
        headers: [{"Accetpt", "application/json"}]
      )

    case resp do
      {:ok, %{status: 200, body: body}} -> body
      _ -> []
    end
  end

  defp pls_url do
    Application.get_env(:tiki, :pls_url)
  end
end
