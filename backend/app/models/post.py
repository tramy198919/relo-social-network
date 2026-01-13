from typing import Optional, List, Any, Dict
from beanie import Document, Link, PydanticObjectId
from pydantic import BaseModel, Field, ConfigDict
from datetime import datetime
from app.models.user import User, UserOut

class Reaction(BaseModel):
    user_id: str = Field(validation_alias="user_id", serialization_alias="userId")
    type: str # 'like', 'love', 'haha', 'wow', 'sad', 'angry'

    model_config = ConfigDict(
        populate_by_name=True
    )

class Post(Document):
    content: str
    author: Link[User]
    image_urls: List[str] = Field(default_factory=list)
    file_urls: List[str] = Field(default_factory=list)
    video_urls: List[str] = Field(default_factory=list)
    
    shared_post: Optional[Link["Post"]] = None
    
    reactions: List[Reaction] = Field(default_factory=list)
    comments_count: int = 0
    
    created_at: datetime = Field(default_factory=datetime.now)
    updated_at: datetime = Field(default_factory=datetime.now)
    
    class Settings:
        name = "posts"

# Pydantic Schemas
class PostCreate(BaseModel):
    content: str

class PostOut(BaseModel):
    id: str = Field(validation_alias="id")
    content: str
    authorId: str = Field(validation_alias="author_id")
    authorInfo: UserOut = Field(validation_alias="author_info")
    mediaUrls: List[str] = Field(default_factory=list, validation_alias="media_urls")
    reactions: List[Reaction] = Field(default_factory=list)
    reactionCounts: Dict[str, int] = Field(default_factory=dict, validation_alias="reaction_counts")
    sharedPost: Optional["PostOut"] = Field(default=None, validation_alias="shared_post")
    createdAt: datetime = Field(validation_alias="created_at")
    isLiked: bool = False

    model_config = ConfigDict(
        from_attributes=True,
        populate_by_name=True
    )

    @classmethod
    def from_doc(cls, doc: Post, current_user_id: Optional[str] = None) -> Optional["PostOut"]:
        try:
            author_data = doc.author
            if author_data is None:
                return None
            
            # Create a dict for UserOut to ensure displayName is correct
            user_dict = {
                "id": str(author_data.id),
                "username": getattr(author_data, "username", "Unknown"),
                "email": getattr(author_data, "email", None),
                "display_name": getattr(author_data, "display_name", "Người dùng"),
                "avatar_url": getattr(author_data, "avatar_url", None),
                "background_url": getattr(author_data, "background_url", None),
                "bio": getattr(author_data, "bio", None),
                "is_public_email": getattr(author_data, "is_public_email", True)
            }
            author_out = UserOut.model_validate(user_dict)

            # Combine all media URLs into mediaUrls
            media_urls = []
            if doc.image_urls: media_urls.extend(doc.image_urls)
            if doc.video_urls: media_urls.extend(doc.video_urls)
            if doc.file_urls: media_urls.extend(doc.file_urls)

            # Initialize reactionCounts
            reaction_counts = {}
            for r in doc.reactions:
                reaction_counts[r.type] = reaction_counts.get(r.type, 0) + 1

            # Check if current user liked
            is_liked = False
            if current_user_id:
                is_liked = any(r.user_id == current_user_id for r in doc.reactions)

            # Handle shared post
            shared_post_out = None
            if doc.shared_post:
                shared_doc = None
                if isinstance(doc.shared_post, Post):
                    shared_doc = doc.shared_post
                elif hasattr(doc.shared_post, "value") and doc.shared_post.value:
                    shared_doc = doc.shared_post.value
                
                if shared_doc:
                    # Recursive call for shared post
                    shared_post_out = cls.from_doc(shared_doc, current_user_id)

            return cls(
                id=str(doc.id),
                content=doc.content,
                authorId=str(author_data.id),
                authorInfo=author_out,
                mediaUrls=media_urls,
                reactions=doc.reactions,
                reactionCounts=reaction_counts,
                sharedPost=shared_post_out,
                createdAt=doc.created_at,
                isLiked=is_liked
            )
        except Exception as e:
            print(f"Error serializing post {doc.id}: {e}")
            import traceback
            traceback.print_exc()
            return None
