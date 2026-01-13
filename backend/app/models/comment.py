from typing import Optional
from beanie import Document, Link, PydanticObjectId
from pydantic import BaseModel, Field, ConfigDict
from datetime import datetime
from app.models.user import User, UserOut

class Comment(Document):
    post_id: PydanticObjectId
    author: Link[User]
    content: str
    created_at: datetime = Field(default_factory=datetime.now)

    class Settings:
        name = "comments"

class CommentOut(BaseModel):
    id: str = Field(validation_alias="id")
    postId: str = Field(validation_alias="post_id")
    authorInfo: UserOut = Field(validation_alias="author_info")
    content: str
    createdAt: datetime = Field(validation_alias="created_at")

    model_config = ConfigDict(
        from_attributes=True,
        populate_by_name=True
    )

    @classmethod
    def from_doc(cls, doc: Comment) -> "CommentOut":
        author_data = doc.author
        # Fallback if link not fetched
        user_dict = {
            "id": str(author_data.id),
            "username": getattr(author_data, "username", "Unknown"),
            "email": getattr(author_data, "email", ""),
            "display_name": getattr(author_data, "display_name", "Người dùng"),
            "avatar_url": getattr(author_data, "avatar_url", None),
            "background_url": getattr(author_data, "background_url", None),
            "bio": getattr(author_data, "bio", None)
        }
        author_out = UserOut.model_validate(user_dict)
        
        return cls(
            id=str(doc.id),
            postId=str(doc.post_id),
            authorInfo=author_out,
            content=doc.content,
            createdAt=doc.created_at
        )
