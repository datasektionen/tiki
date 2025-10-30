defmodule Tiki.Workers.ReportGeneratorWorker do
  @moduledoc """
  Oban worker for generating ticket sales reports asynchronously.
  """

  use Oban.Worker, queue: :default, max_attempts: 1

  alias Phoenix.PubSub
  alias Tiki.Reports

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    event_ids = parse_event_ids(args["event_ids"])
    ticket_type_ids = parse_ticket_type_ids(args["ticket_type_ids"])
    start_date = parse_date(args["start_date"])
    end_date = parse_date(args["end_date"])
    include_details = Map.get(args, "include_details", true)
    payment_type = args["payment_type"] || ""
    id = args["id"]

    opts = [
      event_ids: event_ids,
      ticket_type_ids: ticket_type_ids,
      start_date: start_date,
      end_date: end_date,
      include_details: include_details,
      payment_type: payment_type
    ]

    try do
      report = Reports.generate_report(opts)
      broadcast_result(:ok, report, id)
      :ok
    rescue
      e ->
        error_message = Exception.message(e)
        broadcast_result(:error, %{message: error_message}, id)
        {:error, error_message}
    end
  end

  defp parse_event_ids("all"), do: :all
  defp parse_event_ids(ids) when is_list(ids), do: ids

  defp parse_ticket_type_ids("all"), do: :all
  defp parse_ticket_type_ids(nil), do: :all
  defp parse_ticket_type_ids(ids) when is_list(ids), do: ids

  defp parse_date(nil), do: nil

  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end

  defp parse_date(_), do: nil

  defp broadcast_result(status, payload, requester_id) do
    PubSub.broadcast(
      Tiki.PubSub,
      "reports:#{requester_id}",
      {:report_result, status, payload}
    )
  end
end
