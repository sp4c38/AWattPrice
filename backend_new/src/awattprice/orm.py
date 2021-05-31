"""Database tables represented as objects."""

from sqlalchemy import Boolean
from sqlalchemy import Column
from sqlalchemy import Enum
from sqlalchemy import ForeignKey
from sqlalchemy import Integer
from sqlalchemy import MetaData
from sqlalchemy import String
from sqlalchemy.orm import relationship
from sqlalchemy.orm import registry as Registry

from awattprice import defaults
from awattprice.defaults import Region


TABLE_NAMES = defaults.ORM_TABLE_NAMES


metadata = MetaData()
registry = Registry(metadata)
BaseClass = registry.generate_base()


class PriceBelowNotification(BaseClass):
    """Hold info about the subscription of the price below notification of a token."""

    __tablename__ = TABLE_NAMES.price_below_table
    token_id = Column(ForeignKey(f"{TABLE_NAMES.token_table}.token_id"), primary_key=True)
    active = Column(Boolean, nullable=False)
    below_value = Column(Integer, nullable=True)

    token = relationship("Token", back_populates="price_below", uselist=False)


class Token(BaseClass):
    """Store apns notification token information."""

    __tablename__ = TABLE_NAMES.token_table
    # Note: The token id *as well as* the token can be used to identify a single row.
    token_id = Column(Integer, primary_key=True)
    token = Column(String, unique=True, nullable=False)
    region = Column(Enum(Region), nullable=False)
    # Tax selection is dependent on the region. For example in Austria there are no non-tax and tax prices.
    # With this design this dependence violates the 3NF. This violation is disregarded in this case because
    # it would make the design unnecessarily more complicated. Yhe region and tax selection is
    # safe-checked in the program code.
    tax = Column(Boolean, default=False, nullable=False)

    price_below = relationship(
        PriceBelowNotification, back_populates="token", cascade="all, delete-orphan", uselist=False
    )