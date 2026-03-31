import pytest
from datetime import date
from httpx import AsyncClient
from fastapi import FastAPI
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.ext.asyncio import async_sessionmaker
from sqlalchemy.pool import StaticPool

from app.main import app
from app.database import Base
from app.routers.tasks import get_db
from app.models import Task
from app.schemas import TaskStatus


# Test database setup
TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"

@pytest.fixture
async def db_engine():
    """Create an in-memory SQLite database for testing."""
    engine = create_async_engine(
        TEST_DATABASE_URL,
        echo=False,
        future=True,
        poolclass=StaticPool,
        connect_args={"check_same_thread": False},
    )
    
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    yield engine
    
    await engine.dispose()


@pytest.fixture
async def test_session(db_engine):
    """Create a test session."""
    async_session_maker = async_sessionmaker(
        bind=db_engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    
    async with async_session_maker() as session:
        yield session
        await session.rollback()


@pytest.fixture
def override_get_db(test_session):
    """Override get_db dependency."""
    async def _override_get_db():
        yield test_session
    
    return _override_get_db


@pytest.fixture
async def client(override_get_db, test_session):
    """Create a test client with overridden dependencies."""
    app.dependency_overrides[get_db] = override_get_db
    
    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac
    
    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_create_task_returns_expected_shape(client, test_session):
    """Test creating a task returns correct response shape with computed fields."""
    response = await client.post(
        "/api/v1/tasks/",
        json={
            "title": "Test Task",
            "description": "A test task",
            "due_date": "2026-12-31",
            "status": "To-Do",
            "blocked_by_id": None
        }
    )
    
    assert response.status_code == 201
    data = response.json()
    
    # Check response shape
    assert "id" in data
    assert data["title"] == "Test Task"
    assert data["description"] == "A test task"
    assert data["due_date"] == "2026-12-31"
    assert data["status"] == "To-Do"
    assert "is_blocked" in data
    assert data["is_blocked"] is False
    assert "blocked_by_title" in data
    assert "created_at" in data
    assert "updated_at" in data


@pytest.mark.asyncio
async def test_create_blocked_task_returns_blocker_metadata(client, test_session):
    """Test creating a blocked task includes blocker metadata."""
    # First, create a blocker task
    blocker_response = await client.post(
        "/api/v1/tasks/",
        json={
            "title": "Blocker Task",
            "description": "",
            "due_date": "2026-12-31",
            "status": "To-Do"
        }
    )
    blocker_id = blocker_response.json()["id"]
    
    # Create a task blocked by the first one
    response = await client.post(
        "/api/v1/tasks/",
        json={
            "title": "Blocked Task",
            "description": "",
            "due_date": "2026-12-31",
            "status": "To-Do",
            "blocked_by_id": blocker_id
        }
    )
    
    assert response.status_code == 201
    data = response.json()
    
    assert data["is_blocked"] is True
    assert data["blocked_by_title"] == "Blocker Task"
    assert data["blocked_by_id"] == blocker_id


@pytest.mark.asyncio
async def test_get_tasks_supports_search_and_status_filter(client):
    """Test getting tasks with search and status filtering."""
    # Create multiple tasks
    await client.post(
        "/api/v1/tasks/",
        json={
            "title": "Buy Groceries",
            "description": "",
            "due_date": "2026-12-31",
            "status": "To-Do"
        }
    )
    
    await client.post(
        "/api/v1/tasks/",
        json={
            "title": "Write Report",
            "description": "",
            "due_date": "2026-12-31",
            "status": "In Progress"
        }
    )
    
    await client.post(
        "/api/v1/tasks/",
        json={
            "title": "Fix Bug",
            "description": "",
            "due_date": "2026-12-31",
            "status": "Done"
        }
    )
    
    # Test search
    response = await client.get("/api/v1/tasks/?search=Buy")
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["title"] == "Buy Groceries"
    
    # Test status filter
    response = await client.get("/api/v1/tasks/?status=In Progress")
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["status"] == "In Progress"


@pytest.mark.asyncio
async def test_all_tasks_endpoint_ignores_main_list_filters(client):
    """Test /tasks/all ignores search and status filters."""
    # Create tasks
    for i in range(3):
        await client.post(
            "/api/v1/tasks/",
            json={
                "title": f"Task {i}",
                "description": "",
                "due_date": "2026-12-31",
                "status": "To-Do"
            }
        )
    
    # Get filtered tasks
    response = await client.get("/api/v1/tasks/?search=Task 1&status=Done")
    assert response.status_code == 200
    assert len(response.json()) == 0
    
    # Get all tasks (should return all 3)
    response = await client.get("/api/v1/tasks/all")
    assert response.status_code == 200
    assert len(response.json()) == 3


@pytest.mark.asyncio
async def test_update_missing_task_returns_404(client):
    """Test updating a non-existent task returns 404."""
    response = await client.put(
        "/api/v1/tasks/999",
        json={
            "title": "Updated Task",
            "description": "",
            "due_date": "2026-12-31",
            "status": "To-Do"
        }
    )
    
    assert response.status_code == 404
    assert "Task not found" in response.json()["detail"]


@pytest.mark.asyncio
async def test_delete_returns_204_and_clears_dependencies(client):
    """Test delete returns 204 and clears blocking dependencies."""
    # Create blocker
    blocker_response = await client.post(
        "/api/v1/tasks/",
        json={
            "title": "Blocker",
            "description": "",
            "due_date": "2026-12-31",
            "status": "To-Do"
        }
    )
    blocker_id = blocker_response.json()["id"]
    
    # Create blocked task
    blocked_response = await client.post(
        "/api/v1/tasks/",
        json={
            "title": "Blocked",
            "description": "",
            "due_date": "2026-12-31",
            "status": "To-Do",
            "blocked_by_id": blocker_id
        }
    )
    
    # Delete blocker
    response = await client.delete(f"/api/v1/tasks/{blocker_id}")
    assert response.status_code == 204
    
    # Verify blocked task is no longer blocked
    get_response = await client.get(f"/api/v1/tasks/{blocked_response.json()['id']}")
    assert get_response.status_code == 200
    assert get_response.json()["is_blocked"] is False


@pytest.mark.asyncio
async def test_circular_dependency_returns_409(client):
    """Test creating circular dependency returns 409."""
    # Create task A
    task_a = await client.post(
        "/api/v1/tasks/",
        json={
            "title": "Task A",
            "description": "",
            "due_date": "2026-12-31",
            "status": "To-Do"
        }
    )
    task_a_id = task_a.json()["id"]
    
    # Create task B blocked by A
    task_b = await client.post(
        "/api/v1/tasks/",
        json={
            "title": "Task B",
            "description": "",
            "due_date": "2026-12-31",
            "status": "To-Do",
            "blocked_by_id": task_a_id
        }
    )
    task_b_id = task_b.json()["id"]
    
    # Try to make A blocked by B (creates cycle)
    response = await client.put(
        f"/api/v1/tasks/{task_a_id}",
        json={
            "title": "Task A",
            "description": "",
            "due_date": "2026-12-31",
            "status": "To-Do",
            "blocked_by_id": task_b_id
        }
    )
    
    assert response.status_code == 409
    assert "circular dependency" in response.json()["detail"].lower()


@pytest.mark.asyncio
async def test_self_blocking_update_returns_409(client):
    task_response = await client.post(
        "/api/v1/tasks/",
        json={
            "title": "Self Block Test",
            "description": "",
            "due_date": "2026-12-31",
            "status": "To-Do",
        },
    )
    task_id = task_response.json()["id"]

    response = await client.put(
        f"/api/v1/tasks/{task_id}",
        json={
            "title": "Self Block Test",
            "description": "",
            "due_date": "2026-12-31",
            "status": "To-Do",
            "blocked_by_id": task_id,
        },
    )

    assert response.status_code == 409
    assert "cannot be blocked by itself" in response.json()["detail"].lower()
