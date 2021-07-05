"""Perform operations on tokens and their configurations."""
from awattprice.orm import PriceBelowNotification
from awattprice.orm import Token
from sqlalchemy import and_
from sqlalchemy import case
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncEngine
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from awattprice_notifications.price_below.defaults import DetailedPriceData


async def collect_applying_tokens(engine: AsyncEngine, updated_regions_data: DetailedPriceData):
    """Collect all tokens from the database which apply to get a price below notification."""
    applying_regions = list(updated_regions_data.keys())
    # Cases for each region to check if the lowest price value is equal to lower than the wish value.
    region_cases = []
    for region, price_data in updated_regions_data.items():
        region_cases.append(case())
    async with AsyncSession(engine) as session:
        # SELECT *
        # FROM price_below_notification pbn
        # INNER JOIN token t
        #     ON pbn.token_id == t.token_id
        # WHERE pbn.active = True
        #     AND t.region IN ("DE", "AT")
        #     AND (
        #         (t.tax = TRUE AND (8 * 1.19) <= below_value) 
        #         OR (t.tax = FALSE AND 11 <= below_value)
        #     );   
        applying_notifications_stmt = (
            select(PriceBelowNotification)
            .options(
                joinedload(PriceBelowNotification.token, innerjoin=True)
            )
            .where(
                and_(
                    PriceBelowNotification.active == True, 
                    Token.region.in_(applying_regions),
                )
            )
        )

        tokens = await session.execute(applying_notifications_stmt)
        tokens = tokens.scalars().all()
        print(tokens[0].token)
        print(tokens)