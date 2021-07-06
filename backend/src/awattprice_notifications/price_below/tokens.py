"""Perform operations on tokens and their configurations."""
import awattprice

from awattprice.orm import PriceBelowNotification
from awattprice.orm import Token
from decimal import Decimal
from sqlalchemy import and_
from sqlalchemy import case
from sqlalchemy import or_
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncEngine
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from awattprice_notifications.price_below.defaults import DetailedPriceData


async def collect_applying_tokens(engine: AsyncEngine, updated_regions_data: DetailedPriceData):
    """Collect all tokens from the database which apply to get a price below notification."""
    # For each region check if the lowest price value is equal or lower than the below value of the user.
    below_value_checks = []
    for region, price_data in updated_regions_data.items():
        lowest_price = Decimal(str(price_data.lowest_price))
        lowest_price_kwh = lowest_price * Decimal(str(awattprice.defaults.MWH_TO_KWH))
        if region.tax is None:
            below_value_checks.append(
                and_(Token.region == region, lowest_price_kwh <= PriceBelowNotification.below_value)
            )
        else:
            tax = Decimal(str(region.tax))
            below_value_checks.append(
                and_(
                    Token.region == region,
                    or_(
                        and_(
                            Token.tax == True,
                            (lowest_price_kwh * tax) <= PriceBelowNotification.below_value,
                        ),
                        and_(
                            Token.tax == False,
                            price_data.lowest_price <= PriceBelowNotification.below_value,
                        ),
                    ),
                )
            )
    async with AsyncSession(engine) as session:
        applying_notifications_stmt = (
            select(PriceBelowNotification)
            .options(joinedload(PriceBelowNotification.token, innerjoin=True))
            .where(
                and_(
                    PriceBelowNotification.active == True,
                    or_(*below_value_checks)
                )
            )
        )

        tokens = await session.execute(applying_notifications_stmt)
        tokens = tokens.scalars().all()
        print(tokens)
