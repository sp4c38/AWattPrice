# Generation Mix Data Flow

The backend serves generation mix data from ENTSO-E actual generation per production type data.

## Endpoints

`/generation-mix/{area_key}/history?hours=168` is the compatibility endpoint for app versions that use `intervals.last` as the current generation mix. It keeps the legacy behavior: all usable history intervals are exposed, with only trailing low-count publication intervals trimmed so older app versions do not get an obviously incomplete newest point. This endpoint must not filter by an exact production-type set, because ENTSO-E data is too noisy and that can collapse the history into stale sparse intervals.

`/generation-mix/{area_key}/published-history?hours=168` is the endpoint for newer app versions. It exposes all usable published intervals and marks incomplete intervals with `is_partial_publication = true`. The app should use the latest non-partial interval for the main Insights card, and may show partial intervals in history views with an explanatory note.

Both endpoints are generated from the same ENTSO-E download during refresh and stored as separate cached JSON files.

## How "missing" data is detected

ENTSO-E's actual-generation curves use `curveType A03` (variable sized block): inside a `Period`, an omitted position means the value is **unchanged** from the previous point, not that data is missing. The parser therefore forward-fills each production type's value across omitted positions **within a Period** (so e.g. solar staying `0` all night is filled, not treated as a gap). This matches what the ENTSO-E Transparency Platform shows as a number for those slots.

Genuinely missing data shows up in two structural ways, both left empty by the parser:

- **Gaps between Periods** — a type stops reporting and resumes later (Transparency Platform shows `N/A`). These are real mid-window holes.
- **After a type's last Period** — the trailing not-yet-published edge (Transparency Platform shows `-`).

An interval is marked `is_partial_publication = true` when the production types that are missing there — sized by each missing type's last known value (carried forward) — exceed `PARTIAL_PUBLICATION_MAGNITUDE_THRESHOLD` (2%) of the interval's estimated total generation. This flags materially incomplete intervals (e.g. a multi-GW wind series with a gap) while ignoring negligible drop-offs (e.g. a small oil plant that turned off), and it works the same for mid-window gaps and the trailing edge. A type that ends at `~0` contributes a `~0` estimate, so it is correctly treated as "off" rather than "unpublished".

`latest_complete_end_timestamp` is the end of the most recent non-partial interval; `latest_published_end_timestamp` is the end of the most recent interval of any kind.

## Future Cleanup

When deployed app versions that still call `/history` are no longer relevant, the compatibility endpoint can be deprecated and eventually removed. At that point, `/published-history` should become the only generation mix history endpoint, or it can be renamed back to `/history` if the API version is bumped.
