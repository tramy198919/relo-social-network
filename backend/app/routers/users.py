from fastapi import APIRouter, Depends, HTTPException, Body, Form, UploadFile, File, Request
from typing import List, Any, Optional
from app.models.user import User, UserOut
from app.models.friend_request import FriendRequest, FriendRequestOut
from app.core.deps import get_current_user
from beanie import PydanticObjectId

router = APIRouter()

@router.get("/me", response_model=UserOut)
async def read_user_me(current_user: User = Depends(get_current_user)):
    return current_user

@router.put("/me", response_model=UserOut)
async def update_user_me(
    request: Request,
    displayName: Optional[str] = Form(None),
    bio: Optional[str] = Form(None),
    isPublicEmail: Optional[bool] = Form(None),
    avatar: Optional[UploadFile] = File(None),
    background: Optional[UploadFile] = File(None),
    current_user: User = Depends(get_current_user)
):
    import os
    static_dir = "static"
    if not os.path.exists(static_dir):
        os.makedirs(static_dir)

    if displayName:
        current_user.display_name = displayName
    if bio:
        current_user.bio = bio
    if isPublicEmail is not None:
        current_user.is_public_email = isPublicEmail
        
    base_url = str(request.base_url).rstrip("/")
    
    if avatar:
        filename = f"avatar_{current_user.id}_{avatar.filename.replace(' ', '_')}"
        file_path = os.path.join(static_dir, filename)
        content_bytes = await avatar.read()
        with open(file_path, "wb") as buffer:
            buffer.write(content_bytes)
        current_user.avatar_url = f"{base_url}/static/{filename}"
        
    if background:
        filename = f"bg_{current_user.id}_{background.filename.replace(' ', '_')}"
        file_path = os.path.join(static_dir, filename)
        content_bytes = await background.read()
        with open(file_path, "wb") as buffer:
            buffer.write(content_bytes)
        current_user.background_url = f"{base_url}/static/{filename}"
        
    await current_user.save()
    return current_user

@router.get("/search", response_model=List[UserOut])
async def search_users(
    query: str,
    current_user: User = Depends(get_current_user)
):
    users = await User.find(
        {
            "$or": [
                {"username": {"$regex": query, "$options": "i"}},
                {"display_name": {"$regex": query, "$options": "i"}}
            ]
        }
    ).to_list()
    return users

@router.get("/friends", response_model=List[UserOut])
async def get_friends(current_user: User = Depends(get_current_user)):
    friend_ids = []
    for fid in current_user.friends:
        try:
            friend_ids.append(PydanticObjectId(fid))
        except Exception:
            continue
            
    friends = await User.find({"_id": {"$in": friend_ids}}).to_list()
    return friends

@router.post("/batch", response_model=List[UserOut])
async def get_users_batch(
    data: dict = Body(...),
    current_user: User = Depends(get_current_user)
):
    user_ids = data.get("user_ids", [])
    ids = []
    for uid in user_ids:
        try:
            ids.append(PydanticObjectId(uid))
        except:
            continue
    users = await User.find({"_id": {"$in": ids}}).to_list()
    return users

@router.get("/friend-requests/pending")
async def get_pending_requests(current_user: User = Depends(get_current_user)):
    requests = await FriendRequest.find(
        FriendRequest.to_user.id == current_user.id,
        FriendRequest.status == "pending",
        fetch_links=True
    ).to_list()
    
    result = []
    for req in requests:
        out = await FriendRequestOut.from_doc(req)
        result.append(out.model_dump(by_alias=True))
    return result

@router.post("/friend-request")
async def send_friend_request(
    data: dict = Body(...),
    current_user: User = Depends(get_current_user)
):
    to_user_id = data.get("to_user_id")
    if not to_user_id:
        raise HTTPException(status_code=400, detail="Missing to_user_id")
        
    to_user = await User.get(to_user_id)
    if not to_user:
        raise HTTPException(status_code=404, detail="User not found")
        
    # Check if already friends
    if str(to_user.id) in current_user.friends:
        raise HTTPException(status_code=400, detail="Already friends")
        
    existing = await FriendRequest.find_one(
        FriendRequest.from_user.id == current_user.id,
        FriendRequest.to_user.id == to_user.id,
        FriendRequest.status == "pending"
    )
    if existing:
        await existing.delete()
        return {"message": "Friend request cancelled"}
        
    request = FriendRequest(from_user=current_user, to_user=to_user)
    await request.create()
    return {"message": "Friend request sent", "id": str(request.id)}

@router.post("/friend-request/{request_id}")
async def respond_to_request(
    request_id: str,
    data: dict = Body(...),
    current_user: User = Depends(get_current_user)
):
    response = data.get("response") # accepted or declined
    req = await FriendRequest.get(request_id)
    if not req:
        raise HTTPException(status_code=404, detail="Request not found")
        
    if str(req.to_user.ref.id) != str(current_user.id):
        raise HTTPException(status_code=403, detail="Not authorized")
        
    if response == "accepted" or response == "accept":
        req.status = "accepted"
        # Add to friends list
        from_user = await User.get(req.from_user.ref.id)
        if str(from_user.id) not in current_user.friends:
            current_user.friends.append(str(from_user.id))
            await current_user.save()
        if str(current_user.id) not in from_user.friends:
            from_user.friends.append(str(current_user.id))
            await from_user.save()
    else:
        req.status = "rejected"
        
    await req.save()
    return {"message": f"Request {response}"}

