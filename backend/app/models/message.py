from typing import Optional, List, Any
from beanie import Document, Link, PydanticObjectId
from pydantic import BaseModel, Field, ConfigDict
from datetime import datetime
from app.models.user import User

class Message(Document):
    conversation_id: PydanticObjectId
    sender: Link[User]
    message_type: str = "text" # text, audio, file, media
    text: Optional[str] = None
    file_urls: List[str] = []
    timestamp: datetime = Field(default_factory=datetime.now)
    status: str = "sent"
    read_by: List[str] = []
    
    class Settings:
        name = "messages"

class MessageOut(BaseModel):
    id: str
    content: dict
    senderId: str
    conversationId: str
    createdAt: str
    status: str
    avatarUrl: Optional[str] = ""

    @classmethod
    async def from_doc(cls, doc: Message) -> "MessageOut":
        if isinstance(doc.sender, Link):
            await doc.fetch_link(Message.sender)
            
        content = {"type": doc.message_type}
        if doc.message_type == "text":
            content["text"] = doc.text
        elif doc.file_urls:
            content["url"] = doc.file_urls[0] if doc.file_urls else ""
            content["path"] = doc.file_urls[0] if doc.file_urls else "" # for audio/file
            content["paths"] = doc.file_urls # for media
            
        return cls(
            id=str(doc.id),
            content=content,
            senderId=str(doc.sender.id),
            conversationId=str(doc.conversation_id),
            createdAt=doc.timestamp.isoformat(),
            status=doc.status,
            avatarUrl=getattr(doc.sender, 'avatar_url', '') or ''
        )

class Conversation(Document):
    name: Optional[str] = None
    is_group: bool = False
    participants: List[Link[User]]
    avatar_url: Optional[str] = Field(None, alias="avatarUrl")
    last_message: Optional[dict] = None
    updated_at: datetime = Field(default_factory=datetime.now)
    muted_by: List[str] = []
    seen_ids: List[str] = []
    
    class Settings:
        name = "conversations"

class ConversationOut(BaseModel):
    id: str
    name: Optional[str] = None
    isGroup: bool = Field(validation_alias="is_group")
    participants: List[Any]
    avatarUrl: Optional[str] = Field(None, validation_alias="avatar_url")
    lastMessage: Optional[dict] = Field(None, validation_alias="last_message")
    updatedAt: str
    seenIds: List[str] = Field(default_factory=list, validation_alias="seen_ids")
    
    model_config = ConfigDict(
        from_attributes=True,
        populate_by_name=True
    )

    @classmethod
    async def from_doc(cls, doc: Conversation) -> "ConversationOut":
        if any(isinstance(p, Link) for p in doc.participants):
             await doc.fetch_link(Conversation.participants)
        
        # We need UserOut for participants
        from app.models.user import UserOut
        
        return cls(
            id=str(doc.id),
            name=doc.name,
            is_group=doc.is_group,
            participants=[UserOut.model_validate(p) for p in doc.participants],
            avatar_url=doc.avatar_url,
            last_message=doc.last_message,
            updatedAt=doc.updated_at.isoformat(),
            seen_ids=doc.seen_ids
        )

class ConversationCreate(BaseModel):
    participant_ids: List[str]
    is_group: bool = False
    name: Optional[str] = None
