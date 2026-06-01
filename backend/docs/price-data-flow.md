# Price Data Flow

This document describes how the backend turns ENTSO-E day-ahead price data into the cached API response used by the app and notification worker.

## Source Data

Prices are downloaded from the ENTSO-E Transparency Platform with `documentType=A44`.

For markets with multiple auction sequences:

- `Sequence 1` is the preferred day-ahead auction, usually SDAC.
- `Sequence 2` is fallback data, for example the earlier EXAA auction in Austria.
- Regions without sequence metadata are treated as unclassified source data, not fallback data.

## A03 Step Curves

ENTSO-E price documents use `curveType=A03` for stepwise price curves. In these documents, repeated prices may be omitted. A missing position after a known price means the previous price continues until the next explicit price or the end of the period.

The backend therefore expands each `A03` time series before comparing it with other sequences:

- explicit points are imported as-is
- missing positions after a previous point are carried forward
- leading missing positions are not invented

Carried-forward points are official source-derived prices. They are exposed with `is_carried_forward = true`, but they are not lower quality and should be displayed like normal prices.

## Sequence Selection

After each time series has been expanded, the backend merges price points by timestamp:

1. preferred sequence prices win first
2. fallback sequence prices fill only timestamps still missing from the preferred sequence
3. once a timestamp has a preferred-sequence price, fallback data cannot replace it

This prevents fallback auction prices from replacing omitted repeated prices in the preferred auction.

## Tomorrow Fallback Rule

Fallback-only tomorrow data is blocked before `17:00` in the local price-zone time.

Before that cutoff, tomorrow is not published if it contains only fallback prices and no preferred-sequence prices. After `17:00`, fallback-only data may be used as an emergency fallback.

This rule applies to all regions with fallback sequence data.

## Cache Replacement

The refresher stores newly downloaded data only when it is better than the current cache. New data wins when it:

- extends the cached time range
- contains more unique price points
- has fewer fallback points
- differs from the cached price payload

The current-price refresher skips downloading for a region when tomorrow is already complete and contains no fallback points.

## API Metadata

The price API exposes these source-quality fields:

- `sequence_position`: ENTSO-E sequence used for the point
- `is_fallback`: true when the point came from a non-primary sequence
- `is_carried_forward`: true when the point was expanded from an `A03` step curve
- `fallback_price_count`: number of fallback points in the response
- `carried_forward_price_count`: number of carried-forward points in the response

The app does not need special display logic for carried-forward points. They represent the same official price continuing across omitted intervals.

## Notifications

The notification worker requires tomorrow to contain every expected interval for the local day.

Fallback prices are allowed only within the configured fallback tolerance. Carried-forward `A03` points are treated as normal source prices and do not count against that tolerance.
