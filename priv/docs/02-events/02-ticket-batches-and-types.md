%{
title: "Ticket Batches and Ticket Types",
description: "How tickets are structured, capacity is controlled, and pricing works"
}

---

# Ticket Batches and Ticket Types

Tickets in Tiki have a two-level structure: **ticket batches** hold capacity, and **ticket types** are the actual purchasable items inside a batch.

## Ticket batches

A ticket batch represents a pool of capacity. It has:

- **Name**: internal label, not shown to attendees
- **Max size**: the maximum number of tickets that can be sold across all ticket types in this batch and its sub-batches

Batches can be **nested**: a batch can have sub-batches, which can themselves have sub-batches. Capacity constraints propagate up the tree: a ticket purchase counts against the capacity of its batch _and every ancestor batch_.

### Why nest batches?

Nesting lets you model shared capacity with independent sub-caps. For example, a party with a reserved alumni allocation:

```
General admission (max 150)
├── Alumni (max 50)
│   ├── Alumni with alcohol     ← ticket type
│   └── Alumni without alcohol  ← ticket type
└── Students (max 150)
    ├── Students with alcohol    ← ticket type
    └── Students without alcohol ← ticket type
```

In this setup:

- At most 150 tickets total can sell (the general admission cap).
- At most 50 of those can be alumni tickets; even if the student batch is empty, alumni cannot exceed 50.
- The student batch has its own cap of 150, but is also constrained by the parent, so in practice it can sell at most 100 tickets once the alumni batch is full (150 − 50 = 100).
- Within each sub-batch, the alcohol and non-alcohol ticket types share the sub-batch cap; alumni with and without alcohol together cannot exceed 50.

You can also have multiple independent root batches on the same event. Each root batch has its own capacity that is completely separate from the others. This is useful for events with multiple dates or sessions where each has its own cap. For example, a show running on two evenings where each night has 100 seats:

```
Friday (max 100)
└── Friday ticket  ← ticket type

Saturday (max 100)
└── Saturday ticket  ← ticket type
```

Selling out Friday has no effect on Saturday's availability.

For most events, a single batch holding all your ticket types is enough.

## Ticket types

A ticket type is a purchasable item that lives inside a batch. It has:

- **Name** (English and Swedish): shown to attendees
- **Description** (English and Swedish)
- **Start time / End time**: for events with multiple time slots (e.g. a show with two performances), each ticket type can carry its own time
- **Registration Form**: which registration form attendees must fill in when purchasing this type
- **Purchasable**: when unchecked, the ticket type is hidden from the checkout
- **Purchase limit**: maximum number of this ticket type per order
- **Price**: in SEK, as an integer (no decimals). Set to 0 for free tickets.
- **Release time**: if set, the ticket type is not purchasable before this time, and attendees will see when it becomes available. This is the simple FCFS mechanism; for a lottery-based release, see [Releases](/releases/releases).
- **Expire time**: if set, the ticket type becomes unpurchasable after this time
- **Promo code**: if set, the attendee must enter this code during checkout to see the ticket type

### Release time vs. the Release system

There are two separate ways to control when tickets become available, and it's important not to mix them up:

- **Ticket type release time**: a simple timestamp. The ticket type is unpurchasable before this time, then goes on sale to everyone at once on a first-come-first-served basis. Good for scheduled drops where fairness is not a concern, or where overbooking is unlikely.
- **Releases** (the lottery system): when you expect more demand than supply and want allocation to be fair, you create a Release on a batch instead. A Release opens a signup window, runs a draw, and gives winners a purchase window. See [Releases](/releases/releases) for details.

If an active Release exists for a ticket batch, it takes precedence: the ticket types in that batch (or any parent batch) are locked regardless of their individual release times, and cannot be purchased directly until the Release has completed its signup window.

### Pricing

Prices are stored and processed in whole SEK. Tiki does not support decimals or currencies other than SEK. Free tickets (price = 0) skip the payment step entirely, and the order is confirmed immediately at checkout.

### Promo codes

A promo code gates visibility of a ticket type. Attendees who enter the correct code during checkout will see the ticket type; others won't. This is a simple access mechanism — it does not prevent someone who knows the code from sharing it.
