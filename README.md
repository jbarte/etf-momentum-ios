# ETF Momentum for iOS

A native SwiftUI reader for the [ETF Momentum](https://jbarte.github.io/sector_momentum/)
leaderboard. A personal project, **not investment advice**.

Scoring, the database and the web dashboard live in
[jbarte/sector_momentum](https://github.com/jbarte/sector_momentum). This app
signs in with the same invite-only Supabase account and derives the board
natively: rank, composite, Level/Change, rank delta, trend, and the Enter/Exit
band for the chosen horizon.

## Layout

One root Swift package, every module a target, built on Point-Free's
[swift-dependencies](https://github.com/pointfreeco/swift-dependencies):

- `MomentumKit` — the board rules, tested against `band-fixture.json`, which
  sector_momentum's Python generates.
- `SignInClient`, `ScoresClient`, `FeedClient`, `BoardCacheClient` — the
  app's side effects, as swappable clients.
- `SupabaseLive` — the live sign-in and scores clients.
- `SignInFeature`, `BoardFeature` — models, views, previews.
- `AppFeature` — the composition root.
- `App/` — the Xcode app, which links only `AppFeature`.

## Run

    open App/ETFMomentum.xcodeproj

Approve "Trust & Enable" for the swift-dependencies macros on first build. Add
the launch argument `-UseStubData` to run on invented data without signing in.
On an iPhone with a free Apple account, pick your Personal Team under Signing &
Capabilities; the install expires after 7 days, and running it again renews it.

## Test

    swift test
    scripts/check-fixture.sh
