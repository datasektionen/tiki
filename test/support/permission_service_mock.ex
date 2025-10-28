defmodule Tiki.Support.PermissionServiceMock do
  @moduledoc """
  Mock implementation of PermissionService for testing.

  This mock allows tests to control user permissions without relying on
  an external Hive API. By default, users have no permissions, but tests
  can grant permissions using `grant_permission/2`.
  """

  use GenServer
  @behaviour PermissionService

  alias Tiki.Accounts.User

  ## Public API

  @impl PermissionService
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl PermissionService
  def get_permissions(%User{} = user) do
    GenServer.call(__MODULE__, {:get_permissions, user})
  end

  @impl PermissionService
  def clear do
    GenServer.cast(__MODULE__, :clear)
    :ok
  end

  @doc """
  Grants a permission to a user for testing purposes.

  ## Examples

      iex> grant_permission(user, "admin")
      :ok
  """
  def grant_permission(%User{id: user_id}, permission) when is_binary(permission) do
    GenServer.call(__MODULE__, {:grant_permission, user_id, permission})
  end

  @doc """
  Revokes a permission from a user for testing purposes.

  ## Examples

      iex> revoke_permission(user, "admin")
      :ok
  """
  def revoke_permission(%User{id: user_id}, permission) when is_binary(permission) do
    GenServer.call(__MODULE__, {:revoke_permission, user_id, permission})
  end

  ## GenServer Callbacks

  @impl GenServer
  def init(_opts) do
    {:ok, %{permissions: %{}}}
  end

  @impl GenServer
  def handle_call({:get_permissions, %User{id: user_id}}, _from, state) do
    permissions = Map.get(state.permissions, user_id, [])
    {:reply, permissions, state}
  end

  def handle_call({:grant_permission, user_id, permission}, _from, state) do
    current_permissions = Map.get(state.permissions, user_id, [])
    new_permissions = Enum.uniq([permission | current_permissions])
    new_state = put_in(state.permissions[user_id], new_permissions)
    {:reply, :ok, new_state}
  end

  def handle_call({:revoke_permission, user_id, permission}, _from, state) do
    current_permissions = Map.get(state.permissions, user_id, [])
    new_permissions = List.delete(current_permissions, permission)
    new_state = put_in(state.permissions[user_id], new_permissions)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_cast(:clear, _state) do
    {:noreply, %{permissions: %{}}}
  end
end
