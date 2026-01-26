import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../widgets/project_card.dart';
import '../widgets/app_drawer.dart';
import '../widgets/skeleton_loader.dart';
import '../services/api/home_api.dart';
import '../services/api/auth_api.dart';
import '../models/project_model.dart';
import '../models/developer_model.dart';
import '../models/area_model.dart';
import '../utils/auth_helper.dart';
import 'project_details_screen.dart';
import 'latest_for_us_screen.dart';
import 'top_10_screen.dart';
import 'saved_screen.dart';
import 'developers_screen.dart';
import 'areas_screen.dart';
import 'projects_list_screen.dart';
import 'search_screen.dart';
import 'continue_watching_screen.dart';
import 'account_screen.dart';
import 'login_screen.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> with WidgetsBindingObserver {
  final PageController _featuredController = PageController();
  final ScrollController _scrollController = ScrollController();
  final HomeApi _homeApi = HomeApi();
  final AuthApi _authApi = AuthApi();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<AppDrawerState> _drawerKey = GlobalKey<AppDrawerState>();
  final GlobalKey _upcomingSectionKey = GlobalKey();
  
  int _currentFeaturedPage = 0;
  String _selectedFilter = 'Medical';
  bool _isLoading = true;
  String _userName = 'User';
  DateTime? _lastRefreshTime;

  final List<String> _filters = ['Medical', 'Commercial', 'Residential', 'Hotel'];

  // Video player for featured section
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;
  ProjectModel? _videoProject; // Project that contains the video

  static const Color brandRed = Color(0xFFE50914);

  // Data from API
  List<ProjectModel> _featuredProjects = [];
  List<ProjectModel> _latestProjects = [];
  List<ProjectModel> _continueWatching = [];
  List<ProjectModel> _top10Projects = [];
  List<ProjectModel> _northCoastProjects = [];
  List<ProjectModel> _newCairoProjects = [];
  List<ProjectModel> _octoberProjects = [];
  List<ProjectModel> _upcomingProjects = [];
  List<DeveloperModel> _developers = [];
  List<AreaModel> _areas = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Load data asynchronously to avoid blocking UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _loadUserName();
    });
    // Video will be initialized after loading data (in _loadData)
  }

  Future<void> _initializeVideo() async {
    try {
      // Use asset video only (no API video in dev mode)
      String videoUrl = 'assets/videos/orientation.v2.mp4';
      bool isNetworkVideo = false;
      
      // Set video project to first featured project
      if (_featuredProjects.isNotEmpty) {
        _videoProject = _featuredProjects.first;
      }

      // Initialize video controller based on source
      if (isNetworkVideo) {
        _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      } else {
        _videoPlayerController = VideoPlayerController.asset(videoUrl);
      }

      await _videoPlayerController!.initialize();
      
      if (!mounted) {
        _videoPlayerController?.dispose();
        return;
      }
      
      // Mute the video
      await _videoPlayerController!.setVolume(0.0);
      
      // Calculate aspect ratio to match the container (65% of screen height)
      final screenWidth = MediaQuery.of(context).size.width;
      final containerHeight = MediaQuery.of(context).size.height * 0.65;
      final targetAspectRatio = screenWidth / containerHeight;
      
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false, // Disable looping to detect when video ends
        aspectRatio: targetAspectRatio,
        showControls: false,
        allowFullScreen: false,
        allowMuting: true,
        allowPlaybackSpeedChanging: false,
        errorBuilder: (context, errorMessage) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF4A90A4).withOpacity(0.3),
                  const Color(0xFF2d6a7a).withOpacity(0.2),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.3, 0.5],
              ),
            ),
          );
        },
      );

      await _videoPlayerController!.play();

      // Listen for video completion to auto-scroll to next project
      _videoPlayerController!.addListener(_videoListener);

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (e) {
      // Silently fail - video is optional
      if (mounted) {
        setState(() {
          _isVideoInitialized = false;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh continue watching when screen becomes visible again (with debounce)
    final now = DateTime.now();
    if (_lastRefreshTime == null || 
        now.difference(_lastRefreshTime!).inSeconds > 2) {
      _lastRefreshTime = now;
      _refreshContinueWatching();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh continue watching when app comes back to foreground
      _refreshContinueWatching();
    }
  }

  Future<void> _refreshContinueWatching() async {
    try {
      print('🔄 Refreshing continue watching...');
      final continueWatching = await _homeApi.getContinueWatching();
      print('📊 Got ${continueWatching.length} continue watching projects');
      if (mounted) {
        setState(() {
          _continueWatching = continueWatching;
          _lastRefreshTime = DateTime.now();
        });
      }
    } catch (e) {
      print('❌ Error refreshing continue watching: $e');
      // Silently fail - don't show error for background refresh
    }
  }

  // Public method to refresh continue watching (can be called from MainScreen)
  void refreshContinueWatching() {
    _refreshContinueWatching();
  }

  // Test method to add sample progress (for debugging)
  Future<void> _testContinueWatching() async {
    // TODO: Implement test functionality
  }

  Future<void> _loadUserName() async {
    final isLoggedIn = await _authApi.isLoggedIn();
    if (!mounted) return;
    
    if (!isLoggedIn) {
      setState(() {
        _userName = 'Guest';
      });
      return;
    }
    
    // User is logged in, load user info
    final userInfo = await _authApi.getStoredUserInfo();
    if (!mounted) return;
    
    setState(() {
      // Use firstName + lastName if available, otherwise fallback to username
      final firstName = userInfo['firstName'] ?? '';
      final lastName = userInfo['lastName'] ?? '';
      if (firstName.isNotEmpty || lastName.isNotEmpty) {
        _userName = '$firstName $lastName'.trim();
      } else {
        _userName = userInfo['username'] ?? 'User';
      }
    });
  }

  // Public method to refresh user name (called from MainScreen)
  void refreshUserName() {
    _loadUserName();
  }

  Future<void> _loadData() async {
    print('🔄 Starting _loadData()...');
    try {
      // Load data with error handling for each API call
      print('📡 Calling APIs...');
      final results = await Future.wait([
        _homeApi.getFeaturedProjects().catchError((e) {
          print('Error loading featured projects: $e');
          return <ProjectModel>[];
        }),
        _homeApi.getLatestProjects().catchError((e) {
          print('Error loading latest projects: $e');
          return <ProjectModel>[];
        }),
        _homeApi.getContinueWatching().catchError((e) {
          print('Error loading continue watching: $e');
          return <ProjectModel>[];
        }),
        _homeApi.getTop10Projects().catchError((e) {
          print('Error loading top 10 projects: $e');
          return <ProjectModel>[];
        }),
        _homeApi.getProjectsByArea('North Coast').catchError((e) {
          print('Error loading North Coast projects: $e');
          return <ProjectModel>[];
        }),
        _homeApi.getProjectsByArea('New Cairo').catchError((e) {
          print('Error loading New Cairo projects: $e');
          return <ProjectModel>[];
        }),
        _homeApi.getProjectsByArea('October').catchError((e) {
          print('Error loading October projects: $e');
          return <ProjectModel>[];
        }),
        _homeApi.getUpcomingProjects().catchError((e) {
          print('Error loading upcoming projects: $e');
          return <ProjectModel>[];
        }),
        _homeApi.getDevelopers().catchError((e) {
          print('Error loading developers: $e');
          return <DeveloperModel>[];
        }),
        _homeApi.getAreas().catchError((e) {
          print('Error loading areas: $e');
          return <AreaModel>[];
        }),
      ]);

      print('✅ All APIs completed. Results:');
      print('  - Featured: ${(results[0] as List).length}');
      print('  - Latest: ${(results[1] as List).length}');
      print('  - Continue Watching: ${(results[2] as List).length}');
      print('  - Top 10: ${(results[3] as List).length}');
      
      if (mounted) {
        // getFeaturedProjects already filters to featured: true, but double-check
        final allFeatured = results[0] as List<ProjectModel>;
        final featuredOnly = allFeatured.where((p) => p.isFeatured).toList();
        
        print('🏠 Home Feed - Featured projects: ${featuredOnly.length}');
        if (featuredOnly.isEmpty && allFeatured.isNotEmpty) {
          print('⚠️ Warning: No featured projects found, but ${allFeatured.length} projects returned');
          print('   First project featured status: ${allFeatured.first.isFeatured}');
        }
        
        setState(() {
          _featuredProjects = featuredOnly; // Only projects with featured: true
          _latestProjects = results[1] as List<ProjectModel>;
          _continueWatching = results[2] as List<ProjectModel>;
          _top10Projects = results[3] as List<ProjectModel>;
          _northCoastProjects = results[4] as List<ProjectModel>;
          _newCairoProjects = results[5] as List<ProjectModel>;
          _octoberProjects = results[6] as List<ProjectModel>;
          _upcomingProjects = results[7] as List<ProjectModel>;
          _developers = results[8] as List<DeveloperModel>;
          _areas = results[9] as List<AreaModel>;
          _isLoading = false;
        });
        print('✅ setState completed. Featured: ${_featuredProjects.length}, Latest: ${_latestProjects.length}, Continue Watching: ${_continueWatching.length}');
        // Initialize video after loading projects (to get video from API)
        _initializeVideo();
      }
    } catch (e) {
      print('❌ Unexpected error in _loadData: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        print('✅ setState in catch block. _isLoading = false');
      }
    }
  }

  void _videoListener() {
    if (_videoPlayerController != null &&
        _videoPlayerController!.value.isInitialized &&
        _videoPlayerController!.value.duration.inMilliseconds > 0) {
      final position = _videoPlayerController!.value.position;
      final duration = _videoPlayerController!.value.duration;
      
      // Check if video has ended (position is at or very close to duration)
      // Use a small threshold (100ms) to account for timing precision
      if (position.inMilliseconds >= (duration.inMilliseconds - 100)) {
        // Video ended, move to next project only if we're on the first page (with video)
        if (_currentFeaturedPage == 0 && 
            _featuredProjects.length > 1 && 
            mounted) {
          final nextIndex = (_currentFeaturedPage + 1) % _featuredProjects.length;
          _featuredController.animateToPage(
            nextIndex,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoPlayerController?.removeListener(_videoListener);
    _featuredController.dispose();
    _scrollController.dispose();
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  void scrollToUpcomingProjects() {
    // Scroll to upcoming projects section using the key
    Future.delayed(const Duration(milliseconds: 100), () {
      final context = _upcomingSectionKey.currentContext;
      if (context != null && mounted) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.1, // Scroll to show the section near the top with some padding
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.black,
      drawer: AppDrawer(
        key: _drawerKey,
        onScrollToUpcoming: scrollToUpcomingProjects,
      ),
      onDrawerChanged: (isOpened) {
        if (isOpened) {
          // Refresh auth status when drawer is opened
          _drawerKey.currentState?.refreshAuthStatus();
          // Also refresh user name
          _loadUserName();
        }
      },
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Hero section with AppBar, Filters, and Carousel
          SliverToBoxAdapter(
            child: _buildHeroSection(),
          ),
          // Page indicator
          SliverToBoxAdapter(
            child: _buildPageIndicator(),
          ),
          // Sections
          SliverToBoxAdapter(
            child: _buildSection(
              'The latest for us',
              onViewAll: () async {
                final isAuth = await AuthHelper.requireAuth(context);
                if (!isAuth) return;
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LatestForUsScreen(),
                  ),
                );
              },
              child: _buildHorizontalProjectList(),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildSection(
              'Continue watching',
              onViewAll: () async {
                final isAuth = await AuthHelper.requireAuth(context);
                if (!isAuth) return;
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ContinueWatchingScreen(),
                  ),
                );
              },
              child: Column(
                children: [
                  // Test button (for debugging - remove in production)
                  if (_continueWatching.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ElevatedButton(
                        onPressed: _testContinueWatching,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandRed,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Test Continue Watching'),
                      ),
                    ),
                  _buildContinueWatchingList(),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildSection(
              'Top 10',
              onViewAll: () async {
                final isAuth = await AuthHelper.requireAuth(context);
                if (!isAuth) return;
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const Top10Screen(),
                  ),
                );
              },
              child: _buildTop10List(),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildSection(
              'Projects in Northcoast',
              onViewAll: () async {
                final isAuth = await AuthHelper.requireAuth(context);
                if (!isAuth) return;
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProjectsListScreen(
                      title: 'Projects in Northcoast',
                    ),
                  ),
                );
              },
              child: _buildNorthcoastProjects(),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildSection(
              'Projects in New Cairo',
              onViewAll: () async {
                final isAuth = await AuthHelper.requireAuth(context);
                if (!isAuth) return;
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProjectsListScreen(
                      title: 'Projects in New Cairo',
                    ),
                  ),
                );
              },
              child: _buildNewCairoProjects(),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildSection(
              'Projects in October',
              onViewAll: () async {
                final isAuth = await AuthHelper.requireAuth(context);
                if (!isAuth) return;
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProjectsListScreen(
                      title: 'Projects in October',
                    ),
                  ),
                );
              },
              child: _buildOctoberProjects(),
            ),
          ),
          SliverToBoxAdapter(
            key: _upcomingSectionKey,
            child: _buildSection(
              'Upcoming Projects',
              onViewAll: () {},
              child: _buildUpcomingProjectsList(),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildSection(
              'Developers',
              onViewAll: () async {
                final isAuth = await AuthHelper.requireAuth(context);
                if (!isAuth) return;
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DevelopersScreen(),
                  ),
                );
              },
              child: _buildDevelopersList(),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildSection(
              'Discover Areas',
              onViewAll: () async {
                final isAuth = await AuthHelper.requireAuth(context);
                if (!isAuth) return;
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AreasScreen(),
                  ),
                );
              },
              child: _buildAreaChips(),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 20),
          ),
        ],
      ),
    );
  }

  // Hero section with overlaying AppBar and Filters on Carousel
  Widget _buildHeroSection() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.65, // 65% of screen height
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Carousel - full width and height
          PageView.builder(
            controller: _featuredController,
            onPageChanged: (index) {
              setState(() {
                _currentFeaturedPage = index;
              });
              // Restart video when moving to first page (index 0)
              if (_videoPlayerController != null && 
                  _videoPlayerController!.value.isInitialized && 
                  mounted) {
                if (index == 0) {
                  _videoPlayerController!.seekTo(Duration.zero);
                  _videoPlayerController!.play().catchError((_) {});
                } else {
                  _videoPlayerController!.pause();
                }
              }
            },
            itemCount: _featuredProjects.length,
            itemBuilder: (context, index) {
              final project = _featuredProjects[index];
              return _buildFeaturedCard(context, project, index);
            },
            // Performance optimization: add keys for better widget reuse
            key: const PageStorageKey<String>('featured_projects'),
          ),
          // AppBar overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: _buildAppBar(),
            ),
          ),
          // Logo above Watch button (static until API is connected)
          Positioned(
            bottom: 90,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                'assets/images/logo.png/masaya_logo.png',
                height: 100,
                width: 200,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // Try alternative path
                  return Image.asset(
                    'assets/images/masaya_logo.png',
                    height: 100,
                    width: 200,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox.shrink();
                    },
                  );
                },
              ),
            ),
          ),
          // Watch button at bottom
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: _buildWatchButton(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectLogo(ProjectModel project) {
    // Use logo from API if available, otherwise show nothing
    if (project.logo == null || project.logo!.isEmpty) {
      return const SizedBox.shrink();
    }

    return project.logo!.startsWith('http') || project.logo!.startsWith('https')
        ? Image.network(
            project.logo!,
            height: 100,
            width: 200,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return SizedBox(
                width: 200,
                height: 100,
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return const SizedBox.shrink();
            },
          )
        : Image.asset(
            project.logo!,
            height: 100,
            width: 200,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const SizedBox.shrink();
            },
          );
  }

  Widget _buildWatchButton() {
    // Use video project if available, otherwise use current page project
    final projectToOpen = _videoProject ?? 
        (_featuredProjects.isNotEmpty ? _featuredProjects[_currentFeaturedPage] : null);
    
    return GestureDetector(
      onTap: () {
        if (projectToOpen != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProjectDetailsScreen(
                projectId: projectToOpen.id,
                initialTabIndex: 1, // Open on Episodes tab
              ),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_circle_filled,
              color: Colors.white.withOpacity(0.9),
              size: 22,
            ),
            const SizedBox(width: 8),
            const Text(
              'Watch',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedCard(BuildContext context, ProjectModel project, int index) {
    final gradientColors = project.gradientColors.map((c) {
      final hex = c.replaceAll('0x', '');
      return Color(int.parse(hex, radix: 16));
    }).toList();
    final bool isAsset = project.isAsset;
    
    // Use video for first card (index 0), image for others
    final bool useVideo = index == 0 && 
        _isVideoInitialized && 
        _chewieController != null && 
        _videoPlayerController != null &&
        _videoPlayerController!.value.isInitialized;
    
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background video (for first card) or image
        useVideo
            ? Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.fill,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height * 0.65,
                    child: VideoPlayer(_videoPlayerController!),
                  ),
                ),
              )
            : (isAsset
                ? Image.asset(
                    project.image,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: gradientColors,
                          ),
                        ),
                      );
                    },
                  )
                : Image.network(
                    project.image,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: gradientColors,
                          ),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: gradientColors,
                          ),
                        ),
                      );
                    },
                  )),
        // Color tint overlay (light at top)
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                gradientColors[0].withOpacity(0.3),
                gradientColors[1].withOpacity(0.2),
                Colors.transparent,
              ],
              stops: const [0.0, 0.3, 0.5],
            ),
          ),
        ),
        // Dark gradient at bottom - blends into black section below
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.transparent,
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.7),
                Colors.black.withOpacity(0.95),
                Colors.black,
              ],
              stops: const [0.0, 0.35, 0.5, 0.65, 0.85, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Menu icon
          GestureDetector(
            onTap: () {
              _scaffoldKey.currentState?.openDrawer();
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.menu,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Profile avatar
          GestureDetector(
            onTap: () async {
              final isLoggedIn = await _authApi.isLoggedIn();
              if (!isLoggedIn) {
                // If user is not logged in, show login dialog (same as menu items)
                await AuthHelper.requireAuth(context);
                // Refresh user name after returning from login (if user logged in)
                _loadUserName();
              } else {
                // If user is logged in, navigate to account screen
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AccountScreen(),
                    ),
                  );
                }
              }
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Greeting
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hello,',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              Text(
                _userName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Search icon
          IconButton(
            icon: const Icon(
              Icons.search,
              color: Colors.white,
              size: 24,
            ),
            onPressed: () async {
              final isAuth = await AuthHelper.requireAuth(context);
              if (!isAuth) return;
              
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchScreen(),
                ),
              );
            },
          ),
          // Bookmark icon
          IconButton(
            icon: const Icon(
              Icons.bookmark_border,
              color: Colors.white,
              size: 24,
            ),
            onPressed: () async {
              final isAuth = await AuthHelper.requireAuth(context);
              if (!isAuth) return;
              
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SavedScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: _filters.map((filter) {
            final bool isSelected = _selectedFilter == filter;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedFilter = filter;
                  });
                },
                child: Container(
                  height: 32,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.25)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      filter,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_featuredProjects.length, (index) {
          final isActive = index == _currentFeaturedPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isActive ? 24 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: isActive ? brandRed : Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSection(
    String title, {
    required VoidCallback onViewAll,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: onViewAll,
                child: const Text(
                  'View all',
                  style: TextStyle(
                    color: brandRed,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }

  Widget _buildHorizontalProjectList() {
    if (_latestProjects.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _latestProjects.length,
        itemBuilder: (context, index) {
          final project = _latestProjects[index];
          final gradientColors = project.gradientColors.map((c) {
            final hex = c.replaceAll('0x', '');
            return Color(int.parse(hex, radix: 16));
          }).toList();
          
          return Padding(
            padding: EdgeInsets.only(right: index < _latestProjects.length - 1 ? 12 : 0),
            child: _buildLatestCard(
              project: project,
              gradientColors: gradientColors,
            ),
          );
        },
      ),
    );
  }

  Widget _buildLatestCard({
    required ProjectModel project,
    required List<Color> gradientColors,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProjectDetailsScreen(
              projectId: project.id,
              initialTabIndex: 1, // Open on Episodes tab
            ),
          ),
        );
      },
      child: Container(
        width: 160,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Image
              project.isAsset
                  ? Image.asset(
                      project.image,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: gradientColors,
                            ),
                          ),
                        );
                      },
                    )
                  : Image.network(
                      project.image,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: gradientColors,
                            ),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: gradientColors,
                            ),
                          ),
                        );
                      },
                    ),
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
              // Text content
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      project.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      project.subtitle.isNotEmpty ? project.subtitle : project.location,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContinueWatchingList() {
    if (_isLoading) {
      return SizedBox(
        height: 110,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 3,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: const SkeletonProjectCard(),
            );
          },
        ),
      );
    }
    
    if (_continueWatching.isEmpty) {
      return SizedBox(
        height: 110,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'No videos in progress',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _continueWatching.length,
        itemBuilder: (context, index) {
          final project = _continueWatching[index];
          return Padding(
            padding: EdgeInsets.only(right: index < _continueWatching.length - 1 ? 12 : 0),
            child: _buildContinueWatchingItem(
              project: project,
            ),
          );
        },
      ),
    );
  }

  Widget _buildContinueWatchingItem({
    required ProjectModel project,
  }) {
    final gradientColors = project.gradientColors.map((c) {
      final hex = c.replaceAll('0x', '');
      return Color(int.parse(hex, radix: 16));
    }).toList();
    final progress = project.watchProgress ?? 0.0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProjectDetailsScreen(
              projectId: project.id,
            ),
          ),
        );
      },
      child: Container(
        width: 160,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image
              project.isAsset
                  ? Image.asset(
                      project.image,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradientColors,
                            ),
                          ),
                        );
                      },
                    )
                  : Image.network(
                      project.image,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradientColors,
                            ),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradientColors,
                            ),
                          ),
                        );
                      },
                    ),
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
              // Title
              Center(
                child: Text(
                  project.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ),
              // Progress bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(brandRed),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTop10List() {
    if (_top10Projects.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final displayProjects = _top10Projects.take(10).toList();

    return SizedBox(
      height: 175,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: displayProjects.length,
        itemBuilder: (context, index) {
          final project = displayProjects[index];
          final gradientColors = project.gradientColors.map((c) {
            final hex = c.replaceAll('0x', '');
            return Color(int.parse(hex, radix: 16));
          }).toList();
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: RankedProjectCard(
              rank: index + 1,
              title: project.title,
              imageAsset: project.isAsset ? project.image : null,
              imageUrl: project.isAsset ? null : project.image,
              gradientColors: gradientColors,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProjectDetailsScreen(
                      projectId: project.id,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNorthcoastProjects() {
    if (_northCoastProjects.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _northCoastProjects.length,
        itemBuilder: (context, index) {
          final project = _northCoastProjects[index];
          return Padding(
            padding: EdgeInsets.only(right: index < _northCoastProjects.length - 1 ? 12 : 0),
            child: _buildLargeProjectCard(
              project: project,
            ),
          );
        },
      ),
    );
  }

  Widget _buildNewCairoProjects() {
    if (_newCairoProjects.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _newCairoProjects.length,
        itemBuilder: (context, index) {
          final project = _newCairoProjects[index];
          return Padding(
            padding: EdgeInsets.only(right: index < _newCairoProjects.length - 1 ? 12 : 0),
            child: _buildLargeProjectCard(
              project: project,
            ),
          );
        },
      ),
    );
  }

  Widget _buildOctoberProjects() {
    if (_octoberProjects.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _octoberProjects.length,
        itemBuilder: (context, index) {
          final project = _octoberProjects[index];
          return Padding(
            padding: EdgeInsets.only(right: index < _octoberProjects.length - 1 ? 12 : 0),
            child: _buildLargeProjectCard(
              project: project,
            ),
          );
        },
      ),
    );
  }

  Widget _buildLargeProjectCard({
    required ProjectModel project,
  }) {
    final gradientColors = project.gradientColors.map((c) {
      final hex = c.replaceAll('0x', '');
      return Color(int.parse(hex, radix: 16));
    }).toList();
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProjectDetailsScreen(
              projectId: project.id,
              initialTabIndex: 1, // Open on Episodes tab
            ),
          ),
        );
      },
      child: Container(
        width: 200,
        height: 170,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image
              project.isAsset
                  ? Image.asset(
                      project.image,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradientColors,
                            ),
                          ),
                        );
                      },
                    )
                  : Image.network(
                      project.image,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradientColors,
                            ),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF4A90A4), Color(0xFF2d6a7a)],
                      ),
                    ),
                  );
                },
              ),
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
              // Content
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      project.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      project.subtitle.isNotEmpty ? project.subtitle : project.location,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingProjectsList() {
    return SizedBox(
      height: 240,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildUpcomingItem(
            title: 'THE ICON',
            subtitle: 'Gardens',
            imageAsset: 'assets/top10/the_icon.png',
            gradientColors: [const Color(0xFF1a1a2e), const Color(0xFF16213e)],
            hasLogo: true,
          ),
          const SizedBox(width: 12),
          _buildUpcomingItem(
            title: 'masaya',
            subtitle: 'SIDI ABDELRAHMAN',
            imageAsset: 'assets/top10/masaya.png',
            gradientColors: [const Color(0xFF4A90A4), const Color(0xFF2d6a7a)],
            hasLogo: false,
          ),
          const SizedBox(width: 12),
          _buildUpcomingItem(
            title: 'THE ICON',
            subtitle: 'FULLY FINISHED UNITS',
            imageAsset: 'assets/top10/the_icon.png',
            gradientColors: [const Color(0xFF0d4f4f), const Color(0xFF1a6b6b)],
            hasLogo: true,
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingItem({
    required String title,
    required String subtitle,
    required String imageAsset,
    required List<Color> gradientColors,
    bool hasLogo = false,
  }) {
    // Try to find project by title
    ProjectModel? project;
    if (_upcomingProjects.isNotEmpty) {
      try {
        project = _upcomingProjects.firstWhere(
          (p) => p.title.toLowerCase() == title.toLowerCase(),
        );
      } catch (e) {
        project = _upcomingProjects.first;
      }
    }
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProjectDetailsScreen(
              projectId: project?.id,
              initialTabIndex: 1, // Open on Episodes tab
            ),
          ),
        );
      },
      child: SizedBox(
        width: 180,
        height: 230,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image from assets - fills entire card
              Image.asset(
                imageAsset,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradientColors,
                      ),
                    ),
                  );
                },
              ),
              // Color gradient overlay on image
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        gradientColors[0].withOpacity(0.6),
                        gradientColors[1].withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),
              // Dark gradient at bottom for text
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.5),
                        Colors.black.withOpacity(0.9),
                      ],
                      stops: const [0.0, 0.4, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
              // Logo in center (for THE ICON)
              if (hasLogo)
                Center(
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // Title and subtitle at bottom
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDevelopersList() {
    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildDeveloperItem(
            name: 'HE',
            subtitle: 'HORIZON',
          ),
          const SizedBox(width: 12),
          _buildDeveloperItem(
            name: 'EGYPTIAN',
            subtitle: 'DEVELOPERS',
            hasIcon: true,
          ),
          const SizedBox(width: 12),
          _buildDeveloperItem(
            name: 'PAL',
            subtitle: '',
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperItem({
    required String name,
    required String subtitle,
    bool hasIcon = false,
  }) {
    return Container(
      width: 120,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (hasIcon)
            const Icon(
              Icons.account_balance,
              color: Color(0xFFB8860B),
              size: 20,
            ),
          Text(
            name,
            style: const TextStyle(
              color: Color(0xFF8B7355),
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle.isNotEmpty) ...[
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF8B7355),
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAreaChips() {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildAreaChip('North Coast'),
          const SizedBox(width: 10),
          _buildAreaChip('Administrative Capital'),
          const SizedBox(width: 10),
          _buildAreaChip('Fifth Settlement'),
          const SizedBox(width: 10),
          _buildAreaChip('New Cairo'),
        ],
      ),
    );
  }

  Widget _buildAreaChip(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Text(
        name,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
