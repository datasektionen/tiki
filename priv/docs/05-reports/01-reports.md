%{
title: "Reports and Exports",
description: "Generating ticket sales reports and exporting registration data"
}

---

# Reports and Exports

Tiki has two ways to get data out of the system: **sales reports** for bookkeeping and financial reconciliation, and **form answer exports** for analyzing registration data.

## Access

Sales reports are only accessible to site administrators and auditors. These roles are managed outside of Tiki, through [Hive](https://hive.datasektionen.se/), the chapter's central permission system. If you need report access, ask a Hive administrator to grant you the appropriate role.

[Form answer exports](/reports/reports#form-answer-exports) are available to all team members for their own events.

## Sales reports

A report gives a summary of ticket revenue over a given period, broken down by ticket type, with optional individual transaction details. Reports are generated asynchronously: you configure the parameters, submit the request, and the report is delivered when ready.

### Filters

- **Event**: filter to a specific event, or include all events
- **Ticket types**: narrow down to specific ticket types within the selected event(s)
- **Date range**: include only orders paid within a start and end date (inclusive)
- **Payment method**: filter by card (Stripe), Swish, or leave blank for all
- **Include transaction details**: when enabled, the report includes one row per individual ticket in addition to the summary

### Report output

- **Summary**: aggregated revenue and ticket count per ticket type
- **Transaction details** (if requested): individual ticket-level rows with price and payment method
- **Grand total**: total revenue across all included tickets
- **Total tickets**: total number of tickets sold

Prices in reports reflect the price at the time of purchase, taken from the order audit log, so historical reports remain accurate even if ticket prices are later changed.

## Form answer exports

Form responses for an event can be exported as a ZIP archive of CSV files. Each form gets its own CSV file named after the form. A separate `non-answered.csv` file lists any tickets whose holder has not yet submitted a form response.

The export is available from the attendees section of the event management panel, under form answers. This is useful if you need to process responses outside Tiki, for example to generate seating plans or dietary summaries.

See [Forms](/events/forms) for more on how forms and questions are configured.
