defmodule Tiki.Teams do
  @moduledoc """
  The Teams context.
  """

  import Ecto.Query, warn: false
  alias Tiki.Teams.Membership
  alias Ecto.Multi
  alias Tiki.Repo

  alias Tiki.Teams.Team

  @doc """
  Returns the list of teams.

  ## Examples

      iex> list_teams()
      [%Team{}, ...]

  """
  def list_teams do
    Repo.all(Team)
  end

  @doc """
  Gets a single team.

  Raises `Ecto.NoResultsError` if the Team does not exist.

  ## Examples

      iex> get_team!(123)
      %Team{}

      iex> get_team!(456)
      ** (Ecto.NoResultsError)

  """
  def get_team!(id), do: Repo.get!(Team, id)

  @doc """
  Gets statistics for an event. Returns a map with stats. Current statistics:

  * `:total_sales`, total sales in SEK
  * `:tickets_sold` total tickets sold
  """
  def get_team_stats!(id) do
    orders =
      Tiki.Orders.order_stats_query()
      |> join(:inner, [o], e in assoc(o, :event))
      |> where([..., e], e.team_id == ^id)

    query =
      from o in subquery(orders),
        select: %{
          total_sales: coalesce(sum(o.order_price), 0),
          tickets_sold: coalesce(sum(o.ticket_count), 0),
          total_events:
            subquery(from e in Tiki.Events.Event, where: e.team_id == ^id, select: count(e.id))
        }

    old_orders = where(orders, [o], o.inserted_at <= fragment("now() - interval '1 month'"))

    last_month_query =
      from o in subquery(old_orders),
        select: %{
          total_sales: coalesce(sum(o.order_price), 0),
          tickets_sold: coalesce(sum(o.ticket_count), 0),
          total_events:
            subquery(
              from e in Tiki.Events.Event,
                where:
                  e.team_id == ^id and e.inserted_at >= fragment("now() - interval '1 month'"),
                select: count(e.id)
            )
        }

    last_month = Repo.one!(last_month_query)
    current = Repo.one!(query)

    Map.put(current, :last_month, last_month)
  end

  @doc """
  Gets a single team. Returns either team or nil if not found.

  ## Examples

      iex> get_team(123)
      %Team{}

      iex> get_team(456)
      nil

  """
  def get_team(id), do: Repo.get(Team, id)

  @doc """
  Creates a team.

  ## Examples

      iex> create_team(%{field: value})
      {:ok, %Team{}}

      iex> create_team(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_team(attrs \\ %{}, opts \\ []) do
    member_ids = Keyword.get(opts, :members, [])
    team = Team.changeset(%Team{}, attrs)

    multi = Multi.insert(Multi.new(), :team, team)

    result =
      Enum.reduce(member_ids, multi, fn id, multi ->
        Multi.insert(multi, "membership_#{id}", fn %{team: team} ->
          %Membership{team_id: team.id}
          |> Membership.changeset(%{user_id: id, role: :admin})
        end)
      end)
      |> Repo.transaction()

    case result do
      {:ok, %{team: team}} ->
        {:ok, team}

      {:error, :team, changeset, _} ->
        {:error, changeset}

      {:error, membership_id, changeset, _} when is_binary(membership_id) ->
        {:error, changeset}
    end
  end

  @doc """
  Updates a team.

  ## Examples

      iex> update_team(team, %{field: new_value})
      {:ok, %Team{}}

      iex> update_team(team, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_team(%Team{} = team, attrs) do
    team
    |> Team.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a team.

  ## Examples

      iex> delete_team(team)
      {:ok, %Team{}}

      iex> delete_team(team)
      {:error, %Ecto.Changeset{}}

  """
  def delete_team(%Team{} = team) do
    Repo.delete(team)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking team changes.

  ## Examples

      iex> change_team(team)
      %Ecto.Changeset{data: %Team{}}

  """
  def change_team(%Team{} = team, attrs \\ %{}) do
    Team.changeset(team, attrs)
  end

  alias Tiki.Teams.Membership

  @doc """
  Returns the list of team_membership.

  ## Examples

      iex> list_team_membership()
      [%Membership{}, ...]

  """
  def list_team_membership do
    Repo.all(Membership)
  end

  @doc """
  Gets a single membership. Also preloads the user and team
  for the membership.

  Raises `Ecto.NoResultsError` if the Membership does not exist.

  ## Examples

      iex> get_membership!(123)
      %Membership{}

      iex> get_membership!(456)
      ** (Ecto.NoResultsError)

  """
  def get_membership!(id) do
    query =
      from m in Membership,
        where: m.id == ^id,
        join: u in assoc(m, :user),
        join: t in assoc(m, :team),
        preload: [user: u, team: t]

    Repo.one!(query)
  end

  @doc """
  Creates a membership with authorization.

  ## Examples

      iex> create_membership(scope, team_id, %{user_id: 123, role: :member})
      {:ok, %Membership{}}

      iex> create_membership(scope, team_id, %{user_id: 123})
      {:error, %Changeset{}}


      iex> create_membership(unauthorized_scope, team_id, attrs)
      {:error, :unauthorized}

  """
  def create_membership(%Tiki.Accounts.Scope{} = scope, team_id, attrs \\ %{})
      when is_integer(team_id) do
    team = get_team!(team_id)

    with :ok <- Tiki.Policy.authorize(:team_update, scope.user, team) do
      %Membership{team_id: team_id}
      |> Membership.changeset(attrs)
      |> Repo.insert()
    end
  end

  @doc """
  Updates a membership.
  ## Examples

      iex> update_membership(scope, membership, %{role: :admin})
      {:ok, %Membership{}}

      iex> update_membership(unauthorized_scope, membership, attrs)
      {:error, :unauthorized}

  """
  def update_membership(%Tiki.Accounts.Scope{} = scope, %Membership{} = membership, attrs) do
    team = get_team!(membership.team_id)

    with :ok <- Tiki.Policy.authorize(:team_update, scope.user, team) do
      membership
      |> Membership.changeset(attrs)
      |> Repo.update()
    end
  end

  @doc """
  Deletes a membership.

  ## Examples

      iex> delete_membership(membership)
      {:ok, %Membership{}}

      iex> delete_membership(membership)
      {:error, %Ecto.Changeset{}}

  """
  def delete_membership(%Membership{} = membership) do
    Repo.delete(membership)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking membership changes.

  ## Examples

      iex> change_membership(membership)
      %Ecto.Changeset{data: %Membership{}}

  """
  def change_membership(%Membership{} = membership, attrs \\ %{}) do
    Membership.changeset(membership, attrs)
  end

  @doc """
  Returns all the teams that a user is member of.

  ## Examples

      iex> get_teams_for_user(123)
      [%Team{}, ...]

  """
  def get_teams_for_user(user_id) do
    query =
      from m in Team,
        join: membership in assoc(m, :members),
        where: membership.user_id == ^user_id

    Repo.all(query)
  end

  @doc """
  Returns all the team meberships for a given user

  ## Examples

      iex> get_memberships_for_user(123)
      [%Membership{}, ...]

  """
  def get_memberships_for_user(user_id) do
    query =
      from m in Membership,
        where: m.user_id == ^user_id

    Repo.all(query)
  end

  @doc """
  Preloads all the teams that a user is member of, given a user or
  a list of users.

  ## Examples

      iex> preload_teams(users)
      [%User{memberships: [%Membership{team: %Team{}}, ...]}, ...]

      iex> preload_teams(user)
      %User{memberships: [%Membership{team: %Team{}}, ...]}
  """
  def preload_teams(users) do
    query =
      from m in Membership,
        join: team in assoc(m, :team),
        preload: [team: team]

    Repo.preload(users, memberships: query)
  end

  @doc """
  Returns the current memebrships of a team.

  ## Examples

      iex> get_members_for_team(123)
      [%Membership{user: %User{}}, ...]
  """
  def get_members_for_team(team_id) do
    query =
      from m in Membership,
        join: u in assoc(m, :user),
        where: m.team_id == ^team_id,
        preload: [user: u]

    Repo.all(query)
  end
end
