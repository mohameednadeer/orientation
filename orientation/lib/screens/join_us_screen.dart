import 'package:flutter/material.dart';
import '../services/api/admin_api.dart';

class JoinUsScreen extends StatefulWidget {
  const JoinUsScreen({super.key});

  @override
  State<JoinUsScreen> createState() => _JoinUsScreenState();
}

class _JoinUsScreenState extends State<JoinUsScreen> {
  final _companyNameController = TextEditingController();
  final _headOfficeController = TextEditingController();
  final _projectNameController = TextEditingController();
  final _orientationsController = TextEditingController();
  final _notesController = TextEditingController();
  
  final AdminApi _adminApi = AdminApi();
  bool _isLoading = false;
  
  static const Color brandRed = Color(0xFFE50914);

  @override
  void dispose() {
    _companyNameController.dispose();
    _headOfficeController.dispose();
    _projectNameController.dispose();
    _orientationsController.dispose();
    _notesController.dispose();
    super.dispose();
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
            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Contact Information section
                    const Text(
                      'Contact Information',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _companyNameController,
                      hint: 'Company Name*',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _headOfficeController,
                      hint: 'Head Office Adress*',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _projectNameController,
                      hint: 'Name of Project*',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _orientationsController,
                      hint: 'Number of Orientations*',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _notesController,
                      hint: 'Notes',
                      maxLines: 5,
                    ),
                  ],
                ),
              ),
            ),
            // Send button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A2A2A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Send',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
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
                'Join Us',
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    // Validate required fields
    if (_companyNameController.text.trim().isEmpty ||
        _headOfficeController.text.trim().isEmpty ||
        _projectNameController.text.trim().isEmpty ||
        _orientationsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: brandRed,
        ),
      );
      return;
    }

    // Parse orientations count
    final orientationsCount = int.tryParse(_orientationsController.text.trim());
    if (orientationsCount == null || orientationsCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid number of orientations'),
          backgroundColor: brandRed,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final request = JoinRequestModel(
        id: '',
        userId: '',
        companyName: _companyNameController.text.trim(),
        headOffice: _headOfficeController.text.trim(),
        projectName: _projectNameController.text.trim(),
        orientationsCount: orientationsCount,
        notes: _notesController.text.trim().isEmpty 
            ? null 
            : _notesController.text.trim(),
        createdAt: DateTime.now(),
      );

      final success = await _adminApi.submitJoinRequest(request);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request submitted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: brandRed,
          ),
        );
      }
    }
  }
}

