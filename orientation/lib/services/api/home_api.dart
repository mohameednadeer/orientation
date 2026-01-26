import 'package:dio/dio.dart';
import '../dio_client.dart';
import '../../models/project_model.dart';
import '../../models/developer_model.dart';
import '../../models/area_model.dart';
import '../../utils/cache_manager.dart';
import 'project_api.dart';

class HomeApi {
  final DioClient _dioClient = DioClient();
  final ProjectApi _projectApi = ProjectApi();

  HomeApi() {
    _dioClient.init();
  }

  /// GET /projects/trending?limit= (with caching)
  /// Filters to return only projects where featured: true
  Future<List<ProjectModel>> getFeaturedProjects({bool useCache = true}) async {
    const cacheKey = 'featured_projects';
    
    // Try to get from cache first
    if (useCache) {
      final cached = await CacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        final projects = cached.map((e) => ProjectModel.fromJson(e as Map<String, dynamic>)).toList();
        // Filter to ensure only featured projects are returned
        final featured = projects.where((p) => p.isFeatured).toList();
        print('📦 Cached featured projects: ${featured.length} out of ${projects.length}');
        return featured;
      }
    }
    
    try {
      // Get trending projects (which may include featured projects)
      final response = await _dioClient.dio.get('/projects/trending', queryParameters: {'limit': 50});
      final list = response.data is List ? response.data as List : <dynamic>[];
      var projects = list.map((e) => ProjectModel.fromJson(e as Map<String, dynamic>)).toList();
      
      print('📊 Total projects from API: ${projects.length}');
      print('📊 Projects with featured=true: ${projects.where((p) => p.isFeatured).length}');
      
      // Filter to ensure only featured projects are returned
      projects = projects.where((p) => p.isFeatured).toList();
      
      print('✅ Returning ${projects.length} featured projects');
      
      // Cache the results (cache all projects, filter on retrieval)
      if (useCache && list.isNotEmpty) {
        await CacheManager.set(cacheKey, list, duration: const Duration(minutes: 5));
      }
      
      return projects;
    } on DioException catch (e) {
      print('Error getting featured projects: ${e.message}');
      return [];
    }
  }

  /// GET /projects?sortBy=newest&limit= (with caching)
  Future<List<ProjectModel>> getLatestProjects({bool useCache = true}) async {
    const cacheKey = 'latest_projects';
    
    // Try to get from cache first
    if (useCache) {
      final cached = await CacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        return cached.map((e) => ProjectModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    }
    
    try {
      final response = await _dioClient.dio.get('/projects', queryParameters: {'sortBy': 'newest', 'limit': 10});
      final list = response.data is List ? response.data as List : <dynamic>[];
      final projects = list.map((e) => ProjectModel.fromJson(e as Map<String, dynamic>)).toList();
      
      // Cache the results
      if (useCache && list.isNotEmpty) {
        await CacheManager.set(cacheKey, list, duration: const Duration(minutes: 5));
      }
      
      return projects;
    } on DioException catch (e) {
      print('Error getting latest projects: ${e.message}');
      return [];
    }
  }

  /// Uses ProjectApi.getContinueWatchingProjects (local progress + GET /projects/:id)
  Future<List<ProjectModel>> getContinueWatching() async {
    try {
      return await _projectApi.getContinueWatchingProjects();
    } catch (_) {
      return [];
    }
  }

  /// GET /projects/trending?limit=10 (with caching)
  Future<List<ProjectModel>> getTop10Projects({bool useCache = true}) async {
    const cacheKey = 'top10_projects';
    
    // Try to get from cache first
    if (useCache) {
      final cached = await CacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        return cached.map((e) => ProjectModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    }
    
    try {
      final response = await _dioClient.dio.get('/projects/trending', queryParameters: {'limit': 10});
      final list = response.data is List ? response.data as List : <dynamic>[];
      final projects = list.map((e) => ProjectModel.fromJson(e as Map<String, dynamic>)).toList();
      
      // Cache the results
      if (useCache && list.isNotEmpty) {
        await CacheManager.set(cacheKey, list, duration: const Duration(minutes: 5));
      }
      
      return projects;
    } on DioException catch (e) {
      print('Error getting top 10: ${e.message}');
      return [];
    }
  }

  /// GET /projects?location=&limit= (with caching)
  Future<List<ProjectModel>> getProjectsByArea(String area, {bool useCache = true}) async {
    final cacheKey = 'projects_area_$area';
    
    // Try to get from cache first
    if (useCache) {
      final cached = await CacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        return cached.map((e) => ProjectModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    }
    
    try {
      final response = await _dioClient.dio.get('/projects', queryParameters: {'location': area, 'limit': 10});
      final list = response.data is List ? response.data as List : <dynamic>[];
      final projects = list.map((e) => ProjectModel.fromJson(e as Map<String, dynamic>)).toList();
      
      // Cache the results
      if (useCache && list.isNotEmpty) {
        await CacheManager.set(cacheKey, list, duration: const Duration(minutes: 5));
      }
      
      return projects;
    } on DioException catch (e) {
      print('Error getting projects by area: ${e.message}');
      return [];
    }
  }

  /// GET /projects?status=PLANNING&limit= (for "upcoming") (with caching)
  Future<List<ProjectModel>> getUpcomingProjects({bool useCache = true}) async {
    const cacheKey = 'upcoming_projects';
    
    // Try to get from cache first
    if (useCache) {
      final cached = await CacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        return cached.map((e) => ProjectModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    }
    
    try {
      final response = await _dioClient.dio.get('/projects', queryParameters: {'status': 'PLANNING', 'limit': 10});
      final list = response.data is List ? response.data as List : <dynamic>[];
      final projects = list.map((e) => ProjectModel.fromJson(e as Map<String, dynamic>)).toList();
      
      // Cache the results
      if (useCache && list.isNotEmpty) {
        await CacheManager.set(cacheKey, list, duration: const Duration(minutes: 5));
      }
      
      return projects;
    } on DioException catch (e) {
      print('Error getting upcoming: ${e.message}');
      return [];
    }
  }

  /// GET /projects?limit= (backend has no category; use limit). “Upcoming” → status=PLANNING.
  Future<List<ProjectModel>> getProjectsByCategory(String category) async {
    try {
      final q = <String, dynamic>{'limit': 50};
      if (category == 'Upcoming') q['status'] = 'PLANNING';
      final response = await _dioClient.dio.get('/projects', queryParameters: q);
      final list = response.data is List ? response.data as List : <dynamic>[];
      return list.map((e) => ProjectModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// GET /developer — requires ADMIN/SUPERADMIN; may 403 for normal users.
  Future<List<DeveloperModel>> getDevelopers() async {
    try {
      final response = await _dioClient.dio.get('/developer');
      final list = response.data is List ? response.data as List : <dynamic>[];
      return list.map((e) => DeveloperModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      print('Error getting developers: ${e.message}');
      return [];
    }
  }

  /// No /areas in backend; return empty.
  Future<List<AreaModel>> getAreas() async {
    return [];
  }

  String _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet connection.';
      case DioExceptionType.connectionError:
        return 'Unable to connect to server.';
      case DioExceptionType.badResponse:
        return e.response?.data?['message'] ?? 'An error occurred. Please try again.';
      default:
        return 'An unexpected error occurred.';
    }
  }
}
