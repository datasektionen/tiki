defmodule Tiki.Orders.AuditLog do
  @moduledoc """
  Module for auditing order changes.
  """
  use Tiki.Schema
  import Ecto.Changeset

  schema "order_audit_logs" do
    field :event_type, :string
    field :metadata, :map

    belongs_to :order, Tiki.Orders.Order, type: :binary_id

    timestamps(updated_at: false)
  end

  def log(order_id, event_type, metadata \\ %{}) do
    %__MODULE__{}
    |> changeset(%{order_id: order_id, event_type: event_type, metadata: metadata})
    |> Tiki.Repo.insert()
  end

  defp changeset(order, attrs) do
    order
    |> cast(attrs, [:event_type, :metadata, :order_id])
    |> validate_required([:event_type, :metadata, :order_id])
  end
end
