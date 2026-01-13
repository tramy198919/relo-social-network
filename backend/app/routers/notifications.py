from fastapi import APIRouter, Depends, HTTPException
from typing import List, Optional
from app.models.notification import Notification, NotificationOut
from app.models.user import User
from app.core.deps import get_current_user

router = APIRouter()

@router.get("/", response_model=List[NotificationOut])
async def get_notifications(
    limit: int = 50,
    skip: int = 0,
    unread_only: bool = False,
    current_user: User = Depends(get_current_user)
):
    criteria = [Notification.recipient.id == current_user.id]
    if unread_only:
        criteria.append(Notification.is_read == False)
        
    notifications = await Notification.find(*criteria, fetch_links=True).sort(-Notification.created_at).skip(skip).limit(limit).to_list()
    return [NotificationOut.from_doc(n) for n in notifications]

@router.get("/unread-count")
async def get_unread_count(current_user: User = Depends(get_current_user)):
    count = await Notification.find(Notification.recipient.id == current_user.id, Notification.is_read == False).count()
    return {"count": count}

@router.put("/{notification_id}/read")
async def mark_as_read(notification_id: str, current_user: User = Depends(get_current_user)):
    notification = await Notification.get(notification_id)
    if not notification or notification.recipient.ref.id != current_user.id:
        raise HTTPException(status_code=404, detail="Notification not found")
    
    notification.is_read = True
    await notification.save()
    return {"message": "Marked as read"}

@router.put("/read-all")
async def mark_all_as_read(current_user: User = Depends(get_current_user)):
    await Notification.find(Notification.recipient.id == current_user.id, Notification.is_read == False).update({"$set": {"is_read": True}})
    return {"message": "All marked as read"}

@router.delete("/{notification_id}")
async def delete_notification(notification_id: str, current_user: User = Depends(get_current_user)):
    notification = await Notification.get(notification_id)
    if not notification or notification.recipient.ref.id != current_user.id:
        raise HTTPException(status_code=404, detail="Notification not found")
    
    await notification.delete()
    return {"message": "Notification deleted"}
