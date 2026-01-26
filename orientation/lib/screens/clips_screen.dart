import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../models/clip_model.dart';
import '../services/api/project_api.dart';
import '../utils/auth_helper.dart';
import '../widgets/skeleton_loader.dart';
import 'project_details_screen.dart';

class ClipsScreen extends StatefulWidget {
  const ClipsScreen({super.key});

  @override
  State<ClipsScreen> createState() => ClipsScreenState();
}

class ClipsScreenState extends State<ClipsScreen> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final ProjectApi _projectApi = ProjectApi();
  
  List<ClipModel> _clips = [];
  final Map<int, VideoPlayerController> _controllers = {};
  final Map<int, bool> _savedClips = {};
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isVisible = false; // Track if screen is visible

  static const Color brandRed = Color(0xFFE50914);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadClips();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.inactive) {
      pauseAllVideos();
    }
  }

  void pauseAllVideos() {
    for (var controller in _controllers.values) {
      if (controller.value.isPlaying) {
        controller.pause();
      }
    }
  }

  // Call this when tab becomes visible
  void setVisible(bool visible) {
    _isVisible = visible;
    if (visible) {
      // Resume current video if visible
      if (_controllers.containsKey(_currentIndex)) {
        _controllers[_currentIndex]?.play();
      }
    } else {
      // Pause all videos when not visible
      pauseAllVideos();
    }
  }

  Future<void> _loadClips({bool isRefresh = false}) async {
    try {
      if (!isRefresh) {
        setState(() {
          _isLoading = true;
        });
      }
      
      final clips = await _projectApi.getAllClips();
      if (mounted) {
        setState(() {
          _clips = clips;
          _isLoading = false;
        });
        if (clips.isNotEmpty) {
          // Dispose old controllers
          for (var controller in _controllers.values) {
            controller.dispose();
          }
          _controllers.clear();
          
          _initializeVideoAt(_currentIndex >= clips.length ? 0 : _currentIndex);
          _loadSavedStatus();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSavedStatus() async {
    for (int i = 0; i < _clips.length; i++) {
      final isSaved = await _projectApi.isProjectSaved(_clips[i].projectId);
      if (mounted) {
        setState(() {
          _savedClips[i] = isSaved;
        });
      }
    }
  }

  Future<void> _initializeVideoAt(int index) async {
    if (_controllers.containsKey(index)) return;
    if (index < 0 || index >= _clips.length) return;

    final clip = _clips[index];
    
    // Flutter's official sample videos
    final sampleVideos = [
      'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
    ];
    
    final videoUrl = clip.videoUrl.isNotEmpty && !clip.videoUrl.contains('example.com')
        ? clip.videoUrl
        : sampleVideos[index % sampleVideos.length];

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await controller.initialize();
      controller.setLooping(true);

      // Only play if this is current index AND screen is visible
      if (index == _currentIndex && _isVisible) {
        controller.play();
      }

      if (mounted) {
        setState(() {
          _controllers[index] = controller;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video at $index: $e');
    }
  }

  void _onPageChanged(int index) {
    _controllers[_currentIndex]?.pause();

    setState(() {
      _currentIndex = index;
    });

    // Only play if screen is visible
    if (_isVisible) {
      if (_controllers.containsKey(index)) {
        _controllers[index]!.play();
      } else {
        _initializeVideoAt(index);
      }
    }

    // Pre-load next
    if (index + 1 < _clips.length) {
      _initializeVideoAt(index + 1);
    }

    // Dispose old controllers
    _disposeOldControllers(index);
  }

  void _disposeOldControllers(int currentIndex) {
    final keysToRemove = <int>[];
    for (var key in _controllers.keys) {
      if ((key - currentIndex).abs() > 2) {
        keysToRemove.add(key);
      }
    }
    for (var key in keysToRemove) {
      _controllers[key]?.dispose();
      _controllers.remove(key);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pauseAllVideos();
    _pageController.dispose();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _toggleSave(int index) async {
    final isAuth = await AuthHelper.requireAuth(context);
    if (!isAuth) return;
    
    final clip = _clips[index];
    final isCurrentlySaved = _savedClips[index] ?? false;

    setState(() {
      _savedClips[index] = !isCurrentlySaved;
    });

    try {
      if (!isCurrentlySaved) {
        await _projectApi.saveProject(clip.projectId);
        _showSnackBar('Saved!', isSuccess: true);
      } else {
        await _projectApi.unsaveProject(clip.projectId);
        _showSnackBar('Removed from saved', isSuccess: true);
      }
    } catch (e) {
      setState(() {
        _savedClips[index] = isCurrentlySaved;
      });
      _showSnackBar('Error saving');
    }
  }

  Future<void> _openWhatsApp(ClipModel clip) async {
    const phone = '201205403733';
    final message = 'مهتم بمشروع ${clip.developerName}';
    final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';

    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      _showSnackBar('Could not open WhatsApp');
    }
  }

  Future<void> _shareClip(ClipModel clip) async {
    final shareText = '''
🎬 ${clip.title}
🏗️ ${clip.developerName}

${clip.description}

شاهد المزيد على تطبيق Orientation!
''';

    try {
      await Share.share(shareText, subject: clip.title);
    } catch (e) {
      _showSnackBar('Error sharing');
    }
  }

  void _openProjectDetails(ClipModel clip) async {
    final isAuth = await AuthHelper.requireAuth(context);
    if (!isAuth) return;
    
    // Pause current video before navigating
    pauseAllVideos();
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectDetailsScreen(projectId: clip.projectId),
      ),
    );
  }

  void _openEpisodes(ClipModel clip) async {
    final isAuth = await AuthHelper.requireAuth(context);
    if (!isAuth) return;
    
    // Pause current video before navigating
    pauseAllVideos();
    
    // Navigate to Project Details on Episodes tab
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectDetailsScreen(
          projectId: clip.projectId,
          initialTabIndex: 1, // Episodes tab
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: isSuccess ? Colors.green : brandRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: 3, // Show 3 skeleton items
          itemBuilder: (context, index) {
            return const SkeletonClipItem();
          },
        ),
      );
    }

    if (_clips.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.video_library_outlined,
                color: Colors.white.withOpacity(0.3),
                size: 80,
              ),
              const SizedBox(height: 24),
              Text(
                'No Clips Available',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        onRefresh: () => _loadClips(isRefresh: true),
        color: brandRed,
        backgroundColor: Colors.white,
        child: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: _clips.length,
          onPageChanged: _onPageChanged,
          physics: const AlwaysScrollableScrollPhysics(), // Enable pull to refresh
          itemBuilder: (context, index) {
            return _buildClipItem(index);
          },
        ),
      ),
    );
  }

  Widget _buildClipItem(int index) {
    final clip = _clips[index];
    final controller = _controllers[index];
    final isSaved = _savedClips[index] ?? false;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video or Placeholder
        GestureDetector(
          onTap: () {
            if (controller != null && controller.value.isInitialized) {
              if (controller.value.isPlaying) {
                controller.pause();
              } else {
                controller.play();
              }
              setState(() {});
            }
          },
          child: controller != null && controller.value.isInitialized
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                )
              : Container(
                  color: Colors.black,
                  child: clip.thumbnail.isNotEmpty
                      ? (clip.isAsset
                          ? Image.asset(
                              clip.thumbnail,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (_, __, ___) => _buildLoadingPlaceholder(),
                            )
                          : Image.network(
                              clip.thumbnail,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (_, __, ___) => _buildLoadingPlaceholder(),
                            ))
                      : _buildLoadingPlaceholder(),
                ),
        ),
        // Play/Pause indicator
        if (controller != null && !controller.value.isPlaying)
          const Center(
            child: Icon(
              Icons.play_arrow,
              color: Colors.white54,
              size: 80,
            ),
          ),
        // Gradient overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 300,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.95),
                ],
              ),
            ),
          ),
        ),
        // Action buttons - positioned higher
        Positioned(
          right: 16,
          bottom: 200,
          child: Column(
            children: [
              if (clip.hasWhatsApp) ...[
                _ActionButton(
                  imagePath: 'assets/icons_clips/whatsapp.png',
                  label: 'WhatsApp',
                  onTap: () => _openWhatsApp(clip),
                ),
                const SizedBox(height: 18),
              ],
              _ActionButton(
                imagePath: isSaved ? '' : 'assets/icons_clips/save.png',
                icon: isSaved ? Icons.bookmark : null,
                iconColor: isSaved ? brandRed : Colors.white,
                label: isSaved ? 'Saved' : 'Save',
                onTap: () => _toggleSave(index),
              ),
              const SizedBox(height: 18),
              _ActionButton(
                imagePath: 'assets/icons_clips/share.png',
                label: 'Share',
                onTap: () => _shareClip(clip),
              ),
            ],
          ),
        ),
        // Bottom content
        Positioned(
          left: 16,
          right: 80,
          bottom: 30,
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Developer info row - tappable to go to project details
                Row(
                  children: [
                    // Developer avatar - tappable
                    GestureDetector(
                      onTap: () => _openProjectDetails(clip),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: clip.developerLogo.isNotEmpty
                              ? Image.asset(
                                  clip.developerLogo,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.business,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                )
                              : const Icon(
                                  Icons.business,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Developer name - tappable, flexible width
                    Flexible(
                      child: GestureDetector(
                        onTap: () => _openProjectDetails(clip),
                        child: Text(
                          clip.developerName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Watch Orientation button
                    GestureDetector(
                      onTap: () => _openEpisodes(clip),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: brandRed,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_circle_filled,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Watch Orientation',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Title - tappable to go to project details
                GestureDetector(
                  onTap: () => _openProjectDetails(clip),
                  child: Text(
                    clip.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(
                    clip.description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingPlaceholder() {
    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xFFE50914),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String imagePath;
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Color iconColor;

  const _ActionButton({
    required this.imagePath,
    required this.label,
    required this.onTap,
    this.icon,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          icon != null
              ? Icon(icon, color: iconColor, size: 32)
              : Image.asset(
                  imagePath,
                  width: 32,
                  height: 32,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.circle,
                    color: iconColor,
                    size: 32,
                  ),
                ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
