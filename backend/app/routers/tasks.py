import logging
from collections.abc import AsyncGenerator
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from ..database import async_session
from ..services.task_service import TaskService
from ..schemas import TaskCreate, TaskUpdate, TaskResponse, TaskStatus

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/tasks", tags=["tasks"])


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Dependency to get database session."""
    async with async_session() as session:
        yield session


@router.get("/", response_model=List[TaskResponse])
async def get_tasks(
    search: Optional[str] = Query(None, description="Search tasks by title"),
    status: Optional[TaskStatus] = Query(None, description="Filter by status"),
    db: AsyncSession = Depends(get_db)
):
    """Get all tasks with optional search and status filtering."""
    service = TaskService(db)
    return await service.get_tasks(search=search, status=status.value if status else None)


@router.get("/all", response_model=List[TaskResponse])
async def get_all_tasks(db: AsyncSession = Depends(get_db)):
    """Get all tasks without filtering (for blocker dropdown options)."""
    service = TaskService(db)
    return await service.get_all_tasks()


@router.get("/{task_id}", response_model=TaskResponse)
async def get_task(task_id: int, db: AsyncSession = Depends(get_db)):
    """Get a single task by ID."""
    service = TaskService(db)
    task = await service.get_task(task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    return task


@router.post("/", response_model=TaskResponse, status_code=201)
async def create_task(task: TaskCreate, db: AsyncSession = Depends(get_db)):
    """Create a new task."""
    service = TaskService(db)
    try:
        return await service.create_task(task)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except HTTPException:
        raise
    except Exception:
        logger.exception("Unhandled error while creating task")
        raise HTTPException(status_code=500, detail="Internal server error")


@router.put("/{task_id}", response_model=TaskResponse)
async def update_task(task_id: int, task: TaskUpdate, db: AsyncSession = Depends(get_db)):
    """Update an existing task."""
    service = TaskService(db)
    try:
        updated_task = await service.update_task(task_id, task)
        if not updated_task:
            raise HTTPException(status_code=404, detail="Task not found")
        return updated_task
    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(status_code=409, detail=str(e))  # 409 for dependency conflicts
    except Exception:
        logger.exception("Unhandled error while updating task")
        raise HTTPException(status_code=500, detail="Internal server error")


@router.delete("/{task_id}", status_code=204)
async def delete_task(task_id: int, db: AsyncSession = Depends(get_db)):
    """Delete a task by ID."""
    service = TaskService(db)
    deleted = await service.delete_task(task_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Task not found")
