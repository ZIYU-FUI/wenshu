# Quota refusal naming: a spent plan is not a rate limit

## What was wrong

MiniMax answers a spent Token Plan with HTTP 429 and its own numeric code
inside the message text:

```
Error code: 429 - {'type': 'error', 'error': {'type': 'rate_limit_error',
'message': '已达到 Token Plan 用量上限：请升级 Token Plan 套餐或购买积分补充用量。 (2056)',
'http_code': '429'}, 'request_id': '072e842e173009978a64efb5e228e974'}
```

The app read a provider's code only from `baseResp.statusCode`, so on this
path it saw a bare 429 and classified the refusal as a rate limit. The user
was told to wait for a plan that had no quota left, and the agent path
retried it, because the retry decision answered "transient" to every 429.

The sibling code 2067 arrives with HTTP 402 and a different Chinese wording,
and 402 already resolved to the quota failure, so 2067 was already correct
and kept behaving that way.

## The two commits

- `9e0297f8c6` "fix(agent): a spent Token Plan allowance is not a transient
  429" = `Sources/WenshuAgent/Sources/WenshuAgent/Recovery/ErrorClassifier.swift`
  reads the `.transport` error's body (the response's first 500 bytes) and
  answers false for a 429 whose body carries the provider's Token Plan
  allowance wording. The chat layer's single-message collapse is unchanged.
- `a02fac4142` "fix(cover): a MiniMax quota refusal is read from the body" =
  `Sources/WenshuApp/Features/Cover/Service/CoverProviderFailure.swift`
  derives the provider's code from the body when the caller passed none,
  accepts that number only when the provider's own table knows it, and
  keeps `classify` as the single decision point. The table itself, the
  word lists and `.rateLimited` are unchanged.

## The gates

- `swift test --filter CoverProviderFailureTests` on the rebased tree =
  22 tests in 1 suite passed, including "429 with a MiniMax quota code in
  the body is a quota failure".
- `swift test --filter ConversationLoopRunTurnTests` = the reviewer re-ran
  it on the card's branch and the agent card's verdict names it.
- The reviewer read the diff, reverted nothing, and returned an approving
  verdict on both cards, each from the profile that did not implement it.

## Where this is (the durable fact)

Both commits are ancestors of `refs/heads/main` on BOTH remotes, and so is
this record. That is the fact that carries; the tips move as other lanes
land, so they are not quoted here.

- `origin` (gitcode) and `old-origin` (GitHub) both carry the two commits
  and this record as ancestors of their `refs/heads/main`.

## The open item

**The launch-time crash is still unmeasured.** The separate card
`t_0cb4b46d` ran its launch arm and got a VACUOUS arm: six of six trials
read `windows=0 alive=True`, = the app was alive and showed no window, so
it never reached the layout that trips AppKit's runaway-layout guard, and
its zero crashes prove nothing. The arm's own rule says it: a trial with no
window and no report is vacuous, not a pass. The next attempt has to make
the arm reach a window before the crash can be measured at all.
