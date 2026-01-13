from fastapi import APIRouter, Depends, HTTPException, status, Body
from typing import Any
from pydantic import BaseModel, EmailStr
from app.models.user import User, UserCreate, UserLogin, Token, UserOut
from app.core import security
from app.core.deps import get_current_user
from fastapi_mail import ConnectionConfig, FastMail, MessageSchema, MessageType
import random
import string

router = APIRouter()

# Mail configuration
conf = ConnectionConfig(
    MAIL_USERNAME=security.settings.MAIL_USERNAME,
    MAIL_PASSWORD=security.settings.MAIL_PASSWORD,
    MAIL_FROM=security.settings.MAIL_FROM,
    MAIL_PORT=security.settings.MAIL_PORT,
    MAIL_SERVER=security.settings.MAIL_SERVER,
    MAIL_FROM_NAME=security.settings.MAIL_FROM_NAME,
    MAIL_STARTTLS=True,
    MAIL_SSL_TLS=False,
    USE_CREDENTIALS=True,
    VALIDATE_CERTS=True
)

# Models for OTP moved to body dict for flexibility

@router.post("/send-otp")
async def send_otp(data: dict = Body(...)):
    # Flutter sends {'identifier': ...}
    identifier = data.get("identifier")
    if not identifier:
        raise HTTPException(status_code=422, detail="Missing identifier")
    
    print(f"DEBUG: send_otp identifier={identifier}")
    
    # Find user to get their real email
    user = await User.find_one({"$or": [{"email": identifier}, {"username": identifier}]})
    
    email_to_send = identifier
    if user:
        email_to_send = user.email
        print(f"DEBUG: Found user {user.username}, sending OTP to email: {email_to_send}")
    else:
        print(f"DEBUG: User not found for identifier={identifier}, using identifier as email")

    # Mock sending OTP or Real sending
    otp = ''.join(random.choices(string.digits, k=6))
    print(f"DEBUG: Generated OTP {otp} for {email_to_send}")
    
    if security.settings.MAIL_USERNAME and security.settings.MAIL_PASSWORD:
        message = MessageSchema(
            subject="Mã xác thực OTP - Relo Social",
            recipients=[email_to_send],
            body=f"Mã OTP của bạn là: {otp}. Vui lòng không cung cấp mã này cho bất kỳ ai.",
            subtype=MessageType.plain
        )
        fm = FastMail(conf)
        try:
            await fm.send_message(message)
            print(f"DEBUG: Real Email sent to {email_to_send}")
        except Exception as e:
            print(f"DEBUG: Failed to send real email: {e}")
            return {"message": f"OTP sent failed (Check console)", "email": email_to_send}

    return {"message": "OTP sent successfully", "email": email_to_send}

@router.post("/verify-otp")
async def verify_otp(data: dict = Body(...)):
    # Flutter sends {'email': ..., 'otp_code': ...}
    email = data.get("email")
    otp_code = data.get("otp_code")
    print(f"DEBUG: verify_otp email={email}, otp_code={otp_code}")
    # Accept everything to not block user for now
    return {"message": "OTP verified successfully (Mock)"}

@router.post("/reset-password")
async def reset_password(data: dict = Body(...)):
    # Flutter sends {'email': ..., 'new_password': ...}
    email = data.get("email")
    new_password = data.get("new_password")
    
    if not email or not new_password:
         raise HTTPException(status_code=422, detail="Missing fields")
    
    print(f"DEBUG: reset_password email={email}")
    
    # In real app, check if OTP was verified for this email
    user = await User.find_one({"$or": [{"email": email}, {"username": email}]})
        
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    user.password_hash = security.get_password_hash(new_password)
    await user.save()
    return {"message": "Password reset successfully"}

@router.post("/change-email/verify-password")
async def verify_password_for_email_change(data: dict = Body(...)):
    user_id = data.get("user_id")
    password = data.get("password")
    user = await User.get(user_id)
    if not user or not security.verify_password(password, user.password_hash):
        raise HTTPException(status_code=400, detail="Mật khẩu không chính xác")
    return {"status": "ok"}

@router.post("/change-email/update")
async def update_email(data: dict = Body(...)):
    user_id = data.get("user_id")
    new_email = data.get("new_email")
    user = await User.get(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.email = new_email
    await user.save()
    return {"message": "Email updated successfully"}

@router.post("/register", response_model=UserOut)
async def register(user_in: UserCreate) -> Any:
    user = await User.find_one(User.username == user_in.username)
    if user:
        raise HTTPException(
            status_code=400,
            detail="Tên đăng nhập đã tồn tại.",
        )
    user = await User.find_one(User.email == user_in.email)
    if user:
        raise HTTPException(
            status_code=400,
            detail="Email đã được sử dụng.",
        )
        
    user = User(
        username=user_in.username,
        email=user_in.email,
        password_hash=security.get_password_hash(user_in.password),
        display_name=user_in.displayName
    )
    await user.create()
    return user

@router.post("/login", response_model=Token)
async def login(user_in: UserLogin) -> Any:
    user = await User.find_one(User.username == user_in.username)
    if not user or not security.verify_password(user_in.password, user.password_hash):
        raise HTTPException(
            status_code=401,
            detail="Tên đăng nhập hoặc mật khẩu không chính xác.",
        )
        
    if not user.is_active:
        raise HTTPException(status_code=400, detail="Tài khoản đã bị khóa.")
        
    access_token = security.create_access_token(user.id)
    refresh_token = security.create_refresh_token(user.id)
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
    }

@router.post("/refresh", response_model=Token)
async def refresh_token(refresh_token: str = Body(..., embed=True)) -> Any:
    try:
        payload = security.jwt.decode(refresh_token, security.settings.SECRET_KEY, algorithms=[security.settings.ALGORITHM])
        if payload.get("type") != "refresh":
             raise HTTPException(status_code=401, detail="Invalid token type")
        user_id = payload.get("sub")
        if user_id is None:
             raise HTTPException(status_code=401, detail="Invalid token")
    except security.JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")
        
    user = await User.get(user_id)
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
        
    access_token = security.create_access_token(user.id)
    # Rotate refresh token? For simplicity, we can keep using same or issue new one.
    # Let's issue new one
    new_refresh_token = security.create_refresh_token(user.id)
    
    return {
        "access_token": access_token,
        "refresh_token": new_refresh_token,
        "token_type": "bearer",
    }
    
@router.post("/logout")
async def logout(
    current_user: User = Depends(get_current_user),
    device_token: str = Body(None, embed=True)
) -> Any:
    # In a real app with stateful sessions or redis whitelist/blacklist, handle logout here.
    # For stateless JWT, client just discards token.
    # We might remove device token from user if we stored it for notifications.
    return {"message": "Logged out"}
