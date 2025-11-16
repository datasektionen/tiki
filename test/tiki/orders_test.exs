defmodule Tiki.OrdersTest do
  alias Tiki.Checkouts
  alias Tiki.OrdersFixtures
  use Tiki.DataCase

  alias Tiki.Orders

  describe "order" do
    alias Tiki.Orders.Order

    import Tiki.OrdersFixtures

    @standard_preloads [:user, [tickets: :ticket_type], :stripe_checkout, :swish_checkout, :event]

    test "list_team_orders/1 returns all orders for a given team" do
      order = order_fixture() |> Tiki.Repo.preload([:event | @standard_preloads])

      assert Orders.list_team_orders(order.event.team_id) == [order]
    end

    test "list_team_orders/1 returns works for multiple orders" do
      event = Tiki.EventsFixtures.event_fixture()

      orders =
        Enum.map(1..10, fn _ ->
          user = Tiki.AccountsFixtures.user_fixture()

          {:ok, order} =
            OrdersFixtures.create_order(%{user_id: user.id, event_id: event.id, price: 100})

          order
        end)
        |> Enum.sort_by(& &1.inserted_at, :desc)
        |> Tiki.Repo.preload([:event | @standard_preloads])

      assert Orders.list_team_orders(event.team_id) |> Enum.sort() == orders |> Enum.sort()
    end

    test "list_team_orders/1 limits results" do
      event = Tiki.EventsFixtures.event_fixture()

      orders =
        Enum.map(1..3, fn _ ->
          user = Tiki.AccountsFixtures.user_fixture()

          {:ok, order} =
            OrdersFixtures.create_order(%{user_id: user.id, event_id: event.id, price: 100})

          order
        end)
        |> Enum.sort_by(& &1.inserted_at, :desc)
        |> Tiki.Repo.preload([:event | @standard_preloads])

      assert Orders.list_team_orders(event.team_id, limit: 3) == Enum.take(orders, 3)
    end

    test "list_team_orders/1 filters based on status" do
      event = Tiki.EventsFixtures.event_fixture()

      order_1 =
        order_fixture(%{status: :pending}, event: event)
        |> Tiki.Repo.preload([:event | @standard_preloads])

      order_2 =
        order_fixture(%{status: :paid}, event: event)
        |> Tiki.Repo.preload([:event | @standard_preloads])

      assert Orders.list_team_orders(event.team_id, status: [:pending]) == [order_1]
      assert Orders.list_team_orders(event.team_id, status: [:paid]) == [order_2]
    end

    test "list_orders_for_event/1 returns all orders for a given event" do
      event = Tiki.EventsFixtures.event_fixture()

      :rand.seed(:exs64, {1, 1, 2})

      orders =
        Enum.map(1..5, fn _ ->
          status = Enum.random(Ecto.Enum.dump_values(Orders.Order, :status))

          order_fixture(%{status: status}, event: event)
          |> Tiki.Repo.preload(@standard_preloads)
        end)
        |> Tiki.Repo.preload(@standard_preloads)

      list = Orders.list_orders_for_event(event.id)
      assert list == Enum.sort_by(list, & &1.inserted_at, :desc)
      assert Enum.sort(list) == Enum.sort(orders)
    end

    test "list_orders_for_event/1 filters based on status" do
      event = Tiki.EventsFixtures.event_fixture()

      :rand.seed(:exs64, {1, 1, 2})

      orders =
        Enum.map(1..5, fn _ ->
          status = Enum.random(Ecto.Enum.dump_values(Orders.Order, :status))

          order_fixture(%{status: status}, event: event)
          |> Tiki.Repo.preload(@standard_preloads)
        end)
        |> Enum.sort_by(& &1.inserted_at, :desc)
        |> Tiki.Repo.preload(@standard_preloads)

      list = Orders.list_orders_for_event(event.id, status: [:paid])
      assert Enum.sort(list) == Enum.filter(orders, &(&1.status == :paid)) |> Enum.sort()
      assert Enum.all?(list, &(&1.status == :paid))
    end

    test "list_tickets_for_event/1 returns all tickets for a given event" do
      event = Tiki.EventsFixtures.event_fixture()

      tickets =
        Enum.map(1..5, fn _ ->
          batch = Tiki.TicketsFixtures.ticket_batch_fixture(%{event_id: event.id})
          ticket_type = Tiki.TicketsFixtures.ticket_type_fixture(%{batch_id: batch.id})
          order = Tiki.OrdersFixtures.order_fixture(%{event_id: event.id})

          ticket_fixture(%{order_id: order.id, ticket_type_id: ticket_type.id})
        end)
        |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})
        |> Repo.preload(order: [:user], ticket_type: [])
        |> Enum.map(fn ticket -> %{ticket | email: ticket.order.user.email} end)

      assert Orders.list_tickets_for_event(event.id) == tickets
    end

    test "list_tickets_for_event/1 limits the number of tickets returned" do
      event = Tiki.EventsFixtures.event_fixture()

      tickets =
        Enum.map(1..5, fn _ ->
          batch = Tiki.TicketsFixtures.ticket_batch_fixture(%{event_id: event.id})
          ticket_type = Tiki.TicketsFixtures.ticket_type_fixture(%{batch_id: batch.id})
          order = Tiki.OrdersFixtures.order_fixture(%{event_id: event.id})

          ticket_fixture(%{order_id: order.id, ticket_type_id: ticket_type.id})
        end)
        |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})
        |> Repo.preload(order: [:user], ticket_type: [])
        |> Enum.map(fn ticket -> %{ticket | email: ticket.order.user.email} end)

      assert Orders.list_tickets_for_event(event.id, limit: 3) == Enum.take(tickets, 3)
    end

    test "list_orders_for_user/1 returns all orders for a user" do
      user = Tiki.AccountsFixtures.user_fixture()

      order =
        order_fixture(%{user_id: user.id})
        |> Tiki.Repo.preload([:event | @standard_preloads])

      assert Orders.list_orders_for_user(user.id) == [order]
    end

    test "get_order!/1 returns the order with given id" do
      order = order_fixture() |> Tiki.Repo.preload(@standard_preloads)
      assert Orders.get_order!(order.id) == order
    end
  end

  describe "ticket" do
    import Tiki.OrdersFixtures

    test "get_ticket!/1 returns the ticket with given id" do
      ticket =
        ticket_fixture()
        |> Tiki.Repo.preload([:ticket_type, order: [:user], form_response: [:question_responses]])

      assert Orders.get_ticket!(ticket.id) == ticket
    end
  end

  describe "order reservation" do
    import Tiki.OrdersFixtures
    import Tiki.TicketsFixtures

    alias Tiki.Orders.Order

    test "reserve_tickets/3" do
      ticket_type = ticket_type_fixture() |> Tiki.Repo.preload(ticket_batch: [event: []])

      to_purchase = Map.put(%{}, ticket_type.id, 2)
      cost = ticket_type.price * 2

      Orders.subscribe(ticket_type.ticket_batch.event.id)

      result = Orders.reserve_tickets(ticket_type.ticket_batch.event.id, to_purchase)

      assert {:ok, %Order{status: :pending, price: ^cost, id: id}} = result

      Orders.subscribe_to_order(id)

      {:ok, order} = result

      assert to_purchase ==
               Enum.group_by(order.tickets, & &1.ticket_type.id)
               |> Enum.into(%{}, fn {tt, tickets} -> {tt, length(tickets)} end)

      assert Enum.all?(order.tickets, fn %{order_id: order_id} -> order_id == order.id end)
      assert cost == Enum.map(order.tickets, & &1.price) |> Enum.sum()

      assert_receive {:tickets_updated, _}
    end

    test "reserve_tickets/3 works with events with release and expire times" do
      ticket_type =
        ticket_type_fixture(%{
          release_time: DateTime.utc_now() |> DateTime.add(-60, :second),
          expire_time: DateTime.utc_now() |> DateTime.add(60, :second)
        })
        |> Tiki.Repo.preload(ticket_batch: [event: []])

      to_purchase = Map.put(%{}, ticket_type.id, 2)
      cost = ticket_type.price * 2

      Orders.subscribe(ticket_type.ticket_batch.event.id)

      result = Orders.reserve_tickets(ticket_type.ticket_batch.event.id, to_purchase)

      assert {:ok, %Order{status: :pending, price: ^cost, id: id}} = result

      Orders.subscribe_to_order(id)

      {:ok, order} = result

      assert to_purchase ==
               Enum.group_by(order.tickets, & &1.ticket_type.id)
               |> Enum.into(%{}, fn {tt, tickets} -> {tt, length(tickets)} end)

      assert Enum.all?(order.tickets, fn %{order_id: order_id} -> order_id == order.id end)
      assert cost == Enum.map(order.tickets, & &1.price) |> Enum.sum()

      assert_receive {:tickets_updated, _}
    end

    test "reserve_tickets/3 fails if reserving no tickets" do
      ticket_type = ticket_type_fixture() |> Tiki.Repo.preload(ticket_batch: [event: []])
      to_purchase = Map.put(%{}, ticket_type.id, 0)

      assert {:error, msg} =
               Orders.reserve_tickets(ticket_type.ticket_batch.event.id, to_purchase)

      assert msg =~ "order must contain at least one ticket"
    end

    test "reserve_tickets/3 fails if reserving too many tickets of a single type" do
      ticket_type =
        ticket_type_fixture(%{purchase_limit: 2}) |> Tiki.Repo.preload(ticket_batch: [event: []])

      to_purchase = Map.put(%{}, ticket_type.id, 3)

      assert {:error, msg} =
               Orders.reserve_tickets(ticket_type.ticket_batch.event.id, to_purchase)

      assert msg =~ "too many tickets requested"
    end

    test "reserve_tickets/3 fails if reserving too many tickets for an event" do
      event = Tiki.EventsFixtures.event_fixture(max_order_size: 2)
      batch = ticket_batch_fixture(%{event: event})

      ticket_type =
        ticket_type_fixture(%{purchase_limit: 10, ticket_batch_id: batch.id})
        |> Tiki.Repo.preload(ticket_batch: [event: []])

      to_purchase = Map.put(%{}, ticket_type.id, 3)

      assert {:error, msg} =
               Orders.reserve_tickets(ticket_type.ticket_batch.event.id, to_purchase)

      assert msg =~ "too many tickets requested"
    end

    test "reserve_tickets/3 fails if reserving tickets that are not purchasable" do
      ticket_type =
        ticket_type_fixture(%{purchasable: false}) |> Tiki.Repo.preload(ticket_batch: [event: []])

      to_purchase = Map.put(%{}, ticket_type.id, 3)

      assert {:error, msg} =
               Orders.reserve_tickets(ticket_type.ticket_batch.event.id, to_purchase)

      assert msg =~ "not all ticket types are purchasable"
    end

    test "reserve_tickets/3 fails if reserving too many tickets" do
      ticket_type = ticket_type_fixture() |> Tiki.Repo.preload(ticket_batch: [event: []])
      to_purchase = Map.put(%{}, ticket_type.id, 43)

      assert {:error, msg} =
               Orders.reserve_tickets(ticket_type.ticket_batch.event.id, to_purchase)

      assert msg =~ "not enough tickets available"
    end

    test "reserve_tickets/3 fails if reserving tickets to wrong event" do
      ticket_type = ticket_type_fixture() |> Tiki.Repo.preload(ticket_batch: [event: []])
      invalid_ticket_type = ticket_type_fixture()
      to_purchase = Map.put(%{}, ticket_type.id, 2) |> Map.put(invalid_ticket_type.id, 1)

      assert {:error, msg} =
               Orders.reserve_tickets(ticket_type.ticket_batch.event.id, to_purchase)

      assert msg =~ "not enough tickets"
    end

    test "reserve_tickets/3 fails if reserving tickets that are not released yet" do
      ticket_type =
        ticket_type_fixture(%{release_time: DateTime.utc_now() |> DateTime.add(60, :second)})
        |> Tiki.Repo.preload(ticket_batch: [event: []])

      to_purchase = Map.put(%{}, ticket_type.id, 1)

      assert {:error, msg} =
               Orders.reserve_tickets(ticket_type.ticket_batch.event.id, to_purchase)

      assert msg =~ "not all ticket types are purchasable"
    end

    test "reserve_tickets/3 fails if reserving tickets that have expired" do
      ticket_type =
        ticket_type_fixture(%{expire_time: DateTime.utc_now() |> DateTime.add(-60, :second)})
        |> Tiki.Repo.preload(ticket_batch: [event: []])

      to_purchase = Map.put(%{}, ticket_type.id, 1)

      assert {:error, msg} =
               Orders.reserve_tickets(ticket_type.ticket_batch.event.id, to_purchase)

      assert msg =~ "not all ticket types are purchasable"
    end

    test "maybe_cancel_order/1 cancels a pending order" do
      order = order_fixture(%{status: "pending"})

      assert {:ok, order} = Orders.maybe_cancel_order(order.id)
      assert order.status == :cancelled
      assert %Orders.Order{status: :cancelled, tickets: []} = Orders.get_order!(order.id)
    end

    test "maybe_cancel_order/1 cancels an order being checked out" do
      order = order_fixture(%{status: "checkout"})

      assert {:ok, order} = Orders.maybe_cancel_order(order.id)
      assert order.status == :cancelled
      assert %Orders.Order{status: :cancelled, tickets: []} = Orders.get_order!(order.id)
    end

    test "maybe_cancel_order/1 does not modify paid orders" do
      order = order_fixture(%{status: "paid"})
      ticket = ticket_fixture(%{order_id: order.id}) |> Repo.preload(:ticket_type)

      assert {:error, msg} = Orders.maybe_cancel_order(order.id)
      assert msg =~ "order is not cancellable"

      assert %Orders.Order{status: :paid, tickets: [^ticket]} = Orders.get_order!(order.id)
    end

    test "maybe_cancel_order/1 does not modify cancelled orders" do
      order = order_fixture(%{status: "cancelled"}) |> Repo.preload(@standard_preloads)

      assert {:error, msg} = Orders.maybe_cancel_order(order.id)
      assert msg =~ "order is not cancellable"

      assert Orders.get_order!(order.id) == order
    end

    test "maybe_cancel_order/1 returns an error if the order does not exist" do
      assert {:error, msg} = Orders.maybe_cancel_order(Ecto.UUID.generate())
      assert msg =~ "order not found, nothing to cancel"
    end
  end

  describe "checkouts" do
    alias Tiki.Checkouts

    test "init_checkout/2 fails with invalid user data" do
      event = Tiki.EventsFixtures.event_fixture()

      {:ok, order} =
        OrdersFixtures.create_order(%{event_id: event.id, price: 100})

      assert {:error, resason} =
               Orders.init_checkout(order, "credit_card", %{})

      assert resason =~ "user_id or userdata is invalid"
    end

    test "init_checkout/2 with user id creates a stripe checkout" do
      user = Tiki.AccountsFixtures.user_fixture()
      event = Tiki.EventsFixtures.event_fixture()

      {:ok, order} =
        OrdersFixtures.create_order(%{event_id: event.id, price: 100})

      assert {:ok, %Orders.Order{stripe_checkout: %Checkouts.StripeCheckout{}} = updated} =
               Orders.init_checkout(order, "credit_card", user.id)

      assert updated.user_id == user.id
      assert String.starts_with?(updated.stripe_checkout.payment_intent_id, "pi_")
    end

    test "init_checkout/2 with user data creates a stripe checkout" do
      event = Tiki.EventsFixtures.event_fixture()

      {:ok, order} =
        OrdersFixtures.create_order(%{event_id: event.id, price: 100})

      assert {:ok, %Orders.Order{stripe_checkout: %Checkouts.StripeCheckout{}} = updated} =
               Orders.init_checkout(order, "credit_card", %{
                 name: "John Doe",
                 email: "john@doe.com"
               })

      assert updated.user_id != nil
      assert String.starts_with?(updated.stripe_checkout.payment_intent_id, "pi_")

      user = Tiki.Accounts.get_user!(updated.user_id)

      assert user.first_name == "John"
      assert user.last_name == "Doe"
      assert user.locale == "en"
      assert user.full_name == "John Doe"
      assert user.email == "john@doe.com"
    end

    test "init_checkout/2 with user data creates a stripe checkout with locale" do
      event = Tiki.EventsFixtures.event_fixture()

      {:ok, order} =
        OrdersFixtures.create_order(%{event_id: event.id, price: 100})

      assert {:ok, %Orders.Order{stripe_checkout: %Checkouts.StripeCheckout{}} = updated} =
               Orders.init_checkout(order, "credit_card", %{
                 name: "John Doe",
                 email: "john@doe.com",
                 locale: "sv"
               })

      assert updated.user_id != nil
      assert String.starts_with?(updated.stripe_checkout.payment_intent_id, "pi_")

      user = Tiki.Accounts.get_user!(updated.user_id)

      assert user.first_name == "John"
      assert user.last_name == "Doe"
      assert user.locale == "sv"
      assert user.full_name == "John Doe"
      assert user.email == "john@doe.com"
    end

    test "init_checkout/2 with invalid payment method fails" do
      event = Tiki.EventsFixtures.event_fixture()

      {:ok, order} =
        OrdersFixtures.create_order(%{event_id: event.id, price: 100})

      assert {:error, reason} =
               Orders.init_checkout(order, "invalid", %{name: "test", email: "adr@test.com"})

      assert reason =~ "not a valid payment method"
    end

    test "init_checkout/2 with with swish creates a swish checkout" do
      event = Tiki.EventsFixtures.event_fixture()

      {:ok, order} =
        OrdersFixtures.create_order(%{event_id: event.id, price: 100})

      assert {:ok, %Orders.Order{swish_checkout: %Checkouts.SwishCheckout{}} = updated} =
               Orders.init_checkout(order, "swish", %{
                 name: "John Doe",
                 email: "john@doe.com",
                 locale: "sv"
               })

      assert updated.user_id != nil
      assert updated.swish_checkout.swish_id != nil
      assert updated.swish_checkout.callback_identifier != nil
      assert updated.swish_checkout.token != nil

      user = Tiki.Accounts.get_user!(updated.user_id)

      assert user.first_name == "John"
      assert user.last_name == "Doe"
      assert user.locale == "sv"
      assert user.full_name == "John Doe"
      assert user.email == "john@doe.com"
    end
  end

  describe "change_ticket_type" do
    import Tiki.OrdersFixtures
    import Tiki.TicketsFixtures
    alias Tiki.Accounts.Scope

    test "successfully changes ticket type" do
      event = Tiki.EventsFixtures.event_fixture()
      user = Tiki.AccountsFixtures.admin_user_fixture()
      scope = Scope.for(event: event.id, user: user.id)

      batch = ticket_batch_fixture(%{event: event})
      old_type = ticket_type_fixture(%{ticket_batch_id: batch.id, price: 100})
      new_type = ticket_type_fixture(%{ticket_batch_id: batch.id, price: 200})

      order = order_fixture(%{event_id: event.id})
      ticket = ticket_fixture(%{order_id: order.id, ticket_type_id: old_type.id, price: 100})

      assert {:ok, updated_ticket} = Orders.change_ticket_type(scope, ticket.id, new_type.id)
      assert updated_ticket.ticket_type_id == new_type.id
      assert updated_ticket.price == 200
    end

    test "fails if ticket not found" do
      event = Tiki.EventsFixtures.event_fixture()
      user = Tiki.AccountsFixtures.admin_user_fixture()
      scope = Scope.for(event: event.id, user: user.id)

      batch = ticket_batch_fixture(%{event: event})
      ticket_type = ticket_type_fixture(%{ticket_batch_id: batch.id})

      assert {:error, msg} =
               Orders.change_ticket_type(scope, Ecto.UUID.generate(), ticket_type.id)

      assert msg == "ticket not found"
    end

    test "fails if user is not authorized" do
      event = Tiki.EventsFixtures.event_fixture()
      user = Tiki.AccountsFixtures.user_fixture()
      scope = Scope.for(event: event.id, user: user.id)

      batch = ticket_batch_fixture(%{event: event})
      old_type = ticket_type_fixture(%{ticket_batch_id: batch.id})
      new_type = ticket_type_fixture(%{ticket_batch_id: batch.id})

      order = order_fixture(%{event_id: event.id})
      ticket = ticket_fixture(%{order_id: order.id, ticket_type_id: old_type.id})

      assert {:error, :unauthorized} = Orders.change_ticket_type(scope, ticket.id, new_type.id)
    end

    test "fails if ticket type is the same" do
      event = Tiki.EventsFixtures.event_fixture()
      user = Tiki.AccountsFixtures.admin_user_fixture()
      scope = Scope.for(event: event.id, user: user.id)

      batch = ticket_batch_fixture(%{event: event})
      ticket_type = ticket_type_fixture(%{ticket_batch_id: batch.id})

      order = order_fixture(%{event_id: event.id})
      ticket = ticket_fixture(%{order_id: order.id, ticket_type_id: ticket_type.id})

      assert {:error, msg} =
               Orders.change_ticket_type(scope, ticket.id, ticket_type.id)

      assert msg == "ticket type is already set to this value"
    end
  end

  describe "iCal generation" do
    import Tiki.OrdersFixtures
    import Tiki.TicketsFixtures

    test "escapes special characters in iCalendar TEXT values (RFC 5545)" do
      ticket_type =
        ticket_type_fixture(%{
          name: "Ticket; with, special; chars",
          price: 0,
          start_time: ~U[2020-04-24 18:00:00Z],
          end_time: ~U[2020-04-24 21:00:00Z]
        })
        |> Tiki.Repo.preload(ticket_batch: [event: []])

      event = ticket_type.ticket_batch.event
      # Event with newlines and special chars in name and location
      Tiki.Repo.update!(
        Ecto.Changeset.change(event, %{
          name: "Event\nWith\nNewlines",
          location: "Room 123, Building A; Floor 2"
        })
      )

      order = order_fixture(%{event_id: event.id})
      _ticket = ticket_fixture(%{order_id: order.id, ticket_type_id: ticket_type.id})

      order = Tiki.Repo.preload(order, [:event, tickets: :ticket_type])
      ics = Tiki.Orders.OrderNotifier.ics(order)

      # Verify escaping
      assert ics =~ "SUMMARY:Event\\nWith\\nNewlines"
      assert ics =~ "LOCATION:Room 123\\, Building A\\; Floor 2"
      assert ics =~ "Your Tickets: Ticket\\; with\\, special\\; chars"

      # Verify it's valid iCalendar
      assert ics =~ "BEGIN:VCALENDAR"
      assert ics =~ "END:VCALENDAR"
    end

    test "folds lines longer than 75 octets (RFC 5545)" do
      # the ❓ is at position 74, so it should be folded
      long_event_name =
        String.duplicate(
          "This is a very long event name that will definitely exceed 75 octet❓ ",
          3
        )

      ticket_type =
        ticket_type_fixture(%{
          price: 0,
          start_time: ~U[2020-04-24 18:00:00Z],
          end_time: ~U[2020-04-24 21:00:00Z]
        })
        |> Tiki.Repo.preload(ticket_batch: [event: []])

      event = ticket_type.ticket_batch.event
      Tiki.Repo.update!(Ecto.Changeset.change(event, %{name: long_event_name}))

      order = order_fixture(%{event_id: event.id})
      _ticket = ticket_fixture(%{order_id: order.id, ticket_type_id: ticket_type.id})

      order = Tiki.Repo.preload(order, [:event, tickets: :ticket_type])
      ics = Tiki.Orders.OrderNotifier.ics(order)

      # Split by newlines and check line lengths
      lines = String.split(ics, "\r\n")

      Enum.each(lines, fn line ->
        assert byte_size(line) <= 75,
               "Line exceeds 75 bytes: #{inspect(line)} (#{byte_size(line)} bytes)"

        assert String.valid?(line)
      end)

      assert ics =~ "BEGIN:VCALENDAR"
      assert ics =~ "SUMMARY:"
      assert ics =~ "very long event name"
    end
  end

  describe "full order process" do
    import Tiki.OrdersFixtures
    import Tiki.TicketsFixtures

    alias Tiki.Orders.Order

    test "full order process of free ticket" do
      ticket_type =
        ticket_type_fixture(%{
          price: 0,
          start_time: ~U[2020-04-24 18:00:00Z],
          end_time: ~U[2020-04-24 21:00:00Z]
        })
        |> Tiki.Repo.preload(ticket_batch: [event: []])

      to_purchase = Map.put(%{}, ticket_type.id, 2)
      cost = ticket_type.price * 2

      result = Orders.reserve_tickets(ticket_type.ticket_batch.event.id, to_purchase)

      assert {:ok, %Order{status: :pending, price: ^cost, id: id} = order} = result

      assert {:ok, %Order{status: :paid, id: ^id}} =
               Orders.init_checkout(order, nil, %{
                 name: "John Doe",
                 email: "john@doe.com",
                 locale: "en"
               })

      mail = get_order_email()

      assert mail.to == [{"", "john@doe.com"}]
      assert mail.subject =~ "Your order"
      # Start time in "Europe/Stockholm" timezone
      assert mail.html_body =~ "4/24/20, 8:00 pm"

      assert [%Swoosh.Attachment{data: data, filename: "invite.ics"}] = mail.attachments

      assert data =~ "BEGIN:VCALENDAR"
      assert data =~ "DTSTART:20200424T180000Z"
      assert data =~ "DTEND:20200424T210000Z"
      assert data =~ "END:VCALENDAR"
    end

    test "full order process with swedish locale" do
      ticket_type =
        ticket_type_fixture(%{
          price: 0,
          start_time: ~U[2020-04-24 18:00:00Z],
          end_time: ~U[2020-04-24 20:00:00Z]
        })
        |> Tiki.Repo.preload(ticket_batch: [event: []])

      to_purchase = Map.put(%{}, ticket_type.id, 2)
      cost = ticket_type.price * 2

      result = Orders.reserve_tickets(ticket_type.ticket_batch.event.id, to_purchase)

      assert {:ok, %Order{status: :pending, price: ^cost, id: id} = order} = result

      assert {:ok, %Order{status: :paid, id: ^id}} =
               Orders.init_checkout(order, nil, %{
                 name: "John Doe",
                 email: "john@doe.com",
                 locale: "sv"
               })

      mail = get_order_email()

      assert mail.to == [{"", "john@doe.com"}]
      assert mail.subject =~ "Din order"
      # Start time in "Europe/Stockholm" timezone
      assert mail.html_body =~ "2020-04-24 20:00"

      assert [%Swoosh.Attachment{data: data, filename: "invite.ics"}] = mail.attachments

      assert data =~ "BEGIN:VCALENDAR"
      assert data =~ "DTSTART:20200424T180000Z"
      assert data =~ "DTEND:20200424T200000Z"
      assert data =~ "END:VCALENDAR"
    end

    test "full order process with swish" do
      ticket_type =
        ticket_type_fixture(%{
          price: 50,
          start_time: ~U[2020-04-24 18:00:00Z],
          end_time: ~U[2020-04-24 20:00:00Z]
        })
        |> Tiki.Repo.preload(ticket_batch: [event: []])

      to_purchase = Map.put(%{}, ticket_type.id, 2)
      cost = ticket_type.price * 2

      result = Orders.reserve_tickets(ticket_type.ticket_batch.event.id, to_purchase)

      assert {:ok, %Order{status: :pending, price: ^cost, id: id} = order} = result

      Orders.subscribe_to_order(id)

      assert {:ok, %Order{status: :checkout, id: ^id, swish_checkout: swish_checkout}} =
               Orders.init_checkout(order, "swish", %{
                 name: "John Doe",
                 email: "john@doe.com"
               })

      Checkouts.confirm_swish_payment(swish_checkout.callback_identifier, "PAID")

      assert_receive {:paid, %Order{status: :paid, id: ^id} = order}

      assert order.status == :paid

      assert order.swish_checkout.status == "PAID"
      assert order.swish_checkout.id == swish_checkout.id

      mail = get_order_email()

      assert mail.to == [{"", "john@doe.com"}]
      assert mail.subject =~ "Your order for"

      assert [%Swoosh.Attachment{data: data, filename: "invite.ics"}] = mail.attachments

      assert data =~ "BEGIN:VCALENDAR"
      assert data =~ "DTSTART:20200424T180000Z"
      assert data =~ "DTEND:20200424T200000Z"
      assert data =~ "END:VCALENDAR"

      log = Tiki.Orders.get_order_logs(id)

      # TODO: assert more stuff about the order log here
      assert [
               %Tiki.Orders.AuditLog{event_type: "order.paid"},
               %Tiki.Orders.AuditLog{event_type: "order.checkout.swish"},
               %Tiki.Orders.AuditLog{event_type: "order.created"}
             ] = log
    end

    test "full order process with stripe" do
      ticket_type =
        ticket_type_fixture(%{
          price: 50,
          start_time: ~U[2020-04-24 18:00:00Z],
          end_time: ~U[2020-04-24 20:00:00Z]
        })
        |> Tiki.Repo.preload(ticket_batch: [event: []])

      to_purchase = Map.put(%{}, ticket_type.id, 2)
      cost = ticket_type.price * 2

      result = Orders.reserve_tickets(ticket_type.ticket_batch.event.id, to_purchase)

      assert {:ok, %Order{status: :pending, price: ^cost, id: id} = order} = result

      Orders.subscribe_to_order(id)

      assert {:ok, %Order{status: :checkout, id: ^id, stripe_checkout: stripe_checkout}} =
               Orders.init_checkout(order, "credit_card", %{
                 name: "John Doe",
                 email: "john@doe.com"
               })

      Checkouts.confirm_stripe_payment(%Stripe.PaymentIntent{
        id: stripe_checkout.payment_intent_id,
        status: "succeeded"
      })

      assert_receive {:paid, %Order{status: :paid, id: ^id} = order}

      assert order.status == :paid

      mail = get_order_email()

      assert mail.to == [{"", "john@doe.com"}]
      assert mail.subject =~ "Your order for"

      assert [%Swoosh.Attachment{data: data, filename: "invite.ics"}] = mail.attachments

      assert data =~ "BEGIN:VCALENDAR"
      assert data =~ "DTSTART:20200424T180000Z"
      assert data =~ "DTEND:20200424T200000Z"
      assert data =~ "END:VCALENDAR"

      log = Tiki.Orders.get_order_logs(id)

      # TODO: assert more stuff about the order log here
      assert [
               %Tiki.Orders.AuditLog{event_type: "order.paid"},
               %Tiki.Orders.AuditLog{event_type: "order.checkout.credit_card"},
               %Tiki.Orders.AuditLog{event_type: "order.created"}
             ] = log
    end
  end
end
