import 'package:ladder_social_core/src/models/paged_result.dart';
import 'package:ladder_social_core/src/tasks/task_api_service.dart';
import 'package:ladder_social_core/src/tasks/task_models.dart';

final class TaskRepository {
  const TaskRepository(this._api);
  final TaskApiService _api;

  Future<PagedResult<TaskListItem>> getTasks(TaskQuery query) =>
      _api.getTasks(query);
  Future<TaskDetail> getTask(String id) => _api.getTask(id);
  Future<CompletionDateOptions> getCompletionDateOptions(String id) =>
      _api.getCompletionDateOptions(id);
  Future<TaskDetail> createTask(TaskDraft draft) => _api.createTask(draft);
  Future<TaskDetail> updateTask(String id, TaskDraft draft) =>
      _api.updateTask(id, draft);
  Future<void> deleteTask(String id) => _api.deleteTask(id);
  Future<TaskCompletionItem> completeTask({
    required String taskId,
    required DateTime occurrenceDate,
    String? note,
    String? caption,
    ImageUpload? proof,
  }) =>
      _api.completeTask(
        taskId: taskId,
        occurrenceDate: occurrenceDate,
        note: note,
        caption: caption,
        proof: proof,
      );
  Future<PagedResult<TaskCompletionItem>> getCompletions(
    String taskId, {
    int page = 1,
    int pageSize = 20,
  }) =>
      _api.getCompletions(taskId, page: page, pageSize: pageSize);
}
