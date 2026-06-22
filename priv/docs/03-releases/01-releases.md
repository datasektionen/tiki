%{
title: "Releases",
description: "Controlling ticket access with scheduled releases and lottery draws"
}

---

# Releases

A release controls _when_ and _to whom_ tickets become available. Instead of selling first-come-first-served, it opens a signup window. When that window closes, a lottery picks winners from everyone who signed up, and each winner gets a limited time to pay.

Releases are optional. If you don't create one for a ticket batch, its ticket types are available for direct purchase, either immediately or after a specified timestamp (if one is set per ticket type).

## When to use a release

Use a release when you expect more demand than capacity, and you want the allocation to be done via a lottery rather than a race. Typical use case: a popular chapter party where tickets would sell out in seconds if opened directly.

Signing up for a release requires the attendee to be signed in; see [Accounts and Sign-in](/introduction/accounts-and-sign-in).

## Releases belong to ticket batches

A release is always attached to a **ticket batch**, not to individual ticket types. When a release is pending or active, it locks the entire batch it is attached to, including all ticket types directly in that batch and all ticket types in any sub-batches below it. Attendees sign up for specific ticket types within the batch, but the release controls access to all of them as a group.

This means you can use batch nesting to scope a release precisely. For example, you could put all "member" ticket types in one batch and all "non-member" types in a sibling batch, then create a release on only the member batch.

Only one release can be active on a batch at a time, and Tiki also prevents overlapping releases on any ancestor or descendant of that batch; a batch and its relatives can only be under one active release at a time.

## Release fields

- **Name** (English and Swedish): shown to attendees
- **Opens at**: when the signup window starts
- **Signup window** (minutes): how long attendees can register; the draw runs automatically when this closes
- **Purchase window** (minutes): how long winners have to pay after the draw; unpaid orders are cancelled when this expires and their seats fall back to general availability
- **Max tickets per order**: caps how many tickets a single winner can claim. If the event also has a max tickets per order set, the lower of the two values applies.
- **Ticket batch**: the batch whose entire subtree this release controls

## How a release works

A release moves through these phases in order:

| Phase         | What's happening                                                                                                                                                                                                                                                                    |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Scheduled** | The release is configured but the signup window hasn't opened yet. Tickets are locked.                                                                                                                                                                                              |
| **Open**      | The signup window is active. Attendees can register and pick which ticket types they want.                                                                                                                                                                                          |
| **Drawing**   | The signup window has closed. The system is running the lottery. Tickets are still locked.                                                                                                                                                                                          |
| **Purchase**  | The draw is done. Reserved orders are created for all winners and the batch is unlocked. Winners are notified and have the purchase window to complete payment. Any inventory not allocated to a winner (e.g. in an underbooked draw) is immediately available for direct purchase. |
| **Released**  | The purchase window has expired. Reserved orders that were never paid are cancelled and their tickets return to general availability.                                                                                                                                               |

### The lottery draw

When the signup window closes, the draw runs automatically. The algorithm:

1. **Seeded entries win first.** Signups that a team member manually marked as _seeded_ are guaranteed a spot before the random draw. This is useful for reserving tickets for specific people (committee members, speakers, etc.).
2. **Remaining entries are shuffled** using a seeded random function — `SHA256(seed + user_id)` — so the ordering is deterministic and can be independently verified. The seed is stored on the release.
3. **Winners are picked greedily** in priority order until inventory runs out, respecting the full batch tree capacity at every level.

Losing signups receive the status `lost`. Winners get `drawn` (or stay `seeded` if they were pre-seeded). Both groups are notified.

Immediately after the draw, Tiki creates a **reserved order** for each winner based on the ticket types they selected in their signup. The order exists from this moment — the winner does not need to take any action to claim their spot. They only need to complete payment before the purchase window expires.

Once reserved orders are created, the batch is **unlocked**. Any inventory not covered by a reserved order (because fewer people signed up than there were tickets, or because some ticket types had no signups) becomes available for regular direct purchase immediately. If a winner cancels their reserved order at any point during the purchase window, their tickets are released back to general availability right away; they do not wait for the purchase window to expire.

### Managing individual signups

Before the draw runs, team members can intervene on individual signups:

- **Seed** a signup to guarantee it wins.
- **Reject** a signup to remove it from the draw entirely.

Both actions are recorded with who made the decision and when.

## Batch locking

While a release is in the `scheduled`, `open`, or `drawing` phase, the entire batch subtree is locked: no one can reserve any of its ticket types through the normal checkout. Once the draw completes and enters the `purchase` phase, the batch is unlocked. Reserved orders hold the winners' tickets; everything else is available for direct purchase immediately. Tickets from cancelled or expired reserved orders return to general availability the moment the order is cancelled.

## Mixing release and non-release tickets

An order can only contain tickets that belong to the same release context:

- You cannot mix tickets governed by a release with tickets that are available for direct purchase in the same order.
- You cannot mix tickets from two different releases in the same order.

If a user's cart contains such a combination, the system rejects it at checkout with an error message.

The checkout experience is the same whether or not a release is involved: users browse and select tickets exactly as they normally would. The release mechanism operates in the background, and this constraint keeps order processing unambiguous.
