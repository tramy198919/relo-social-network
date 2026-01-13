from typing import Optional, List, Any, Dict
from beanie import Document, Indexed, PydanticObjectId, Link
from pydantic import BaseModel, Field, ConfigDict
from datetime import datetime
from app.models.user import User

class Notification(Document):
    recipient: Link[User]
    sender_id: str
    sender_name: str
    sender_avatar: Optional[str] = None
    type: str # 'friend_request', 'like', 'comment', 'message'
    related_id: Optional[str] = None # Post ID, Message ID, etc.
    content: str
    is_read: bool = False
    created_at: datetime = Field(default_factory=datetime.now)

    class Settings:
        name = "notifications"

class NotificationOut(BaseModel):
    id: str = Field(validation_alias="id")
    userId: str = Field(serialization_alias="userId")
    type: str
    title: str
    message: str
    metadata: Dict[str, Any] = Field(default_factory=dict)
    isRead: bool = Field(serialization_alias="isRead")
    createdAt: datetime = Field(serialization_alias="createdAt")

    model_config = ConfigDict(
        from_attributes=True,
        populate_by_name=True
    )

    @classmethod
    def from_doc(cls, doc: Notification) -> "NotificationOut":
        metadata = {
            "senderId": doc.sender_id,
            "avatar": doc.sender_avatar,
        }
        if doc.related_id:
            if "post" in doc.type or doc.type in ("like", "comment", "share"):
                metadata["postId"] = doc.related_id
            else:
                metadata["relatedId"] = doc.related_id

        recipient_id = ""
        if isinstance(doc.recipient, Link):
            recipient_id = str(doc.recipient.ref.id)
        else:
            recipient_id = str(doc.recipient.id)

        return cls(
            id=str(doc.id),
            userId=recipient_id,
            type=doc.type,
            title=doc.sender_name,
            message=doc.content,
            metadata=metadata,
            isRead=doc.is_read,
            createdAt=doc.created_at
        )
