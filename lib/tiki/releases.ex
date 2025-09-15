defmodule Tiki.Releases do
  @moduledoc """
  The Releases context.
  """

  import Ecto.Query, warn: false
  alias Tiki.Repo

  use Gettext, backend: TikiWeb.Gettext

  alias Tiki.Releases.Release
  alias Tiki.Releases.Signup

  @doc """
  Returns the list of releases.

  ## Examples

      iex> list_releases()
      [%Release{}, ...]

  """
  def list_releases do
    Repo.all(Release)
  end

  @doc """
  Gets a single release.

  Raises `Ecto.NoResultsError` if the Release does not exist.

  ## Examples

      iex> get_release!(123)
      %Release{}

      iex> get_release!(456)
      ** (Ecto.NoResultsError)

  """
  def get_release!(id) do
    query =
      from r in Release,
        where: r.id == ^id,
        join: b in assoc(r, :ticket_batch),
        preload: [ticket_batch: b]

    Repo.one!(query)
  end

  @doc """
  Creates a release.

  ## Examples

      iex> create_release(%{field: value})
      {:ok, %Release{}}

      iex> create_release(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_release(attrs \\ %{}) do
    %Release{}
    |> Release.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a release.

  ## Examples

      iex> update_release(release, %{field: new_value})
      {:ok, %Release{}}

      iex> update_release(release, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_release(%Release{} = release, attrs) do
    release
    |> Release.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a release.

  ## Examples

      iex> delete_release(release)
      {:ok, %Release{}}

      iex> delete_release(release)
      {:error, %Ecto.Changeset{}}

  """
  def delete_release(%Release{} = release) do
    Repo.delete(release)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking release changes.

  ## Examples

      iex> change_release(release)
      %Ecto.Changeset{data: %Release{}}

  """
  def change_release(%Release{} = release, attrs \\ %{}) do
    Release.changeset(release, attrs)
  end

  @doc """
  Returns a release sign up for a given user id for a particular release. Returns the
  sign up or nil if one does not exist.
  """

  def get_user_sign_up(user_id, release_id) do
    Repo.get_by(Signup, user_id: user_id, release_id: release_id)
  end

  def sign_up_user(user_id, release_id) do
    Repo.transaction(fn ->
      last_signup =
        Repo.one(
          from s in Signup,
            where: s.release_id == ^release_id,
            order_by: [desc: s.position],
            limit: 1
        )

      position = if last_signup, do: last_signup.position + 1, else: 1

      %Signup{}
      |> Signup.changeset(%{
        user_id: user_id,
        release_id: release_id,
        status: :pending,
        position: position,
        signed_up_at: DateTime.utc_now()
      })
      |> Repo.insert!()
    end)
  end

  def get_release_sign_ups(release_id) do
    query =
      from s in Signup,
        where: s.release_id == ^release_id,
        left_join: u in assoc(s, :user),
        order_by: s.position,
        preload: [user: u]

    Repo.all(query)
  end

  def shuffle_sign_ups(release_id) do
    sub_query =
      from s in Signup,
        where: s.release_id == ^release_id,
        select: %{id: s.id, position: fragment("ROW_NUMBER() OVER (ORDER BY RANDOM())")}

    query =
      from s in Signup,
        join: ss in subquery(sub_query),
        on: s.id == ss.id,
        update: [set: [position: ss.position]]

    Repo.transaction(fn ->
      accepted =
        Repo.one(
          from s in Signup, where: s.release_id == ^release_id and s.status == :accepted, limit: 1
        )

      if is_nil(accepted) do
        Repo.query!("SET CONSTRAINTS release_signups_release_id_position_unique DEFERRED")

        Repo.update_all(query, [])

        get_release_sign_ups(release_id)
      else
        Repo.rollback(gettext("Release is already allocated."))
      end
    end)
  end

  def update_sort_order(release_id, from, to) do
    Repo.transaction(fn ->
      accepted =
        Repo.one(
          from s in Signup, where: s.release_id == ^release_id and s.status == :accepted, limit: 1
        )

      if is_nil(accepted) do
        Repo.query!("SET CONSTRAINTS release_signups_release_id_position_unique DEFERRED")

        moved =
          Repo.one!(from(s in Signup, where: s.release_id == ^release_id and s.position == ^from))

        if from < to do
          from(s in Signup,
            where: s.release_id == ^release_id and s.position > ^from and s.position <= ^to,
            update: [inc: [position: -1]]
          )
          |> Repo.update_all([])
        else
          from(s in Signup,
            where: s.release_id == ^release_id and s.position >= ^to and s.position < ^from,
            update: [inc: [position: 1]]
          )
          |> Repo.update_all([])
        end

        moved
        |> Signup.changeset(%{position: to})
        |> Repo.update!()

        get_release_sign_ups(release_id)
      else
        Repo.rollback(gettext("Release is already allocated."))
      end
    end)
  end

  def allocate_sign_ups(release_id) do
    Repo.transaction(fn ->
      accepted =
        Repo.one(
          from s in Signup, where: s.release_id == ^release_id and s.status == :accepted, limit: 1
        )

      if is_nil(accepted) do
        release =
          Repo.one!(
            from r in Release,
              where: r.id == ^release_id,
              join: b in assoc(r, :ticket_batch),
              preload: [ticket_batch: b]
          )

        allocated =
          from s in Signup,
            where: s.release_id == ^release_id,
            where: s.position <= ^release.ticket_batch.max_size,
            update: [set: [status: :accepted]]

        non_allocated =
          from s in Signup,
            where: s.release_id == ^release_id,
            where: s.position > ^release.ticket_batch.max_size,
            update: [set: [status: :rejected]]

        Repo.update_all(allocated, [])
        Repo.update_all(non_allocated, [])

        get_release_sign_ups(release_id)
      else
        Repo.rollback(gettext("Release is already allocated."))
      end
    end)
  end

  def is_active?(%Release{} = release) do
    DateTime.compare(DateTime.utc_now(), release.ends_at) == :lt &&
      DateTime.compare(DateTime.utc_now(), release.starts_at) == :gt
  end
end
