from fastapi import FastAPI, HTTPException, Depends, Request
from fastapi.responses import JSONResponse
import traceback
from database import get_db_connection
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer
from schemas import RegisterRequest, LoginRequest, HabitCreate, HabitLogCreate
import jwt
import os
from passlib.context import CryptContext
from datetime import datetime, timedelta
from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    create_tables()
    yield

app = FastAPI(lifespan=lifespan)

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    print(f"CRITICAL ERROR: {str(exc)}")
    print(traceback.format_exc())
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal Server Error", "error": str(exc)},
        headers={
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "*",
            "Access-Control-Allow-Headers": "*"
        }
    )

def create_tables():
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Create Users Table
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        password VARCHAR(255) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    ''')

    # Create Habits Table
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS habits (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        habit_name VARCHAR(255) NOT NULL,
        description TEXT,
        category VARCHAR(100) DEFAULT 'Uncategorized',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )
    ''')

    # Create Habit Logs Table
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS habit_logs (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        habit_id INT NOT NULL,
        date DATE NOT NULL,
        status TINYINT(1) NOT NULL, /* e.g., 1 for complete, 0 for incomplete */
        completed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE CASCADE,
        UNIQUE KEY unique_user_habit_date (user_id, habit_id, date)
    )
    ''')

    conn.commit()
    cursor.close()
    conn.close()


@app.middleware("http")
async def log_requests(request, call_next):
    print(f"Incoming request: {request.method} {request.url}")
    response = await call_next(request)
    print(f"Response status: {response.status_code}")
    return response

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:8080",
        "http://localhost:10000",
        "http://127.0.0.1:8080",
        "*"
    ],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

SECRET_KEY = os.environ.get("SECRET_KEY", "fallback_dev_key_change_in_production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7 # 7 days

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login")

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: timedelta | None = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def get_current_user(token: str = Depends(oauth2_scheme)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise HTTPException(status_code=401, detail="Invalid token")
        return int(user_id)
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

@app.get("/")
def home():
    return {"message": "Master backend running"}

@app.get("/test-db")
def test_database():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT DATABASE();")
    db = cursor.fetchone()
    conn.close()

    return {"database": db}

@app.post("/register")
def register_user(user: RegisterRequest):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    check_query = "SELECT * FROM users WHERE email = %s"
    cursor.execute(check_query, (user.email,))
    existing_user = cursor.fetchone()

    if existing_user:
        conn.close()
        raise HTTPException(status_code=400, detail="Email already registered")

    hashed_password = get_password_hash(user.password)

    insert_query = "INSERT INTO users (name, email, password) VALUES (%s, %s, %s)"
    cursor.execute(insert_query, (user.name, user.email, hashed_password))
    conn.commit()

    user_id = cursor.lastrowid
    conn.close()

    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": str(user_id)}, expires_delta=access_token_expires
    )

    return {
        "success": True,
        "message": "User registered successfully",
        "user_id": user_id,
        "access_token": access_token,
        "token_type": "bearer"
    }

@app.post("/login")
def login_user(user: LoginRequest):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    query = "SELECT * FROM users WHERE email = %s"
    cursor.execute(query, (user.email,))
    existing_user = cursor.fetchone()

    if not existing_user:
        conn.close()
        raise HTTPException(status_code=404, detail="User not found")

    if not verify_password(user.password, existing_user["password"]):
        conn.close()
        raise HTTPException(status_code=401, detail="Invalid password")

    conn.close()

    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": str(existing_user["id"])}, expires_delta=access_token_expires
    )

    return {
        "success": True,
        "message": "Login successful",
        "user": {
            "id": existing_user["id"],
            "name": existing_user["name"],
            "email": existing_user["email"]
        },
        "access_token": access_token,
        "token_type": "bearer"
    }
@app.post("/create-habit")
def create_habit(habit: HabitCreate, current_user: int = Depends(get_current_user)):
    if habit.user_id != current_user:
        raise HTTPException(status_code=403, detail="Not authorized")

    conn = get_db_connection()
    cursor = conn.cursor()

    query = """
    INSERT INTO habits (user_id, habit_name, description, category)
    VALUES (%s, %s, %s, %s)
    """

    cursor.execute(query, (
        habit.user_id,
        habit.habit_name,
        habit.description,
        habit.category
    ))

    conn.commit()

    habit_id = cursor.lastrowid

    conn.close()

    return {
        "success": True,
        "message": "Habit created successfully",
        "habit_id": habit_id
    }
@app.get("/habits/{user_id}")
def get_user_habits(user_id: int, current_user: int = Depends(get_current_user)):
    if user_id != current_user:
        raise HTTPException(status_code=403, detail="Not authorized")
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    query = "SELECT * FROM habits WHERE user_id = %s ORDER BY id DESC"
    cursor.execute(query, (user_id,))
    habits = cursor.fetchall()
    
    today = datetime.now().date()
    yesterday = today - timedelta(days=1)
    
    for habit in habits:
        log_query = "SELECT date, status FROM habit_logs WHERE user_id = %s AND habit_id = %s"
        cursor.execute(log_query, (user_id, habit['id']))
        logs = cursor.fetchall()
        
        logged_dates = set()
        for log in logs:
            if log['status'] == 1:
                dt = log['date'] if isinstance(log['date'], str) else str(log['date'])
                try:
                    date_obj = datetime.strptime(dt, '%Y-%m-%d').date()
                    logged_dates.add(date_obj)
                except ValueError:
                    pass
                    
        streak = 0
        current_date = today
        
        if today in logged_dates:
            streak += 1
            current_date -= timedelta(days=1)
            while current_date in logged_dates:
                streak += 1
                current_date -= timedelta(days=1)
        elif yesterday in logged_dates:
            streak += 1
            current_date = yesterday - timedelta(days=1)
            while current_date in logged_dates:
                streak += 1
                current_date -= timedelta(days=1)
                
        habit['streak'] = streak

    conn.close()

    return {
        "success": True,
        "habits": habits
    }
@app.post("/log-habit")
def log_habit(log: HabitLogCreate, current_user: int = Depends(get_current_user)):
    if log.user_id != current_user:
        raise HTTPException(status_code=403, detail="Not authorized")
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    # Check if log already exists for this user, habit, and date
    check_query = """
    SELECT * FROM habit_logs
    WHERE user_id = %s AND habit_id = %s AND date = %s
    """
    cursor.execute(check_query, (log.user_id, log.habit_id, log.date))
    existing_log = cursor.fetchone()

    if existing_log:
        update_query = """
        UPDATE habit_logs
        SET status = %s,
            completed_at = CURRENT_TIMESTAMP
        WHERE user_id = %s AND habit_id = %s AND date = %s
        """
        cursor.execute(update_query, (log.status, log.user_id, log.habit_id, log.date))
        conn.commit()
        conn.close()

        return {
            "success": True,
            "message": "Habit log updated successfully"
        }

    insert_query = """
    INSERT INTO habit_logs (user_id, habit_id, date, status, completed_at)
    VALUES (%s, %s, %s, %s, CURRENT_TIMESTAMP)
    """
    cursor.execute(insert_query, (log.user_id, log.habit_id, log.date, log.status))
    conn.commit()

    conn.close()

    return {
        "success": True,
        "message": "Habit logged successfully"
    }
@app.get("/habit-logs/{user_id}")
def get_habit_logs(user_id: int, current_user: int = Depends(get_current_user)):
    if user_id != current_user:
        raise HTTPException(status_code=403, detail="Not authorized")
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    query = """
    SELECT id, user_id, habit_id, date, status, completed_at
    FROM habit_logs
    WHERE user_id = %s
    ORDER BY date DESC
    """
    cursor.execute(query, (user_id,))
    logs = cursor.fetchall()

    conn.close()

    return {
        "success": True,
        "logs": logs
    }
@app.get("/habit-logs/{user_id}/{start_date}/{end_date}")
def get_habit_logs_by_date_range(user_id: int, start_date: str, end_date: str, current_user: int = Depends(get_current_user)):
    if user_id != current_user:
        raise HTTPException(status_code=403, detail="Not authorized")
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    query = """
    SELECT id, user_id, habit_id, date, status, completed_at
    FROM habit_logs
    WHERE user_id = %s
      AND date BETWEEN %s AND %s
    ORDER BY date ASC
    """
    cursor.execute(query, (user_id, start_date, end_date))
    logs = cursor.fetchall()

    conn.close()

    return {
        "success": True,
        "logs": logs
    }
@app.delete("/habit/{habit_id}")
def delete_habit(habit_id: int, current_user: int = Depends(get_current_user)):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        query = "DELETE FROM habits WHERE id = %s"
        cursor.execute(query, (habit_id,))
        conn.commit()

        return {
            "success": True,
            "message": "Habit deleted successfully"
        }

    except Exception as e:
        conn.rollback()
        return {
            "success": False,
            "error": str(e)
        }

    finally:
        cursor.close()
        conn.close()

from pydantic import BaseModel

class HabitUpdate(BaseModel):
    habit_name: str
    description: str

@app.put("/habit/{habit_id}")
def update_habit(habit_id: int, habit: HabitUpdate, current_user: int = Depends(get_current_user)):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        check_query = "SELECT * FROM habits WHERE id = %s"
        cursor.execute(check_query, (habit_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Habit not found")

        update_query = """
        UPDATE habits
        SET habit_name = %s, description = %s
        WHERE id = %s
        """
        cursor.execute(update_query, (habit.habit_name, habit.description, habit_id))
        conn.commit()

        return {
            "success": True,
            "message": "Habit updated successfully"
        }

    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        return {
            "success": False,
            "error": str(e)
        }

    finally:
        cursor.close()
        conn.close()