# Soak — Hot Tub Assistant (research, retroactive)

Research retroactively documented 2026-06-05 for Soak v1.0, which submitted 2026-05-31 and is live in the App Store. Mirrors the Pass-1-style structure used for Crust / Flux / Crop / Seal / Pond so future maintenance agents — and the architecturally-parallel Pond app — can reference the *rationale and data lineage*, not just the code. Pricing $3.99, bundle `com.kopaliani.HotTubHelper`, UserDefaults-only persistence, three primary actions (Test & Adjust / After-Use / Shock) + Settings.

Methodology now used for every Moon Dog app didn't exist when Soak was built; this doc backward-fills Pass 1 (industry / brand sources). A manual Pass 2 (r/hottubs + r/spas top-of-last-6-months pass for verbatim pain points + App Store review harvest) is recommended whenever Soak's listing copy is iterated.

## Audience signal

The home hot-tub market is unusually well-suited to a paid-up-front utility app:

- ~7.5M home hot tubs in the US (2024 NSPF / APSP estimates); installed base grows ~250–400k/year. Comparable installed base in EU and AU markets.
- Hardware spend is $4,000–$20,000 for a quality tub; $50–$150/quarter in chemicals. The buyer profile has already cleared the "I'll pay for tools" bar by an order of magnitude.
- Subscription-fatigued: the dominant iOS apps (TestTub, Pooli, Spa Chemical Calculator) lean freemium with subs or ads. The audience explicitly resents "I bought a $10k tub and now you want $5/month for a calculator?"
- Hot-tub chemistry is *recurring* — weekly test + dose, plus per-use top-up, plus weekly shock — so an app gets opened ~2–4 times per week per active user. Retention is structural, not feature-driven.
- Demographic skews 35–65, homeowner, US suburban / EU townhouse / AU coastal. Higher willingness to pay than the median App Store buyer.

Reddit signal (subscriber counts not retrievable at runtime; ballpark):

- r/hottubs — substantial generalist sub
- r/spas — overlapping
- r/troublefreepool — adjacent and overlapping; TFP forum is where serious chemistry questions go
- Hot Tub Patio + Spa Search forums — older but high-quality demographic

## Calculator domain (what users actually want)

Priority order based on TFP wiki structure, Hot Tub Patio / Spa Depot Q&A boards, and Soak's own Test & Adjust flow:

1. **Test result → corrective dose, brand-aware** — the core math. User enters FC/Br + pH + TA + CH, picks their preferred chlorine product (liquid 12.5% / cal-hypo 68% / dichlor 56%) + pH lowerer (dry acid / muriatic 31.45%); Soak returns grams or mL per chemical sized to tub volume. ~70% of why someone opens this. *This is what Soak ships.*
2. **Plain-English "outside practical range → re-test" advisory** — kit error catch. If pH reads 15 or sanitizer reads 50, the user mis-read or the kit reagent expired. *This is what Soak ships.*
3. **"Sanitizer is high → wait, don't add more" advisory** — symptom-first guidance for the canonical "I overshocked, what now?" question. *This is what Soak ships.*
4. **After-use top-up dose** — bather load adds ~1 ppm sanitizer demand per person-hour; the dose is "how much do I add tonight." *This is what Soak ships.*
5. **Weekly shock cycle** — chlorine-shock to 10 ppm equivalent for chlorine systems, MPS at 1 oz/100 gal for bromine. *This is what Soak ships.*
6. **Cyanuric acid (CYA) tracking and FC/CYA ratio** — for chlorine users, CYA accumulates from dichlor and silently lowers effective FC; chronic chlorine-low-but-CYA-high is the canonical TFP diagnostic. *Soak v1.0 does NOT ship this; defined in `Formulas.TargetRange.cyanuricAcid` but never surfaced in UI.*
7. **Combined-parameter diagnostics** — high pH + low TA = CO₂ imbalance; low CH + high pH = scale risk; chronic FC + high TA = chronic high pH. *Soak v1.0 does NOT ship this; advisories trigger per-parameter only.*
8. **Salt-chlorinator systems** — Frog @ease, Hot Spring ACE, salt-only spas with on-board chlorine generation. *Soak v1.0 does NOT ship this; sanitizer enum is `{ chlorine, bromine }` only.*
9. **Test history / trend** — "your FC was 2.5 last week, now 1.8" delta. *Soak v1.0 does NOT ship this; UserDefaults-only persistence has no history array.*
10. **Drain & refill + filter cleaning reminders** — every ~3–4 months for drain/refill; weekly rinse + quarterly chemical soak for filters. *Soak v1.0 does NOT ship this; Frost ships it (TubType + cadence reminders).*

