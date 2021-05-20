"""Tables for the database managed by sqlalchemy."""

from sqlalchemy import Boolean, Column, Enum, ForeignKey, Integer, MetaData, String
from sqlalchemy.orm import relationship
from sqlalchemy.orm import registry as Registry

from awattprice.defaults import Region

metadata = MetaData()
registry = Registry(metadata)
BaseClass = registry.generate_base()


class Token(BaseClass):
    """Table to store apns notification tokens."""

    __tablename__ = "token"
    # Note: The token id *as well as* the token can be used to identify a single row.
    token_id = Column(Integer, primary_key=True)
    token = Column(String, unique=True, nullable=False)
    region = Column(Enum(Region), nullable=False)
    # Tax selection is dependent on the region. For example in Austria there are no non-tax and tax prices.
    # With this design this dependence violates the 3NF. This violation is disregarded in this case because
    # it would make the design unnecessarily more complicated. Instead the region and tax selection is
    # safe-checked in the program code.
    tax = Column(Boolean, default=False, nullable=False)

    notification_setting = relationship(
        "NotificationSetting", back_populates="token", uselist=False, cascade="all, delete, delete-orphan"
    )


class NotificationSetting(BaseClass):
    """Store which notification types to receive for a notification token."""

    __tablename__ = "notification_setting"
    token_id = Column(ForeignKey(Token.token_id), primary_key=True)
    price_below = Column(Boolean, default=False, nullable=False)

    token = relationship(Token, back_populates="notification_setting", uselist=False)
