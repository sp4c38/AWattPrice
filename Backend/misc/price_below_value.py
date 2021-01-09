#!/usr/bin/env python3
# -*- coding: utf-8 -*-

""" 

Find the time in which the most price points fall on or below a certain value.

example:
[3, 10, 4, -5, 9, 2, 1, -3, 7] in cents
-> find longest time range in which prices drop on or below 5ct
-> 2, 1, -3, 7

Note, the file ~/awattprice/data/awattar-data-de.json must exist and should be up-to date.
Note, that this script won't filter out old price points. It will use all price points included
in the data file.
"""

__author__ = "Léon Becker (sp4c38) <lb@space8.me>"
__copyright__ = "Léon Becker"
__license__ = "mit"

import arrow
import json

from box import Box
from datetime import datetime
from dateutil.tz import tzstr
from pathlib import Path
from typing import Optional

def get_below_list(all_data: list, on_below_value: int) -> list:
    # Filters out items of a list which have prices which don't fall on or below the certain passed price.
    filtered_list = []
    current_index = 0

    for item in all_data:
        if item.marketprice <= on_below_value:
            filtered_list.append((current_index, item))

        current_index += 1

    return filtered_list


def recursiv_grouping(current_item_index: Optional[int], items_list: list, belongs_to_group: bool):
    if current_item_index is None:
        current_item_index = 0

    current_item = items_list[current_item_index]
    if current_item_index + 1 > (len(items_list) - 1):
        if belongs_to_group:
            return (current_item,)
        else:
            return (current_item,)

    next_within_group = False
    if items_list[current_item_index + 1][0] == current_item[0] + 1:
        next_within_group = True

    result_list = []
    results = recursiv_grouping(current_item_index + 1, items_list, next_within_group)

    if not next_within_group:
        if not belongs_to_group:
            result_list.extend((current_item, *results,))
        else:
            result_list.extend((current_item, *results,))
    else:
        if not belongs_to_group:
            other_items = results[1:]
            number_of_tuples = [True for i in results[0] if type(i) is tuple]
            if len(number_of_tuples) > 1:
                result_list.extend(((current_item, *results[0],), *other_items,))
            else:
                result_list.extend(((current_item, results[0],), *other_items,))
        else:
            other_items = results[1:]
            number_of_tuples = [True for i in results[0] if type(i) is tuple]
            if len(number_of_tuples) > 1:
                result_list.extend(((current_item, *results[0],), *other_items,))
            else:
                result_list.extend(((current_item, results[0],), *other_items))

    return result_list

def get_grouped_list(filtered_list: list, all_data: list) -> list:
    # Form a list out of the filtered list which groups together sequential items
    # Example input:
    # [(0, 5), (3, 12), (7, -2), (8, -3), (9, -7), (11, 14)] ... where the first item of a tuple is the index in the original list
    # Associated example output:
    # [(7, -2), (8, -3), (9, -7)]

    if len(filtered_list) >= 2:
        if filtered_list[0][0] + 1 == filtered_list[1][0]: 
            return recursiv_grouping(None, filtered_list, True)
        else:
            return recursiv_grouping(None, filtered_list, False)
    else:
        return [filtered_list[0]]
        
def get_longest_time_frame(grouped_list: list, all_data: list):
    longest_time_frame_index = (None, None) # Index in grouped_list, number of the items in the item represented by the index
    current_index = 0
    for grouped_items in grouped_list:
        if longest_time_frame_index[0] == None or longest_time_frame_index[1] == None:
            if type(grouped_items[0]) is int:
                longest_time_frame_index = (current_index, 1)
            else:
                longest_time_frame_index = (current_index, len(grouped_items))
        else:
            amount_of_items = 0
            if type(grouped_items[0]) is int:
                amount_of_items = 1
            else:
                amount_of_items = len(grouped_items)
                
            if amount_of_items > longest_time_frame_index[1]:
                longest_time_frame_index = (current_index, amount_of_items)
                
        current_index += 1
        
    return longest_time_frame_index[0]

def get_start_end_string(longest_time_range: list) -> (str, str):
    raw_items = []
    start = arrow.get(min(longest_time_range)[1].start_timestamp)
    end = arrow.get(max(longest_time_range)[1].end_timestamp)
    
    timezone = timezone = tzstr("CET-1CEST,M3.5.0/2,M10.5.0/3").tzname(datetime.fromtimestamp(start.timestamp))
    format_string = "YYYY-MM-DD, HH:mm:ss"
    start_string = start.to(timezone).format(format_string)
    end_string = end.to(timezone).format(format_string)

    return start_string, end_string

def main():
    price_data_path = Path("~/awattprice/data/awattar-data-de.json").expanduser()
    with price_data_path.open() as fh:
        raw_price_data = Box(json.loads(fh.read()))

    price_data = []
    for price_point in raw_price_data.prices:
        price_point.marketprice = round(price_point.marketprice, 2)
        price_data.append(price_point)

    on_below_value = int(input("This script will find the longest time range in which price drop on or below (int and in cents): "))
    
    below_list = get_below_list(price_data, on_below_value)
    if below_list:
        grouped_list = get_grouped_list(below_list, price_data)
        longest_time_range_index = get_longest_time_frame(grouped_list, price_data) # Index of which item in grouped_list has the most elements
        start_date_string, end_date_string = get_start_end_string(grouped_list[longest_time_range_index])
    
        print(f"The longest time range in which prices fall below {on_below_value}ct is from {start_date_string} to {end_date_string} (times in CET / CEST).")
    else:
        print(f"No results found as there are no price points that drop below {on_below_value}.")

if __name__ == '__main__':
    main()