@router.post("/friend-request/by-user/{user_id}")
async def respond_to_request_by_user(
    user_id: str,
    data: dict = Body(...),
    current_user: User = Depends(get_current_user)
):
    response = data.get("response") # accept or reject
    req = await FriendRequest.find_one(
        FriendRequest.from_user.id == PydanticObjectId(user_id),
        FriendRequest.to_user.id == current_user.id,
        FriendRequest.status == "pending"
    )
    if not req:
        raise HTTPException(status_code=404, detail="Request not found")
        
    if response == "accept" or response == "accepted":
        req.status = "accepted"
        from_user = await User.get(req.from_user.ref.id)
        if str(from_user.id) not in current_user.friends:
            current_user.friends.append(str(from_user.id))
            await current_user.save()
        if str(current_user.id) not in from_user.friends:
            from_user.friends.append(str(current_user.id))
            await from_user.save()
    else:
        req.status = "rejected"
        
    await req.save()
    return {"message": f"Request {response}"}

@router.delete("/friend-request/{user_id}")
async def cancel_friend_request(
    user_id: str,
    current_user: User = Depends(get_current_user)
):
    # Cancel outgoing or remove incoming
    req = await FriendRequest.find_one(
        FriendRequest.from_user.id == current_user.id,
        FriendRequest.to_user.id == PydanticObjectId(user_id),
        FriendRequest.status == "pending"
    )
    if req:
        await req.delete()
        return {"message": "Request cancelled"}
    
    # Check if we were the recipient
    req = await FriendRequest.find_one(
        FriendRequest.from_user.id == PydanticObjectId(user_id),
        FriendRequest.to_user.id == current_user.id,
        FriendRequest.status == "pending"
    )
    if req:
        await req.delete()
        return {"message": "Request removed"}
        
    raise HTTPException(status_code=404, detail="Request not found")

@router.post("/block")
async def block_user(data: dict = Body(...), current_user: User = Depends(get_current_user)):
    user_id = data.get("user_id")
    if user_id not in current_user.blocked_users:
        current_user.blocked_users.append(user_id)
        await current_user.save()
    return {"message": "User blocked"}

@router.post("/unblock")
async def unblock_user(data: dict = Body(...), current_user: User = Depends(get_current_user)):
    user_id = data.get("user_id")
    if user_id in current_user.blocked_users:
        current_user.blocked_users.remove(user_id)
        await current_user.save()
    return {"message": "User unblocked"}

@router.get("/block-status/{other_user_id}")
async def check_block_status(other_user_id: str, current_user: User = Depends(get_current_user)):
    other_user = await User.get(other_user_id)
    if not other_user:
        raise HTTPException(status_code=404, detail="User not found")
        
    is_blocked_by_me = other_user_id in current_user.blocked_users
    is_blocked_by_them = str(current_user.id) in other_user.blocked_users
    
    return {
        "isBlocked": is_blocked_by_me or is_blocked_by_them,
        "isBlockedByMe": is_blocked_by_me,
        "isBlockingMe": is_blocked_by_them
    }

@router.get("/{user_id}/friend-status")
async def check_friend_status(user_id: str, current_user: User = Depends(get_current_user)):
    if user_id in current_user.friends:
        return {"status": "friends"}
    
    # Check pending
    outgoing = await FriendRequest.find_one(
        FriendRequest.from_user.id == current_user.id,
        FriendRequest.to_user.id == PydanticObjectId(user_id),
        FriendRequest.status == "pending"
    )
    if outgoing:
        return {"status": "request_sent"}
        
    incoming = await FriendRequest.find_one(
        FriendRequest.from_user.id == PydanticObjectId(user_id),
        FriendRequest.to_user.id == current_user.id,
        FriendRequest.status == "pending"
    )
    if incoming:
        return {"status": "request_received"}
        
    return {"status": "none"}

@router.get("/blocked-lists/{user_id}", response_model=List[UserOut])
async def get_blocked_users(user_id: str, current_user: User = Depends(get_current_user)):
    user = await User.get(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    blocked = await User.find({"_id": {"$in": [PydanticObjectId(bid) for bid in user.blocked_users]}}).to_list()
    return blocked

@router.post("/{user_id}/unfriend")
async def unfriend_user(user_id: str, current_user: User = Depends(get_current_user)):
    if user_id in current_user.friends:
        current_user.friends.remove(user_id)
        await current_user.save()
        other_user = await User.get(user_id)
        if other_user and str(current_user.id) in other_user.friends:
            other_user.friends.remove(str(current_user.id))
            await other_user.save()
    return {"message": "Unfriended"}

@router.get("/{user_id}", response_model=UserOut)
async def read_user_by_id(
    user_id: str,
    current_user: User = Depends(get_current_user)
):
    try:
        user = await User.get(user_id)
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        return user
    except Exception:
        raise HTTPException(status_code=404, detail="User not found or Invalid ID")
