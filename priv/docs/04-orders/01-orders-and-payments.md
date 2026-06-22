%{
title: "Orders and Payments",
description: "How orders are created, paid for, and managed"
}

---

# Orders and Payments

An order is created when tickets are reserved, either by an attendee during normal checkout or automatically by the system when a release draw completes and a winner is assigned tickets. In both cases the order moves through the same state machine and can be paid via Stripe (card) or Swish.

## Order lifecycle

```
pending → checkout → paid
       ↘          ↗
        cancelled
```

| Status        | Meaning                                                                                                                                                                                                                             |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **pending**   | Tickets are reserved but checkout hasn't started. For release winners this is the initial state — the order exists before the winner takes any action. The order will be auto-cancelled if not paid within the reservation timeout. |
| **checkout**  | Payment has been initiated (a Stripe or Swish session is open).                                                                                                                                                                     |
| **paid**      | Payment confirmed. Tickets are issued and the attendee receives a confirmation email.                                                                                                                                               |
| **cancelled** | The order was cancelled, either by the attendee, by timeout, or by a failed payment. Reserved tickets are released back to inventory.                                                                                               |

Once an order reaches `paid` or `cancelled`, it cannot transition further.

## Payment methods

Tiki supports two payment methods:

### Stripe (card)

Standard card payment. When an attendee initiates card checkout, Tiki creates a Stripe PaymentIntent and returns a client secret used to complete the payment in the browser. Stripe sends a webhook when payment succeeds, which confirms the order server-side.

### Swish

Swedish mobile payment. Tiki creates a Swish payment request and displays a QR code. The attendee pays via the Swish app; Tiki receives a callback from Swish when the payment completes. Supported statuses from Swish are `PAID`, `DECLINED`, `ERROR`, and `CANCELLED`; the latter three cancel the order.

### Free tickets

If an order's total price is 0 SEK (all ticket types in the order are free), payment is skipped entirely, and the order goes directly to `paid` status when the attendee confirms checkout.

## Reservation timeout

When tickets are reserved (order created), a background job is scheduled to cancel the order if it isn't paid within the reservation window. This prevents tickets from being held indefinitely by incomplete checkouts. The timeout applies to both regular purchases and release winners who haven't paid. If an order is cancelled before the timeout, by the attendee or by a team member, the tickets are released back to inventory immediately, without waiting for the timeout to fire.

## Email confirmation

When an order is confirmed (status moves to `paid`), the attendee automatically receives a confirmation email containing a QR code. This QR code is used for check-in at the event.

No other automated emails are sent; release draw results, reminders, and similar notifications are handled outside Tiki.

## Managing orders as a team member

From the event management view you can:

- **View all tickets sold** for the event, with search and filter by attendee name, ticket type, status, and more. Each ticket links to its associated order.
- **View order details**: which tickets were purchased, the payment method, and a full audit log of every status transition, including who triggered each change and when.
- **Change a ticket type**: reassign a ticket to a different type (e.g. a different performance date) if capacity allows. Any price difference must be handled outside Tiki.

Tiki does not support cancelling paid orders or issuing refunds; both must be handled outside Tiki (e.g. via the Stripe dashboard or Swish). Refund support is planned for a future release.

### Check-in

Paid tickets each carry a unique QR code. At the event, use the check-in view to scan codes and mark attendees as arrived. You can also check in attendees manually from the list without scanning. Check-in can be toggled: clicking again undoes a check-in if you made a mistake.

The check-in view is live: it updates in real time across all devices, so multiple people can scan simultaneously at the door without stepping on each other.
