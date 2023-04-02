defmodule Tiki.Checkouts do
  @moduledoc """
  The Checkouts context.
  """

  import Ecto.Query, warn: false
  alias Tiki.Repo

  alias Tiki.Checkouts.StripeCheckout

  @doc """
  Returns the list of stripe_checkouts.

  ## Examples

      iex> list_stripe_checkouts()
      [%StripeCheckout{}, ...]

  """
  def list_stripe_checkouts do
    Repo.all(StripeCheckout)
  end

  @doc """
  Gets a single stripe_checkout.

  Raises `Ecto.NoResultsError` if the Stripe checkout does not exist.

  ## Examples

      iex> get_stripe_checkout!(123)
      %StripeCheckout{}

      iex> get_stripe_checkout!(456)
      ** (Ecto.NoResultsError)

  """
  def get_stripe_checkout!(id), do: Repo.get!(StripeCheckout, id)

  @doc """
  Creates a stripe_checkout.

  ## Examples

      iex> create_stripe_checkout(%{field: value})
      {:ok, %StripeCheckout{}}

      iex> create_stripe_checkout(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_stripe_checkout(attrs \\ %{}) do
    %StripeCheckout{}
    |> StripeCheckout.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a stripe_checkout.

  ## Examples

      iex> update_stripe_checkout(stripe_checkout, %{field: new_value})
      {:ok, %StripeCheckout{}}

      iex> update_stripe_checkout(stripe_checkout, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_stripe_checkout(%StripeCheckout{} = stripe_checkout, attrs) do
    stripe_checkout
    |> StripeCheckout.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a stripe_checkout.

  ## Examples

      iex> delete_stripe_checkout(stripe_checkout)
      {:ok, %StripeCheckout{}}

      iex> delete_stripe_checkout(stripe_checkout)
      {:error, %Ecto.Changeset{}}

  """
  def delete_stripe_checkout(%StripeCheckout{} = stripe_checkout) do
    Repo.delete(stripe_checkout)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking stripe_checkout changes.

  ## Examples

      iex> change_stripe_checkout(stripe_checkout)
      %Ecto.Changeset{data: %StripeCheckout{}}

  """
  def change_stripe_checkout(%StripeCheckout{} = stripe_checkout, attrs \\ %{}) do
    StripeCheckout.changeset(stripe_checkout, attrs)
  end
end
