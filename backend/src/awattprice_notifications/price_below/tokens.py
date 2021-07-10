"""Perform operations on tokens and their configurations."""
import awattprice

from awattprice.orm import PriceBelowNotification
from awattprice.orm import Token
from decimal import Decimal
from sqlalchemy import and_
from sqlalchemy import or_
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncEngine
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import defaultload
from sqlalchemy.orm import contains_eager
from sqlalchemy.orm import join

from awattprice_notifications.price_below.defaults import DetailedPriceData


async def collect_applying_tokens(engine: AsyncEngine, updated_regions_data: DetailedPriceData):
    """Collect all tokens from the database which apply to get a price below notification.

    The Token.price_below row gets loaded too.
    """
    # For each region check if the lowest price value is equal or lower than the below value of the user.
    below_value_checks = []
    for region, price_data in updated_regions_data.items():
        lowest_price_point = price_data.data.prices[price_data.lowest_price_index]
        lowest_price_kwh = lowest_price_point.marketprice * awattprice.defaults.EURMWH_TO_CENTWKWH
        if region.tax is None:
            below_value_checks.append(
                and_(Token.region == region, lowest_price_kwh <= PriceBelowNotification.below_value)
            )
        else:
            below_value_checks.append(
                and_(
                    Token.region == region,
                    or_(
                        and_(
                            Token.tax == True,
                            (lowest_price_kwh * region.tax) <= PriceBelowNotification.below_value,
                        ),
                        and_(
                            Token.tax == False,
                            lowest_price_kwh <= PriceBelowNotification.below_value,
                        ),
                    ),
                )
            )

    async with AsyncSession(engine) as session:
        applying_notifications_stmt = (
            select(Token)
            .join(Token.price_below)
            .options(contains_eager(Token.price_below))
            .where(
                and_(
                    PriceBelowNotification.active == True,
                    or_(*below_value_checks)
                )
            )
        )

        tokens = await session.execute(applying_notifications_stmt)
        tokens = tokens.scalars().all()

    return tokens
