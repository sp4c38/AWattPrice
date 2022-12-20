"""Database tables represented as orms."""
from sqlalchemy import Boolean
from sqlalchemy import Column
from sqlalchemy import Enum
from sqlalchemy import Float
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
Base = registry.generate_base()


# pylint: disable=too-few-public-methods
class PriceBelowNotification(Base):
    """Hold info about the subscription of the price below notification of a token."""

    __tablename__ = TABLE_NAMES.price_below_table

    token_id = Column(ForeignKey(f"{TABLE_NAMES.token_table}.token_id"), primary_key=True)
    active = Column(Boolean, nullable=False)
    below_value = Column(Integer, nullable=True)

    token = relationship("Token", back_populates="price_below", uselist=False)


# pylint: enable=too-few-public-methods


# pylint: disable=too-few-public-methods
class Token(Base):
    """Store apns notification token information."""

    __tablename__ = TABLE_NAMES.token_table

    # Note: The token id *as well as* the token can be used to identify a single row.
    token_id = Column(Integer, primary_key=True)
    token = Column(String, unique=True, nullable=False)
    region = Column(Enum(Region), nullable=False)
    tax = Column(Boolean, default=False, nullable=False)
    base_fee = Column(Float(2), default=0, nullable=False)

    price_below = relationship(
        PriceBelowNotification, back_populates="token", cascade="all, delete-orphan", uselist=False
    )


# pylint: enable=too-few-public-methods
