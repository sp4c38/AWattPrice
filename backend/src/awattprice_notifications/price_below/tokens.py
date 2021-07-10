"""Perform operations on tokens and their configurations."""
import awattprice

from awattprice.orm import PriceBelowNotification
from awattprice.orm import Token
from sqlalchemy import and_
from sqlalchemy import or_
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncEngine
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import contains_eager

from awattprice_notifications.price_below.defaults import DetailedPriceData


async def collect_applying_tokens(engine: AsyncEngine, updated_regions_data: DetailedPriceData) -> [Token]:
    """Collect all tokens from the database which apply to get a price below notification.

    The price below row of each token is included on the tokens of the output.
    """
    # For each region check if the lowest price value is equal or lower than the below value of the user.
    below_value_checks = []
    for region, price_data in updated_regions_data.items():
        lowest_price = price_data.data.prices[price_data.lowest_price_index]
        lowest_marketprice_kwh = lowest_price.marketprice * awattprice.defaults.EURMWH_TO_CENTWKWH
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
                            Token.tax is True,
                            (lowest_marketprice_kwh * region.tax) <= PriceBelowNotification.below_value,
                        ),
                        and_(
                            Token.tax is False,
                            lowest_marketprice_kwh <= PriceBelowNotification.below_value,
                        ),
                    ),
                )
            )

    async with AsyncSession(engine) as session:
        applying_notifications_stmt = (
            select(Token)
            .join(Token.price_below)
            .options(contains_eager(Token.price_below))
            .where(and_(PriceBelowNotification.active is True, or_(*below_value_checks)))
        )

        tokens = await session.execute(applying_notifications_stmt)
        tokens = tokens.scalars().all()

    return tokens
