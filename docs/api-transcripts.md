# Captured API transcripts

Every block below is literal output from a local run:
Rails 7.0.4.3 on Ruby 3.1.3, PostgreSQL 17.6, server on 127.0.0.1:8800,
webhook basic-auth enabled, Slack credentials deliberately absent.
Generated 2026-09-25T15:31:32Z.

### Health probe

```console
$ curl -sS http://127.0.0.1:8800/up
{"status":"ok","database":"ok"}
< HTTP 200
```

### A spam complaint is stored and an alert is queued (201)

```console
$ curl -sS -u postmark:****** -X POST http://127.0.0.1:8800/api/v1/spam_reports \
    -H "Content-Type: application/json" -d '<payload>'
{"id":6,"record_type":"Bounce","report_type":"SpamNotification","type_code":512,"name":"Spam notification","tag":"welcome-email","message_stream":"outbound","description":"The recipient marked the message as spam.","email":"annoyed-customer@example.com","from":"alerts@notify-spam.test","bounced_at":"2023-03-14T17:29:39.000Z","created_at":"2026-09-25T15:31:33.051Z","updated_at":"2026-09-25T15:31:33.051Z","notified_at":null,"notification_attempts":0,"duplicate":false,"notification_enqueued":true}
< HTTP 201
```

### The same event delivered again is recognised as a replay (200, no second alert)

```console
$ curl -sS -u postmark:****** -X POST http://127.0.0.1:8800/api/v1/spam_reports \
    -H "Content-Type: application/json" -d '<payload>'
{"id":6,"record_type":"Bounce","report_type":"SpamNotification","type_code":512,"name":"Spam notification","tag":"welcome-email","message_stream":"outbound","description":"The recipient marked the message as spam.","email":"annoyed-customer@example.com","from":"alerts@notify-spam.test","bounced_at":"2023-03-14T17:29:39.000Z","created_at":"2026-09-25T15:31:33.051Z","updated_at":"2026-09-25T15:31:33.061Z","notified_at":"2026-09-25T15:31:33.061Z","notification_attempts":0,"duplicate":true,"notification_enqueued":false}
< HTTP 200
```

### A hard bounce is stored without queueing an alert (201)

```console
$ curl -sS -u postmark:****** -X POST http://127.0.0.1:8800/api/v1/spam_reports \
    -H "Content-Type: application/json" -d '<payload>'
{"id":7,"record_type":"Bounce","report_type":"HardBounce","type_code":1,"name":"Hard bounce","tag":"welcome-email","message_stream":"outbound","description":"The server was unable to deliver your message.","email":"gone@example.org","from":"alerts@notify-spam.test","bounced_at":"2023-03-14T18:02:11.000Z","created_at":"2026-09-25T15:31:33.083Z","updated_at":"2026-09-25T15:31:33.083Z","notified_at":null,"notification_attempts":0,"duplicate":false,"notification_enqueued":false}
< HTTP 201
```

### An unknown Type is rejected as a validation error (422, not 500)

```console
$ curl -sS -u postmark:****** -X POST http://127.0.0.1:8800/api/v1/spam_reports \
    -H "Content-Type: application/json" -d '<payload>'
{"message":"Report type \"Nonsense\" is not a valid type (expected one of: SpamNotification, HardBounce, SoftBounce, Delivery)"}
< HTTP 422
```

### A missing required field is rejected (422)

```console
$ curl -sS -u postmark:****** -X POST http://127.0.0.1:8800/api/v1/spam_reports -d '{... no Email ...}'
{"message":"Email can't be blank"}
< HTTP 422
```

### A malformed body is rejected (400)

```console
$ curl -sS -u postmark:****** -X POST http://127.0.0.1:8800/api/v1/spam_reports -d '{not json'
{"message":"Request body could not be parsed as JSON"}
< HTTP 400
```

### Without credentials the endpoint refuses the call (401)

```console
$ curl -sS -X POST http://127.0.0.1:8800/api/v1/spam_reports -d '<payload>'
{"message":"Invalid or missing webhook credentials"}
< HTTP 401
```

### With the wrong password (401)

```console
$ curl -sS -u postmark:wrong -X POST http://127.0.0.1:8800/api/v1/spam_reports -d '<payload>'
{"message":"Invalid or missing webhook credentials"}
< HTTP 401
```
