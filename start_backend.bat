@echo off
cd backend
if not exist venv (
    echo Creating virtual environment...
    python -m venv venv
    call venv\Scripts\activate.bat
    pip install -r requirements.txt
) else (
    call venv\Scripts\activate.bat
)
echo Starting server...
uvicorn main:app --reload --host 0.0.0.0 --port 5173
pause
