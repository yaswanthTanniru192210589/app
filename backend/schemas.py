from pydantic import BaseModel, EmailStr

class RegisterRequest(BaseModel):
    name: str
    email: EmailStr
    password: str

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class HabitCreate(BaseModel):
    user_id: int
    habit_name: str
    description: str
    category: str = "Uncategorized"
class HabitLogCreate(BaseModel):
    user_id: int
    habit_id: int
    date: str
    status: int