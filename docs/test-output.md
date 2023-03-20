# Captured test and lint output

Literal output from 2026-09-25 (Ruby 3.1.3, Rails 7.0.4.3, PostgreSQL 17.6).

## Test suite

```console
$ bin/rails test

...............................................................

Finished in 0.246380s, 255.7026 runs/s, 815.8130 assertions/s.
63 runs, 201 assertions, 0 failures, 0 errors, 0 skips
```

## Linter

```console
$ bundle exec rubocop
................................................

48 files inspected, no offenses detected
```

## Proof that the suite can fail

A green suite proves nothing on its own, so the delivery-correctness
invariants were checked by mutation.

Mutation 1 - stamp `notified_at` *before* the send (the bug this design
exists to prevent) and drop the replay lookup from `SpamReportIngestion`:

```
55 runs, 173 assertions, 5 failures, 1 errors, 0 skips
```

Mutation 2 - make the idempotency key random instead of content-derived:

```
55 runs, 177 assertions, 4 failures, 0 errors, 0 skips

SpamReportIngestionTest#test_a_replayed_webhook_is_recognised_and_neither_stored_nor_alerted_twice
SpamReportIngestionTest#test_loses_the_insert_race_gracefully_and_reports_a_duplicate
SpamReportsApiTest#test_a_replayed_webhook_answers_200_and_queues_nothing
SpamReportTest#test_event_key_is_stable_for_the_same_event_and_different_for_a_changed_one
```

Both mutations were reverted. The counts differ from the totals above because
the mutation runs predate the health-check and middleware tests.
