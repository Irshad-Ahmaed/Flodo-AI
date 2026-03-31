import asyncio
from datetime import date, datetime
from typing import List, Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from ..models import Task
from ..schemas import TaskCreate, TaskUpdate, TaskResponse, TaskStatus


class TaskService:
    def __init__(self, db: AsyncSession):
        self.db = db

    @staticmethod
    def _to_response(task: Task) -> TaskResponse:
        is_blocked = (
            task.blocked_by_id is not None and
            task.blocked_by is not None and
            task.blocked_by.status != "Done"
        )
        blocked_by_title = task.blocked_by.title if task.blocked_by else None

        return TaskResponse(
            id=task.id,
            title=task.title,
            description=task.description or "",
            due_date=task.due_date,
            status=TaskStatus(task.status),
            blocked_by_id=task.blocked_by_id,
            is_blocked=is_blocked,
            blocked_by_title=blocked_by_title,
            created_at=task.created_at,
            updated_at=task.updated_at,
        )

    async def get_tasks(
        self,
        search: Optional[str] = None,
        status: Optional[str] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[TaskResponse]:
        """Get all tasks with optional search and status filtering."""
        query = select(Task).options(selectinload(Task.blocked_by))

        # Apply filters
        if search:
            query = query.where(Task.title.ilike(f"%{search}%"))
        if status:
            query = query.where(Task.status == status)

        query = query.offset(skip).limit(limit)
        result = await self.db.execute(query)
        tasks = result.scalars().all()

        # Convert to response models with computed fields
        return [self._to_response(task) for task in tasks]

    async def get_all_tasks(self) -> List[TaskResponse]:
        """Get all tasks without applying the default pagination cap."""
        query = select(Task).options(selectinload(Task.blocked_by))
        result = await self.db.execute(query)
        tasks = result.scalars().all()
        return [self._to_response(task) for task in tasks]

    async def get_task(self, task_id: int) -> Optional[TaskResponse]:
        """Get a single task by ID."""
        query = select(Task).options(selectinload(Task.blocked_by)).where(Task.id == task_id)
        result = await self.db.execute(query)
        task = result.scalar_one_or_none()

        if not task:
            return None

        return self._to_response(task)

    async def create_task(self, task_data: TaskCreate) -> TaskResponse:
        """Create a new task with validation."""
        # Validate blocked_by_id if provided
        if task_data.blocked_by_id:
            await self._validate_blocked_by(task_data.blocked_by_id, exclude_task_id=None)

        # Simulate 2-second delay for assignment requirement
        await asyncio.sleep(2)

        # Create task
        task = Task(
            title=task_data.title,
            description=task_data.description or "",
            due_date=task_data.due_date,
            status=task_data.status.value,
            blocked_by_id=task_data.blocked_by_id
        )

        self.db.add(task)
        await self.db.commit()
        result = await self.get_task(task.id)
        return result if result is not None else self._to_response(task)

    async def update_task(self, task_id: int, task_data: TaskUpdate) -> Optional[TaskResponse]:
        """Update an existing task with validation."""
        # Get existing task
        query = select(Task).where(Task.id == task_id)
        result = await self.db.execute(query)
        task = result.scalar_one_or_none()

        if not task:
            return None

        # Validate blocked_by_id if provided
        if task_data.blocked_by_id:
            await self._validate_blocked_by(task_data.blocked_by_id, exclude_task_id=task_id)

        # Simulate 2-second delay for assignment requirement
        await asyncio.sleep(2)

        # Update task
        task.title = task_data.title
        task.description = task_data.description or ""
        task.due_date = task_data.due_date
        task.status = task_data.status.value
        task.blocked_by_id = task_data.blocked_by_id

        await self.db.commit()
        # Return response with computed fields
        return await self.get_task(task_id)

    async def delete_task(self, task_id: int) -> bool:
        """Delete a task by ID."""
        query = select(Task).where(Task.id == task_id)
        result = await self.db.execute(query)
        task = result.scalar_one_or_none()

        if not task:
            return False

        await self.db.delete(task)
        await self.db.commit()
        return True

    async def _validate_blocked_by(self, blocked_by_id: int, exclude_task_id: Optional[int] = None):
        """Validate that the blocked_by_id is valid."""
        # Check if blocker task exists
        query = select(Task).where(Task.id == blocked_by_id)
        result = await self.db.execute(query)
        blocker = result.scalar_one_or_none()

        if not blocker:
            raise ValueError(f"Task with id {blocked_by_id} does not exist")

        # Reject self-reference on update.
        if exclude_task_id is not None and blocked_by_id == exclude_task_id:
            raise ValueError("A task cannot be blocked by itself")

        # Check for circular dependencies
        await self._check_circular_dependency(blocked_by_id, exclude_task_id)

    async def _check_circular_dependency(self, blocked_by_id: int, target_task_id: Optional[int] = None):
        """Check if adding a blocking relationship would create a circular dependency."""
        visited = set()
        current = blocked_by_id

        while current is not None:
            if current in visited:
                raise ValueError("This blocking relationship would create a circular dependency")

            visited.add(current)

            # Get the task that blocks current
            query = select(Task).where(Task.id == current)
            result = await self.db.execute(query)
            task = result.scalar_one_or_none()

            if not task or task.blocked_by_id is None:
                break

            # If we reach the target task, we have a cycle
            if task.blocked_by_id == target_task_id:
                raise ValueError("This blocking relationship would create a circular dependency")

            current = task.blocked_by_id
