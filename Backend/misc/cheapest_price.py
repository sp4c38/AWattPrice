#!/usr/bin/env python3

"""Calculate the cheapest price to check the AWattPrice App.

Call:

    ./cheapest_price.py 120

for 120 minutes of continuous consumption.

This is an alternative implementation to test the AwattPrice App.

Note, the file ~/awattprice/data/awattar-data-de.json must be updated.
"""

import json
import sys

from pathlib import Path

import arrow

from box import Box


__author__ = "Frank Becker <fb@alien8.de>"


def calculate_price(start, end, price_data, power):
    """Return the price for the time from start to end."""
    start_date = arrow.get(start.date())
    timedelta_minutes = int((end - start).seconds / 60)
    # Minutes left of first hour or the requested timeframe if shorter
    minutes_start_hour = min(60 - start.minute, timedelta_minutes)
    # Only calculate for the last couple of minutes if we spawn over an hour gap
    is_timedelta_same_hour = any(
        [
            start.hour == end.hour,
            # Account for e. g. 12:00 to 13:00
            start.hour == end.shift(hours=-1).hour and end.minute == 0,
        ]
    )
    if is_timedelta_same_hour:
        minutes_end_hour = 0
    else:
        minutes_end_hour = end.minute
    # Get an arrow.datetime obj with only the hour set, e. g. <Arrow [2020-11-25T23:00:00+00:00]>
    lookup_hour = start_date.shift(hours=+start.hour)
    price = price_data.get(lookup_hour.timestamp)
    if not price:
        sys.stderr.write(f"Could not find {lookup_hour}({lookup_hour.timestamp}) in price data.\n")
        return None
    # The price for the first hour is price per minute * minutes * power consumption.
    # Brackets are for readability
    price = minutes_start_hour * power * (price / 60)
    # Exit early if the requested timeframe is in the current hour.
    if is_timedelta_same_hour:
        return price
    # We calculate the price for the partial hours separately after this loop.
    end_hour = arrow.get(end.date()).shift(hours=+end.hour)
    while lookup_hour < end_hour:
        lookup_hour = lookup_hour.shift(hours=+1)
        if lookup_hour == end_hour and minutes_end_hour == 0:
            continue
        price_of_hour = price_data.get(lookup_hour.timestamp)
        if not price_of_hour:
            sys.stderr.write(f"Could not find {lookup_hour}({lookup_hour.timestamp}) in price data.\n")
            return None
        if lookup_hour == end_hour:
            price += power * minutes_end_hour * (price_of_hour / 60)
        else:
            price += price_of_hour * power
    return price


def find_cheapest_price(price_data, timeframe, power):
    """Return start time and end time where the electricity price is the cheapest.

    :param price_data: Price data, key is start hour in unix time, value is price
    :type price_data: Dict[int, float]
    :param timeframe: time span for which we want to consume power
    :type price_data: int
    :param power: the total power consumption (kWh) which occurres in the timeframe
    :type power: float

    :rtype: tuple(int, float)
    """
    start = arrow.now()
    end = start.shift(minutes=+timeframe)
    start_date = arrow.get(start.date())
    max_end_ts = max(price_data)
    next_full_hour = start_date.shift(hours=+start.to("UTC").hour + 1)
    # left aligned
    prices = {start.timestamp: calculate_price(start, end, price_data, power)}
    # aligned on the next full hour
    prices[next_full_hour.timestamp] = calculate_price(
        next_full_hour, next_full_hour.shift(minutes=+timeframe), price_data, power
    )

    # Shift the window by one hour got jump into the loop that increments at the end
    next_full_hour = next_full_hour.shift(hours=+1)
    # We have price data until the next_full_hour + 1h
    while next_full_hour.shift(minutes=+timeframe).timestamp <= max_end_ts:
        # 1) Look for end bound price (use the full last hour)
        # Get the last hour.
        end_hour = next_full_hour.shift(minutes=+timeframe).replace(minute=0)
        prices[end_hour.shift(minutes=-timeframe).timestamp] = calculate_price(
            end_hour.shift(minutes=-timeframe),
            end_hour,
            price_data,
            power,
        )
        # start bound
        prices[next_full_hour.timestamp] = calculate_price(
            next_full_hour, next_full_hour.shift(minutes=+timeframe), price_data, power
        )
        # Shift the window by one hour
        next_full_hour = next_full_hour.shift(hours=+1)
    # Add the price that ends at the end of the last hour we have prices for

    # 1) Look for end bound price (use the full last hour)
    # Get the last hour.
    end_hour = next_full_hour.shift(minutes=+timeframe).replace(minute=0)
    prices[end_hour.shift(minutes=-timeframe).timestamp] = calculate_price(
        end_hour.shift(minutes=-timeframe),
        end_hour,
        price_data,
        power,
    )

    for ts, p in prices.items():
        print(arrow.get(ts).to("local"), p)

    cheapest_price_ts = min(prices, key=prices.get)
    print(
        "\n"
        f"The cheapest price is starting at {arrow.get(cheapest_price_ts).to('local')} "
        f"ending at {arrow.get(cheapest_price_ts).shift(minutes=+timeframe).to('local')} "
        f"costing {prices[cheapest_price_ts]}."
    )


def main():
    file_path = Path("~/awattprice/data/awattar-data-de.json").expanduser()
    with file_path.open() as fh:
        data = Box(json.load(fh))

    if len(sys.argv) == 2:
        time_frame_minutes = int(sys.argv[1])
    else:
        time_frame_minutes = 60 * 3 + 0
    prices = {p.start_timestamp: p.marketprice for p in data.prices}
    power = 1  # Power consumption in kWh
    find_cheapest_price(prices, time_frame_minutes, power)


if __name__ == "__main__":
    main()
