from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect, Body, Form, UploadFile, File
from typing import List, Optional, Any
from app.models.message import Message, Conversation, ConversationCreate, MessageOut, ConversationOut
from app.models.user import User
from app.core.deps import get_current_user
from beanie import PydanticObjectId
from jose import jwt, JWTError
from app.core.config import settings

router = APIRouter()

# WebSocket Manager
class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []
        self.user_connections: dict = {} # user_id -> WebSocket

    async def connect(self, websocket: WebSocket, user_id: str):
        await websocket.accept()
        self.active_connections.append(websocket)
        self.user_connections[user_id] = websocket

    def disconnect(self, websocket: WebSocket, user_id: str):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)
        if user_id in self.user_connections:
            del self.user_connections[user_id]

    async def send_personal_message(self, message: str, user_id: str):
        if user_id in self.user_connections:
            try:
                await self.user_connections[user_id].send_text(message)
            except:
                pass

manager = ConnectionManager()

@router.get("/conversations")
async def get_conversations(current_user: User = Depends(get_current_user)):
    # Beanie participants is a list of Links. We need to find where any link points to our user.
    # We query by the DB ref structure or fetch and filter. 
    # Let's use a more robust query for Beanie Links:
    conversations = await Conversation.find(
        {"participants.$id": current_user.id},
        fetch_links=True
    ).sort(-Conversation.updated_at).to_list()
    
    # If Beanie's $id query is acting up with Links, fallback:
    if not conversations:
        all_convs = await Conversation.find_all(fetch_links=True).to_list()
        conversations = [
            c for c in all_convs 
            if any(str(p.id) == str(current_user.id) for p in c.participants)
        ]
        # Sort by updated_at desc
        conversations.sort(key=lambda x: x.updated_at, reverse=True)

    result = []
    for conv in conversations:
        out = await ConversationOut.from_doc(conv)
        result.append(out.model_dump(by_alias=True))
    return result

@router.get("/conversations/{conversation_id}")
async def get_conversation_by_id(conversation_id: str, current_user: User = Depends(get_current_user)):
    conv = await Conversation.get(conversation_id, fetch_links=True)
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")
    out = await ConversationOut.from_doc(conv)
    return out.model_dump(by_alias=True)

@router.post("/conversations")
async def create_conversation(
    conv_in: ConversationCreate,
    current_user: User = Depends(get_current_user)
):
    participants = []
    for pid in conv_in.participant_ids:
        user = await User.get(pid)
        if user:
            participants.append(user)
    
    if str(current_user.id) not in [str(p.id) for p in participants]:
        participants.append(current_user)
        
    # Check if a 1:1 conversation already exists between these two
    if not conv_in.is_group and len(participants) == 2:
        p_ids = [str(p.id) for p in participants]
        existing = await Conversation.find(
            {"is_group": False, "participants.$id": {"$all": [PydanticObjectId(i) for i in p_ids]}}
        ).first_or_none()
        if existing:
            out = await ConversationOut.from_doc(existing)
            return out.model_dump(by_alias=True)

    conv = Conversation(
        name=conv_in.name,
        is_group=conv_in.is_group,
        participants=participants
    )
    await conv.create()
    out = await ConversationOut.from_doc(conv)
    return out.model_dump(by_alias=True)

@router.get("/conversations/{conversation_id}/messages")
async def get_messages(
    conversation_id: str,
    offset: int = 0,
    limit: int = 50,
    current_user: User = Depends(get_current_user)
):
    messages = await Message.find(
        Message.conversation_id == PydanticObjectId(conversation_id),
        fetch_links=True
    ).sort(-Message.timestamp).skip(offset).limit(limit).to_list()
    
    result = []
    for msg in messages:
        out = await MessageOut.from_doc(msg)
        result.append(out.model_dump(by_alias=True))
    return result

@router.post("/conversations/{conversation_id}/messages")
async def send_message(
    conversation_id: str,
    type: str = Form(...),
    text: Optional[str] = Form(None),
    files: List[UploadFile] = File(None),
    current_user: User = Depends(get_current_user)
):
    conv = await Conversation.get(conversation_id, fetch_links=True)
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")
        
    file_urls = []
    if files:
        for f in files:
            file_urls.append(f"http://10.0.2.2:5173/static/{f.filename}")
            
    message = Message(
        conversation_id=PydanticObjectId(conversation_id),
        sender=current_user,
        message_type=type,
        text=text,
        file_urls=file_urls
    )
    await message.create()
    
    # Update last message
    conv.last_message = {
        "content_type": type,
        "text": text,
        "sender_id": str(current_user.id),
        "timestamp": message.timestamp.isoformat()
    }
    conv.updated_at = message.timestamp
    conv.seen_ids = [str(current_user.id)]
    await conv.save()
    
    # Notify via WS
    msg_out = await MessageOut.from_doc(message)
    msg_data = msg_out.model_dump(by_alias=True)
    import json
    ws_msg = json.dumps({
        "type": "new_message", 
        "payload": {
            "message": msg_data,
            "conversation": {
                "participantCount": len(conv.participants)
            }
        }
    })
    
    for p in conv.participants:
        if str(p.id) != str(current_user.id):
            await manager.send_personal_message(ws_msg, str(p.id))
            
    return msg_data

@router.post("/conversations/{conversation_id}/seen")
async def mark_as_seen(
    conversation_id: str,
    current_user: User = Depends(get_current_user)
):
    conv = await Conversation.get(conversation_id)
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")
        
    user_id_str = str(current_user.id)
    if user_id_str not in conv.seen_ids:
        conv.seen_ids.append(user_id_str)
        await conv.save()
        
    return {"status": "success"}

@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, token: str = None):
    if not token:
        await websocket.close(code=1008)
        return
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            await websocket.close(code=1008)
            return
    except:
        await websocket.close(code=1008)
        return

    await manager.connect(websocket, user_id)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket, user_id)
