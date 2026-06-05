# Soak — Backlog

Living engineering planning surface for Soak v1.1+. Pairs with [`SOAK_RESEARCH.md`](SOAK_RESEARCH.md) (product / market snapshot from the retroactive Pass-1 sweep). Structure convention documented in [`SPEC.md`](../SPEC.md) "Feature backlog".

## Shipped

| Version | Date | Changes |
|---|---|---|
| v1.0 | 2026-05-31 | Initial submission. Brand-aware dose math (FC / Br / pH / TA / CH) with 3 chlorine products + 2 pH lowerers; Test & Adjust + After-Use + Shock + Settings + 3-step onboarding; UserDefaults persistence; locale-aware metric default; UI-test instrumentation flags |
| v1.0.1 | 2026-06-XX | UX polish + iOS 17 deployment floor |

## Up next — v1.1: Localization

### Why

Single biggest revenue lever for a shipped indie iOS utility per the 2025–2026 indie-recap research (Roman Koch's January 2026 Medium post; Itemlist localization-recovery data). Apple's own numbers: localized apps see up to 128% more downloads per country and 38% lift vs non-localized. Each localization gives a fresh 30-char subtitle + 100-char keyword allocation in App Store Connect — the multiplier effect compounds existing US ranking through cross-localization. Soak is live, the chemistry is stable, and the audience profile (hot-tub owners 35–65) is widely distributed across European + Asian markets. Sourced from [`SOAK_RESEARCH.md`](SOAK_RESEARCH.md) v1.1 backlog (medium priority, ~2–3 days effort estimate; localization-execution research adds ~half a day for App Store Connect metadata + screenshot regeneration so revised estimate is ~3–4 days end-to-end).

### Scope

**In:**
- All user-facing UI strings in Soak.app extracted to a String Catalog (`Localizable.xcstrings`)
- 5 languages: **DE, ES, FR, IT, JA**
- App Store Connect localized metadata per language: subtitle (≤30 chars), promotional text (≤170), description (~280 words per the [`LISTING_PROMPTS.md`](../LISTING_PROMPTS.md) 7-block structure), keywords (≤100 chars no spaces)
- Regenerated screenshots per language using the [`SCREENSHOT_PROMPTS.md`](../SCREENSHOT_PROMPTS.md) 4-shot plan: iPhone 6.9" + iPad 13" × 4 shots × 5 languages = 40 PNGs
- Localized "What's New" v1.1 copy per language
- String Catalog plural-rule handling where relevant ("person" / "people", "session" / "sessions")

**Out (explicitly deferred):**
- TFP source-citation copy — TroubleFreePool is an English-only forum; translating "Per TFP: …" loses provenance signal. The advisory phrasing stays English where source attribution would distort. (If the v1.1 source-attributed-advisory feature ships in parallel, revisit.)
- Brand product names — "Dichlor 56%", "Cal-hypo 68%", "Liquid chlorine 12.5%", "Muriatic acid 31.45%", "Soda ash", "Dry acid", "Calcium chloride", "Sodium bromide" — these are chemical / commercial identifiers, not user-facing prose. Stay as-printed-on-label.
- Privacy policy and support pages — separate web site (`daria-kopaliani.github.io/moondog/hottub/…`), out of app scope. v1.2+.
- App name — "Soak: Hot Tub Assistant" stays globally per the Submit-Sequence step 1 rule (App Store name is locked at first submission).
- Regional tub-volume conventions — onboarding help text "Typical home tubs hold 250–500 gallons / 950–1900 liters" is already useMetric-branched; no per-locale override in v1.1.
- KO / ZH-Hans / PT-BR — high App Store revenue tier but lower hot-tub-specific market fit; queued for v1.2 if v1.1 conversion data justifies.

### Approach

**String extraction:**
- Audit every user-facing literal in `soak/HotTubHelper/HotTubHelper/` — start with Models.swift (`displayName`), Views/*.swift (all `Text(...)` strings, navigationTitle, footer strings, advisory bodies, recommendation titles), HotTubConfig.swift (any user-visible defaults).
- Right-click any existing `.strings` file → "Migrate to String Catalog" (Xcode 26 native command). For Soak, no existing `.strings` file is present — create `Localizable.xcstrings` fresh in the app target.
- Mark strings for localization with `String(localized: "key")` or the SwiftUI `Text("key")` form (auto-localizes when the String Catalog has the key).
- Use String Catalog's built-in pluralization for "%d person" / "%d people" and "%d session" / "%d sessions" — no manual `Localizable.stringsdict` needed; xcstrings handles it.

**Translation method (per-language split):**
- **DeepL Free tier** for DE / ES / FR / IT — DeepL ranked #1 for European-language quality in the 2026 Intento benchmark; Free tier is 50,000 chars/month and Soak's UI strings are ~3,000–5,000 chars total. Cost: $0.
- **Claude (Opus 4.6 or 4.7) primary, DeepL cross-check** for JA — per benchmark, Claude/ChatGPT outperforms DeepL on Asian languages for context-heavy / idiomatic text. Hot-tub chemistry vocabulary needs Japanese-natural phrasing for advisories ("warning" tone differs from English).
- **Manual chemistry-vocab review pass** per language — Daria reviews chemistry-specific strings (FC, Br, ppm, alkalinity, calcium hardness, sanitizer) against the local hot-tub-care vocabulary. For markets where Daria isn't fluent, a native-speaker friend pass is the fallback before submission.

**Character expansion:**
- Assume DE / FR strings are ~30% longer than EN (well-documented).
- Audit the dose hero (`DoseHero` in NumericInput.swift), reading rows (`readingRow` in TestAdjustView), and Settings volume row — the three places where layout is tight.
- If overflow risk, use `.minimumScaleFactor(0.8)` on the offending Text or shorten the EN source string.

**App Store Connect metadata workflow:**
- 5 languages × (subtitle + promo + description + keywords + What's New) = 25 metadata entries.
- Per [`LISTING_PROMPTS.md`](../LISTING_PROMPTS.md) structure: keywords field is comma-separated no spaces; description is the 7-block hooked structure (~280 words); subtitle ≤30 chars; promo ≤170; "What's New" is per-version localized copy.
- Use the `pbcopy` clipboard delivery flow per `SPEC.md` Submit Sequence — each localized field gets written to `listing-{lang}.txt` first, then `pbcopy < file` to preserve paragraph breaks.

**Screenshot regeneration:**
- 4 shots × 2 devices × 5 languages = **40 PNGs**.
- Re-use the captured PNGs from initial v1.0 submission (the *content* in dark mode at 9:41 doesn't change). Only the caption-text overlay differs.
- If Soak's screenshots were composed in Figma per [`SCREENSHOT_PROMPTS.md`](../SCREENSHOT_PROMPTS.md), duplicate the source file 5 times and swap the caption text per language. If composed via a screenshot tool (Picasso / AppMockUp), follow that tool's localization export flow.
- Caption translations: use the same DeepL / Claude split as in-app strings. Verify ≤55 chars per language (caption length budget per `SCREENSHOT_PROMPTS.md`); German captions may need rephrasing if 30%-expansion blows the budget.

### Open questions

(Resolved 2026-06-05 with Daria before scaffolding.)

1. **JA translation method.** **Resolved: Claude primary + DeepL cross-check.** Per 2026 Intento benchmark Claude wins on Asian-language idioms + chemistry vocab; DeepL second pass catches obvious errors.
2. **DE volume defaults.** **Resolved: keep 400 gal / 1500 L globally for v1.1.** Per-locale `niceDefaultGallons` override queued in backlog (data-gated; revisit if DE conversion data shows drop-off at onboarding volume step).
3. **What's-new copy template.** **Resolved: function-translated per locale.** EN: "Soak now speaks 5 new languages: German, Spanish, French, Italian, and Japanese." Each locale gets that sentence translated via the same method as in-app strings.
4. **Subtitle re-translation strategy.** **Resolved: function-first, keyword-targeted per locale.** Each locale's subtitle targets locale-search terms (e.g. JA 温泉/スパ/水質, DE Whirlpool/Wasserpflege), not literal EN translation. Reference top hot-tub apps per store for keyword cues.
5. **Privacy policy URL.** **Resolved: all 5 locales point at EN privacy page** (`daria-kopaliani.github.io/moondog/hottub/privacy.html`) for v1.1. Apple doesn't require localized privacy text. Localize URLs later when data justifies.

### Definition of done

- [ ] `Localizable.xcstrings` created at the app target root; every user-facing string extracted from Models / Views / Config / NumericInput / SettingsToolbar
- [ ] DE / ES / FR / IT translated via DeepL; JA translated via Claude with DeepL cross-check
- [ ] Daria's chemistry-vocab review pass per language (or native-speaker review queued where applicable)
- [ ] Character-expansion audit: DoseHero, readingRow, Settings volume row verified at DE / FR / JA without truncation
- [ ] String Catalog plural rules verified for "person" / "people" and "session" / "sessions"
- [ ] App Store Connect metadata localized: subtitle, promotional text, description (7-block per `LISTING_PROMPTS.md`), keywords (no spaces, fresh per-locale 100-char budget), "What's New" v1.1 — all 5 languages
- [ ] Screenshots regenerated: 4 shots × 2 devices × 5 languages = 40 PNGs, captions ≤55 chars per language
- [ ] Each language verified in simulator (Scheme → Run → Language → switch and exercise all 5 flows: onboarding, Test & Adjust, After-Use, Shock, Settings)
- [ ] App Store Connect preview verified at search-results size per locale against a top competitor in that locale
- [ ] Metadata-only submission flow (if String Catalog migration produced no functional code change, this is metadata-only; if any code change ships, full binary submit)
- [ ] Post-launch: monitor App Store Connect impressions / downloads per locale for 14 days; baseline established for v1.2 KO / ZH-Hans / PT-BR decision

### Handoff prompt

Paste the block below into a new Claude Code session started in `/Users/dariakopaliani/Projects/moondog/`. Same shape as `FLUX_HANDOFF.md`, `CROP_HANDOFF.md`, `SEAL_HANDOFF.md`, `POND_HANDOFF.md`.

---

```
Build Soak v1.1: localization to 5 languages (DE, ES, FR, IT, JA) for the live Soak: Hot Tub Assistant app. Soak v1.0 shipped 2026-05-31; this is its first feature update. Bundle com.kopaliani.HotTubHelper; no bundle change.

Read these first, in order, before doing anything else:
1. /Users/dariakopaliani/Projects/moondog/SPEC.md — Moon Dog portfolio + conventions. Especially "Feature backlog" (how this workflow is structured), "Submit sequence" (App Store metadata + clipboard delivery), and Conventions (iOS 17 deployment, git identity override, encryption Info.plist flag, screenshot dimensions).
2. /Users/dariakopaliani/.claude/projects/-Users-dariakopaliani-Projects-moondog/memory/MEMORY.md plus every file it links to — Daria's preferences, work patterns, and feedback memories. Especially "Propose before changing code", "Let Daria pace the ship flow", "Commit scope", "Hot Tub git identity".
3. /Users/dariakopaliani/Projects/moondog/soak/SOAK_BACKLOG.md — this file. The "Up next: v1.1 Localization" section IS the spec. Read all of it. Why / Scope / Approach / Open questions / Definition of done.
4. /Users/dariakopaliani/Projects/moondog/soak/SOAK_RESEARCH.md — Soak's audience / chemistry / competing-apps context. Useful for advisory-tone calibration during translation review.
5. /Users/dariakopaliani/Projects/moondog/LISTING_PROMPTS.md, SCREENSHOT_PROMPTS.md, ICON_PROMPTS.md — ship-prep reusable patterns. App Store metadata localization uses LISTING_PROMPTS' 7-block structure per language; screenshot regeneration uses SCREENSHOT_PROMPTS' 4-shot pattern per language.
6. /Users/dariakopaliani/Projects/moondog/soak/HOW_WE_WORK.md — Soak's project-level working rules.

Then do these four steps, in order, stopping after each for Daria to direct you:

Step 1 — Resolve the open questions.
The "Open questions" subsection of SOAK_BACKLOG.md Up-Next has 5 items (JA translation method, DE volume defaults, What's-new copy template, subtitle re-translation strategy, privacy policy URL). Surface each in chat with my recommendation and any alternatives; wait for Daria's lock-in on each before proceeding.

Step 2 — Extract strings.
Audit every user-facing literal in /Users/dariakopaliani/Projects/moondog/soak/HotTubHelper/HotTubHelper/. Files to sweep: Models.swift, Formulas.swift (only displayName-style literals if any), HotTubConfig.swift, ContentView.swift, NumericInput.swift, SettingsToolbar.swift, and every file in Views/. Catalog every string in a proposal to Daria (in chat) before creating Localizable.xcstrings — she should see the full string set before any code change. Pay particular attention to advisory-body strings in TestAdjustView (multi-sentence), recommendation titles ("Raises Alkalinity to X ppm" — has a number interpolation that needs proper format-arg in xcstrings), and onboarding help strings (multi-line, length-sensitive).

Step 3 — Scaffold + translate (only after Daria's "go").
Per the "Propose before changing code" feedback: present the file diff for Localizable.xcstrings + the source-file edits (Text("key") replacements) before applying. Once go:
- Create Localizable.xcstrings in the HotTubHelper app target. Xcode 26 String Catalog format.
- Replace every Text/literal with the localized form. Use String(localized:) for non-SwiftUI strings (Models displayNames). Use Text("key") in views — SwiftUI auto-localizes from the catalog.
- Translate DE / ES / FR / IT via DeepL Free tier (50k char/month is sufficient — Soak's UI is ~3-5k chars).
- Translate JA via Claude with DeepL cross-check (per benchmark, Claude handles Asian-language idioms + chemistry vocabulary better; DeepL cross-check catches obvious errors).
- Verify String Catalog plural rules for "%d person" / "%d people" and "%d session" / "%d sessions" — xcstrings handles this natively.
- Run a character-expansion audit: build to simulator in DE and FR, exercise DoseHero (After-Use, Shock), readingRow (Test & Adjust), Settings volume row — look for truncation. If found, apply .minimumScaleFactor(0.8) on the offending Text, or shorten the EN source.

Step 4 — App Store Connect metadata + screenshots.
After in-app localization is verified in simulator (all 5 languages):
- Use LISTING_PROMPTS.md 7-block description structure per language. Translate the existing EN Soak listing (subtitle, promo text, description, keywords, What's New) into 5 languages. Use the same DeepL / Claude split as in-app strings.
- Subtitle per locale targets locale-specific search terms (function-first, not literal-EN translation). Reference top App Store hot-tub-app subtitles per locale for keyword ideas.
- Keywords field per locale is comma-separated no spaces. Each locale gets a fresh 100-char budget — no need to repeat words from that locale's subtitle.
- Write each localized field to /Users/dariakopaliani/Projects/moondog/soak/listing-{lang}-{field}.txt, then pbcopy per the SPEC Submit-Sequence Delivery Flow when Daria asks for each field to paste.
- Regenerate screenshots: 4 shots × 2 devices × 5 languages = 40 PNGs. Re-use the dark-mode 9:41 captures from v1.0 if available in /Users/dariakopaliani/Projects/moondog/soak/screenshots/. Translate captions per language; verify ≤55 chars per language. Per SCREENSHOT_PROMPTS the screen content doesn't change — only the caption overlay differs per language.
- Final pass: each locale's listing preview compared side-by-side with a top competitor in that locale at App Store search-results size.

Conventions to follow throughout (full list in SPEC.md, key ones again):
- Soak repo git identity: daria.kopaliani@gmail.com via -c user.email=... override on each commit; do NOT git config to persist.
- Scope each commit to a single coherent change. Expected commits: (a) Localizable.xcstrings + Text("key") edits, (b) DE translations, (c) ES, (d) FR, (e) IT, (f) JA, (g) character-expansion fixes if any, (h) App Store Connect metadata files. Eight commits is a fine cadence; don't bundle multiple languages in one commit.
- Propose code edits in chat before making them; wait for "go".
- After any visible UI change (e.g., a layout fix for DE overflow), name the screen Daria should navigate to in the sim.
- Do NOT push toward App Store submission. Daria paces the ship flow. After Step 4 stop and let her drive the App Review submit.

Pricing: unchanged at $3.99 (no price experiment in v1.1).

Final reminder: stop after each of the four steps and let Daria direct. Do not run ahead. Do not localize TFP source citations or brand product names (per Scope-out in SOAK_BACKLOG.md).
```

---

## Queued (prioritized)

| Feature | Why | Effort | Priority |
|---|---|---|---|
| CYA tracking + FC/CYA ratio | `Formulas.TargetRange.cyanuricAcid` defined but not surfaced; dichlor users accumulate CYA silently, FC effectiveness drops. The canonical TFP diagnostic missing from v1.0. | ~0.5 day | **High** |
| Combined-parameter advisories | High pH + low TA = CO₂ imbalance; low CH + high pH = scale risk; chronic FC + high TA = chronic high pH. Per-parameter advisors miss these canonical diagnoses. | ~0.5 day | **High** |
| Source-attributed advisory copy | "Per TFP: …" inline in advisory bodies. Matches Crust / Flux / Crop / Seal / Pond named-source wedge. Note: blocks pure-metadata-only localization update — coordinate with v1.1 timing. | ~0.5 day | Medium |
| Salt-chlorinator support (Frog @ease / ACE) | Excluded sub-segment of hot-tub market. Add `Sanitizer.salt` case + salt-level reading + chlorinator output % math. | ~1 day | Medium |
| Test-history trend | UserDefaults array of last 5–10 readings. "Your FC was 2.5 last week, now 1.8" delta. No SwiftData migration needed. | ~0.5 day | Medium |
| Drain & refill + filter cleaning reminders | Frost ships these (lastWaterChange / lastFilterClean cadence). Port the pattern to Soak. | ~0.5 day | Medium |
| KO / ZH-Hans / PT-BR localization (v1.2) | After v1.1 localization conversion data justifies expansion. | ~2 days | Low (deferred to post-v1.1 data) |
| Per-locale onboarding defaults | Soak ships with US-tuned defaults (400 gal volume, bromine sanitizer, Dichlor 56%, Dry acid). Other markets diverge: EU spas skew smaller volumes (300–500 L personal); EU pool/spa retail favors different chlorine products (Cal-hypo less common in JP, Dichlor brand-dominant in DE); pH lowerer market split (muriatic acid common in US retail, dry acid dominant in EU). Detect `Locale.current` on first launch and set `niceDefaultGallons` + default `sanitizer` + `preferredChlorineProduct` + `preferredPHLowerer` accordingly per locale. Decision: ship v1.1 with global US-tuned defaults; revisit when conversion data shows per-locale drop-off at onboarding (volume step + chemical product picker step are the two suspect surfaces). | ~1 day | Low (data-gated) |
| Remove dead code | `SanitizerPill` (NumericInput.swift line 47) unused; `Formulas.afterUseDose` default `chlorineProduct` parameter unused. | ~10 min | Low |
| Apple Watch glance | Today's after-use dose. Defer until install base ≥1k. | ~2 days | Low |
| iPad-optimized layout | Form-on-iPad-Pro is functional but not tuned. Max-width column. | ~0.5 day | Low |

## Considered, deferred

(Empty — no features explicitly rejected yet. Items land here with a "why not" when decisions get made.)
