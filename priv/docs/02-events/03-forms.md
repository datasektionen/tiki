%{
title: "Forms",
description: "Collecting information from attendees at checkout"
}

---

# Forms

Forms let you collect information from attendees when they purchase a ticket. After checkout, attendees are prompted to fill in the form associated with their [ticket type](/events/ticket-batches-and-types#ticket-types) before their registration is considered complete.

Common use cases: food preferences, seating preferences, or any question specific to a ticket type.

## Default form

When a new event is created, a default form is automatically created for it. For many events this default form is sufficient without changes; it collects the attendee's name and email. When creating a ticket type, the event's default form is pre-selected, so you don't have to configure anything unless you need something different.

## How forms are scoped

Forms belong to an event and are then assigned to ticket types. A ticket type must have exactly one form. This means:

- You can use the default form for all ticket types (good for simple cases).
- Or you can create separate forms per ticket type. For example, a VIP ticket might ask additional questions that are not relevant for general admission.

## Question types

Each form contains one or more questions. Available question types:

| Type              | Description                                                 |
| ----------------- | ----------------------------------------------------------- |
| **Attendee name** | Asks for the attendee's name; see the note below            |
| **Text**          | A single-line free-text answer                              |
| **Text area**     | A multi-line free-text answer                               |
| **Email**         | An email address field with format validation               |
| **Select**        | A dropdown with a fixed list of options; attendee picks one |
| **Multi-select**  | A list of options where attendee can pick multiple          |

All question types support English and Swedish labels and descriptions. Select and multi-select questions require the same number of options in both languages.

Questions can be marked **required**, which prevents the attendee from skipping the question.

> **Note on attendee name:** A ticket is purchased by one user, but may be intended for someone else. Without an attendee name question on the form, you only know who bought the ticket — not who will actually attend. If knowing each individual attendee's name matters for your event (e.g. for a guest list or seating plan), make sure to include an attendee name question and mark it required.

## Viewing and exporting form responses

Responses for an event can be viewed from the attendees section of the event management panel, filtered by form. Responses can also be exported as CSV files; see [Reports and Exports](/reports/reports#form-answer-exports).
