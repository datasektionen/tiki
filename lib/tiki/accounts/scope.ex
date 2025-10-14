defmodule Tiki.Accounts.Scope do
  @moduledoc """
  Represents the authentication and authorization context for the current request.

  The scope contains information about who the user is and what team context
  they're operating in. It does NOT contain specific resources like events or
  orders - those are stored in assigns.

  ## Examples

      # Create a scope for a user without a team
      iex> Scope.for_user(user)
      %Scope{user: user, team: nil}

      # Create a scope for a user with a team
      iex> Scope.for_user_and_team(user, team)
      %Scope{user: user, team: team}

  """

  alias Tiki.Accounts.User
  alias Tiki.Teams.Team

  defstruct [:user, :team]

  @type t :: %__MODULE__{
          user: User.t() | nil,
          team: Team.t() | nil
        }

  @doc """
  Creates a scope for the given user.

  Returns nil if no user is given.
  """
  @spec for_user(User.t()) :: t()
  @spec for_user(nil) :: nil
  def for_user(%User{} = user) do
    %__MODULE__{user: user, team: nil}
  end

  def for_user(nil), do: nil

  @doc """
  Creates a scope for the given user and team.

  Returns a scope with just the user if no team is given.
  Returns nil if no user is given.
  """
  @spec for_user_and_team(User.t(), Team.t() | nil) :: t()
  @spec for_user_and_team(nil, any()) :: nil
  def for_user_and_team(%User{} = user, %Team{} = team) do
    %__MODULE__{user: user, team: team}
  end

  def for_user_and_team(%User{} = user, nil) do
    for_user(user)
  end

  def for_user_and_team(nil, _team), do: nil
end
