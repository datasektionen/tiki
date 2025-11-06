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
    %__MODULE__{order_id: order_id}
    |> changeset(%{
      event_type: event_type,
      metadata: encode_metadata(metadata)
    })
    |> Tiki.Repo.insert()
  end

  defp changeset(order, attrs) do
    order
    |> cast(attrs, [:event_type, :metadata])
    |> validate_required([:event_type, :metadata])
  end

  defp encode_metadata(%Tiki.Orders.Order{} = order) do
    %{
      id: order.id,
      status: order.status,
      price: order.price,
      user_id: order.user_id,
      event_id: order.event_id,
      tickets: empty_array_if_not_loaded(order.tickets, &encode_metadata/1),
      stripe_checkout: nil_if_not_loaded(order.stripe_checkout, &encode_metadata/1),
      swish_checkout: nil_if_not_loaded(order.swish_checkout, &encode_metadata/1)
    }
  end

  defp encode_metadata(%Tiki.Orders.Ticket{} = ticket) do
    %{
      id: ticket.id,
      price: ticket.price,
      ticket_type: encode_metadata(ticket.ticket_type)
    }
  end

  defp encode_metadata(%Tiki.Tickets.TicketType{} = ticket_type) do
    %{
      id: ticket_type.id,
      name: ticket_type.name
    }
  end

  defp encode_metadata(%Tiki.Checkouts.StripeCheckout{} = checkout) do
    %{
      id: checkout.id,
      payment_intent_id: checkout.payment_intent_id,
      payment_method_id: checkout.payment_method_id,
      status: checkout.status
    }
  end

  defp encode_metadata(%Tiki.Checkouts.SwishCheckout{} = checkout) do
    %{
      id: checkout.id,
      swish_id: checkout.swish_id,
      callback_identifier: checkout.callback_identifier,
      token: checkout.token,
      status: checkout.status
    }
  end

  defp encode_metadata(data) when is_list(data), do: Enum.map(data, &encode_metadata/1)

  defp encode_metadata(data) when is_map(data) do
    Enum.map(data, fn {key, val} -> {encode_metadata(key), encode_metadata(val)} end)
    |> Enum.into(%{})
  end

  defp encode_metadata(data) when is_integer(data) or is_binary(data) or is_atom(data), do: data

  defp nil_if_not_loaded(%Ecto.Association.NotLoaded{}, _), do: nil
  defp nil_if_not_loaded(value, apply_fn), do: apply_fn.(value)

  defp empty_array_if_not_loaded(%Ecto.Association.NotLoaded{}, _), do: []
  defp empty_array_if_not_loaded(value, apply_fn), do: apply_fn.(value)
end
