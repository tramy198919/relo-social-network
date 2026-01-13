from typing import Optional
from beanie import Document, Link, PydanticObjectId
from pydantic import BaseModel, Field, ConfigDict
from datetime import datetime
from app.models.user import User, UserOut

class FriendRequest(Document):
    from_user: Link[User]
    to_user: Link[User]
    status: str = "pending" # pending, accepted, rejected
    created_at: datetime = Field(default_factory=datetime.now)

    class Settings:
        name = "friend_requests"

class FriendRequestOut(BaseModel):
    id: str
    fromUser: UserOut
    status: str
    createdAt: datetime = Field(alias="created_at")

    model_config = ConfigDict(
        from_attributes=True,
        populate_by_name=True
    )

    @classmethod
    async def from_doc(cls, doc: FriendRequest) -> "FriendRequestOut":
        # Ensure from_user is fetched
        if isinstance(doc.from_user, Link):
            await doc.fetch_link(FriendRequest.from_user)
            
        return cls(
            id=str(doc.id),
            fromUser=UserOut.model_validate(doc.from_user),
            status=doc.status,
            created_at=doc.created_at
        )
