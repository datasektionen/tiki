defmodule Tiki.ReleasesLifecycleTest do
  use Tiki.DataCase

  alias Tiki.Releases
  alias Tiki.Releases.{DrawEngine, Signup}
  alias Tiki.Tickets
  alias Tiki.Workers.EventSchedulerWorker

  import Tiki.ReleasesFixtures
  import Tiki.TicketsFixtures
  import Tiki.AccountsFixtures
  import Tiki.OrdersFixtures

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Builds an open-phase release backed by a real ticket_batch + ticket_type
  # so that sign_up can validate ticket types. Returns {release, ticket_type}.
  defp open_release_with_ticket_type(batch_attrs \\ %{}) do
    batch = ticket_batch_fixture(Map.merge(%{max_size: 10}, batch_attrs))
    tt = ticket_type_fixture(%{ticket_batch_id: batch.id, purchase_limit: 5})
    release = persisted_release_in_phase(:open, %{ticket_batch: batch, max_tickets_per_order: 5})
    {release, tt}
  end

  # ---------------------------------------------------------------------------
  # get_phase/1
  # ---------------------------------------------------------------------------

  describe "get_phase/1" do
    test "returns :scheduled when opens_at is in the future" do
      assert Releases.get_phase(release_in_phase(:scheduled)) == :scheduled
    end

    test "returns :open between opens_at and lottery_end" do
      assert Releases.get_phase(release_in_phase(:open)) == :open
    end

    test "returns :drawing after lottery_end when draw has not run" do
      assert Releases.get_phase(release_in_phase(:drawing)) == :drawing
    end

    test "returns :purchase when draw has run and purchase window is open" do
      assert Releases.get_phase(release_in_phase(:purchase)) == :purchase
    end

    test "returns :released after purchase_end regardless of drawn_at" do
      assert Releases.get_phase(release_in_phase(:released)) == :released
    end
  end

  # ---------------------------------------------------------------------------
  # get_user_sign_up/2
  # ---------------------------------------------------------------------------

  describe "get_user_sign_up/2" do
    test "returns nil when user has no signup for the release" do
      {release, _tt} = open_release_with_ticket_type()
      user = user_fixture()
      assert Releases.get_user_sign_up(user.id, release.id) == nil
    end

    test "returns the signup with preloads when it exists" do
      {release, tt} = open_release_with_ticket_type()
      user = user_fixture()

      {:ok, signup} = Releases.sign_up(release.id, %{tt.id => 1}, user.id)

      result = Releases.get_user_sign_up(user.id, release.id)
      assert result.id == signup.id
      assert result.release_id == release.id
      assert result.user_id == user.id
      assert length(result.items) == 1
      assert hd(result.items).ticket_type_id == tt.id
    end
  end

  # ---------------------------------------------------------------------------
  # sign_up/3
  # ---------------------------------------------------------------------------

  describe "sign_up/3" do
    test "creates a signup for an open release" do
      {release, tt} = open_release_with_ticket_type()
      user = user_fixture()

      assert {:ok, signup} = Releases.sign_up(release.id, %{tt.id => 2}, user.id)
      assert signup.release_id == release.id
      assert signup.user_id == user.id
      assert signup.status == :queued
      assert length(signup.items) == 1
      assert hd(signup.items).quantity == 2
    end

    test "returns :unauthenticated when user_id is nil" do
      {release, tt} = open_release_with_ticket_type()
      assert {:error, :unauthenticated} = Releases.sign_up(release.id, %{tt.id => 1}, nil)
    end

    test "returns :not_open when release is not in the open phase" do
      batch = ticket_batch_fixture(%{max_size: 10})
      tt = ticket_type_fixture(%{ticket_batch_id: batch.id})
      release = persisted_release_in_phase(:scheduled, %{ticket_batch: batch})
      user = user_fixture()

      assert {:error, :not_open} = Releases.sign_up(release.id, %{tt.id => 1}, user.id)
    end

    test "returns :not_open when release is already released" do
      batch = ticket_batch_fixture(%{max_size: 10})
      tt = ticket_type_fixture(%{ticket_batch_id: batch.id})
      release = persisted_release_in_phase(:released, %{ticket_batch: batch})
      user = user_fixture()

      assert {:error, :not_open} = Releases.sign_up(release.id, %{tt.id => 1}, user.id)
    end

    test "returns :exceeds_ticket_limit when quantity exceeds purchase_limit" do
      batch = ticket_batch_fixture(%{max_size: 10})
      tt = ticket_type_fixture(%{ticket_batch_id: batch.id, purchase_limit: 1})

      release =
        persisted_release_in_phase(:open, %{ticket_batch: batch, max_tickets_per_order: 5})

      user = user_fixture()

      assert {:error, :exceeds_ticket_limit} =
               Releases.sign_up(release.id, %{tt.id => 2}, user.id)
    end

    test "returns :exceeds_order_limit when total exceeds max_tickets_per_order" do
      batch = ticket_batch_fixture(%{max_size: 10})
      tt = ticket_type_fixture(%{ticket_batch_id: batch.id, purchase_limit: 10})

      release =
        persisted_release_in_phase(:open, %{ticket_batch: batch, max_tickets_per_order: 1})

      user = user_fixture()

      assert {:error, :exceeds_order_limit} = Releases.sign_up(release.id, %{tt.id => 2}, user.id)
    end

    test "prevents duplicate signups from the same user" do
      {release, tt} = open_release_with_ticket_type()
      user = user_fixture()

      assert {:ok, _} = Releases.sign_up(release.id, %{tt.id => 1}, user.id)
      assert {:error, _} = Releases.sign_up(release.id, %{tt.id => 1}, user.id)
    end

    test "broadcasts :signup_updated on success" do
      {release, tt} = open_release_with_ticket_type()
      user = user_fixture()
      Releases.subscribe_event(release.event_id, user.id)

      {:ok, signup} = Releases.sign_up(release.id, %{tt.id => 1}, user.id)

      assert_received {:signup_updated, ^signup}
    end
  end

  # ---------------------------------------------------------------------------
  # cancel_signup/2
  # ---------------------------------------------------------------------------

  describe "cancel_signup/2" do
    test "cancels a queued signup during the open phase" do
      {release, tt} = open_release_with_ticket_type()
      user = user_fixture()
      scope = Tiki.Accounts.Scope.for(user: user.id)

      {:ok, signup} = Releases.sign_up(release.id, %{tt.id => 1}, user.id)

      assert {:ok, _} = Releases.cancel_signup(scope, signup.id)
      assert Releases.get_user_sign_up(user.id, release.id) == nil
    end

    test "returns :not_found for a non-existent signup" do
      user = user_fixture()
      scope = Tiki.Accounts.Scope.for(user: user.id)
      assert {:error, :not_found} = Releases.cancel_signup(scope, Ecto.UUID.generate())
    end

    test "returns :not_found when the user does not own the signup" do
      {release, tt} = open_release_with_ticket_type()
      owner = user_fixture()
      other = user_fixture()
      scope = Tiki.Accounts.Scope.for(user: other.id)

      {:ok, signup} = Releases.sign_up(release.id, %{tt.id => 1}, owner.id)

      assert {:error, :not_found} = Releases.cancel_signup(scope, signup.id)
    end

    test "returns :not_open when the release is no longer in the open phase" do
      batch = ticket_batch_fixture(%{max_size: 10})
      tt = ticket_type_fixture(%{ticket_batch_id: batch.id})
      user = user_fixture()
      scope = Tiki.Accounts.Scope.for(user: user.id)

      # Sign up while open
      open_release = persisted_release_in_phase(:open, %{ticket_batch: batch})
      {:ok, signup} = Releases.sign_up(open_release.id, %{tt.id => 1}, user.id)

      # Force the release to look released by moving timestamps into the past
      past = DateTime.add(DateTime.utc_now(), -200, :minute)

      open_release
      |> Tiki.Releases.Release.changeset(%{opens_at: past})
      |> Repo.update!()

      assert {:error, :not_open} = Releases.cancel_signup(scope, signup.id)
    end

    test "broadcasts :signup_deleted on success" do
      {release, tt} = open_release_with_ticket_type()
      user = user_fixture()
      scope = Tiki.Accounts.Scope.for(user: user.id)

      {:ok, signup} = Releases.sign_up(release.id, %{tt.id => 1}, user.id)

      Releases.subscribe(release.id, sign_ups: true)
      {:ok, _} = Releases.cancel_signup(scope, signup.id)

      assert_received {:signup_deleted, deleted}
      assert signup.id == deleted.id
    end
  end

  # ---------------------------------------------------------------------------
  # seed_signup/2
  # ---------------------------------------------------------------------------

  describe "seed_signup/2" do
    test "promotes a queued signup to seeded" do
      {release, tt} = open_release_with_ticket_type()
      user = user_fixture()
      admin = admin_user_fixture()
      {:ok, signup} = Releases.sign_up(release.id, %{tt.id => 1}, user.id)

      assert {:ok, updated} = Releases.seed_signup(signup.id, admin.id)
      assert updated.status == :seeded
      assert updated.decided_by_id == admin.id
      assert updated.decided_at != nil
    end

    test "demotes a seeded signup back to queued (toggle)" do
      {release, tt} = open_release_with_ticket_type()
      user = user_fixture()
      admin = admin_user_fixture()
      {:ok, signup} = Releases.sign_up(release.id, %{tt.id => 1}, user.id)
      {:ok, seeded} = Releases.seed_signup(signup.id, admin.id)
      assert seeded.status == :seeded

      assert {:ok, toggled} = Releases.seed_signup(signup.id, admin.id)
      assert toggled.status == :queued
    end

    test "promotes a rejected signup to seeded" do
      {release, tt} = open_release_with_ticket_type()
      user = user_fixture()
      admin = admin_user_fixture()
      {:ok, signup} = Releases.sign_up(release.id, %{tt.id => 1}, user.id)
      {:ok, _} = Releases.reject_signup(signup.id, admin.id)

      assert {:ok, updated} = Releases.seed_signup(signup.id, admin.id)
      assert updated.status == :seeded
    end

    test "returns :invalid_status for drawn signups" do
      {release, tt} = open_release_with_ticket_type()
      user = user_fixture()
      admin = admin_user_fixture()
      {:ok, signup} = Releases.sign_up(release.id, %{tt.id => 1}, user.id)

      # Force status to :drawn directly
      Repo.update_all(
        from(s in Signup, where: s.id == ^signup.id),
        set: [status: :drawn]
      )

      assert {:error, :invalid_status} = Releases.seed_signup(signup.id, admin.id)
    end

    test "broadcasts :signup_updated on success" do
      {release, tt} = open_release_with_ticket_type()
      user = user_fixture()
      admin = admin_user_fixture()
      {:ok, signup} = Releases.sign_up(release.id, %{tt.id => 1}, user.id)

      Releases.subscribe(release.id, sign_ups: true)
      {:ok, _} = Releases.seed_signup(signup.id, admin.id)

      assert_received {:signup_updated, _}
    end
  end

  # ---------------------------------------------------------------------------
  # reject_signup/2
  # ---------------------------------------------------------------------------

  describe "reject_signup/2" do
    test "marks a queued signup as rejected" do
      {release, tt} = open_release_with_ticket_type()
      user = user_fixture()
      admin = admin_user_fixture()
      {:ok, signup} = Releases.sign_up(release.id, %{tt.id => 1}, user.id)

      assert {:ok, updated} = Releases.reject_signup(signup.id, admin.id)
      assert updated.status == :rejected
      assert updated.decided_by_id == admin.id
    end

    test "un-rejects a rejected signup back to queued (toggle)" do
      {release, tt} = open_release_with_ticket_type()
      user = user_fixture()
      admin = admin_user_fixture()
      {:ok, signup} = Releases.sign_up(release.id, %{tt.id => 1}, user.id)
      {:ok, _} = Releases.reject_signup(signup.id, admin.id)

      assert {:ok, toggled} = Releases.reject_signup(signup.id, admin.id)
      assert toggled.status == :queued
    end

    test "marks a seeded signup as rejected" do
      {release, tt} = open_release_with_ticket_type()
      user = user_fixture()
      admin = admin_user_fixture()
      {:ok, signup} = Releases.sign_up(release.id, %{tt.id => 1}, user.id)
      {:ok, _} = Releases.seed_signup(signup.id, admin.id)

      assert {:ok, updated} = Releases.reject_signup(signup.id, admin.id)
      assert updated.status == :rejected
    end

    test "returns :invalid_status for lost signups" do
      {release, tt} = open_release_with_ticket_type()
      user = user_fixture()
      admin = admin_user_fixture()
      {:ok, signup} = Releases.sign_up(release.id, %{tt.id => 1}, user.id)

      Repo.update_all(
        from(s in Signup, where: s.id == ^signup.id),
        set: [status: :lost]
      )

      assert {:error, :invalid_status} = Releases.reject_signup(signup.id, admin.id)
    end
  end

  # ---------------------------------------------------------------------------
  # release_unclaimed/1
  # ---------------------------------------------------------------------------

  describe "release_unclaimed/1" do
    test "cancels pending orders belonging to winners of the release" do
      {release, tt} = open_release_with_ticket_type()
      user = user_fixture()
      {:ok, signup} = Releases.sign_up(release.id, %{tt.id => 1}, user.id)

      # Attach a pending order directly (simulating a draw result)
      {:ok, order} = create_order(%{user_id: user.id, event_id: release.event_id, price: 0})

      Repo.update_all(
        from(s in Signup, where: s.id == ^signup.id),
        set: [order_id: order.id]
      )

      # maybe_cancel_order cancels synchronously then enqueues a Swish CancelWorker job
      Oban.Testing.with_testing_mode(:inline, fn ->
        Releases.release_unclaimed(release)
      end)

      cancelled = Repo.get!(Tiki.Orders.Order, order.id)
      assert cancelled.status == :cancelled
    end

    test "leaves paid orders untouched" do
      {release, tt} = open_release_with_ticket_type()
      user = user_fixture()
      {:ok, signup} = Releases.sign_up(release.id, %{tt.id => 1}, user.id)

      {:ok, order} = create_order(%{user_id: user.id, event_id: release.event_id, price: 0})

      Repo.update_all(
        from(s in Signup, where: s.id == ^signup.id),
        set: [order_id: order.id]
      )

      # Mark the order as paid before calling release_unclaimed
      Repo.update_all(
        from(o in Tiki.Orders.Order, where: o.id == ^order.id),
        set: [status: :paid]
      )

      Releases.release_unclaimed(release)

      paid = Repo.get!(Tiki.Orders.Order, order.id)
      assert paid.status == :paid
    end

    test "does not touch pending orders for other releases" do
      {release, _tt} = open_release_with_ticket_type()
      user = user_fixture()
      {:ok, order} = create_order(%{user_id: user.id, event_id: release.event_id, price: 0})

      # This order has no signup linking it to the release
      Releases.release_unclaimed(release)

      unchanged = Repo.get!(Tiki.Orders.Order, order.id)
      assert unchanged.status == :pending
    end
  end

  # ---------------------------------------------------------------------------
  # DrawEngine.perform_draw/1
  # ---------------------------------------------------------------------------

  describe "DrawEngine.perform_draw/1" do
    test "selects winners up to capacity and marks losers as :lost" do
      batch = ticket_batch_fixture(%{max_size: 1})
      tt = ticket_type_fixture(%{ticket_batch_id: batch.id, purchase_limit: 5})

      release =
        persisted_release_in_phase(:open, %{ticket_batch: batch, max_tickets_per_order: 5})

      users = Enum.map(1..3, fn _ -> user_fixture() end)

      Enum.each(users, fn u ->
        {:ok, _} = Releases.sign_up(release.id, %{tt.id => 1}, u.id)
      end)

      # Force to drawing phase
      Repo.update_all(
        from(r in Tiki.Releases.Release, where: r.id == ^release.id),
        set: [opens_at: DateTime.add(DateTime.utc_now(), -30, :minute), signup_window_minutes: 10]
      )

      assert {:ok, winner_count} = DrawEngine.perform_draw(release.id)
      assert winner_count == 1

      statuses =
        Repo.all(from s in Signup, where: s.release_id == ^release.id)
        |> Enum.frequencies_by(& &1.status)

      assert Map.get(statuses, :drawn, 0) == 1
      assert Map.get(statuses, :lost, 0) == 2
    end

    test "everyone wins when entries <= capacity (undersubscribed)" do
      batch = ticket_batch_fixture(%{max_size: 10})
      tt = ticket_type_fixture(%{ticket_batch_id: batch.id, purchase_limit: 5})

      release =
        persisted_release_in_phase(:open, %{ticket_batch: batch, max_tickets_per_order: 5})

      users = Enum.map(1..3, fn _ -> user_fixture() end)

      Enum.each(users, fn u ->
        {:ok, _} = Releases.sign_up(release.id, %{tt.id => 1}, u.id)
      end)

      Repo.update_all(
        from(r in Tiki.Releases.Release, where: r.id == ^release.id),
        set: [opens_at: DateTime.add(DateTime.utc_now(), -30, :minute), signup_window_minutes: 10]
      )

      assert {:ok, 3} = DrawEngine.perform_draw(release.id)

      statuses =
        Repo.all(from s in Signup, where: s.release_id == ^release.id)
        |> Enum.frequencies_by(& &1.status)

      assert Map.get(statuses, :drawn, 0) == 3
      assert Map.get(statuses, :lost, 0) == 0
    end

    test "seeded entries win before random ones" do
      batch = ticket_batch_fixture(%{max_size: 1})
      tt = ticket_type_fixture(%{ticket_batch_id: batch.id, purchase_limit: 5})

      release =
        persisted_release_in_phase(:open, %{ticket_batch: batch, max_tickets_per_order: 5})

      admin = admin_user_fixture()
      favored = user_fixture()
      others = Enum.map(1..4, fn _ -> user_fixture() end)

      {:ok, favored_signup} = Releases.sign_up(release.id, %{tt.id => 1}, favored.id)
      Enum.each(others, fn u -> Releases.sign_up(release.id, %{tt.id => 1}, u.id) end)

      {:ok, _} = Releases.seed_signup(favored_signup.id, admin.id)

      Repo.update_all(
        from(r in Tiki.Releases.Release, where: r.id == ^release.id),
        set: [opens_at: DateTime.add(DateTime.utc_now(), -30, :minute), signup_window_minutes: 10]
      )

      {:ok, _} = DrawEngine.perform_draw(release.id)

      winner = Repo.get!(Signup, favored_signup.id)
      assert winner.status == :seeded
    end

    test "rejected entries are excluded from the draw" do
      batch = ticket_batch_fixture(%{max_size: 10})
      tt = ticket_type_fixture(%{ticket_batch_id: batch.id, purchase_limit: 5})

      release =
        persisted_release_in_phase(:open, %{ticket_batch: batch, max_tickets_per_order: 5})

      admin = admin_user_fixture()
      outcast = user_fixture()
      others = Enum.map(1..2, fn _ -> user_fixture() end)

      {:ok, outcast_signup} = Releases.sign_up(release.id, %{tt.id => 1}, outcast.id)
      Enum.each(others, fn u -> Releases.sign_up(release.id, %{tt.id => 1}, u.id) end)

      {:ok, _} = Releases.reject_signup(outcast_signup.id, admin.id)

      Repo.update_all(
        from(r in Tiki.Releases.Release, where: r.id == ^release.id),
        set: [opens_at: DateTime.add(DateTime.utc_now(), -30, :minute), signup_window_minutes: 10]
      )

      {:ok, _} = DrawEngine.perform_draw(release.id)

      outcast_after = Repo.get!(Signup, outcast_signup.id)
      assert outcast_after.status == :rejected
    end

    test "is idempotent — a second call is a no-op" do
      batch = ticket_batch_fixture(%{max_size: 10})
      tt = ticket_type_fixture(%{ticket_batch_id: batch.id, purchase_limit: 5})

      release =
        persisted_release_in_phase(:open, %{ticket_batch: batch, max_tickets_per_order: 5})

      user = user_fixture()
      {:ok, _} = Releases.sign_up(release.id, %{tt.id => 1}, user.id)

      Repo.update_all(
        from(r in Tiki.Releases.Release, where: r.id == ^release.id),
        set: [opens_at: DateTime.add(DateTime.utc_now(), -30, :minute), signup_window_minutes: 10]
      )

      assert {:ok, 1} = DrawEngine.perform_draw(release.id)
      assert :ok = DrawEngine.perform_draw(release.id)
    end

    test "sets drawn_at on the release after the draw" do
      batch = ticket_batch_fixture(%{max_size: 10})
      tt = ticket_type_fixture(%{ticket_batch_id: batch.id, purchase_limit: 5})

      release =
        persisted_release_in_phase(:open, %{ticket_batch: batch, max_tickets_per_order: 5})

      user = user_fixture()
      {:ok, _} = Releases.sign_up(release.id, %{tt.id => 1}, user.id)

      Repo.update_all(
        from(r in Tiki.Releases.Release, where: r.id == ^release.id),
        set: [opens_at: DateTime.add(DateTime.utc_now(), -30, :minute), signup_window_minutes: 10]
      )

      {:ok, _} = DrawEngine.perform_draw(release.id)

      updated_release = Repo.get!(Tiki.Releases.Release, release.id)
      assert updated_release.drawn_at != nil
      assert Releases.get_phase(updated_release) == :purchase
    end
  end

  # ---------------------------------------------------------------------------
  # EventSchedulerWorker
  # ---------------------------------------------------------------------------

  describe "EventSchedulerWorker" do
    test "\"open\" action broadcasts release change" do
      {release, _} = open_release_with_ticket_type()
      Releases.subscribe(release.id)

      Oban.Testing.with_testing_mode(:inline, fn ->
        EventSchedulerWorker.perform(%Oban.Job{
          args: %{"release_id" => release.id, "action" => "open"}
        })
      end)

      assert_received {:release_updated, ^release}
    end

    test "\"draw\" action runs the draw engine" do
      batch = ticket_batch_fixture(%{max_size: 10})
      tt = ticket_type_fixture(%{ticket_batch_id: batch.id, purchase_limit: 5})

      release =
        persisted_release_in_phase(:open, %{ticket_batch: batch, max_tickets_per_order: 5})

      user = user_fixture()
      {:ok, _} = Releases.sign_up(release.id, %{tt.id => 1}, user.id)

      Repo.update_all(
        from(r in Tiki.Releases.Release, where: r.id == ^release.id),
        set: [opens_at: DateTime.add(DateTime.utc_now(), -30, :minute), signup_window_minutes: 10]
      )

      Oban.Testing.with_testing_mode(:inline, fn ->
        EventSchedulerWorker.perform(%Oban.Job{
          args: %{"release_id" => release.id, "action" => "draw"}
        })
      end)

      updated = Repo.get!(Tiki.Releases.Release, release.id)
      assert updated.drawn_at != nil
    end

    test "\"release\" action cancels pending winner orders" do
      batch = ticket_batch_fixture(%{max_size: 10})
      _tt = ticket_type_fixture(%{ticket_batch_id: batch.id})
      release = persisted_release_in_phase(:purchase, %{ticket_batch: batch})

      user = user_fixture()
      {:ok, order} = create_order(%{user_id: user.id, event_id: release.event_id, price: 0})

      # Create a signup that is a winner with a pending order
      signup =
        %Signup{}
        |> Signup.changeset(%{
          user_id: user.id,
          release_id: release.id,
          status: :drawn,
          order_id: order.id
        })
        |> Repo.insert!()

      _ = signup

      Oban.Testing.with_testing_mode(:inline, fn ->
        EventSchedulerWorker.perform(%Oban.Job{
          args: %{"release_id" => release.id, "action" => "release"}
        })
      end)

      cancelled = Repo.get!(Tiki.Orders.Order, order.id)
      assert cancelled.status == :cancelled
    end

    test "returns :ok for a non-existent release_id" do
      result =
        EventSchedulerWorker.perform(%Oban.Job{
          args: %{"release_id" => Ecto.UUID.generate(), "action" => "open"}
        })

      assert result == :ok
    end

    test "schedules three jobs when a release is created" do
      ticket_batch = ticket_batch_fixture()
      user = admin_user_fixture()
      scope = Tiki.Accounts.Scope.for(event: ticket_batch.event_id, user: user.id)

      {:ok, release} =
        Tiki.Releases.create_release(scope, %{
          name: "test",
          name_sv: "test",
          opens_at: DateTime.add(DateTime.utc_now(), 60, :minute),
          signup_window_minutes: 10,
          purchase_window_minutes: 30,
          max_tickets_per_order: 2,
          ticket_batch_id: ticket_batch.id
        })

      scheduled =
        Repo.all(
          from j in Oban.Job,
            where: j.worker == "Tiki.Workers.EventSchedulerWorker",
            where: fragment("?->>'release_id' = ?", j.args, ^to_string(release.id))
        )

      assert length(scheduled) == 3
      actions = Enum.map(scheduled, & &1.args["action"]) |> Enum.sort()
      assert actions == ["draw", "open", "release"]
    end
  end

  # ---------------------------------------------------------------------------
  # Tickets.request_tickets/3
  # ---------------------------------------------------------------------------

  describe "Tickets.request_tickets/3" do
    test "routes to sign_up when ticket types belong to an active release" do
      {release, tt} = open_release_with_ticket_type()
      user = user_fixture()

      assert {:ok, {:signup, signup}} =
               Tickets.request_tickets(release.event_id, %{tt.id => 1}, user.id)

      assert signup.release_id == release.id
    end

    test "routes to reserve_tickets (FCFS) when ticket types have no release" do
      batch = ticket_batch_fixture(%{max_size: 10})
      tt = ticket_type_fixture(%{ticket_batch_id: batch.id})
      user = user_fixture()

      assert {:ok, {:order, order}} =
               Tickets.request_tickets(batch.event_id, %{tt.id => 1}, user.id)

      assert order.event_id == batch.event_id
    end

    test "returns :mixed_request for ticket types spanning different releases" do
      batch1 = ticket_batch_fixture()
      batch2 = ticket_batch_fixture(%{event: Tiki.Repo.preload(batch1, :event).event})
      tt1 = ticket_type_fixture(%{ticket_batch_id: batch1.id})
      tt2 = ticket_type_fixture(%{ticket_batch_id: batch2.id})

      _release = persisted_release_in_phase(:open, %{ticket_batch: batch1})

      user = user_fixture()

      assert {:error, :mixed_request} =
               Tickets.request_tickets(batch1.event_id, %{tt1.id => 1, tt2.id => 1}, user.id)
    end

    test "returns error when release is not in open phase (FCFS locked out)" do
      batch = ticket_batch_fixture(%{max_size: 10})
      tt = ticket_type_fixture(%{ticket_batch_id: batch.id})
      _release = persisted_release_in_phase(:scheduled, %{ticket_batch: batch})
      user = user_fixture()

      # The release is active (scheduled) so request_tickets routes to sign_up,
      # which rejects because phase != :open
      assert {:error, :not_open} =
               Tickets.request_tickets(batch.event_id, %{tt.id => 1}, user.id)
    end

    test "multiple types from the same release route to a single sign_up" do
      batch = ticket_batch_fixture(%{max_size: 10})
      tt1 = ticket_type_fixture(%{ticket_batch_id: batch.id, purchase_limit: 3})
      tt2 = ticket_type_fixture(%{ticket_batch_id: batch.id, purchase_limit: 3})

      release =
        persisted_release_in_phase(:open, %{ticket_batch: batch, max_tickets_per_order: 5})

      user = user_fixture()

      assert {:ok, {:signup, signup}} =
               Tickets.request_tickets(release.event_id, %{tt1.id => 1, tt2.id => 1}, user.id)

      assert signup.release_id == release.id
      assert length(signup.items) == 2
    end

    test "returns :unknown_ticket_type for a non-existent ticket type id" do
      batch = ticket_batch_fixture(%{max_size: 10})
      user = user_fixture()

      assert {:error, :unknown_ticket_type} =
               Tickets.request_tickets(batch.event_id, %{Ecto.UUID.generate() => 1}, user.id)
    end

    test "types from an expired release are treated as plain FCFS" do
      batch = ticket_batch_fixture(%{max_size: 10})
      tt = ticket_type_fixture(%{ticket_batch_id: batch.id})
      _release = persisted_release_in_phase(:released, %{ticket_batch: batch})
      user = user_fixture()

      # Once a release ends, its ticket types fall back to the FCFS ground state
      assert {:ok, {:order, order}} =
               Tickets.request_tickets(batch.event_id, %{tt.id => 1}, user.id)

      assert order.event_id == batch.event_id
    end

    test "mix of active-release type and expired-release type returns :mixed_request" do
      event = Tiki.EventsFixtures.event_fixture()
      batch1 = ticket_batch_fixture(%{event: event, max_size: 10})
      batch2 = ticket_batch_fixture(%{event: event, max_size: 10})
      tt1 = ticket_type_fixture(%{ticket_batch_id: batch1.id})
      tt2 = ticket_type_fixture(%{ticket_batch_id: batch2.id})

      _active = persisted_release_in_phase(:open, %{ticket_batch: batch1})
      _expired = persisted_release_in_phase(:released, %{ticket_batch: batch2})

      user = user_fixture()

      assert {:error, :mixed_request} =
               Tickets.request_tickets(event.id, %{tt1.id => 1, tt2.id => 1}, user.id)
    end

    test "requesting only zero-quantity items returns an error" do
      batch = ticket_batch_fixture(%{max_size: 10})
      tt = ticket_type_fixture(%{ticket_batch_id: batch.id})
      user = user_fixture()

      # Zero-quantity items are filtered before the DB lookup, so the resolved
      # scope is empty — expect :empty_request (or the current behaviour if buggy)
      assert {:error, _} =
               Tickets.request_tickets(batch.event_id, %{tt.id => 0}, user.id)
    end
  end

  # ---------------------------------------------------------------------------
  # FCFS release guard (Orders.reserve_tickets safety net)
  # ---------------------------------------------------------------------------

  describe "FCFS reservation guard during active release" do
    test "direct reserve_tickets is blocked when an active release governs the ticket type" do
      batch = ticket_batch_fixture(%{max_size: 10})
      tt = ticket_type_fixture(%{ticket_batch_id: batch.id})
      _release = persisted_release_in_phase(:open, %{ticket_batch: batch})
      user = user_fixture()

      assert {:error, _} = Tiki.Orders.reserve_tickets(batch.event_id, %{tt.id => 1}, user.id)
    end

    test "direct reserve_tickets is blocked for unauthenticated users during active release" do
      batch = ticket_batch_fixture(%{max_size: 10})
      tt = ticket_type_fixture(%{ticket_batch_id: batch.id})
      _release = persisted_release_in_phase(:open, %{ticket_batch: batch})

      assert {:error, _} = Tiki.Orders.reserve_tickets(batch.event_id, %{tt.id => 1}, nil)
    end

    test "direct reserve_tickets succeeds after the release ends" do
      batch = ticket_batch_fixture(%{max_size: 10})
      tt = ticket_type_fixture(%{ticket_batch_id: batch.id})
      _release = persisted_release_in_phase(:released, %{ticket_batch: batch})
      user = user_fixture()

      assert {:ok, _order} = Tiki.Orders.reserve_tickets(batch.event_id, %{tt.id => 1}, user.id)
    end
  end

  # ---------------------------------------------------------------------------
  # DrawEngine — seed capacity accounting and empty pool
  # ---------------------------------------------------------------------------

  describe "DrawEngine.perform_draw/1 — seed and capacity edge cases" do
    test "seeds fill all available capacity, leaving random pool with zero spots" do
      batch = ticket_batch_fixture(%{max_size: 2})
      tt = ticket_type_fixture(%{ticket_batch_id: batch.id, purchase_limit: 5})

      release =
        persisted_release_in_phase(:open, %{ticket_batch: batch, max_tickets_per_order: 5})

      admin = admin_user_fixture()
      seed1 = user_fixture()
      seed2 = user_fixture()
      others = Enum.map(1..3, fn _ -> user_fixture() end)

      {:ok, s1} = Releases.sign_up(release.id, %{tt.id => 1}, seed1.id)
      {:ok, s2} = Releases.sign_up(release.id, %{tt.id => 1}, seed2.id)
      Enum.each(others, fn u -> Releases.sign_up(release.id, %{tt.id => 1}, u.id) end)

      {:ok, _} = Releases.seed_signup(s1.id, admin.id)
      {:ok, _} = Releases.seed_signup(s2.id, admin.id)

      Repo.update_all(
        from(r in Tiki.Releases.Release, where: r.id == ^release.id),
        set: [opens_at: DateTime.add(DateTime.utc_now(), -30, :minute), signup_window_minutes: 10]
      )

      assert {:ok, 2} = DrawEngine.perform_draw(release.id)

      statuses =
        Repo.all(from s in Signup, where: s.release_id == ^release.id)
        |> Enum.frequencies_by(& &1.status)

      # both seeds win, all random entries lose
      assert Map.get(statuses, :seeded, 0) == 2
      assert Map.get(statuses, :lost, 0) == 3
      assert Map.get(statuses, :drawn, 0) == 0
    end

    test "draw with zero eligible entries succeeds with zero winners" do
      batch = ticket_batch_fixture(%{max_size: 10})
      _tt = ticket_type_fixture(%{ticket_batch_id: batch.id})
      release = persisted_release_in_phase(:open, %{ticket_batch: batch})

      # No signups at all
      Repo.update_all(
        from(r in Tiki.Releases.Release, where: r.id == ^release.id),
        set: [opens_at: DateTime.add(DateTime.utc_now(), -30, :minute), signup_window_minutes: 10]
      )

      assert {:ok, 0} = DrawEngine.perform_draw(release.id)
    end

    test "draw with all entries rejected results in zero winners" do
      batch = ticket_batch_fixture(%{max_size: 10})
      tt = ticket_type_fixture(%{ticket_batch_id: batch.id, purchase_limit: 5})

      release =
        persisted_release_in_phase(:open, %{ticket_batch: batch, max_tickets_per_order: 5})

      admin = admin_user_fixture()
      users = Enum.map(1..3, fn _ -> user_fixture() end)

      signups =
        Enum.map(users, fn u ->
          {:ok, s} = Releases.sign_up(release.id, %{tt.id => 1}, u.id)
          s
        end)

      Enum.each(signups, fn s -> Releases.reject_signup(s.id, admin.id) end)

      Repo.update_all(
        from(r in Tiki.Releases.Release, where: r.id == ^release.id),
        set: [opens_at: DateTime.add(DateTime.utc_now(), -30, :minute), signup_window_minutes: 10]
      )

      assert {:ok, 0} = DrawEngine.perform_draw(release.id)

      statuses =
        Repo.all(from s in Signup, where: s.release_id == ^release.id)
        |> Enum.frequencies_by(& &1.status)

      assert Map.get(statuses, :rejected, 0) == 3
      assert Map.get(statuses, :drawn, 0) == 0
    end
  end

  # ---------------------------------------------------------------------------
  # DrawEngine — shared batch capacity (sub-batch releases)
  # ---------------------------------------------------------------------------

  describe "DrawEngine.perform_draw/1 — shared batch capacity" do
    test "draw respects batch capacity when multiple ticket types share the same batch" do
      # Batch capacity is 2, but two ticket types both drawing from it.
      # The inventory map gives each type `available = 2` independently, so
      # pick_winners currently selects 3 winners before discovering the oversell —
      # causing reserve_release_signups to roll back rather than cleanly limiting to 2.
      batch = ticket_batch_fixture(%{max_size: 2})
      tt_a = ticket_type_fixture(%{ticket_batch_id: batch.id, purchase_limit: 5})
      tt_b = ticket_type_fixture(%{ticket_batch_id: batch.id, purchase_limit: 5})

      release =
        persisted_release_in_phase(:open, %{ticket_batch: batch, max_tickets_per_order: 5})

      user1 = user_fixture()
      user2 = user_fixture()
      user3 = user_fixture()

      {:ok, _} = Releases.sign_up(release.id, %{tt_a.id => 1}, user1.id)
      {:ok, _} = Releases.sign_up(release.id, %{tt_b.id => 1}, user2.id)
      {:ok, _} = Releases.sign_up(release.id, %{tt_a.id => 1}, user3.id)

      Repo.update_all(
        from(r in Tiki.Releases.Release, where: r.id == ^release.id),
        set: [opens_at: DateTime.add(DateTime.utc_now(), -30, :minute), signup_window_minutes: 10]
      )

      # Batch holds 2; 3 entered — exactly 2 should win, 1 should lose
      assert {:ok, 2} = DrawEngine.perform_draw(release.id)

      statuses =
        Repo.all(from s in Signup, where: s.release_id == ^release.id)
        |> Enum.frequencies_by(& &1.status)

      assert Map.get(statuses, :drawn, 0) == 2
      assert Map.get(statuses, :lost, 0) == 1
    end

    test "draw respects parent batch capacity when the release batch is a child with multiple ticket types" do
      # The release is on child_batch (max_size: 10).
      # The PARENT batch caps total inventory at 2.
      # Both TT_A and TT_B are in child_batch, so the draw sees
      # inventory = {TT_A => min(2, 10) = 2, TT_B => min(2, 10) = 2} independently.
      # pick_winners therefore draws 3 winners, overrunning the shared parent cap.
      event = Tiki.EventsFixtures.event_fixture()
      parent = ticket_batch_fixture(%{event: event, max_size: 2})

      user_admin = admin_user_fixture()
      child_scope = Tiki.Accounts.Scope.for(event: event.id, user: user_admin.id)

      {:ok, child} =
        Tiki.Tickets.create_ticket_batch(child_scope, %{
          name: "child",
          max_size: 10,
          parent_batch_id: parent.id
        })

      tt_a = ticket_type_fixture(%{ticket_batch_id: child.id, purchase_limit: 5})
      tt_b = ticket_type_fixture(%{ticket_batch_id: child.id, purchase_limit: 5})

      release =
        persisted_release_in_phase(:open, %{ticket_batch: child, max_tickets_per_order: 5})

      user1 = user_fixture()
      user2 = user_fixture()
      user3 = user_fixture()

      {:ok, _} = Releases.sign_up(release.id, %{tt_a.id => 1}, user1.id)
      {:ok, _} = Releases.sign_up(release.id, %{tt_b.id => 1}, user2.id)
      {:ok, _} = Releases.sign_up(release.id, %{tt_a.id => 1}, user3.id)

      Repo.update_all(
        from(r in Tiki.Releases.Release, where: r.id == ^release.id),
        set: [opens_at: DateTime.add(DateTime.utc_now(), -30, :minute), signup_window_minutes: 10]
      )

      # Parent holds 2 total; 3 entered — exactly 2 should win, 1 should lose
      assert {:ok, 2} = DrawEngine.perform_draw(release.id)

      statuses =
        Repo.all(from s in Signup, where: s.release_id == ^release.id)
        |> Enum.frequencies_by(& &1.status)

      assert Map.get(statuses, :drawn, 0) == 2
      assert Map.get(statuses, :lost, 0) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # FCFS purchase_limit: nil guard
  # ---------------------------------------------------------------------------

  describe "release on parent batch governs ticket types in child batches" do
    test "request_tickets routes to the release when the release is on an ancestor batch" do
      event = Tiki.EventsFixtures.event_fixture()
      parent = ticket_batch_fixture(%{event: event, max_size: 10})

      user_admin = admin_user_fixture()
      child_scope = Tiki.Accounts.Scope.for(event: event.id, user: user_admin.id)

      {:ok, child} =
        Tiki.Tickets.create_ticket_batch(child_scope, %{
          name: "child",
          max_size: 10,
          parent_batch_id: parent.id
        })

      tt = ticket_type_fixture(%{ticket_batch_id: child.id, purchase_limit: 5})

      # Release is on the parent batch; ticket type is in the child batch
      _release =
        persisted_release_in_phase(:open, %{ticket_batch: parent, max_tickets_per_order: 5})

      user = user_fixture()

      # Should route to the release (signup), not FCFS (order)
      assert {:ok, {:signup, _signup}} = Tickets.request_tickets(event.id, %{tt.id => 1}, user.id)
    end

    test "create_release rejects overlapping release for a batch in the same subtree" do
      event = Tiki.EventsFixtures.event_fixture()
      parent = ticket_batch_fixture(%{event: event, max_size: 10})

      user_admin = admin_user_fixture()
      child_scope = Tiki.Accounts.Scope.for(event: event.id, user: user_admin.id)

      {:ok, child} =
        Tiki.Tickets.create_ticket_batch(child_scope, %{
          name: "child",
          max_size: 10,
          parent_batch_id: parent.id
        })

      scope = Tiki.Accounts.Scope.for(event: event.id, user: user_admin.id)

      opens_at = DateTime.add(DateTime.utc_now(), 60, :minute)

      # Release on the parent batch
      assert {:ok, _} =
               Tiki.Releases.create_release(scope, %{
                 name: "parent release",
                 name_sv: "parent release sv",
                 opens_at: opens_at,
                 signup_window_minutes: 30,
                 purchase_window_minutes: 30,
                 ticket_batch_id: parent.id
               })

      # Overlapping release on the child batch should be rejected
      assert {:error, %Ecto.Changeset{}} =
               Tiki.Releases.create_release(scope, %{
                 name: "child release",
                 name_sv: "child release sv",
                 opens_at: DateTime.add(opens_at, 10, :minute),
                 signup_window_minutes: 30,
                 purchase_window_minutes: 30,
                 ticket_batch_id: child.id
               })
    end
  end

  describe "FCFS reserve_tickets — purchase_limit" do
    test "nil purchase_limit allows any quantity within the order limit" do
      batch = ticket_batch_fixture(%{max_size: 10})
      tt = ticket_type_fixture(%{ticket_batch_id: batch.id, purchase_limit: nil})
      user = user_fixture()

      assert {:ok, _order} = Tiki.Orders.reserve_tickets(batch.event_id, %{tt.id => 3}, user.id)
    end
  end
end
