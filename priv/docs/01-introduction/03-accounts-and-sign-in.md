%{
title: "Accounts and Sign-in",
description: "How attendee accounts and sign-in work in Tiki"
}

---

# Accounts and Sign-in

Tiki supports two ways to sign in:

- **Chapter SSO**: sign in with your chapter account via the Computer Science Chapter's single sign-on system at [sso.datasektionen.se](https://sso.datasektionen.se) (OpenID Connect).
- **Magic link**: enter your email address and Tiki sends you a link that signs you in directly. This is the option for people without a chapter account.

## Buying tickets without an account

Attendees do not need to be signed in to browse events or purchase tickets. During checkout, they fill in their details (such as name and email) manually.

If an attendee _is_ signed in, Tiki pre-fills known fields such as their email address to speed up checkout.

## Releases require sign-in

Signing up for a [release](/releases/releases) requires the attendee to be signed in. This is a deliberate restriction: because the lottery draws winners fairly from the pool of signups, Tiki needs to tie each signup to a verified identity to prevent someone from entering the lottery multiple times.

Attendees who try to sign up for a release while not signed in will be prompted to log in first.
