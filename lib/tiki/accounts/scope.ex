defmodule Tiki.Accounts.Scope do
  @moduledoc """
  Represents the authentication and authorization context for the current request.

  The scope contains information about who the user is, what team and event
  context they're operating in
  """

  alias Tiki.Accounts.User
  alias Tiki.Teams.Team
  alias Tiki.Events.Event

  defstruct user: nil, team: nil, event: nil

  @funs %{
    user: &Tiki.Accounts.get_user!/1,
    team: &Tiki.Teams.get_team!/1,
    event: &Tiki.Events.get_event!/1
  }

  @doc """
  Creates a scope for the given user.

  Returns nil if no user is given.
  """
  def for_user(%User{} = user) do
    %__MODULE__{user: user}
  end

  def for_user(nil), do: nil

  def put_team(%__MODULE__{} = scope, %Team{} = team) do
    %{scope | team: team}
  end

  def put_team(%__MODULE__{} = scope, nil), do: scope
  def put_team(nil, _), do: nil

  def put_event(%__MODULE__{} = scope, %Event{} = event) do
    %{scope | event: event}
  end

  def put_event(nil, _), do: nil

  @doc """
  Helper to create a scope from a keyword list

  ## Examples

    iex> Tiki.Accounts.Scope.for(user: 1, team: 1, event: "1aa6a96c-658b-41b0-a4db-ae8116bac3d9")
    %Tiki.Accounts.Scope{
      user: %Tiki.Accounts.User{
        id: 1,
        ...
      },
      team: %Tiki.Teams.Team{
        id: 1,
        ...
      },
      event: %Tiki.Events.Event{
        id: "1aa6a96c-658b-41b0-a4db-ae8116bac3d9",
        ...
      }
    }
  """
  def for(opts) when is_list(opts) do
    Enum.reduce(opts, %__MODULE__{}, fn {name, value}, scope ->
      Map.put(scope, name, apply(@funs[name], [value]))
    end)
  end
end
