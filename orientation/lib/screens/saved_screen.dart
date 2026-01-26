import 'package:flutter/material.dart';
import '../models/project_model.dart';
import '../services/api/project_api.dart';
import '../utils/auth_helper.dart';
import 'project_details_screen.dart';
import 'login_screen.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  final ProjectApi _projectApi = ProjectApi();
  List<ProjectModel> _savedProjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedProjects();
  }

  Future<void> _loadSavedProjects() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final projects = await _projectApi.getSavedProjects();
      if (mounted) {
        setState(() {
          _savedProjects = projects;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeFromSaved(ProjectModel project) async {
    final isAuth = await AuthHelper.requireAuth(context);
    if (!isAuth) return;
    
    // Optimistic update
    setState(() {
      _savedProjects.removeWhere((p) => p.id == project.id);
    });

    try {
      await _projectApi.unsaveProject(project.id);
      _showSnackBar('Removed from saved');
    } catch (e) {
      // Revert on error
      _loadSavedProjects();
      _showSnackBar('Error removing project', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            _buildAppBar(context),
            // List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFE50914),
                      ),
                    )
                  : _savedProjects.isEmpty
                      ? _buildEmptyState()
                      : _buildSavedList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.chevron_left,
              color: Colors.white,
              size: 28,
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Saved',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 28),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_outline,
            color: Colors.white.withOpacity(0.3),
            size: 80,
          ),
          const SizedBox(height: 24),
          Text(
            'No Saved Projects',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Projects you save will appear here for easy access',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedList() {
    return RefreshIndicator(
      onRefresh: _loadSavedProjects,
      color: const Color(0xFFE50914),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _savedProjects.length,
        itemBuilder: (context, index) {
          final project = _savedProjects[index];
          return _SavedProjectItem(
            project: project,
            onTap: () async {
              final isAuth = await AuthHelper.requireAuth(context);
              if (!isAuth) return;
              
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProjectDetailsScreen(
                    projectId: project.id,
                  ),
                ),
              ).then((_) => _loadSavedProjects()); // Refresh on return
            },
            onRemove: () => _removeFromSaved(project),
          );
        },
      ),
    );
  }
}

class _SavedProjectItem extends StatelessWidget {
  final ProjectModel project;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const _SavedProjectItem({
    required this.project,
    this.onTap,
    this.onRemove,
  });

  List<Color> _parseGradientColors() {
    try {
      return project.gradientColors.map((colorStr) {
        final hexColor = colorStr.replaceAll('0x', '').replaceAll('#', '');
        return Color(int.parse(hexColor, radix: 16));
      }).toList();
    } catch (e) {
      return [const Color(0xFF4A90A4), const Color(0xFF2d6a7a)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = _parseGradientColors();

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: project.image.isNotEmpty
                    ? (project.isAsset
                        ? Image.asset(
                            project.image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholder(),
                          )
                        : Image.network(
                            project.image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholder(),
                          ))
                    : _buildPlaceholder(),
              ),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.developerName.isNotEmpty 
                        ? project.developerName 
                        : project.area,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    project.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (project.location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      project.location,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Watch button
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Watch',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Remove button
            IconButton(
              icon: const Icon(
                Icons.favorite,
                color: Color(0xFFE50914),
                size: 24,
              ),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Text(
        project.title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
