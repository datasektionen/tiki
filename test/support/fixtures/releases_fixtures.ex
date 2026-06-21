defmodule Tiki.ReleasesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Tiki.Releases` context.
  """

  @doc """
  Generate a release.
  """
  def release_fixture(attrs \\ %{}) do
    ticket_batch =
      Map.get_lazy(attrs, :ticket_batch, &Tiki.TicketsFixtures.ticket_batch_fixture/0)

    user = Tiki.AccountsFixtures.admin_user_fixture()
    scope = Tiki.Accounts.Scope.for(event: ticket_batch.event_id, user: user.id)

    {:ok, release} =
      attrs
      |> Map.drop([:ticket_batch])
      |> Enum.into(%{
        name: "some name",
        name_sv: "some name_sv",
        opens_at: ~U[2025-09-10 13:05:00Z],
        signup_window_minutes: 60,
        purchase_window_minutes: 60,
        max_tickets_per_order: 2,
        ticket_batch_id: ticket_batch.id
      })
      |> then(&Tiki.Releases.create_release(scope, &1))

    Tiki.Repo.get!(Tiki.Releases.Release, release.id)
  end

  @doc """
  Build a Release struct in the given phase without hitting the DB.
  Useful for unit-testing `get_phase/1`.
  """
  def release_in_phase(:scheduled) do
    opens_at = DateTime.add(DateTime.utc_now(), 60, :minute)

    %Tiki.Releases.Release{
      opens_at: opens_at,
      signup_window_minutes: 10,
      purchase_window_minutes: 30,
      drawn_at: nil
    }
  end

  def release_in_phase(:open) do
    opens_at = DateTime.add(DateTime.utc_now(), -5, :minute)

    %Tiki.Releases.Release{
      opens_at: opens_at,
      signup_window_minutes: 20,
      purchase_window_minutes: 30,
      drawn_at: nil
    }
  end

  def release_in_phase(:drawing) do
    opens_at = DateTime.add(DateTime.utc_now(), -30, :minute)

    %Tiki.Releases.Release{
      opens_at: opens_at,
      signup_window_minutes: 10,
      purchase_window_minutes: 60,
      drawn_at: nil
    }
  end

  def release_in_phase(:purchase) do
    opens_at = DateTime.add(DateTime.utc_now(), -30, :minute)
    drawn_at = DateTime.add(DateTime.utc_now(), -15, :minute)

    %Tiki.Releases.Release{
      opens_at: opens_at,
      signup_window_minutes: 10,
      purchase_window_minutes: 60,
      drawn_at: drawn_at
    }
  end

  def release_in_phase(:released) do
    opens_at = DateTime.add(DateTime.utc_now(), -120, :minute)

    %Tiki.Releases.Release{
      opens_at: opens_at,
      signup_window_minutes: 30,
      purchase_window_minutes: 30,
      drawn_at: nil
    }
  end

  @doc """
  Creates a persisted release in a specific lifecycle phase by manipulating timestamps.
  """
  def persisted_release_in_phase(phase, attrs \\ %{}) do
    base_release = release_in_phase(phase)

    ticket_batch =
      Map.get_lazy(attrs, :ticket_batch, &Tiki.TicketsFixtures.ticket_batch_fixture/0)

    user = Tiki.AccountsFixtures.admin_user_fixture()
    scope = Tiki.Accounts.Scope.for(event: ticket_batch.event_id, user: user.id)

    {:ok, release} =
      attrs
      |> Map.drop([:ticket_batch])
      |> Enum.into(%{
        name: "some name",
        name_sv: "some name_sv",
        opens_at: base_release.opens_at,
        signup_window_minutes: base_release.signup_window_minutes,
        purchase_window_minutes: base_release.purchase_window_minutes,
        max_tickets_per_order: 5,
        ticket_batch_id: ticket_batch.id
      })
      |> then(&Tiki.Releases.create_release(scope, &1))

    release = Tiki.Repo.get!(Tiki.Releases.Release, release.id)

    if base_release.drawn_at do
      release
      |> Tiki.Releases.Release.changeset(%{drawn_at: base_release.drawn_at})
      |> Tiki.Repo.update!()
    else
      release
    end
  end

  @doc """
  Creates a signup for a user for a release with given items.
  `items` is a map of %{ticket_type_id => quantity}.
  """
  def signup_fixture(release, user, items \\ %{}) do
    {:ok, signup} = Tiki.Releases.sign_up(release.id, items, user.id)
    signup
  end
end
