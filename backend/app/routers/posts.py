from fastapi import APIRouter, Depends, HTTPException, Body, UploadFile, File, Form, Request
from pydantic import BaseModel, Field
from typing import List, Optional
from app.models.post import Post, PostOut, Reaction
from app.models.user import User
from app.models.comment import Comment, CommentOut
from app.models.notification import Notification
from app.core.deps import get_current_user
from beanie import PydanticObjectId
from app.routers.messages import manager
import json

router = APIRouter()

class ShareRequest(BaseModel):
    content: Optional[str] = None

class ReactRequest(BaseModel):
    reaction_type: str = Field(alias="reaction_type")

@router.get("/user/{user_id}", response_model=List[PostOut])
async def get_user_posts(
    user_id: str,
    skip: int = 0,
    limit: int = 20,
    current_user: User = Depends(get_current_user)
):
    # Beanie $id query can be flaky with Links
    posts = await Post.find(
        {"author.$id": PydanticObjectId(user_id)},
        fetch_links=True
    ).sort(-Post.created_at).skip(skip).limit(limit).to_list()
    
    if not posts:
        # Fallback manual filter
        all_posts = await Post.find_all(fetch_links=True).sort(-Post.created_at).to_list()
        posts = [p for p in all_posts if str(p.author.id) == user_id]
        # Apply skip/limit
        posts = posts[skip : skip + limit]
    
    feed = []
    for p in posts:
        # Fetch shared post author details if needed
        if p.shared_post:
            shared_doc = p.shared_post
            if isinstance(shared_doc, Post):
                await shared_doc.fetch_link("author")

        post_out = PostOut.from_doc(p, str(current_user.id))
        if post_out:
            feed.append(post_out)
    return feed

@router.get("/feed", response_model=List[PostOut])
async def get_feed(
    skip: int = 0,
    limit: int = 20,
    current_user: User = Depends(get_current_user)
):
    # For now, just return all posts sorted by date.
    # In real app, filter by friends.
    posts = await Post.find_all(fetch_links=True).sort(-Post.created_at).skip(skip).limit(limit).to_list()
    
    feed = []
    for p in posts:
        # If this is a shared post, we need to fetch the author of the shared post explicitly
        if p.shared_post:
            # Ensure we have the document (it should be since fetch_links=True)
            shared_doc = p.shared_post
            if isinstance(shared_doc, Post):
                await shared_doc.fetch_link("author")
        
        post_out = PostOut.from_doc(p, str(current_user.id))
        if post_out:
            feed.append(post_out)
            
    return feed



@router.post("", response_model=PostOut)
async def create_post(
    request: Request,
    content: str = Form(...),
    files: List[UploadFile] = File(None),
    current_user: User = Depends(get_current_user)
):
    import os
    
    # Ensure static directory exists
    static_dir = "static"
    if not os.path.exists(static_dir):
        os.makedirs(static_dir)

    image_paths = []
    if files:
        for file in files:
            if not file.filename:
                continue
            
            # Use a safer filename
            filename = file.filename.replace(" ", "_")
            file_path = os.path.join(static_dir, filename)
            
            # Read and write content
            content_bytes = await file.read()
            with open(file_path, "wb") as buffer:
                buffer.write(content_bytes)
            
            # Generate absolute URL based on the request host
            base_url = str(request.base_url).rstrip("/")
            image_paths.append(f"{base_url}/static/{filename}")
            
    post = Post(
        content=content,
        author=current_user,
        image_urls=image_paths
    )
    await post.create()
    
    return PostOut.from_doc(post, str(current_user.id))

@router.get("/{post_id}/comments/count")
async def get_comments_count(post_id: str):
    post = await Post.get(post_id)
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    return {"count": post.comments_count}

@router.put("/{post_id}", response_model=PostOut)
async def update_post(
    post_id: str,
    request: Request,
    content: str = Form(...),
    existing_image_urls: List[str] = Form(None),
    files: List[UploadFile] = File(None),
    current_user: User = Depends(get_current_user)
):
    post = await Post.get(post_id, fetch_links=True)
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
        
    if post.author.id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to edit this post")
        
    post.content = content
    
    # Start with existing URLs if provided
    image_paths = existing_image_urls if existing_image_urls else []
    
    if files:
        import os
        static_dir = "static"
        if not os.path.exists(static_dir):
            os.makedirs(static_dir)
            
        for file in files:
            if not file.filename: continue
            filename = file.filename.replace(" ", "_")
            file_path = os.path.join(static_dir, filename)
            content_bytes = await file.read()
            with open(file_path, "wb") as buffer:
                buffer.write(content_bytes)
            
            base_url = str(request.base_url).rstrip("/")
            image_paths.append(f"{base_url}/static/{filename}")
    
    post.image_urls = image_paths
            
    await post.save()
    return PostOut.from_doc(post, str(current_user.id))

@router.post("/{post_id}/share", response_model=PostOut)
async def share_post(
    post_id: str,
    share_req: ShareRequest = Body(...),
    current_user: User = Depends(get_current_user)
):
    original_post = await Post.get(post_id, fetch_links=True)
    if not original_post:
        raise HTTPException(status_code=404, detail="Original post not found")
        
    new_post = Post(
        content=share_req.content if share_req.content else "",
        author=current_user,
        shared_post=original_post
    )
    await new_post.create()
    
    # Notify original author
    if str(original_post.author.id) != str(current_user.id):
        notif = Notification(
            recipient=original_post.author,
            sender_id=str(current_user.id),
            sender_name=current_user.display_name,
            sender_avatar=current_user.avatar_url,
            type="post_share",
            related_id=str(new_post.id),
            content=f"đã chia sẻ bài viết của bạn"
        )
        await notif.create()
        # WS notify
        ws_msg = json.dumps({
            "type": "post_share",
            "payload": {
                "type": "post_share",
                "userId": str(current_user.id),
                "userDisplayName": current_user.display_name,
                "avatar": current_user.avatar_url,
                "postId": str(new_post.id)
            }
        })
        await manager.send_personal_message(ws_msg, str(original_post.author.id))
    
    new_post_fetched = await Post.get(str(new_post.id), fetch_links=True)
    if new_post_fetched and new_post_fetched.shared_post:
        # Fetch author of the shared post explicitly
        shared_doc = new_post_fetched.shared_post
        if isinstance(shared_doc, Post):
            await shared_doc.fetch_link("author")

    return PostOut.from_doc(new_post_fetched, str(current_user.id))

