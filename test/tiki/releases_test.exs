defmodule Tiki.ReleasesTest do
  use Tiki.DataCase

  alias Tiki.Releases

  describe "releases" do
    alias Tiki.Releases.Release

    import Tiki.ReleasesFixtures
    import Tiki.TicketsFixtures
    import Tiki.AccountsFixtures
    import Tiki.EventsFixtures

    @invalid_attrs %{
      name: nil,
      name_sv: nil,
      opens_at: nil,
      signup_window_minutes: nil,
      purchase_window_minutes: nil
    }

    test "list_releases/0 returns all releases" do
      release = release_fixture()
      assert Releases.list_releases() == [release]
    end

    test "get_release!/1 returns the release with given id" do
      release = release_fixture() |> Repo.preload(:ticket_batch)
      assert Releases.get_release!(release.id) == release
    end

    test "create_release/1 with valid data creates a release" do
      ticket_batch = Tiki.TicketsFixtures.ticket_batch_fixture()
      user = Tiki.AccountsFixtures.admin_user_fixture()
      scope = Tiki.Accounts.Scope.for(event: ticket_batch.event_id, user: user.id)

      valid_attrs = %{
        name: "some name",
        name_sv: "some name_sv",
        opens_at: ~U[2025-09-10 13:05:00Z],
        signup_window_minutes: 60,
        purchase_window_minutes: 60,
        ticket_batch_id: ticket_batch.id
      }

      assert {:ok, %Release{} = release} = Releases.create_release(scope, valid_attrs)

      assert release.name == "some name"
      assert release.name_sv == "some name_sv"
      assert release.opens_at == ~U[2025-09-10 13:05:00Z]
      assert release.signup_window_minutes == 60
      assert release.purchase_window_minutes == 60
    end

    test "create_release/1 with invalid data returns error changeset" do
      ticket_batch = Tiki.TicketsFixtures.ticket_batch_fixture()
      user = Tiki.AccountsFixtures.admin_user_fixture()
      scope = Tiki.Accounts.Scope.for(event: ticket_batch.event_id, user: user.id)

      assert {:error, %Ecto.Changeset{}} = Releases.create_release(scope, @invalid_attrs)
    end

    test "create_release/2 rejects a second overlapping release for the same batch" do
      ticket_batch = Tiki.TicketsFixtures.ticket_batch_fixture()
      user = Tiki.AccountsFixtures.admin_user_fixture()
      scope = Tiki.Accounts.Scope.for(event: ticket_batch.event_id, user: user.id)

      opens_at = DateTime.add(DateTime.utc_now(), 60, :minute)

      first_attrs = %{
        name: "first release",
        name_sv: "first release sv",
        opens_at: opens_at,
        signup_window_minutes: 30,
        purchase_window_minutes: 30,
        ticket_batch_id: ticket_batch.id
      }

      assert {:ok, _} = Releases.create_release(scope, first_attrs)

      # Second release overlaps: starts during the first's purchase window
      second_attrs = %{
        name: "second release",
        name_sv: "second release sv",
        opens_at: DateTime.add(opens_at, 20, :minute),
        signup_window_minutes: 30,
        purchase_window_minutes: 30,
        ticket_batch_id: ticket_batch.id
      }

      assert {:error, %Ecto.Changeset{}} = Releases.create_release(scope, second_attrs)
    end

    test "create_release/2 allows two non-overlapping releases on the same batch" do
      event = event_fixture()
      batch = ticket_batch_fixture(%{event: event})
      user = admin_user_fixture()
      scope = Tiki.Accounts.Scope.for(event: event.id, user: user.id)

      opens_at = ~U[2025-10-01 10:00:00Z]

      # First release: 10:00 → 11:00 (signup 30 + purchase 30)
      assert {:ok, _} =
               Releases.create_release(scope, %{
                 name: "first",
                 name_sv: "first sv",
                 opens_at: opens_at,
                 signup_window_minutes: 30,
                 purchase_window_minutes: 30,
                 ticket_batch_id: batch.id
               })

      # Second release starts exactly when the first ends: no overlap
      assert {:ok, _} =
               Releases.create_release(scope, %{
                 name: "second",
                 name_sv: "second sv",
                 opens_at: DateTime.add(opens_at, 60, :minute),
                 signup_window_minutes: 30,
                 purchase_window_minutes: 30,
                 ticket_batch_id: batch.id
               })
    end

    test "create_release/2 rejects an overlapping release on a descendant batch" do
      event = event_fixture()
      parent = ticket_batch_fixture(%{event: event})
      user = admin_user_fixture()
      scope = Tiki.Accounts.Scope.for(event: event.id, user: user.id)

      {:ok, child} =
        Tiki.Tickets.create_ticket_batch(scope, %{
          name: "child batch",
          max_size: 10,
          parent_batch_id: parent.id
        })

      opens_at = ~U[2025-10-01 10:00:00Z]

      # Release on the parent batch
      assert {:ok, _} =
               Releases.create_release(scope, %{
                 name: "parent release",
                 name_sv: "parent release sv",
                 opens_at: opens_at,
                 signup_window_minutes: 30,
                 purchase_window_minutes: 30,
                 ticket_batch_id: parent.id
               })

      # Overlapping release on the child batch should be rejected
      assert {:error, %Ecto.Changeset{} = cs} =
               Releases.create_release(scope, %{
                 name: "child release",
                 name_sv: "child release sv",
                 opens_at: DateTime.add(opens_at, 20, :minute),
                 signup_window_minutes: 30,
                 purchase_window_minutes: 30,
                 ticket_batch_id: child.id
               })

      assert {"overlaps with an existing release", _} = cs.errors[:ticket_batch_id]
    end

    test "create_release/2 rejects an overlapping release on an ancestor batch" do
      event = event_fixture()
      parent = ticket_batch_fixture(%{event: event})
      user = admin_user_fixture()
      scope = Tiki.Accounts.Scope.for(event: event.id, user: user.id)

      {:ok, child} =
        Tiki.Tickets.create_ticket_batch(scope, %{
          name: "child batch",
          max_size: 10,
          parent_batch_id: parent.id
        })

      opens_at = ~U[2025-10-01 10:00:00Z]

      # Release on the child batch
      assert {:ok, _} =
               Releases.create_release(scope, %{
                 name: "child release",
                 name_sv: "child release sv",
                 opens_at: opens_at,
                 signup_window_minutes: 30,
                 purchase_window_minutes: 30,
                 ticket_batch_id: child.id
               })

      # Overlapping release on the parent batch should be rejected
      assert {:error, %Ecto.Changeset{} = cs} =
               Releases.create_release(scope, %{
                 name: "parent release",
                 name_sv: "parent release sv",
                 opens_at: DateTime.add(opens_at, 20, :minute),
                 signup_window_minutes: 30,
                 purchase_window_minutes: 30,
                 ticket_batch_id: parent.id
               })

      assert {"overlaps with an existing release", _} = cs.errors[:ticket_batch_id]
    end

    test "update_release/2 rejects a timing update that would cause an overlap" do
      event = event_fixture()
      batch = ticket_batch_fixture(%{event: event})
      user = admin_user_fixture()
      scope = Tiki.Accounts.Scope.for(event: event.id, user: user.id)

      opens_at = ~U[2025-10-01 10:00:00Z]

      assert {:ok, _first} =
               Releases.create_release(scope, %{
                 name: "first",
                 name_sv: "first sv",
                 opens_at: opens_at,
                 signup_window_minutes: 30,
                 purchase_window_minutes: 30,
                 ticket_batch_id: batch.id
               })

      # Second release is safely after the first (starts at 11:00)
      assert {:ok, second} =
               Releases.create_release(scope, %{
                 name: "second",
                 name_sv: "second sv",
                 opens_at: DateTime.add(opens_at, 60, :minute),
                 signup_window_minutes: 30,
                 purchase_window_minutes: 30,
                 ticket_batch_id: batch.id
               })

      # Shifting the second release back into the first's window should be rejected
      assert {:error, %Ecto.Changeset{}} =
               Releases.update_release(second, %{
                 opens_at: DateTime.add(opens_at, 20, :minute)
               })
    end

    test "update_release/2 does not treat the release as overlapping with itself" do
      event = event_fixture()
      batch = ticket_batch_fixture(%{event: event})
      user = admin_user_fixture()
      scope = Tiki.Accounts.Scope.for(event: event.id, user: user.id)

      assert {:ok, release} =
               Releases.create_release(scope, %{
                 name: "release",
                 name_sv: "release sv",
                 opens_at: ~U[2025-10-01 10:00:00Z],
                 signup_window_minutes: 30,
                 purchase_window_minutes: 30,
                 ticket_batch_id: batch.id
               })

      # Updating a field unrelated to timing should not trigger an overlap error
      assert {:ok, _} = Releases.update_release(release, %{name: "updated name"})
    end

    test "update_release/2 with valid data updates the release" do
      release = release_fixture()

      update_attrs = %{
        name: "some updated name",
        name_sv: "some updated name_sv",
        opens_at: ~U[2025-09-11 13:05:00Z],
        signup_window_minutes: 90,
        purchase_window_minutes: 90
      }

      assert {:ok, %Release{} = release} = Releases.update_release(release, update_attrs)
      assert release.name == "some updated name"
      assert release.name_sv == "some updated name_sv"
      assert release.opens_at == ~U[2025-09-11 13:05:00Z]
      assert release.signup_window_minutes == 90
      assert release.purchase_window_minutes == 90
    end

    test "update_release/2 with invalid data returns error changeset" do
      release = release_fixture() |> Repo.preload(:ticket_batch)
      assert {:error, %Ecto.Changeset{}} = Releases.update_release(release, @invalid_attrs)
      assert release == Releases.get_release!(release.id)
    end

    test "change_release/1 returns a release changeset" do
      release = release_fixture()
      assert %Ecto.Changeset{} = Releases.change_release(release)
    end
  end
end
