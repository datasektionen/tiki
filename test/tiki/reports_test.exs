defmodule Tiki.ReportsTest do
  use Tiki.DataCase

  alias Tiki.Reports
  alias Tiki.Reports.ReportParams
  alias Tiki.Accounts.Scope

  import Tiki.EventsFixtures
  import Tiki.TicketsFixtures
  import Tiki.AccountsFixtures

  defp order_stripe(event, price) do
    ticket_batch = ticket_batch_fixture(%{event: event})

    ticket_type =
      ticket_type_fixture(%{
        price: price,
        ticket_batch_id: ticket_batch.id
      })
      |> Tiki.Repo.preload(ticket_batch: [event: []])

    to_purchase = Map.put(%{}, ticket_type.id, 1)
    result = Tiki.Orders.reserve_tickets(ticket_type.ticket_batch.event.id, to_purchase)

    assert {:ok, order} = result

    Tiki.Orders.subscribe_to_order(order.id)

    assert {:ok, order} =
             Tiki.Orders.init_checkout(order, "credit_card", %{
               name: "John Doe",
               email: "john@doe.com"
             })

    Tiki.Checkouts.confirm_stripe_payment(%Stripe.PaymentIntent{
      id: order.stripe_checkout.payment_intent_id,
      status: "succeeded"
    })

    Swoosh.X.TestAssertions.flush_emails()

    assert_receive {:paid, %Tiki.Orders.Order{status: :paid} = order}
    order
  end

  defp order_swish(event, price) do
    ticket_batch = ticket_batch_fixture(%{event: event})

    ticket_type =
      ticket_type_fixture(%{
        price: price,
        ticket_batch_id: ticket_batch.id
      })
      |> Tiki.Repo.preload(ticket_batch: [event: []])

    to_purchase = Map.put(%{}, ticket_type.id, 1)
    result = Tiki.Orders.reserve_tickets(ticket_type.ticket_batch.event.id, to_purchase)

    assert {:ok, order} = result

    Tiki.Orders.subscribe_to_order(order.id)

    assert {:ok, order} =
             Tiki.Orders.init_checkout(order, "swish", %{
               name: "John Doe",
               email: "john@doe.com"
             })

    Tiki.Checkouts.confirm_swish_payment(order.swish_checkout.callback_identifier, "PAID")
    Swoosh.X.TestAssertions.flush_emails()

    assert_receive {:paid, %Tiki.Orders.Order{status: :paid} = order}
    order
  end

  describe "queue_report_generation/2" do
    test "enqueues a report job with valid params" do
      user = user_fixture() |> grant_permission("audit")
      scope = Scope.for_user(user)
      event = event_fixture()

      params = %{
        "event_id" => event.id,
        "ticket_type_ids" => [],
        "start_date" => nil,
        "end_date" => nil,
        "include_details" => false,
        "payment_type" => ""
      }

      assert {:ok, job} = Reports.queue_report_generation(scope, params)
      assert is_map(job)
    end

    test "returns error with invalid params when date range is backwards" do
      user = user_fixture() |> grant_permission("audit")
      scope = %Scope{user: user}

      params = %{
        "event_id" => "",
        "ticket_type_ids" => [],
        "start_date" => "2024-01-15",
        "end_date" => "2024-01-10",
        "include_details" => false,
        "payment_type" => ""
      }

      assert {:error, changeset} = Reports.queue_report_generation(scope, params)
      assert changeset.errors[:end_date]
    end

    test "returns unauthorized when user lacks permission" do
      user = user_fixture()
      scope = %Scope{user: user}

      params = %{
        "event_id" => "",
        "ticket_type_ids" => [],
        "start_date" => nil,
        "end_date" => nil,
        "include_details" => false,
        "payment_type" => ""
      }

      assert {:error, :unauthorized} = Reports.queue_report_generation(scope, params)
    end

    test "accepts valid date parameters" do
      user = user_fixture() |> grant_permission("audit")
      scope = %Scope{user: user}

      params = %{
        "event_id" => "",
        "ticket_type_ids" => [],
        "start_date" => "2024-01-10",
        "end_date" => "2024-01-15",
        "include_details" => true,
        "payment_type" => "stripe"
      }

      assert {:ok, _job} = Reports.queue_report_generation(scope, params)
    end

    test "accepts nil dates for unbounded ranges" do
      user = user_fixture() |> grant_permission("audit")
      scope = %Scope{user: user}

      params = %{
        "event_id" => "",
        "ticket_type_ids" => [],
        "start_date" => nil,
        "end_date" => nil,
        "include_details" => false,
        "payment_type" => ""
      }

      assert {:ok, _job} = Reports.queue_report_generation(scope, params)
    end

    test "returns a report over pubsub" do
      user = user_fixture() |> grant_permission("audit")
      scope = Scope.for_user(user)
      event = event_fixture(name: "Event 1")
      order = order_swish(event, 100)

      params = %{
        "event_id" => "",
        "ticket_type_ids" => [],
        "start_date" => nil,
        "end_date" => nil,
        "include_details" => false,
        "payment_type" => ""
      }

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, job} = Reports.queue_report_generation(scope, params)
        assert is_map(job)

        Oban.drain_queue(queue: :default)
        assert_receive {:report_result, :ok, report}

        assert [
                 %{
                   event_name: event.name,
                   event_id: event.id,
                   total_revenue: 100,
                   total_quantity: 1,
                   items:
                     Enum.map(order.tickets, fn t ->
                       %{
                         ticket_type_id: t.ticket_type.id,
                         ticket_type_name: t.ticket_type.name,
                         quantity: 1,
                         total_revenue: 100
                       }
                     end)
                 }
               ] == report.summary
      end)
    end
  end

  describe "generate_report/1" do
    test "generates report with no data returns empty summary" do
      report =
        Reports.generate_report(
          event_ids: :all,
          ticket_type_ids: :all,
          start_date: nil,
          end_date: nil,
          include_details: false,
          payment_type: ""
        )

      assert report.summary == []
      assert report.details == []
      assert report.grand_total == 0
      assert report.total_tickets == 0
      assert report.generated_at
      assert is_struct(report.generated_at, DateTime)
    end

    test "generates report with paid orders" do
      event = event_fixture(name: "Event 1")
      order_swish(event, 100)

      report =
        Reports.generate_report(
          event_ids: :all,
          ticket_type_ids: :all,
          start_date: nil,
          end_date: nil,
          include_details: false,
          payment_type: ""
        )

      assert length(report.summary) == 1
      assert report.grand_total == 100
      assert report.total_tickets == 1

      event_summary = List.first(report.summary)
      assert event_summary.total_revenue == 100
      assert event_summary.total_quantity == 1

      order_swish(event, 100)

      report =
        Reports.generate_report(
          event_ids: :all,
          ticket_type_ids: :all,
          start_date: nil,
          end_date: nil,
          include_details: false,
          payment_type: ""
        )

      assert length(report.summary) == 1
      assert report.grand_total == 200
      assert report.total_tickets == 2

      event_summary = List.first(report.summary)
      assert event_summary.total_revenue == 200
      assert event_summary.total_quantity == 2
    end

    test "filters by event_ids" do
      event1 = event_fixture()
      event2 = event_fixture()

      order_swish(event1, 100)
      order_swish(event2, 200)

      report =
        Reports.generate_report(
          event_ids: [event1.id],
          ticket_type_ids: :all,
          start_date: nil,
          end_date: nil,
          include_details: false,
          payment_type: ""
        )

      assert length(report.summary) == 1
      assert report.grand_total == 100
      assert report.total_tickets == 1
      assert List.first(report.summary).event_name == event1.name

      report =
        Reports.generate_report(
          event_ids: [event1.id, event2.id],
          ticket_type_ids: :all,
          start_date: nil,
          end_date: nil,
          include_details: false,
          payment_type: ""
        )

      assert length(report.summary) == 2
      assert report.grand_total == 300
      assert report.total_tickets == 2
      assert Enum.map(report.summary, & &1.event_name) == [event1.name, event2.name]
    end

    test "filters by ticket_type_ids" do
      event = event_fixture()
      order1 = order_swish(event, 100)

      report =
        Reports.generate_report(
          event_ids: :all,
          ticket_type_ids: Enum.map(order1.tickets, & &1.ticket_type_id),
          start_date: nil,
          end_date: nil,
          include_details: false,
          payment_type: ""
        )

      assert report.grand_total == 100
      assert report.total_tickets == 1

      _ = order_swish(event, 100)

      report =
        Reports.generate_report(
          event_ids: :all,
          ticket_type_ids: Enum.map(order1.tickets, & &1.ticket_type_id),
          start_date: nil,
          end_date: nil,
          include_details: false,
          payment_type: ""
        )

      assert report.grand_total == 100
      assert report.total_tickets == 1
    end

    test "includes details when requested" do
      event = event_fixture()
      order = order_swish(event, 100)

      report =
        Reports.generate_report(
          event_ids: :all,
          ticket_type_ids: :all,
          start_date: nil,
          end_date: nil,
          include_details: true,
          payment_type: ""
        )

      assert length(report.details) == 1
      detail = List.first(report.details)
      assert detail.order_id == order.id
      assert detail.price == 100
      assert detail.ticket_type_name == hd(order.tickets).ticket_type.name
      assert detail.event_name == event.name
    end

    test "uses historical prices from metadata" do
      event = event_fixture()
      order = order_swish(event, 100)

      ticket_type = hd(order.tickets).ticket_type

      user = admin_user_fixture()
      scope = Tiki.Accounts.Scope.for(event: event.id, user: user.id)

      Tiki.Tickets.update_ticket_type(scope, ticket_type, %{price: 500})

      assert %Tiki.Tickets.TicketType{price: 500} =
               Tiki.Tickets.get_ticket_type!(ticket_type.id)

      report =
        Reports.generate_report(
          event_ids: :all,
          ticket_type_ids: :all,
          start_date: nil,
          end_date: nil,
          include_details: true,
          payment_type: ""
        )

      # Report should use the price from metadata captured at time of purchase
      assert report.grand_total == 100
      assert List.first(report.details).price == 100
    end

    test "filters by payment method" do
      event = event_fixture()
      order_stripe(event, 100)
      order_swish(event, 200)

      report_all =
        Reports.generate_report(
          event_ids: :all,
          ticket_type_ids: :all,
          start_date: nil,
          end_date: nil,
          include_details: false,
          payment_type: ""
        )

      report_stripe =
        Reports.generate_report(
          event_ids: :all,
          ticket_type_ids: :all,
          start_date: nil,
          end_date: nil,
          include_details: false,
          payment_type: "stripe"
        )

      report_swish =
        Reports.generate_report(
          event_ids: :all,
          ticket_type_ids: :all,
          start_date: nil,
          end_date: nil,
          include_details: false,
          payment_type: "swish"
        )

      assert report_all.grand_total == 300
      assert report_all.total_tickets == 2

      assert report_stripe.grand_total == 100
      assert report_stripe.total_tickets == 1

      assert report_swish.grand_total == 200
      assert report_swish.total_tickets == 1
    end

    test "detailed transactions are sorted chronologically by date, not alphabetically" do
      # Create events with names that sort differently alphabetically
      event_z = event_fixture(name: "Z Event")
      event_a = event_fixture(name: "A Event")

      order_swish(event_z, 100)
      order_swish(event_a, 200)

      report =
        Reports.generate_report(
          event_ids: :all,
          ticket_type_ids: :all,
          start_date: nil,
          end_date: nil,
          include_details: true,
          payment_type: ""
        )

      details = report.details
      assert length(details) == 2

      first_detail = Enum.at(details, 0)
      second_detail = Enum.at(details, 1)

      # Should be sorted chronologically by paid_at, not alphabetically by event_name
      assert first_detail.event_name == "Z Event"
      assert second_detail.event_name == "A Event"
      assert NaiveDateTime.compare(first_detail.paid_at, second_detail.paid_at) in [:lt, :eq]
    end
  end

  describe "ReportParams changeset" do
    test "validates date range" do
      changeset =
        ReportParams.changeset(%{
          "start_date" => "2024-01-15",
          "end_date" => "2024-01-10"
        })

      refute changeset.valid?
      assert changeset.errors[:end_date]
    end

    test "allows start_date without end_date" do
      changeset =
        ReportParams.changeset(%{
          "start_date" => "2024-01-10",
          "end_date" => nil
        })

      assert changeset.valid?
    end

    test "allows end_date without start_date" do
      changeset =
        ReportParams.changeset(%{
          "start_date" => nil,
          "end_date" => "2024-01-15"
        })

      assert changeset.valid?
    end

    test "allows both dates to be nil" do
      changeset =
        ReportParams.changeset(%{
          "start_date" => nil,
          "end_date" => nil
        })

      assert changeset.valid?
    end

    test "allows equal start and end dates" do
      changeset =
        ReportParams.changeset(%{
          "start_date" => "2024-01-10",
          "end_date" => "2024-01-10"
        })

      assert changeset.valid?
    end
  end
end
