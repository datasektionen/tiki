defmodule PermissionService do
  @moduledoc """
  Behaviour for permission services.

  This behaviour defines the contract for services that manage user permissions.
  Implementations can be external APIs (like Hive) or test mocks.
  """

  alias Tiki.Accounts.User

  @doc """
  Starts the permission service GenServer.

  This is called when the service is added to the supervision tree.
  """
  @callback start_link(keyword()) :: GenServer.on_start()

  @doc """
  Gets a list of permissions for the given user.

  Returns a list of permission strings (e.g., ["admin", "audit"]).
  """
  @callback get_permissions(User.t()) :: [String.t()]

  @doc """
  Clears the permission cache.

  This is useful for invalidating cached permissions when they change.
  """
  @callback clear() :: :ok
end