@router.get("/{post_id}", response_model=PostOut)
async def get_post(
    post_id: str,
    current_user: User = Depends(get_current_user)
):
    post = await Post.get(post_id, fetch_links=True)
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    
    # Fetch shared post author details if needed
    if post.shared_post:
        shared_doc = post.shared_post
        if isinstance(shared_doc, Post):
            await shared_doc.fetch_link("author")
            
    return PostOut.from_doc(post, str(current_user.id))

@router.post("/{post_id}/react")
async def react_to_post(
    post_id: str,
    react_req: ReactRequest = Body(...),
    current_user: User = Depends(get_current_user)
):
    post = await Post.get(post_id, fetch_links=True)
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    
    user_id_str = str(current_user.id)
    # Remove existing reaction from this user if any
    post.reactions = [r for r in post.reactions if r.user_id != user_id_str]
    
    # Add new reaction
    post.reactions.append(Reaction(user_id=user_id_str, type=react_req.reaction_type))
    await post.save()
    
    # Refresh to get author info for PostOut
    post = await Post.get(post_id, fetch_links=True)
    
    # Notify author
    if str(post.author.id) != user_id_str:
        notif = Notification(
            recipient=post.author,
            sender_id=user_id_str,
            sender_name=current_user.display_name,
            sender_avatar=current_user.avatar_url,
            type="post_reaction",
            related_id=post_id,
            content=f"đã bày tỏ cảm xúc về bài viết của bạn"
        )
        await notif.create()
        ws_msg = json.dumps({
            "type": "post_reaction", 
            "payload": {
                "type": "post_reaction",
                "userId": user_id_str, # Sender
                "userDisplayName": current_user.display_name,
                "avatar": current_user.avatar_url,
                "postId": post_id
            }
        })
        await manager.send_personal_message(ws_msg, str(post.author.id))
        
    return PostOut.from_doc(post, user_id_str)

@router.post("/{post_id}/comments", response_model=CommentOut)
async def create_comment(
    post_id: str,
    content: str = Body(..., embed=True),
    current_user: User = Depends(get_current_user)
):
    post = await Post.get(post_id, fetch_links=True)
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    
    comment = Comment(
        post_id=PydanticObjectId(post_id),
        author=current_user,
        content=content
    )
    await comment.create()
    
    post.comments_count += 1
    await post.save()
    
    # Notify author
    if str(post.author.id) != str(current_user.id):
        notif = Notification(
            recipient=post.author,
            sender_id=str(current_user.id),
            sender_name=current_user.display_name,
            sender_avatar=current_user.avatar_url,
            type="post_comment",
            related_id=post_id,
            content=f"đã bình luận về bài viết của bạn"
        )
        await notif.create()
        ws_msg = json.dumps({
            "type": "post_comment",
            "payload": {
                "type": "post_comment",
                "userId": str(current_user.id),
                "userDisplayName": current_user.display_name,
                "avatar": current_user.avatar_url,
                "postId": post_id
            }
        })
        await manager.send_personal_message(ws_msg, str(post.author.id))

    return CommentOut.from_doc(comment)

@router.get("/{post_id}/comments", response_model=List[CommentOut])
async def get_comments(post_id: str):
    comments = await Comment.find(
        Comment.post_id == PydanticObjectId(post_id),
        fetch_links=True
    ).sort(Comment.created_at).to_list()
    return [CommentOut.from_doc(c) for c in comments]

@router.delete("/comments/{comment_id}")
async def delete_comment(
    comment_id: str,
    current_user: User = Depends(get_current_user)
):
    comment = await Comment.get(comment_id, fetch_links=True)
    if not comment:
        raise HTTPException(status_code=404, detail="Comment not found")
        
    # Permission: only author or post author can delete
    post = await Post.get(str(comment.post_id), fetch_links=True)
    if str(comment.author.id) != str(current_user.id) and (not post or str(post.author.id) != str(current_user.id)):
        raise HTTPException(status_code=403, detail="Not authorized")
        
    await comment.delete()
    if post:
        post.comments_count = max(0, post.comments_count - 1)
        await post.save()
    return {"message": "Comment deleted"}

@router.put("/comments/{comment_id}", response_model=CommentOut)
async def update_comment(
    comment_id: str,
    content: str = Body(..., embed=True),
    current_user: User = Depends(get_current_user)
):
    comment = await Comment.get(comment_id, fetch_links=True)
    if not comment:
        raise HTTPException(status_code=404, detail="Comment not found")
        
    if str(comment.author.id) != str(current_user.id):
        raise HTTPException(status_code=403, detail="Not authorized")
        
    comment.content = content
    await comment.save()
    return CommentOut.from_doc(comment)

@router.delete("/{post_id}")
async def delete_post(
    post_id: str,
    current_user: User = Depends(get_current_user)
):
    post = await Post.get(post_id, fetch_links=True)
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
        
    if post.author.id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")
        
    await post.delete()
    return {"message": "Post deleted"}
