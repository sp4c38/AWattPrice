# Generation Mix Data Flow

The backend serves generation mix data from ENTSO-E actual generation per production type data.

## Endpoints

`/generation-mix/{area_key}/history?hours=168` is the compatibility endpoint for app versions that use `intervals.last` as the current generation mix. It keeps the legacy behavior: all usable history intervals are exposed, with only trailing low-count publication intervals trimmed so older app versions do not get an obviously incomplete newest point. This endpoint must not filter by an exact production-type set, because ENTSO-E data is too noisy and that can collapse the history into stale sparse intervals.

`/generation-mix/{area_key}/published-history?hours=168` is the endpoint for newer app versions. It exposes all usable published intervals and marks incomplete intervals with `is_partial_publication = true`. The app should use the latest non-partial interval for the main Insights card, and may show partial intervals in history views with an explanatory note.

Both endpoints are generated from the same ENTSO-E download during refresh and stored as separate cached JSON files.

## Future Cleanup

When deployed app versions that still call `/history` are no longer relevant, the compatibility endpoint can be deprecated and eventually removed. At that point, `/published-history` should become the only generation mix history endpoint, or it can be renamed back to `/history` if the API version is bumped.
