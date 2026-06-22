%{
title: "Teams and Access",
description: "How access is organized in Tiki: site admins, teams, and roles"
}

---

# Teams and Access

Access in Tiki is organized into two layers: site-level access controlled by site administrators, and team-level access controlled by team admins.

## Site administrators

Site administrators manage the Tiki platform itself. They can:

- Create and delete teams
- Perform site-wide administrative actions (e.g. accessing sales reports)

Site admin access is granted through [Hive](https://hive.datasektionen.se/), the Computer Science Chapter's central permission system; it is not managed inside Tiki. If you need site admin access, contact Systemansvarig at [d-sys@datasektionen.se](mailto:d-sys@datasektionen.se).

## Teams

A team is the organizational unit in Tiki. Each team owns its events, and everyone who manages those events must be a member of that team.

Most organizer groups within the chapter have their own team. If your team doesn't exist yet, ask a site administrator to create it.

## Roles within a team

There are two roles a team member can hold:

| Role            | Can do                                                                                                                          |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| **Team admin**  | Everything a team member can do, plus: create and edit events, and manage team membership (add/remove members, change roles).   |
| **Team member** | Manage ticket types, orders, releases, and attendees for the team's events. Cannot manage team membership or create new events. |

To be added to a team, ask a team admin. To get a new team created, ask a site administrator.

## Selecting a team

When you first log in to the Tiki admin interface, you will be prompted to select which team you want to work in. If you are a member of multiple teams, you can switch between them at any time from the top navigation.

All actions (creating events, viewing orders, running reports) are scoped to the currently selected team.
