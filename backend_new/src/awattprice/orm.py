"""Database tables represented as objects."""

from sqlalchemy import Boolean
from sqlalchemy import Colum
from sqlalchemy import Enum
from sqlalchemy import ForeignKey
from sqlalchemy import Integer
from sqlalchemy import MetaData
from sqlalchemy import String
from sqlalchemy.orm import relationship
from sqlalchemy.orm import registry as Registry

from awattprice.defaults import Region

metadata = MetaData()
registry = Registry(metadata)
BaseClass = registry.generate_base()


class PriceBelowNotification(BaseClass):
    """Table to hold information about the price below value notification."""

    __tablename__ = "price_below_notification"
    price_below_id = Column(Integer, primary_key=True)
    active = Column(Boolean, nullable=False)
    below_value = Column(Integer, nullable=True)


class Token(BaseClass):
    """Table to store apns notification tokens."""

    __tablename__ = "token"
    # Note: The token id *as well as* the token can be used to identify a single row.
    token_id = Column(Integer, primary_key=True)
    token = Column(String, unique=True, nullable=False)
    region = Column(Enum(Region), nullable=False)
    # Tax selection is dependent on the region. For example in Austria there are no non-tax and tax prices.
    # With this design this dependence violates the 3NF. This violation is disregarded in this case because
    # it would make the design unnecessarily more complicated. Yhe region and tax selection is
    # safe-checked in the program code.
    tax = Column(Boolean, default=False, nullable=False)
    # price_below_notification = Column(ForeignKey())
