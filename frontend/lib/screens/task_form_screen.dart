import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../models/task.dart';
import '../models/task_draft.dart';
import '../models/task_status.dart';
import '../providers/draft_provider.dart';
import '../providers/task_provider.dart';

class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({super.key, this.task});

  final Task? task;

  bool get isEditing => task != null;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  DateTime? _dueDate;
  TaskStatus _status = TaskStatus.todo;
  int? _blockedById;
  bool _isSaving = false;
  bool _isLoadingDraft = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.task?.description ?? '');
    _dueDate = widget.task?.dueDate;
    _status = widget.task?.status ?? TaskStatus.todo;
    _blockedById = widget.task?.blockedById;

    _titleController.addListener(_persistDraftSafely);
    _descriptionController.addListener(_persistDraftSafely);

    if (!widget.isEditing) {
      unawaited(_loadDraft());
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_persistDraftSafely);
    _descriptionController.removeListener(_persistDraftSafely);
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    setState(() => _isLoadingDraft = true);
    final store = await ref.read(draftStoreProvider.future);
    final draft = await store.loadCreateDraft();

    if (!mounted) {
      return;
    }

    if (draft != null) {
      _titleController.text = draft.title;
      _descriptionController.text = draft.description;
      _dueDate = draft.dueDate;
      _status = draft.status;
      _blockedById = draft.blockedById;
    }

    setState(() => _isLoadingDraft = false);
  }

  void _persistDraftSafely() {
    if (widget.isEditing || _isLoadingDraft) {
      return;
    }
    unawaited(_persistDraft());
  }

  Future<void> _persistDraft() async {
    final store = await ref.read(draftStoreProvider.future);
    await store.saveCreateDraft(
      TaskDraft(
        title: _titleController.text,
        description: _descriptionController.text,
        dueDate: _dueDate,
        status: _status,
        blockedById: _blockedById,
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) {
      return;
    }

    setState(() => _dueDate = picked);
    _persistDraftSafely();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showMessage('Title is required.');
      return;
    }
    if (_dueDate == null) {
      _showMessage('Please choose a due date.');
      return;
    }

    setState(() => _isSaving = true);

    final repository = ref.read(taskRepositoryProvider);
    final payload = Task(
      id: widget.task?.id ?? 0,
      title: title,
      description: _descriptionController.text.trim(),
      dueDate: _dueDate!,
      status: _status,
      blockedById: _blockedById,
      isBlocked: widget.task?.isBlocked ?? false,
      blockedByTitle: widget.task?.blockedByTitle,
      createdAt: widget.task?.createdAt,
      updatedAt: widget.task?.updatedAt,
    );

    try {
      if (widget.isEditing) {
        await repository.updateTask(payload);
      } else {
        await repository.createTask(payload);
        final store = await ref.read(draftStoreProvider.future);
        await store.clearCreateDraft();
      }

      ref.invalidate(tasksProvider);
      ref.invalidate(taskOptionsProvider);

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on AppApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final optionsAsync = ref.watch(taskOptionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Task' : 'Create Task'),
      ),
      body: optionsAsync.when(
        data: (options) {
          final selectableTasks = options
              .where((task) => task.id != widget.task?.id)
              .toList()
            ..sort((a, b) => a.title.compareTo(b.title));

          final currentBlockedId =
              selectableTasks.any((task) => task.id == _blockedById)
                  ? _blockedById
                  : null;

          if (_blockedById != currentBlockedId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() => _blockedById = currentBlockedId);
              }
            });
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'What needs to be done?',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Add a short description',
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: const Text('Due date'),
                subtitle: Text(
                  _dueDate == null
                      ? 'Choose a date'
                      : DateFormat('MMM d, yyyy').format(_dueDate!),
                ),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _pickDueDate,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TaskStatus>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: TaskStatus.values
                    .map(
                      (status) => DropdownMenuItem<TaskStatus>(
                        value: status,
                        child: Text(status.label),
                      ),
                    )
                    .toList(),
                onChanged: _isSaving
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() => _status = value);
                        _persistDraftSafely();
                      },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                initialValue: currentBlockedId,
                decoration: const InputDecoration(labelText: 'Blocked by'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('None'),
                  ),
                  ...selectableTasks.map(
                    (task) => DropdownMenuItem<int?>(
                      value: task.id,
                      child: Text(task.title),
                    ),
                  ),
                ],
                onChanged: _isSaving
                    ? null
                    : (value) {
                        setState(() => _blockedById = value);
                        _persistDraftSafely();
                      },
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.isEditing ? 'Save Changes' : 'Create Task'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load task options.\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
