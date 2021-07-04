"""Perform operations on tokens and their configurations."""
from awattprice import orm
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncEngine
from sqlalchemy.ext.asyncio import AsyncSession

from awattprice_notifications.price_below.defaults import DetailedPriceData


async def collect_applying_tokens(engine: AsyncEngine, updated_regions_data: DetailedPriceData):
    """Collect all tokens from the database which apply to get a price below notification."""
    applying_regions = list(updated_regions_data.keys())
    async with AsyncSession(engine) as session:
        # WITH pbns AS (
        #     SELECT *
        #     FROM price_below_notification pbn
        #     WHERE pbn.active = TRUE
        # )
        # SELECT *
        # FROM pbns AS pbn
        # INNER JOIN token t
        #     ON pbn.token_id == t.token_id
        #     AND t.region IN ("DE", "AT")
        #     AND (
        #         (t.tax = TRUE AND (8 * 1.19) <= below_value) 
        #         OR (t.tax = FALSE AND 11 <= below_value)
        #     );   
        active_notifications_stmt = (
            select(orm.PriceBelowNotification)
                .where(orm.PriceBelowNotification.active == True)
        ).cte()
        # applying_notifications_stmt = (
        #     select(active_notifications_stmt)
        # )

        tokens = await session.execute(active_notifications_stmt)
        tokens = tokens.scalars().all()
        print(tokens)