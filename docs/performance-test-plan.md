# Performance and concurrency test plan

## Targets

- p95 below 300 ms for suitable non-heavy authenticated reads under a defined staging load.
- Discovery remains indexed with PostGIS and service/eligibility indexes.
- Booking acceptance and cash collection remain correct under concurrent requests.
- Notification and webhook backlogs remain observable and recoverable.

## Scenarios

1. 100,000 synthetic profiles with realistic service-area distribution.
2. Nearby search at 10, 50 and 100 concurrent requests.
3. Two customers attempting the same professional/time range simultaneously.
4. Two professionals accepting one automatic dispatch simultaneously.
5. Concurrent cash collections near and above the configured exposure threshold.
6. Duplicate/delayed payment webhooks during provider latency.
7. Quote dispute escalation and notification retries during reconnects.
8. Professional active-work uniqueness under repeated start requests.

## Measurements

Record p50/p95/p99 latency, throughput, database lock waits, rejected transitions, duplicate event count, ledger posting latency, webhook age, CPU/memory, and error class. Define pass/fail thresholds in staging before launch and retain the run report with the release artifact.

## Scale responses

Use query plans and indexes first. Partition/archive high-volume event/history data only after measured growth. Keep PostGIS searches bounded by radius and result limit. Add a queue only if scheduled jobs and transactional database locking no longer meet measured reliability targets.
