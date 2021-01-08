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

import json

from box import Box
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
            result_list.extend((current_item, *results,)) # (7, 10), ((10, 13),)
            print("result")
            print(result_list)
    else:
        if not belongs_to_group:
            print("two")
            other_items = results[1:]
            number_of_tuples = [True for i in results[0] if type(i) is tuple]
            if len(number_of_tuples) > 1:
                result_list.extend(((current_item, *results[0],), *other_items,))
            else:
                result_list.extend(((current_item, results[0],), *other_items,))
            print(result_list)
        else:
            print("b called with")
            print(results)
            print("add")
            print(current_item)
            other_items = results[1:]
            result_list.extend(((current_item, results[0],), *other_items,))
            print(result_list)

    # print(result_list)
    return result_list

def get_grouped_list(filtered_list: list, all_data) -> list:
    # Form a list out of the filtered list which groups together sequential items
    # Example input:
    # [(0, 5), (3, 12), (7, -2), (8, -3), (9, -7), (11, 14)] ... where the first item of a tuple is the index in the original list
    # Associated example output:
    # [(7, -2), (8, -3), (9, -7)]

    filtered_list = [(5, 5), (6, 8), (7, 10), (8, 2), (10, 13), (11, 19), (14, 100), (15, 200)]
    if len(filtered_list) >= 2:
        if filtered_list[0][0] + 1 == filtered_list[1][0]: 
            print("final")
            print(recursiv_grouping(None, filtered_list, True))
        else:
            print("final")
            print(recursiv_grouping(None, filtered_list, False))

def main():
    price_data_path = Path("~/awattprice/data/awattar-data-de.json").expanduser()
    with price_data_path.open() as fh:
        raw_price_data = Box(json.loads(fh.read()))

    price_data = []
    for price_point in raw_price_data.prices:
        price_point.marketprice = round(price_point.marketprice, 2)
        price_data.append(price_point)

    on_below_value = 5#int(input("This script will find the longest time range in which price drop on or below (int and in cents): "))
    
    below_list = get_below_list(price_data, on_below_value)
    grouped_list = get_grouped_list(below_list, price_data)

if __name__ == '__main__':
    main()