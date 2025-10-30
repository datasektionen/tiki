defmodule Tiki.Reports.ReportParams do
  @moduledoc """
  Form parameters for generating reports.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :event_id, :string
    field :ticket_type_ids, {:array, :string}, default: []
    field :start_date, :date
    field :end_date, :date
    field :include_details, :boolean, default: false
    field :payment_type, :string, default: ""
  end

  def changeset(params \\ %{}) do
    %__MODULE__{}
    |> cast(params, [
      :event_id,
      :ticket_type_ids,
      :start_date,
      :end_date,
      :include_details,
      :payment_type
    ])
    |> validate_date_range()
  end

  defp validate_date_range(changeset) do
    start_date = get_field(changeset, :start_date)
    end_date = get_field(changeset, :end_date)

    case {start_date, end_date} do
      {nil, nil} ->
        changeset

      {_start, nil} ->
        changeset

      {nil, _end} ->
        changeset

      {start_date, end_date} ->
        if Date.compare(start_date, end_date) in [:lt, :eq] do
          changeset
        else
          add_error(changeset, :end_date, "must be on or after start date")
        end
    end
  end
end
