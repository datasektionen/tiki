%{
title: "What is Tiki?",
description: "An overview of Tiki for admins and team members"
}

---

# What is Tiki?

Tiki is the event and ticket management platform for the Computer Science Chapter at KTH. It covers the full lifecycle of a ticketed event: setting up ticket types and pricing, controlling access with lottery-based releases for high-demand events, accepting payments via card or Swish, and checking in attendees on the door.

> **Who this documentation is for:** This is documentation for **team admins and team members**, the people who create and manage events in Tiki. If you're an attendee looking to buy or manage your own tickets, the platform will guide you through checkout.

## Who manages Tiki

Access in Tiki is organized around teams and roles ([Teams and Access](/introduction/teams-and-access) covers this in full):

- **Site administrators**: manage the platform itself, creating teams and controlling site-wide settings. Site admin access is granted through [Hive](https://hive.datasektionen.se/), the chapter's central permission system.
- **Team admins**: full access within their team. They create and edit events, manage team members, and do everything a team member can.
- **Team members**: manage ticket types, orders, releases, and attendees for the team's events, but cannot manage team membership.

To get access, ask a team admin to add you to their team. If your team doesn't exist yet, ask a site administrator to create it.

## Key concepts

The core entities in Tiki:

- **Event**: the top-level object. An event has a name, date, and location, and contains everything else.
- **Ticket batch**: a named group of ticket types within an event. Most events have one batch, but you can use several to separate, for example, member and non-member tickets, or to attach different release rules to different groups.
- **Ticket type**: a specific purchasable ticket inside a batch, with a name, description, price, and quantity. Attendees buy ticket types.
- **Release**: a distribution mechanism for events where demand outstrips supply. Instead of selling tickets first-come first-served, a release opens a signup window, runs a lottery when it closes, then gives winners a short window to pay. A release is attached to a ticket batch, not a ticket type.
- **Order**: a completed purchase. An order belongs to one attendee and contains one or more tickets. Orders can be paid by card (Stripe) or Swish; free tickets generate an order without a payment step.
- **Form**: optional custom questions attached to a ticket type, such as food preferences. Attendees answer them at checkout, and answers are visible on the order and in reports.

## Setting up an event

The typical setup sequence for a new event:

1. **Log in and select your team.** When you first open the admin interface you'll be prompted to choose which team you're working in.
2. **Create the event.** Set the name, date, location, and description. The event is hidden from the public listing until you're ready.
3. **Add ticket batches and ticket types.** Create at least one batch and add your ticket types inside it, setting a name, price, and quantity for each.
4. **Decide how tickets go on sale:**
   - _First come, first served_: set a release time on each ticket type, and tickets go on sale to everyone at once.
   - _Lottery release_: for high-demand events, create a [Release](/releases/releases) on the batch instead. It opens a signup window, runs a draw, and gives winners a purchase window.
5. **Publish the event** by removing the hidden flag. Attendees can now view and purchase tickets.
6. **On the day**, use the check-in view to scan QR codes and admit attendees.

Attendees pay via card (Stripe) or Swish; free tickets skip the payment step entirely.
