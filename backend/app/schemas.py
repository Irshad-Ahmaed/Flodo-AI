from datetime import date, datetime
from typing import Optional
from pydantic import BaseModel, field_validator, ConfigDict
from enum import Enum


class TaskStatus(str, Enum):
    TODO = "To-Do"
    IN_PROGRESS = "In Progress"
    DONE = "Done"


class TaskBase(BaseModel):
    title: str
    description: Optional[str] = ""
    due_date: date
    status: TaskStatus
    blocked_by_id: Optional[int] = None

    @field_validator('title')
    @classmethod
    def title_must_not_be_empty(cls, v):
        if not v or not v.strip():
            raise ValueError('Title must not be empty')
        return v.strip()

    @field_validator('description')
    @classmethod
    def description_defaults_to_empty(cls, v):
        return v or ""

    model_config = ConfigDict(from_attributes=True)


class TaskCreate(TaskBase):
    pass


class TaskUpdate(TaskBase):
    pass


class TaskResponse(TaskBase):
    id: int
    is_blocked: bool
    blocked_by_title: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
