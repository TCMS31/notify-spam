# Captured pipeline evidence

Literal output from a local run on 2026-09-25 (Ruby 3.1.3, Rails 7.0.4.3,
PostgreSQL 17.6), seeded with `bin/rails db:seed` and then driven by the
requests in [api-transcripts.md](api-transcripts.md). Slack credentials are
deliberately unset, so the app degrades to the null notifier and logs the
alert instead of sending it.

## 1. The rendered Slack alert

Driving the real `SlackNotifier` with a recording double in place of its HTTP
client shows exactly what `chat.postMessage` would receive:

```console
$ bin/rails runner script/slack_preview.rb
chat.postMessage channel=#email-alerts
text:
  | Request with Spam Payload detected! 
  |  *Type*: SpamNotification 
  |  *Email*: annoyed@example.com 
  |  *Description*: The recipient marked the message as spam.
receipt: slack:1678814979.000100
```

## 2. What is stored after those requests

```console
$ bin/rails runner 'SpamReport.order(:id).each { |r| puts format("%-3s %-17s %-5s %-30s %s", r.id, r.report_type, r.type_code, r.email, r.notified? ? "notified" : "-") }'
1   SpamNotification  512   annoyed@example.com            -
2   SpamNotification  512   reporter@example.net           -
3   HardBounce        1     gone@example.org               -
4   SoftBounce        4     full@example.org               -
5   Delivery          0     happy@example.com              -
6   SpamNotification  512   annoyed-customer@example.com   notified
7   HardBounce        1     gone@example.org               -
```

Only `SpamNotification` events carrying type code 512 are ever alerted on;
everything else is stored for the record and nothing more.

## 3. Undelivered alerts can be swept

The default `:async` Active Job adapter runs in-process, so work queued by a
short-lived process (`db:seed`) is lost when it exits. Because `notified_at`
records what actually reached Slack rather than what was attempted, the
pending set is exact and re-queueing it cannot double-send.

```console
$ bin/rails notifications:sweep
queued 2 pending notification(s)
```
