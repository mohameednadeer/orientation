import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../dio_client.dart';
import '../../models/project_model.dart';
import '../../models/episode_model.dart';
import '../../models/clip_model.dart';
import '../../models/pdf_file_model.dart';

class ProjectApi {
  final DioClient _dioClient = DioClient();

  ProjectApi() {
    _dioClient.init();
  }

  /// GET /projects/:id
  Future<ProjectModel?> getProjectById(String id) async {
    try {
      final response = await _dioClient.dio.get('/projects/$id');
      return ProjectModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// GET /episode, then filter by projectId
  Future<List<EpisodeModel>> getEpisodes(String projectId) async {
    try {
      final response = await _dioClient.dio.get('/episode');
      final list = response.data is List ? response.data as List : <dynamic>[];
      final out = <EpisodeModel>[];
      for (final e in list) {
        final m = e as Map<String, dynamic>?;
        if (m == null) continue;
        final pid = _resolveId(m['projectId']);
        if (pid == projectId) out.add(EpisodeModel.fromJson(m));
      }
      out.sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
      return out;
    } on DioException catch (_) {
      return [];
    }
  }

  String? _resolveId(dynamic v) {
    if (v == null) return null;
    if (v is Map) return v['_id']?.toString() ?? v['id']?.toString();
    return v.toString();
  }

  /// Uses local cache (updated on save/unsave). PATCH /projects/:id/save-project does not return savedProjects.
  Future<bool> isProjectSaved(String projectId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('saved_projects') ?? [];
    return ids.contains(projectId);
  }

  /// PATCH /projects/:id/save-project — no body. On success, add to local cache.
  Future<void> saveProject(String projectId) async {
    await _dioClient.dio.patch('/projects/$projectId/save-project');
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('saved_projects') ?? [];
    if (!ids.contains(projectId)) {
      ids.add(projectId);
      await prefs.setStringList('saved_projects', ids);
    }
  }

  /// PATCH /projects/:id/unsave-project — no body. On success, remove from local cache.
  Future<void> unsaveProject(String projectId) async {
    await _dioClient.dio.patch('/projects/$projectId/unsave-project');
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('saved_projects') ?? [];
    ids.remove(projectId);
    await prefs.setStringList('saved_projects', ids);
  }

  /// Uses local cache of saved ids; fetches each project via GET /projects/:id
  Future<List<ProjectModel>> getSavedProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('saved_projects') ?? [];
    final out = <ProjectModel>[];
    for (final id in ids) {
      final p = await getProjectById(id);
      if (p != null) out.add(p);
    }
    return out;
  }

  /// Progress stored locally; no backend. GET /projects/:id increments view on each fetch.
  Future<void> trackWatching(String projectId, String episodeId, double progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('watch_progress_${projectId}_$episodeId', progress);
  }

  Future<double> getWatchingProgress(String projectId, String episodeId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('watch_progress_${projectId}_$episodeId') ?? 0.0;
  }

  /// Continue watching from local progress; fetches projects via GET /projects/:id
  Future<List<ProjectModel>> getContinueWatchingProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('watch_progress_'));
    final Map<String, double> byProject = {};
    for (final k in keys) {
      final rest = k.replaceFirst('watch_progress_', '');
      final i = rest.lastIndexOf('_');
      if (i <= 0 || i >= rest.length - 1) continue;
      final pid = rest.substring(0, i);
      final prog = prefs.getDouble(k) ?? 0.0;
      if (prog > 0 && prog < 0.95) {
        if (!byProject.containsKey(pid) || (byProject[pid] ?? 0) < prog) {
          byProject[pid] = prog;
        }
      }
    }
    final out = <ProjectModel>[];
    for (final e in byProject.entries) {
      final p = await getProjectById(e.key);
      if (p != null) out.add(p.copyWith(watchProgress: e.value));
    }
    out.sort((a, b) => (b.watchProgress ?? 0).compareTo(a.watchProgress ?? 0));
    return out;
  }

  /// GET /reels, filter by projectId, map to ClipModel (reels used as clips)
  Future<List<ClipModel>> getClipsByProject(String projectId) async {
    try {
      final response = await _dioClient.dio.get('/reels');
      final list = response.data is List ? response.data as List : <dynamic>[];
      return list
          .map((e) => e as Map<String, dynamic>)
          .where((m) => _resolveId(m['projectId']) == projectId)
          .map(ClipModel.fromJson)
          .toList();
    } on DioException catch (_) {
      return [];
    }
  }

  /// GET /reels
  Future<List<ClipModel>> getAllClips() async {
    try {
      final response = await _dioClient.dio.get('/reels');
      final list = response.data is List ? response.data as List : <dynamic>[];
      return list.map((e) => ClipModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (_) {
      return [];
    }
  }

  /// POST /reels/:id/save — Save a reel to user's saved reels
  Future<bool> saveReel(String reelId) async {
    try {
      await _dioClient.dio.post('/reels/$reelId/save');
      return true;
    } on DioException catch (_) {
      return false;
    }
  }

  /// POST /reels/:id/unsave — Remove a reel from user's saved reels
  Future<bool> unsaveReel(String reelId) async {
    try {
      await _dioClient.dio.post('/reels/$reelId/unsave');
      return true;
    } on DioException catch (_) {
      return false;
    }
  }

  /// GET /reels/saved — Get all reels saved by the current user
  Future<List<ClipModel>> getSavedReels() async {
    try {
      final response = await _dioClient.dio.get('/reels/saved');
      final list = response.data is List ? response.data as List : <dynamic>[];
      return list.map((e) => ClipModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (_) {
      return [];
    }
  }

  /// Backend reels have no like; always false.
  Future<bool> isClipLiked(String clipId) async => false;

  /// No backend for reel like; no-op.
  Future<void> likeClip(String clipId) async {}

  /// No backend for reel like; no-op.
  Future<void> unlikeClip(String clipId) async {}

  /// POST /reels — multipart: title, description?, projectId?, file (video), thumbnail (required by backend).
  /// thumbnailPath optional; if null, backend may 400.
  Future<bool> addReel({
    required String title,
    required String description,
    required String? videoPath,
    required String? projectId,
    required bool hasWhatsApp,
    String? developerId,
    String? developerName,
    String? developerLogo,
    String? thumbnailPath,
  }) async {
    if (videoPath == null || videoPath.isEmpty) return false;
    try {
      final form = <String, dynamic>{
        'title': title,
        'description': description,
        if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
        'file': await MultipartFile.fromFile(videoPath),
      };
      if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
        form['thumbnail'] = await MultipartFile.fromFile(thumbnailPath);
      }
      final res = await _dioClient.dio.post('/reels', data: FormData.fromMap(form));
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// GET /projects?developerId=
  Future<List<ProjectModel>> getDeveloperProjects(String developerId) async {
    try {
      final response = await _dioClient.dio.get('/projects', queryParameters: {'developerId': developerId});
      final list = response.data is List ? response.data as List : <dynamic>[];
      return list.map((e) => ProjectModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (_) {
      return [];
    }
  }

  /// GET /projects with optional limit and excludeId (client-side filter)
  Future<List<ProjectModel>> getProjects({int limit = 20, String? excludeId}) async {
    try {
      final response = await _dioClient.dio.get('/projects', queryParameters: {'limit': limit});
      final list = response.data is List ? response.data as List : <dynamic>[];
      var items = list.map((e) => ProjectModel.fromJson(e as Map<String, dynamic>)).toList();
      if (excludeId != null) items = items.where((p) => p.id != excludeId).toList();
      return items;
    } on DioException catch (_) {
      return [];
    }
  }

  /// GET /projects?location= — for “projects by area”
  Future<List<ProjectModel>> getProjectsByArea(String location) async {
    try {
      final response = await _dioClient.dio.get('/projects', queryParameters: {'location': location, 'limit': 20});
      final list = response.data is List ? response.data as List : <dynamic>[];
      return list.map((e) => ProjectModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (_) {
      return [];
    }
  }

  /// No direct “set inventory URL” in backend; /files/upload/inventory requires a file. No-op.
  Future<bool> updateInventory(String projectId, String inventoryUrl) async => false;

  /// POST /files/upload/inventory — multipart: projectId, title, inventory (file). Backend requires title. Requires ADMIN.
  Future<bool> uploadInventoryFile(String projectId, String filePath, {String? title}) async {
    try {
      final form = FormData.fromMap({
        'projectId': projectId,
        'title': title?.trim().isNotEmpty == true ? title!.trim() : 'Inventory',
        'inventory': await MultipartFile.fromFile(filePath),
      });
      final res = await _dioClient.dio.post('/files/upload/inventory', data: form);
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// GET /files/get/inventory (auth) — returns { message, inventories }. Filter by projectId.
  /// Inventory has project (not projectId) and inventoryUrl (not fileUrl).
  Future<String?> getInventoryUrl(String projectId) async {
    try {
      final response = await _dioClient.dio.get('/files/get/inventory');
      final data = response.data as Map<String, dynamic>?;
      final list = (data?['inventories'] as List?) ?? <dynamic>[];
      for (final e in list) {
        final m = e as Map<String, dynamic>?;
        if (m == null) continue;
        final pid = _resolveId(m['project']) ?? _resolveId(m['projectId']);
        if (pid == projectId) {
          final url = m['inventoryUrl']?.toString() ?? m['fileUrl']?.toString();
          if (url != null && url.isNotEmpty) return url;
        }
      }
      return null;
    } on DioException catch (_) {
      return null;
    }
  }

  /// GET /files/get/pdf (auth) — returns { message, pdfs }. Filter by projectId.
  /// File has project (not projectId) and pdfUrl (not fileUrl).
  Future<List<PdfFileModel>> getPdfFiles(String projectId) async {
    try {
      final response = await _dioClient.dio.get('/files/get/pdf');
      final data = response.data as Map<String, dynamic>?;
      final list = (data?['pdfs'] as List?) ?? <dynamic>[];
      return list
          .map((e) => e as Map<String, dynamic>)
          .where((m) => (_resolveId(m['project']) ?? _resolveId(m['projectId'])) == projectId)
          .map(PdfFileModel.fromJson)
          .toList();
    } on DioException catch (_) {
      return [];
    }
  }

  /// PATCH /files/update/inventory/:id — Update an inventory file
  Future<bool> updateInventoryFile(String inventoryId, {String? title, String? filePath}) async {
    try {
      final form = <String, dynamic>{};
      if (title != null && title.isNotEmpty) {
        form['title'] = title;
      }
      if (filePath != null && filePath.isNotEmpty) {
        form['inventory'] = await MultipartFile.fromFile(filePath);
      }
      final res = await _dioClient.dio.patch('/files/update/inventory/$inventoryId', data: FormData.fromMap(form));
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// PATCH /files/update/pdf/:id — Update a PDF file
  Future<bool> updatePdfFile(String pdfId, {String? title, String? filePath}) async {
    try {
      final form = <String, dynamic>{};
      if (title != null && title.isNotEmpty) {
        form['title'] = title;
      }
      if (filePath != null && filePath.isNotEmpty) {
        form['PDF'] = await MultipartFile.fromFile(filePath);
      }
      final res = await _dioClient.dio.patch('/files/update/pdf/$pdfId', data: FormData.fromMap(form));
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// DELETE /files/delete/inventory/:id — Delete an inventory file
  Future<bool> deleteInventoryFile(String inventoryId) async {
    try {
      final res = await _dioClient.dio.delete('/files/delete/inventory/$inventoryId');
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// DELETE /files/delete/pdf/:id — Delete a PDF file
  Future<bool> deletePdfFile(String pdfId) async {
    try {
      final res = await _dioClient.dio.delete('/files/delete/pdf/$pdfId');
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }
}
