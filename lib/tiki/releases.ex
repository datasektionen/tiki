defmodule Tiki.Releases do
  @moduledoc """
  The Releases context.
  """

  import Ecto.Query, warn: false
  alias Tiki.Repo

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
  def get_release!(id), do: Repo.get!(Release, id)

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
          from s in Signup, where: s.release_id == ^release_id, order_by: s.position, limit: 1
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
end
