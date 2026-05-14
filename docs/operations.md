# Operations

V1 defaults to file-backed local durability and a small runtime.

## Local Verification

```bash
cd server
mix precommit
```

## Runtime Review Checklist

- Can duplicate commands mutate state twice?
- Can duplicate ticks advance time twice?
- Does restart replay the same snapshot?
- Are events persisted before broadcast?
- Are actor/session mismatches rejected before rules run?
- Are AI or slow external calls outside GenServer bottlenecks?

## Production Notes

- Use TLS.
- Disable `dev_open`.
- Protect admin routes.
- Configure payload and rate limits.
- Keep logs free of tokens, secrets, prompts, and private player data.
