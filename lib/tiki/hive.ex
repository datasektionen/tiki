defmodule Tiki.Hive do
  use GenServer

  alias Tiki.Accounts.User
  # 5 hours
  @ttl 1000 * 60 * 60 * 5

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc """
  Gets a list of hive permissions for tiki for the given user.
  """
  def get_permissions(user) do
    GenServer.call(__MODULE__, {:get_permissions, user}, 10_000)
  end

  @doc """
  Invalidates the permissions for the given user.
  """
  def clear() do
    GenServer.cast(__MODULE__, :clear)
  end

  def init(_) do
    :ets.new(:tiki_hive, [:named_table, :set, :protected])
    {:ok, %{timers: %{}}}
  end

  def handle_call({:get_permissions, user}, _from, state) do
    kth_id = user.kth_id

    case :ets.lookup(:tiki_hive, kth_id) do
      [{^kth_id, permissions}] ->
        {:reply, permissions, state}

      [] ->
        permissions = fetch_permissions(user)

        :ets.insert(:tiki_hive, {user.kth_id, permissions})
        timer = Process.send_after(self(), {:invalidate, kth_id}, @ttl)

        {:reply, permissions, %{state | timers: Map.put(state.timers, kth_id, timer)}}
    end
  end

  def handle_cast(:clear, %{timers: timers}) do
    for {_, timer} <- timers do
      Process.cancel_timer(timer)
    end

    :ets.delete(:tiki_hive)
    :ets.new(:tiki_hive, [:named_table, :set, :protected])
    {:noreply, %{timers: %{}}}
  end

  def handle_info({:invalidate, kth_id}, state) do
    :ets.delete(:tiki_hive, kth_id)
    {:noreply, state}
  end

  defp fetch_permissions(%User{kth_id: kth_id})
       when is_binary(kth_id) and byte_size(kth_id) > 0 do
    resp =
      Req.get(hive_url() <> "/user/#{kth_id}/permissions",
        headers: [{"Accept", "application/json"}, {"Authorization", "Bearer #{hive_api_token()}"}]
      )

    case resp do
      {:ok, %{status: 200, body: body}} when is_list(body) ->
        Enum.map(body, fn %{"id" => id} -> id end)

      _ ->
        []
    end
  end

  defp fetch_permissions(_), do: []

  defp hive_url do
    Application.get_env(:tiki, :hive_url)
  end

  defp hive_api_token do
    Application.get_env(:tiki, :hive_api_token)
  end
end
