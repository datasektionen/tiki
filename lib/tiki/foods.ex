defmodule Tiki.Foods do
  @moduledoc """
  The Foods context.
  """

  import Ecto.Query, warn: false
  alias Tiki.Repo

  alias Tiki.Foods.Food
  alias Tiki.Accounts.User

  @doc """
  Returns the list of foods.

  ## Examples

    iex> list_foods()
    [%Food{}, ...]

  """
  def list_foods do
    Repo.all(Food)
  end

  @doc """
  Lists foods with ids

  ## Examples
      iex> list_foods_with_ids(["2", "3"])
      [%Food{id: 2}, ...]
  """
  def list_foods_with_ids(ids) do
    Repo.all(from f in Food, where: f.id in ^ids)
  end

  @doc """
  Gets a single food.

  Raises `Ecto.NoResultsError` if the Food does not exist.

  ## Examples

      iex> get_food!(123)
      %Food{}

      iex> get_food!(456)
      ** (Ecto.NoResultsError)

  """
  def get_food!(id), do: Repo.get!(Food, id)

  @doc """
  Creates a food.

  ## Examples

      iex> create_food(%{field: value})
      {:ok, %Food{}}

      iex> create_food(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_food(attrs \\ %{}) do
    %Food{}
    |> Food.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a food.

  ## Examples

      iex> update_food(food, %{field: new_value})
      {:ok, %Food{}}

      iex> update_food(food, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_food(%Food{} = food, attrs) do
    food
    |> Food.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a food.

  ## Examples

      iex> delete_food(food)
      {:ok, %Food{}}

      iex> delete_food(food)
      {:error, %Ecto.Changeset{}}

  """
  def delete_food(%Food{} = food) do
    Repo.delete(food)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking food changes.

  ## Examples

      iex> change_food(food)
      %Ecto.Changeset{data: %Food{}}

  """
  def change_food(%Food{} = food, attrs \\ %{}) do
    Food.changeset(food, attrs)
  end

  def list_users_with_food_preference(food_id) do
    query =
      from u in User,
        join: f in assoc(u, :foods),
        where: f.id == ^food_id

    Repo.all(query)
  end

  def remove_food_preference_from_user(user_id, food_id) do
    query =
      from fp in "food_preferences",
        where: fp.food_id == ^food_id and fp.user_id == ^user_id

    Repo.delete_all(query)
  end
end
