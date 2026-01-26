import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../models/clip_model.dart';
import '../services/api/project_api.dart';
import '../utils/auth_helper.dart';
import 'project_details_screen.dart';

class ReelsPlayerScreen extends StatefulWidget {
  final List<ClipModel> clips;
  final int initialIndex;

  const ReelsPlayerScreen({
    super.key,
    required this.clips,
    this.initialIndex = 0,
  });

  @override
  State<ReelsPlayerScreen> createState() => _ReelsPlayerScreenState();
}

class _ReelsPlayerScreenState extends State<ReelsPlayerScreen> with WidgetsBindingObserver {
  late PageController _pageController;
  final ProjectApi _projectApi = ProjectApi();
  final Map<int, VideoPlayerController> _controllers = {};
  final Map<int, bool> _likedClips = {};
  final Map<int, bool> _savedClips = {};
  int _currentIndex = 0;

  static const Color brandRed = Color(0xFFE50914);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _initializeCurrentVideo();
    _loadLikedStatus();
    _loadSavedStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.inactive) {
      _pauseAllVideos();
    }
  }

  void _pauseAllVideos() {
    for (var controller in _controllers.values) {
      if (controller.value.isPlaying) {
        controller.pause();
      }
    }
  }

  Future<void> _loadLikedStatus() async {
    for (int i = 0; i < widget.clips.length; i++) {
      final isLiked = await _projectApi.isClipLiked(widget.clips[i].id);
      if (mounted) {
        setState(() {
          _likedClips[i] = isLiked;
        });
      }
    }
  }

  Future<void> _loadSavedStatus() async {
    for (int i = 0; i < widget.clips.length; i++) {
      final isSaved = await _projectApi.isProjectSaved(widget.clips[i].projectId);
      if (mounted) {
        setState(() {
          _savedClips[i] = isSaved;
        });
      }
    }
  }

  Future<void> _initializeCurrentVideo() async {
    await _initializeVideoAt(_currentIndex);
    // Pre-load next video
    if (_currentIndex + 1 < widget.clips.length) {
      _initializeVideoAt(_currentIndex + 1);
    }
  }

  Future<void> _initializeVideoAt(int index) async {
    if (_controllers.containsKey(index)) return;
    if (index < 0 || index >= widget.clips.length) return;

    final clip = widget.clips[index];
    // Use sample video for demo
    // Flutter's official sample videos that work everywhere
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

      if (index == _currentIndex) {
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
    // Pause previous video
    _controllers[_currentIndex]?.pause();

    setState(() {
      _currentIndex = index;
    });

    // Play current video
    if (_controllers.containsKey(index)) {
      _controllers[index]!.play();
    } else {
      _initializeVideoAt(index);
    }

    // Pre-load next video
    if (index + 1 < widget.clips.length) {
      _initializeVideoAt(index + 1);
    }

    // Dispose old videos to save memory
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
    _pauseAllVideos();
    _pageController.dispose();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _toggleLike(int index) async {
    final clip = widget.clips[index];
    final isCurrentlyLiked = _likedClips[index] ?? false;

    setState(() {
      _likedClips[index] = !isCurrentlyLiked;
    });

    try {
      if (!isCurrentlyLiked) {
        await _projectApi.likeClip(clip.id);
      } else {
        await _projectApi.unlikeClip(clip.id);
      }
    } catch (e) {
      // Revert on error
      setState(() {
        _likedClips[index] = isCurrentlyLiked;
      });
    }
  }

  Future<void> _toggleSave(int index) async {
    final isAuth = await AuthHelper.requireAuth(context);
    if (!isAuth) return;
    
    final clip = widget.clips[index];
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
    const phone = '201205403733'; // Default number
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
    
    _pauseAllVideos();
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
    
    _pauseAllVideos();
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video PageView
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.clips.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              return _buildReelItem(index);
            },
          ),
          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: GestureDetector(
              onTap: () {
                _pauseAllVideos();
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReelItem(int index) {
    final clip = widget.clips[index];
    final controller = _controllers[index];
    final isLiked = _likedClips[index] ?? false;
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
                              errorBuilder: (_, __, ___) => _buildLoadingPlaceholder(),
                            )
                          : Image.network(
                              clip.thumbnail,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildLoadingPlaceholder(),
                            ))
                      : _buildLoadingPlaceholder(),
                ),
        ),
        // Play/Pause indicator
        if (controller != null && !controller.value.isPlaying)
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 50,
              ),
            ),
          ),
        // Gradient overlay at bottom
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
        // Action buttons (right side) - positioned higher
        Positioned(
          right: 16,
          bottom: 200,
          child: Column(
            children: [
              if (clip.hasWhatsApp) ...[
                _ActionButton(
                  icon: Icons.chat,
                  label: 'WhatsApp',
                  onTap: () => _openWhatsApp(clip),
                  useImage: true,
                  imagePath: 'assets/icons_clips/whatsapp.png',
                ),
                const SizedBox(height: 18),
              ],
              _ActionButton(
                icon: isLiked ? Icons.favorite : Icons.favorite_border,
                label: '${clip.likes + (isLiked ? 1 : 0)}',
                onTap: () => _toggleLike(index),
                iconColor: isLiked ? brandRed : Colors.white,
                useImage: !isLiked,
                imagePath: 'assets/icons_clips/like.png',
              ),
              const SizedBox(height: 18),
              _ActionButton(
                icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
                label: isSaved ? 'Saved' : 'Save',
                onTap: () => _toggleSave(index),
                iconColor: isSaved ? brandRed : Colors.white,
                useImage: !isSaved,
                imagePath: 'assets/icons_clips/save.png',
              ),
              const SizedBox(height: 18),
              _ActionButton(
                icon: Icons.share,
                label: 'Share',
                onTap: () => _shareClip(clip),
                useImage: true,
                imagePath: 'assets/icons_clips/share.png',
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
                // Developer info row
                Row(
                  children: [
                    // Avatar - tappable
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
                    // Name - tappable, flexible width
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
                    // Watch button - opens Episodes tab
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
                // Title - tappable
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
                // Description
                Text(
                  clip.description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;
  final bool useImage;
  final String imagePath;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = Colors.white,
    this.useImage = false,
    this.imagePath = '',
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          useImage && imagePath.isNotEmpty
              ? Image.asset(
                  imagePath,
                  width: 32,
                  height: 32,
                  errorBuilder: (_, __, ___) => Icon(
                    icon,
                    color: iconColor,
                    size: 32,
                  ),
                )
              : Icon(
                  icon,
                  color: iconColor,
                  size: 32,
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
