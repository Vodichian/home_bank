import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:home_bank/bank/bank_facade.dart';
import 'dart:io'; // For File type if you were still using _imagePath for server upload
import 'package:image_picker/image_picker.dart'; // If you keep image picking
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:bank_server/bank.dart'; // Required for User object

class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  createState() => _CreateUserScreenState();
}

final Logger _logger = Logger(
  printer: PrettyPrinter(methodCount: 0),
);

// Enum to manage the current step of the form
enum CreateUserStep { enterCredentials, enterFullName }

class _CreateUserScreenState extends State<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _fullNameController =
      TextEditingController(); // Controller for full name
  String? _imagePath; // Still here if you plan to use it

  bool _isLoading = false; // To show loading indicator
  int? _createdUserId; // To store the ID of the newly created user

  CreateUserStep _currentStep = CreateUserStep.enterCredentials;

  Future<void> _handleUserCreationFlow() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final bank = context.read<BankFacade>();
    final String username = _usernameController.text;
    final String password = _passwordController.text;
    final String fullName = _fullNameController.text;

    try {
      if (_currentStep == CreateUserStep.enterCredentials) {
        _logger.i("Attempting to create user: $username");
        // Step 1: Create user with username and password
        _createdUserId = await bank.createUser(username, password);
        _logger.i("User $username created with ID: $_createdUserId");

        // If successful, move to the next step
        if (!mounted) return;
        setState(() {
          _currentStep = CreateUserStep.enterFullName;
          _isLoading = false; // Stop loading for the next input
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'User account created! Now, please enter your full name.')),
        );
      } else if (_currentStep == CreateUserStep.enterFullName &&
          _createdUserId != null) {
        _logger.i(
            "Attempting to update user ID: $_createdUserId with full name: $fullName");
        // Step 2: login
        await bank.login(username, password);

        // Step 3: Fetch the created user
        User userToUpdate = await bank.getUser(_createdUserId!);

        // Step 4: Update the user with the full name
        userToUpdate.fullName = fullName;
        // userToUpdate.imagePath = _imagePath ?? ''; // If you are also setting image path

        await bank.updateUser(userToUpdate);
        _logger
            .i("User ID: $_createdUserId updated successfully with full name.");

        // Step 5: Logout to clear stale user info
        await bank.logout();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User profile updated with full name!')),
        );
        context.go('/login'); // Navigate to login after successful update
      }
    } catch (onError) {
      _logger.e('Operation failed: $onError');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Operation failed: $onError')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    // This part remains if you still want image picking functionality
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (!mounted) return;

    if (pickedFile != null) {
      setState(() {
        _imagePath = pickedFile.path;
      });
    }
  }

  Widget _buildCredentialsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _usernameController,
          builder: (context, value, child) {
            return FutureBuilder<bool>(
              future: value.text.isEmpty
                  ? Future.value(false) // Don't check if empty
                  : context.read<BankFacade>().hasUsername(value.text),
              builder: (context, snapshot) {
                String? usernameErrorText;
                if (snapshot.connectionState == ConnectionState.active ||
                    snapshot.connectionState == ConnectionState.waiting &&
                        value.text.isNotEmpty) {
                  // Optionally show a small loading indicator or specific message
                } else if (snapshot.hasError) {
                  // usernameErrorText = 'Error checking username';
                  // _logger.e("Error checking username: ${snapshot.error}");
                } else if (snapshot.hasData &&
                    snapshot.data == true &&
                    value.text.isNotEmpty) {
                  usernameErrorText = 'Username is already taken';
                }

                return TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    errorText: usernameErrorText,
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please enter a username';
                    }
                    if (usernameErrorText != null && val.isNotEmpty) {
                      // Show taken error from async check
                      return usernameErrorText;
                    }
                    return null;
                  },
                  onChanged: (text) {
                    // Trigger rebuild of FutureBuilder by changing state
                    // Minimal setState to re-evaluate the FutureBuilder
                    setState(() {});
                  },
                );
              },
            );
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          decoration: const InputDecoration(labelText: 'Password'),
          obscureText: true,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a password';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
        // Image picking UI (optional)
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _pickImage,
          child: const Text('Choose Profile Image (Optional)'),
        ),
        if (_imagePath != null)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Image.file(File(_imagePath!), height: 100),
          ),
      ],
    );
  }

  Widget _buildFullNameForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _fullNameController,
          decoration: const InputDecoration(labelText: 'Full Name'),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your full name';
            }
            return null;
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentStep == CreateUserStep.enterCredentials
            ? 'Create User Account'
            : 'Enter Your Full Name'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_currentStep == CreateUserStep.enterFullName) {
                // If on full name step, go back to credentials step
                // Potentially clear _createdUserId or handle this state change carefully
                setState(() {
                  _currentStep = CreateUserStep.enterCredentials;
                  _createdUserId = null; // Reset created user ID
                });
              } else {
                // Otherwise, go back to login screen
                context.go('/login');
              }
            }),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_currentStep == CreateUserStep.enterCredentials)
                _buildCredentialsForm()
              else
                _buildFullNameForm(),
              const SizedBox(height: 20),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: _handleUserCreationFlow,
                  child: Text(_currentStep == CreateUserStep.enterCredentials
                      ? 'Next: Enter Full Name'
                      : 'Finish Creation'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _usernameController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }
}
