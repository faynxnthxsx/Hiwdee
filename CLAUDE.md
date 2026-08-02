# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**HiewDee** (`hiewdee`) — a Flutter app that matches people who want items bought abroad/upcountry with travellers who carry them, with the platform holding funds in escrow. Portfolio project. All user-facing strings and most code comments are in **Thai** — match that when editing.

## Environment

`flutter` is **not on PATH**. The SDK lives at `D:\flutter-sdk\bin\flutter.bat` — invoke it by full path, or prepend `$env:PATH = "D:\flutter-sdk\bin;$env:PATH"` in PowerShell first.

## Commands

```powershell
& D:\flutter-sdk\bin\flutter.bat pub get
& D:\flutter-sdk\bin\flutter.bat run -d chrome     # or -d windows / -d edge
& D:\flutter-sdk\bin\flutter.bat analyze           # must stay at "No issues found!"
& D:\flutter-sdk\bin\flutter.bat test
& D:\flutter-sdk\bin\flutter.bat test test/pricing_engine_test.dart          # single file
& D:\flutter-sdk\bin\flutter.bat test --plain-name "ค่าหิ้ว"                  # single group/test
```

Only web (chrome/edge) and windows desktop targets are configured — there is no `android/`, `ios/`, `macos/`, or `linux/` directory.

**Demo login:** any 10-digit phone + OTP `123456`. Phone `0812345678` returns a seeded account with reviews and wallet balance.

## Architecture

`lib/core/` (router, theme, utils) · `lib/shared/widgets/` · `lib/features/<name>/{domain,data,presentation}`.
`domain/` is pure Dart models and business rules with no Flutter or Riverpod imports — that is why the pricing/funding logic is testable without a widget tree. `data/` holds repositories plus their Riverpod providers. `presentation/` holds screens and widgets.

### Guest-first auth — the defining pattern

`app_router.dart` has **no `redirect` and no route guards**. Every route is publicly reachable. Gating happens at the *button* level via the `AuthGate` extension on `WidgetRef` (`lib/core/router/auth_gate.dart`):

- `ensureSignedIn(context, reason:)` → shows `LoginSheet` as a modal bottom sheet, returns `bool`
- `ensureAddress(context, reason:)` → sign-in, then pushes the address form if none exists; returns `Address?`
- `ensureCarrier(context, reason:)` → sign-in, then pushes carrier onboarding; returns `bool`

Each returns a falsy/null value when the user backs out, and callers are expected to abort silently. When adding an action that requires identity, call one of these and check the result — **do not** add a redirect or wrap a screen in an auth check. Tab screens that need auth render `AuthRequiredView` in place of their content rather than navigating away. The notification bell in `feed_screen.dart` is the smallest complete example: gate → sheet → user stays on the feed.

### Cards must be `Material`, not `Container`

Screens are built from full-bleed white cards. Any card containing a `ListTile`/`SwitchListTile` must use `Material(color: Colors.white, …)` — a `Container(color:)` compiles to a `ColoredBox` that hides the tile's background and ink splashes, and Flutter throws a debug assertion for it on every build. `_card()` helpers in `address_form_screen.dart` and `create_request_screen.dart` already do this; `cost_calculator_screen._switchTile` wraps individual tiles in a transparent `Material` where the surrounding card stays a `Container`.

Route order in `app_router.dart` matters and is annotated: `/request/new` must precede `/request/:id`, and `/calculator/guide` must precede `/calculator`.

### State

Riverpod 3 `Notifier`/`NotifierProvider` throughout; no code generation. Repositories are in-memory mocks that seed sample data relative to `DateTime.now()` so it never looks stale (`RequestNotifier._seed`). The Supabase swap is meant to happen behind the existing repository classes without touching `presentation/`.

`AuthController` holds one `AppUser` that can be both requester and carrier — `enableCarrierMode()` flips `isCarrier` on the same user rather than creating a second account.

### Pricing & customs (`lib/features/pricing/`)

The core logic of the project, and where the tests concentrate. `PricingEngine.quote(QuoteInput, ImportRoute)` composes:

- `ThaiCustoms.assess` — two routes with very different outcomes. `handCarry` uses the 20,000฿ traveller allowance (shared across a trip via `allowanceUsedTHB`; non-divisible goods over the allowance are taxed in full, not on the excess). `postal` exempts duty under CIF 1,500฿ but still charges VAT. VAT base is `taxableBase + duty + excise` — never the bare goods price.
- `ServiceFeePolicy.compute` — `max(weight basis, value basis)`, deliberately **not** a sum; `FeeModifier` multipliers compound; result rounds up to 5฿.
- `Parcel` — chargeable weight is `max(actual, W×L×H/5000)`.
- Local tax refund is *extracted* from a tax-inclusive price (`price × r / (1+r)`), then 85% of that.
- FX comes from `FxRates` unless `QuoteInput.fxRateTHB` overrides it. `OriginCountries.all` is a **curated** list — `localTaxRate` and `minSpendForRefund` are legal data that fail silently when wrong, so users never add countries; `OriginCountries.other` (`isCustom: true`) is the escape hatch and the UI must label it as unverified. Duty still computes correctly for it because duty is keyed on the goods' HS category, not the country.
- Currency is selectable independently of country (`cost_calculator_screen._effectiveOrigin`). `minSpendForRefund` is denominated in the country's own currency, so switching currency must convert that threshold — otherwise the refund test compares two different units.
- `paymentFee` is grossed up (`x × r / (1−r)`) so the platform nets the intended amount.
- Platform fee is charged on the **service fee only**, not the order total — the rationale is documented in `pricing_engine.dart` and shouldn't be changed casually.

`ThaiCustoms.collectVatBelowThreshold` is an intentional switch for a policy that changes often.

### Funding (`lib/features/payments/domain/funding_policy.dart`)

Invariant enforced by tests: `FundingPlan.carrierOutOfPocket == 0` in **every** branch. `FundingPolicy.decide` picks a method from the merchant profile (online → platform pays merchant; card-accepting → single-use virtual card; cash-only → advance transfer bounded by `CarrierTier.cashAdvanceCapTHB` plus a bond). Any new branch must keep `carrierOutOfPocket` at 0 — block the order instead.

### Thai geography

`assets/data/thai_geo.json` (7,436 subdistricts) loads once via `thaiGeoRepositoryProvider` (a `FutureProvider`) and is indexed in memory for cascading province → district → subdistrict pickers. Bangkok (code 10) is force-sorted first; postal code auto-fills from the chosen subdistrict.

## Tests

`test/` holds 90 pure-Dart tests (no widget tests). Test names and groups are Thai, so `--plain-name` filters need Thai strings. Riverpod logic is tested with `ProviderContainer` directly. The domain layer's freedom from Flutter imports is what keeps this fast — preserve it.
