"""Perform operations on tokens and their configurations."""
from collections import defaultdict

import awattprice

from awattprice.defaults import Region
from awattprice.orm import PriceBelowNotification
from awattprice.orm import Token
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
        lowest_price = price_data.data.prices[price_data.lowest_price_index]
        lowest_marketprice_kwh = lowest_price.marketprice * awattprice.defaults.EURMWH_TO_CENTWKWH
        lowest_marketprice_kwh = round(lowest_marketprice_kwh, awattprice.defaults.PRICE_CENTKWH_ROUNDING_PLACES)
        if region.tax is None:
            below_value_checks.append(
                and_(Token.region == region, lowest_marketprice_kwh <= PriceBelowNotification.below_value)
            )
        else:
            below_value_checks.append(
                and_(
                    Token.region == region,
                    or_(
                        and_(
                            Token.tax == True,
                            (lowest_marketprice_kwh * region.tax) <= PriceBelowNotification.below_value,
                        ),
                        and_(
                            Token.tax == False,
                            lowest_marketprice_kwh <= PriceBelowNotification.below_value,
                        ),
                    ),
                )
            )
    return below_value_checks


async def collect_applying_tokens(
    engine: AsyncEngine, updated_regions_data: dict[Region, DetailedPriceData]
) -> dict[Region, list[Token]]:
    """Collect all tokens from the database for the specified regions which apply to get a price below notification.

    The price below attributes on the returned tokens are filled.

    :returns: Dictionary with region as key and list of tokens as the value. Updated regions which
        don't have any tokens associated aren't included in the returned dictionary.
    """
    below_value_checks = get_below_value_checks(updated_regions_data)
    async with AsyncSession(engine) as session:
        applying_notifications_stmt = (
            select(Token)
            .join(Token.price_below)
            .options(contains_eager(Token.price_below))
            .where(and_(PriceBelowNotification.active == True, or_(*below_value_checks)))
        )

        ungrouped_tokens = await session.execute(applying_notifications_stmt)
        ungrouped_tokens = ungrouped_tokens.scalars().all()

    tokens = defaultdict(list)
    for token in ungrouped_tokens:
        tokens[token.region].append(token)

    return tokens
