---
name: auth-handling
description: Request authentication from users to access external services like Google, Amadeus, Stripe. Use when you need to connect to a service that requires credentials.
allowed-tools: mcp__bron__request_auth
---

# Auth Handling - Service Authentication

## When to Use

Use the `request_auth` tool when:
- User wants to use an external service
- You need API access for a task
- No existing credentials for the service

## How to Use

Call `request_auth` with:

```json
{
  "provider": "google|amadeus|booking|stripe|uber|etc",
  "auth_type": "oauth|api_key",
  "reason": "Brief explanation of why access is needed"
}
```

## Provider Reference

| Provider | Auth Type | Use For |
|----------|-----------|---------|
| google | oauth | Gmail, Calendar, Drive |
| amadeus | api_key | Flight booking |
| booking | api_key | Hotel booking |
| stripe | api_key | Payments |
| uber | oauth | Rideshare |
| lyft | oauth | Rideshare |
| slack | oauth | Messaging |
| twilio | api_key | SMS |
| doordash | oauth | Food delivery |
| openweathermap | api_key | Weather |

## Examples

### Google Services (Gmail, Calendar)
```json
{
  "provider": "google",
  "auth_type": "oauth",
  "reason": "To access your Gmail and send emails"
}
```

### Flight Booking
```json
{
  "provider": "amadeus",
  "auth_type": "api_key",
  "reason": "To search and book flights"
}
```

### Hotel Booking
```json
{
  "provider": "booking",
  "auth_type": "api_key",
  "reason": "To search and book hotels"
}
```

### Payments
```json
{
  "provider": "stripe",
  "auth_type": "api_key",
  "reason": "To process payment"
}
```

## Auth Flow

1. Call `request_auth` with provider details
2. User sees auth UI (OAuth button or API key input)
3. User completes authentication
4. Credentials are stored securely
5. You can now access the service

## Best Practices

1. **Be specific** in the reason - tell user exactly what you'll do
2. **Request once** - don't ask for auth if already connected
3. **Minimal scope** - only request permissions you need
4. **Immediate use** - after auth, proceed with task immediately

## Response Messages

After requesting auth, say something brief like:
- "Need to connect your Google account first."
- "Connecting to Amadeus for flight search."
- "One moment while I set up payment access."

Keep responses SHORT - don't explain the whole OAuth flow.

