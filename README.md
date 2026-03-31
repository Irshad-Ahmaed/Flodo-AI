# Flodo Task Management App

A full-stack task management app built for the Flodo Flutter assignment.

## Track And Stretch Goal
- Track: A — Full-Stack Builder
- Stretch Goal: 1 — Debounced Autocomplete Search

## Features Implemented
- Create, read, update, and delete tasks
- Task fields:
  - Title
  - Description
  - Due Date
  - Status (`To-Do`, `In Progress`, `Done`)
  - Optional `Blocked By`
- Search tasks by title
- Filter tasks by status
- Blocked tasks are shown with distinct styling until the blocker is marked `Done`
- Draft persistence for the create-task form
- 2-second backend delay on task create and update
- Disabled/loading save button during create and update
- Debounced search with matching title text highlight

## Project Structure
```text
backend/
  app/
  tests/

frontend/
  lib/
```

## Backend Setup
1. Open a terminal in `backend`.
2. Create and activate a virtual environment.
3. Install dependencies:

```bash
pip install -r requirements.txt
```

4. Start the API:

```bash
uvicorn app.main:app --reload
```

Backend runs on:

```text
http://127.0.0.1:8000
```

API docs:

```text
http://127.0.0.1:8000/docs
```

## Frontend Setup
1. Open a terminal in `frontend`.
2. Install Flutter packages:

```bash
flutter pub get
```

3. If platform folders are missing, generate them:

```bash
flutter create .
```

4. Run the app.

For Chrome:

```bash
flutter run -d chrome
```

For Windows:

```bash
flutter run -d windows
```

Note:
- Windows desktop builds require Developer Mode enabled because Flutter plugins use symlinks.

## API Base URL Notes
The frontend chooses the API base URL by platform:
- Android emulator: `http://10.0.2.2:8000/api/v1`
- iOS simulator / web / desktop: `http://127.0.0.1:8000/api/v1`

Make sure the backend is running before launching the frontend.

## How To Use
- Create tasks from the main screen
- Tap a task to edit it
- Swipe a task to delete it
- Use the search field to search by title
- Use the status chips to filter by status
- Create a blocked task by selecting another task in `Blocked By`

## Technical Decision
One technical decision I’m proud of is keeping blocked-task state computed on the backend instead of storing a separate flag. This keeps the UI simple and ensures the blocked styling always reflects the latest blocker status.

## AI Usage Report
AI tools were used to accelerate development, debugging, and code review.

Helpful uses:
- refining the implementation plan
- reviewing backend API behavior and tests
- identifying edge cases around blocking logic, API responses, and frontend/backend integration
- helping structure the Flutter frontend around the assignment requirements

Example of bad AI output and fix:
- One generated backend validation version allowed a task to indirectly block itself because the self-reference check was written incorrectly.
- I fixed it by correcting the validation logic and adding an API regression test to cover self-blocking updates.
