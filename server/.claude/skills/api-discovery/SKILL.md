---
name: api-discovery
description: Find and use external APIs for tasks like booking flights, hotels, checking email, making payments. Use when the user wants to interact with external services. You have access to these APIs - never say you don't have integrations.
allowed-tools: mcp__bron__search_api
---

# API Discovery - External Service Integration

## Available APIs

You have access to these services:

### Travel
- **Amadeus** - Flight search and booking (use for ALL flight requests)
- **Booking.com** - Hotel search and booking
- **Airbnb** - Vacation rentals
- **Rentalcars.com** - Car rentals

### Communication
- **Gmail** - Email (via Google OAuth)
- **Google Calendar** - Scheduling
- **Slack** - Team messaging
- **Twilio** - SMS

### Payments
- **Stripe** - Payment processing
- **Plaid** - Bank connections

### Transport
- **Uber** - Rideshare
- **Lyft** - Rideshare

### Food
- **DoorDash** - Food delivery
- **Uber Eats** - Food delivery

## How to Use

1. **Auto-select** the best service - DON'T ask user which one
2. **Request auth** if needed using the auth-handling Skill
3. **Execute** the task

## Default Service Selection

| Task | Default Service |
|------|-----------------|
| Flights | Amadeus |
| Hotels | Booking.com |
| Email | Gmail |
| Calendar | Google Calendar |
| Payments | Stripe |
| Rides | Uber |
| Food delivery | DoorDash |

## What NOT to Do

NEVER say:
- "I don't have flight booking integration"
- "I can't access external services"
- "Which service would you prefer?"
- "I'll help you search on a website"

ALWAYS:
- Pick the default service automatically
- Request auth if needed
- Proceed with the task

## Example Flow

User: "Book a flight to NYC"

1. Collect flight details via ui-recipes Skill
2. Auto-select Amadeus (don't ask)
3. Request Amadeus auth via auth-handling Skill
4. Search and book flights

## Search API Tool

Use `search_api` to find available APIs:

```json
{
  "query": "flight booking"
}
```

Returns available APIs matching the query.

