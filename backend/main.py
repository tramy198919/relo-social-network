from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from motor.motor_asyncio import AsyncIOMotorClient
from beanie import init_beanie

from app.core.config import settings
from app.models.user import User
from app.models.post import Post
from app.models.message import Message, Conversation
from app.models.notification import Notification
from app.models.friend_request import FriendRequest
from app.models.comment import Comment

from app.routers import auth, users, posts, messages, notifications

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    app.mongodb_client = AsyncIOMotorClient(settings.MONGODB_URL)
    app.mongodb_db = app.mongodb_client[settings.MONGODB_DB_NAME]
    
    print(f"Connecting to MongoDB at: {settings.MONGODB_URL.split('@')[-1]}") # Log host only for safety
    await init_beanie(
        database=app.mongodb_db,
        document_models=[
            User,
            Post,
            Message,
            Conversation,
            Notification,
            FriendRequest,
            Comment
        ]
    )
    print("Beanie initialized successfully!")
    print("Database connected and app is ready!")
    yield
    # Shutdown
    app.mongodb_client.close()

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    lifespan=lifespan
)

# Set all CORS enabled origins
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix=f"{settings.API_V1_STR}/auth", tags=["auth"])
app.include_router(users.router, prefix=f"{settings.API_V1_STR}/users", tags=["users"])
app.include_router(posts.router, prefix=f"{settings.API_V1_STR}/posts", tags=["posts"])
app.include_router(messages.router, prefix=f"{settings.API_V1_STR}/messages", tags=["messages"])
app.include_router(messages.router, prefix="/websocket", tags=["websocket"])
app.include_router(notifications.router, prefix=f"{settings.API_V1_STR}/notifications", tags=["notifications"])

app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/")
async def root():
    return {"message": "Welcome to Relo API"}
