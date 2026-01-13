from typing import Optional, List, Any
from beanie import Document, Indexed, PydanticObjectId
from pydantic import BaseModel, EmailStr, Field, ConfigDict, field_validator
from datetime import datetime

class User(Document):
    username: Indexed(str, unique=True)
    email: Indexed(EmailStr, unique=True)
    password_hash: str
    display_name: str = Field(alias="displayName")
    bio: Optional[str] = None
    avatar_url: Optional[str] = Field(None, alias="avatarUrl")
    background_url: Optional[str] = Field(None, alias="backgroundUrl")
    is_active: bool = True
    is_public_email: bool = Field(True, alias="isPublicEmail")
    created_at: datetime = Field(default_factory=datetime.now)
    
    # Friends
    friends: List[str] = [] # List of User IDs
    
    # Blocked
    blocked_users: List[str] = []
    
    class Settings:
        name = "users"

class UserCreate(BaseModel):
    username: str
    email: EmailStr
    password: str
    displayName: str

class UserLogin(BaseModel):
    username: str
    password: str
    device_token: Optional[str] = None

class UserOut(BaseModel):
    id: str = Field(validation_alias="id")
    username: str
    email: Optional[EmailStr] = None
    displayName: str = Field(validation_alias="display_name", serialization_alias="displayName")
    bio: Optional[str] = None
    avatarUrl: Optional[str] = Field(None, validation_alias="avatar_url", serialization_alias="avatarUrl")
    backgroundUrl: Optional[str] = Field(None, validation_alias="background_url", serialization_alias="backgroundUrl")
    isPublicEmail: bool = Field(True, validation_alias="is_public_email", serialization_alias="isPublicEmail")
    
    model_config = ConfigDict(
        from_attributes=True,
        populate_by_name=True
    )

    @field_validator("id", mode="before")
    @classmethod
    def convert_id(cls, v: Any) -> str:
        return str(v)

class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str
