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
I used ChatGPT during the assignment to speed up planning, implementation review, debugging, and cleanup.

Most useful ways ChatGPT helped:
- breaking the assignment into a practical implementation plan before coding
- keeping the scope aligned to exactly what the assignment asked for: core requirements + Track A + one stretch goal
- reviewing backend API behavior, validation, and tests
- identifying edge cases around blocked tasks, dependency handling, and API response shape
- helping structure the Flutter frontend around the backend contract
- checking submission readiness such as README content, ignored files, and cleanup

Useful pattern for completing the assignment with ChatGPT:
- start by converting the assignment into a clear build plan
- choose the track and only one stretch goal early
- implement backend and frontend in small verified steps
- use ChatGPT for code review after each major piece, not only for code generation
- use it to check edge cases, requirement coverage, and missing tests before submission

Example of bad AI output and fix:
- One generated backend validation version allowed a task to block itself because the self-reference check was written incorrectly.
- I fixed it by correcting the validation logic and adding an API regression test to cover self-blocking updates.
