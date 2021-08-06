"""Perform operations on tokens and their configurations."""
from collections import defaultdict

import awattprice

from awattprice.defaults import Region
from awattprice.orm import PriceBelowNotification
from awattprice.orm import Token
from box import Box
from loguru import logger
from sqlalchemy import and_
from sqlalchemy import or_
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncEngine
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import contains_eager
from sqlalchemy.sql.elements import BooleanClauseList

from awattprice_notifications.price_below.prices import DetailedPriceData


def get_below_value_checks(regions_data: dict[Region, DetailedPriceData]) -> list[BooleanClauseList]:
    """Get sqlalchemy and_ clauses which check if the price data drops below or on the users below value.

    These checks respect the tax option of the user by adding or leaving away the tax on the price data.
    """
    below_value_checks = []
    for region, price_data in regions_data.items():
        lowest_marketprice = price_data.lowest_price.marketprice
        lowest_marketprice_untaxed = lowest_marketprice.ct_kwh(taxed=False, round_=True)
        if region.tax is None:
            below_value_checks.append(
                and_(Token.region == region, lowest_marketprice_untaxed <= PriceBelowNotification.below_value)
            )
        else:
            lowest_marketprice_taxed = lowest_marketprice.ct_kwh(taxed=True, round_=True)
            below_value_checks.append(
                and_(
                    Token.region == region,
                    or_(
                        and_(
                            Token.tax == True,
                            lowest_marketprice_taxed <= PriceBelowNotification.below_value,
                        ),
                        and_(
                            Token.tax == False,
                            lowest_marketprice_untaxed <= PriceBelowNotification.below_value,
                        ),
                    ),
                )
            )
    return below_value_checks


async def collect_applying_tokens(
    engine: AsyncEngine, regions_data: dict[Region, DetailedPriceData]
) -> Box[Region, list[Token]]:
    """Collect all tokens from the database for the specified regions which apply to get a price below notification.

    The price below rows on the returned tokens are loaded.

    :returns: Dictionary with region as key and list of tokens as the value. Updated regions which
        don't have any tokens associated aren't included in the returned dictionary.
    """
    below_value_checks = get_below_value_checks(regions_data)
    if not below_value_checks:
        return Box()
    async with AsyncSession(engine) as session:
        applying_notifications_stmt = (
            select(Token)
            .join(Token.price_below)
            .options(contains_eager(Token.price_below))
            .where(and_(PriceBelowNotification.active == True, or_(*below_value_checks)))
        )

        ungrouped_tokens = await session.execute(applying_notifications_stmt)
        ungrouped_tokens = ungrouped_tokens.scalars().all()

    region_tokens = defaultdict(list)
    for token in ungrouped_tokens:
        region_tokens[token.region].append(token)
    region_tokens = Box(region_tokens)

    return region_tokens