## Authoritative sources

- [TroubleFreePool — PoolMath formulas + wiki](https://www.troublefreepool.com/wiki/index.php?title=Calculators) — the canonical reference for every chemistry constant in Soak's `Formulas.swift`. TFP's TFPC methodology underpins the dose math.
- [PoolMath by TFP (iOS)](https://apps.apple.com/us/app/pool-math-by-troublefreepool/id1228819359) — free, pool-first, the gold-standard reference app; not a hot-tub-first product.
- [Hot Tub Patio guides + calculator](https://hottubpatio.com/hot-tub-chemical-calculator-app/)
- [Spa Depot / SpaSearch forums](https://www.spasearch.org/) — older but technically deep
- [Industry pool / spa chemistry guides] — generic but consistent on the 10k-gal reference for dose scaling
- [AquaChek test-strip reference ranges](https://www.aquachek.com/) — used implicitly in the practical-range advisories

## Chemistry data — every constant cited

### Sanitizer constants (per 10,000 gal to raise FC or Br by 1 ppm)

| Constant | Value | Unit | Source |
|---|---|---|---|
| Liquid chlorine 12.5% | 10.0 | fl oz | TFP PoolMath; sodium hypochlorite solution density × 12.5% available chlorine |
| Cal-hypo 68% | 2.0 | oz (dry) | TFP PoolMath; calcium hypochlorite granular 68% available chlorine |
| Dichlor 56% | 2.4 | oz (dry) | TFP PoolMath; sodium dichloroisocyanurate, also contributes ~0.9 ppm CYA per ppm FC (Soak does not currently track this drift) |
| Sodium bromide → bromine | 0.13 oz / 100 gal / 1 ppm | oz | Industry rule-of-thumb; equivalent to ~1.3 g per 100 gal per 1 ppm |

### pH constants (per 10,000 gal to shift pH by 0.1)

| Constant | Value | Unit | Source |
|---|---|---|---|
| Soda ash (sodium carbonate) | 3.0 | oz | TFP PoolMath; assumes typical TA ~80–120 ppm buffer |
| Dry acid (sodium bisulfate) | 0.5 | oz | TFP PoolMath; same buffer assumption |
| Muriatic acid 31.45% | 6.4 | fl oz | TFP PoolMath; HCl 31.45% w/w solution |

### Alkalinity + calcium constants

| Constant | Value | Unit | Source |
|---|---|---|---|
| Baking soda (TA raise, per 10k gal per 10 ppm) | 1.5 | lb | TFP PoolMath; sodium bicarbonate to total alkalinity |
| Muriatic 31.45% (TA lower, per 10k gal per 10 ppm) | 1.0 | qt | TFP PoolMath; pairs with aeration to drive off CO₂ |
| Calcium chloride (CH raise, per 10k gal per 10 ppm) | 1.0 | lb | TFP PoolMath; calcium chloride dihydrate equivalent |

### Target and practical ranges

| Parameter | Target | Ideal | Practical | Source |
|---|---|---|---|---|
| Free Chlorine | 1.0–3.0 ppm | — | 0–20 | TFP / industry hot-tub guidance |
| Bromine | 2.0–4.0 ppm | — | 0–20 | TFP / industry |
| pH | 7.2–7.8 | 7.4–7.6 | 0–14 | TFP / industry |
| Total Alkalinity | 80–120 ppm | — | 0–500 | TFP |
| Calcium Hardness | 150–250 ppm | — | 0–1000 | TFP (varies by region/source water) |
| Cyanuric Acid | 30–50 ppm | — | (not enforced) | TFP — **defined but not surfaced in v1** |

### Bather-load + shock constants

- After-use demand: 1 ppm sanitizer per person-hour (industry rule-of-thumb)
- Chlorine shock target: 10 ppm FC equivalent (TFP for non-CYA-corrected; with CYA the TFP "SLAM" level is higher — v1 does not model this)
- Bromine shock: 1 oz MPS (potassium monopersulfate) per 100 gal (industry)

## Competing apps — landscape + gaps

| App | Platform | Price | Strengths | Misses |
|---|---|---|---|---|
| **TestTub** | iOS | Freemium / sub | Step-by-step Taylor-kit instructions, multi-system support, offline | Sub-monetized; complexity wall for casual users |
| **Pooli** | iOS | Freemium / sub | Test-strip camera scanning, borate-aware adjusted alkalinity, recent cold-plunge support | Sub; pool-first heritage; camera scanning over-promises in mixed lighting |
| **HotTub&Pool** | iOS | Paid | LSI calculation, dose math for the standard chemistry set | Older UX; not actively maintained |
| **Spa Chemical Calculator** | iOS | Free (ads) | Basic dose math, step guides | Ad-supported; no brand-aware product picker |
| **PoolMath by TFP** | iOS | Free | The TFPC gold standard; underpins Soak's formulas | Pool-first; hot-tub usage requires the user to mentally scale and ignore irrelevant fields |

**The gap Soak fills:** every paid-or-attention-quality option is *either* sub-monetized (TestTub / Pooli), *or* ad-supported (Spa Chemical Calculator), *or* pool-first (PoolMath, HotTub&Pool), *or* aging without the modern iOS-native UX patterns. **Soak ships paid-up-front, ad-free, account-free, hot-tub-first, brand-aware, symptom-first.** $3.99 paid once against $5/month for TestTub or Pooli is the wedge.

## Verbatim pain points (placeholder — to be harvested in a Pass 2 sweep)

Documented pain themes recur across forum threads and competing-app reviews; literal quotes will be filled in if/when Soak's listing copy is iterated:

- "Why does the app think my hot tub is a swimming pool?" — pool-first apps over-fitting math
- "I have to subscribe to use the calculator?" — the canonical sub-fatigue complaint
- "I added the suggested dose and pH didn't move" — typical when TA is far from target buffer assumption
- "I'm using dichlor — should I switch to liquid?" — CYA-creep question Soak doesn't currently address
- "What do I do when both pH and FC are high?" — combined-parameter diagnosis question Soak doesn't currently address
- "My salt system Frog @ease — your app doesn't know about it" — salt-chlorinator gap

## Differentiation thesis

Three things Soak does that none of the iOS hot-tub apps do in combination:

1. **Brand-aware corrective doses keyed to the specific product on the user's shelf** — picking "dichlor 56%" vs "cal-hypo 68%" vs "liquid 12.5%" changes the output unit and quantity. The user doesn't translate; Soak does. Same wedge ported to every later Moon Dog app.
2. **Symptom-first home + practical-range advisories** — "your reading is outside practical range, re-test your kit" / "sanitizer is high, wait don't add" — the Soak voice is "what should I do?" not "configure these parameters." This is the Moon Dog product voice in its first form.
3. **Paid-up-front, $3.99, no subscription, no ads, no account, offline** — the wedge against TestTub / Pooli's subs and Spa Chemical Calculator's ads. The audience already paid $10,000 for the tub; $3.99 is rounding.

## Risks / footguns (what to watch)

- **Chemistry-data correctness is load-bearing.** A wrong constant on liquid chlorine 12.5% silently corrupts every chlorine dose. The TFP citation per constant in this doc (and ideally inline in Soak's UI in v1.1) is the audit trail.
- **CYA drift on dichlor users is silent in v1.0.** Owners using dichlor weekly add ~0.9 ppm CYA per ppm FC. After ~3 months CYA can hit 100+ ppm and effective FC drops below sanitizing threshold even when test strips read 2 ppm. v1.0 doesn't warn; the user blames the test kit. **This is the single biggest functional risk in the shipped product.**
- **Salt-chlorinator owners are excluded.** Sanitizer enum is `{ chlorine, bromine }` only. Frog @ease / Hot Spring ACE / generic salt-only spa owners can't model their system; some bounce off, some hack around it (treat as chlorine).
- **Apple App Review on chemistry-claims framing.** TFP-cited dose math is defensible; "this is safe to drink" claims would not be. Soak stays on the chemistry side and uses "Per industry guidance" language indirectly through the TFP citation chain.
- **CH range varies by source water.** Hard-water regions (US Southwest, parts of EU) routinely have tap water CH > 400 ppm; Soak's 150–250 target assumes typical municipal water and doesn't surface a regional override.

## Scope read (retroactive — what shipped in v1.0)

What v1.0 ships:
- Brand-aware dose math for FC (3 products), pH up/down (3 products), TA up/down, CH up
- Test & Adjust screen with 4 readings + status dot + recommendations + advisories
- After-Use Dose with person × hours stepper and heavy-use advisory (≥5 person-hours)
- Shock cycle with 4-step instructions
- 3-step onboarding (volume / sanitizer / preferred chemicals)
- Settings (units, volume, sanitizer, products, privacy / support)
- Locale-aware metric default + decimal-separator handling
- UI-test instrumentation flags (`-UITestDemoState`, `-UITestSampleReadings`, `-UITestStartScreen=…`)
- Test coverage for every formula via absolute-tolerance assertions in `FormulasTests`

What v1.0 does NOT ship: v1.1+ planning lives in [`BACKLOG.md`](BACKLOG.md). This research doc stays as the *snapshot* of the retroactive Pass-1 sweep; the backlog is the *living* engineering planning surface where active feature specs + handoffs land.

## Pricing rationale

$3.99 paid up-front. The lowest price band in the Moon Dog portfolio.

- Sub competitors (TestTub, Pooli) set the "$5/month or $50/year" reference. Soak's $3.99 paid once = 10 months of one competitor sub.
- Soak's chemistry is simpler than Reef's; the audience is broader and price-sensitive at the margin (hot-tub buyers vs reef-aquarium hobbyists).
- $3.99 maximizes conversion against the free / freemium alternatives.
- Validate post-launch; consider $4.99 only after the next 3 apps post-launch data set the band.

## Sources

- [TroubleFreePool — PoolMath formulas + wiki](https://www.troublefreepool.com/wiki/index.php?title=Calculators)
- [PoolMath by TFP (iOS)](https://apps.apple.com/us/app/pool-math-by-troublefreepool/id1228819359)
- [PoolMath calculator (web)](https://www.troublefreepool.com/calc.html)
- [PoolMath release blog (2026)](https://www.troublefreepool.com/blog/2026/02/06/pool-chemical-calculator-poolmath/)
- [TestTub (App Store)](https://apps.apple.com/us/app/testtub/id6749869752) — competitor
- [Pooli (App Store + release notes)](https://pooli.app/release/) — competitor
- [HotTub&Pool (App Store)](https://apps.apple.com/us/app/hottub-pool/id358719601) — competitor
- [Spa Chemical Calculator (Google Play)](https://play.google.com/store/apps/details?id=com.spachemicalcaculator.spa_calc_app&hl=en_US) — competitor
- [Hot Tub Patio guides](https://hottubpatio.com/hot-tub-chemical-calculator-app/)
- [SwimUniversity — 6 best pool chemical calculator apps 2026](https://www.swimuniversity.com/pool-chemical-calcuator-apps/)
- [PoolPad — Pool chemical calculator apps overview](https://www.poolpad.com/pool-chemical-calcuator-apps/)
