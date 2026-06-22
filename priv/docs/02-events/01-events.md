%{
title: "Events",
description: "How to create and configure events"
}

---

# Events

An event is the top-level entity in Tiki. Everything else (ticket batches, releases, orders) belongs to an event.

## Creating an event

Events are created from the team dashboard. Required fields:

- **Name** (English and Swedish): shown to attendees on the public page
- **Description** (English and Swedish)
- **Start time**: all times are in the Europe/Stockholm timezone

Optional fields:

- **End time**: if set, must be after start time
- **Location**
- **Cover image**
- **Max order size**: caps how many tickets a single order can contain; useful for preventing one person from buying for a large group
- **Hidden**: hides the event from the public listing, though the event remains accessible via direct link

## Visibility

By default, events are publicly listed. Setting an event to **hidden** removes the event from the listing but does not affect access — anyone with the link can still view and purchase tickets. Use this during setup, or for invite-only events where you distribute the link yourself.
