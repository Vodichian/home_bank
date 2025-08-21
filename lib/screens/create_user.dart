import 'dart:io'; // For File type, Platform, Process
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:home_bank/bank/bank_facade.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:bank_server/bank.dart'; // Required for User object
import 'package:path/path.dart' as p; // For path manipulation

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
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (!mounted) return;

    if (pickedFile != null) {
      setState(() {
        _imagePath = pickedFile.path;
      });
    }
  }

  Future<void> _launchBankCardGenerator() async {
    if (!Platform.isWindows) {
      _logger.w("Bank card generator can only be launched on Windows.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bank card generator is only available on Windows.")),
      );
      return;
    }

    final String username = _usernameController.text;
    final String password = _passwordController.text; // Ensure this is available and appropriate to pass
    final String fullName = _fullNameController.text;

    // Basic validation: ensure necessary fields for the generator are not empty.
    // Adjust as needed based on what bank_card_generator.exe requires.
    // if (username.isEmpty || password.isEmpty || fullName.isEmpty) {
    //      _logger.w("Cannot launch card generator: Username, password, or full name is missing.");
    //      ScaffoldMessenger.of(context).showSnackBar(
    //        const SnackBar(content: Text("Please fill in username, password, and full name to generate a card.")),
    //     );
    //     return;
    // }

    try {
      // Get the directory of the currently running home_bank.exe
      final String exePath = Platform.resolvedExecutable;
      final String exeDir = p.dirname(exePath);

      // Construct the relative path to the bundled bank_card_generator.exe
      // This path assumes your Flutter build bundles assets as expected for Windows.
      final String executableRelativePath = p.join(
          'data', 'flutter_assets', 'assets', 'executables', 'bank_card_generator', 'bank_card_generator.exe');
      final String generatorPath = p.join(exeDir, executableRelativePath);

      _logger.i("Attempting to launch bank card generator from: $generatorPath");
      _logger.i("With arguments: --username '$username' --password '$password' --fullname '$fullName'");

      // Check if the executable exists before trying to run it
      final generatorFile = File(generatorPath);
      if (!await generatorFile.exists()) {
        _logger.e("Bank card generator executable not found at $generatorPath");
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Error: Bank card generator executable not found.")),
          );
        }
        return;
      }
      
      // runInShell: true can be useful on Windows if you have issues with paths or permissions,
      // but it's also good to try without it first.
      // If bank_card_generator.exe is a console app, a console window might flash open.
      final processResult = await Process.run(
        generatorPath,
        [
          '--APP_USERNAME',
          username,
          '--APP_PASSWORD',
          password, 
          // '--fullname',
          // fullName,
        ],
        workingDirectory: p.dirname(generatorPath), // Optional: set working directory if .exe needs it
      );

      _logger.i("Bank card generator stdout: ${processResult.stdout}");
      _logger.e("Bank card generator stderr: ${processResult.stderr}");
      _logger.i("Bank card generator exit code: ${processResult.exitCode}");

      if (!mounted) return;

      if (processResult.exitCode == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bank card generator launched successfully (check its output).")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Bank card generator failed. Exit code: ${processResult.exitCode}. Error: ${processResult.stderr}")),
        );
      }
    } catch (e, s) {
      _logger.e("Error launching bank card generator: $e", error: e, stackTrace: s);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("An error occurred while launching the card generator: $e")),
      );
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
                setState(() {
                  _currentStep = CreateUserStep.enterCredentials;
                  _createdUserId = null; 
                });
              } else {
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
              const SizedBox(height: 10), // Reduced spacing a bit
              if (Platform.isWindows) // Conditionally display the button
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.credit_card),
                    label: const Text('Generate User Card'),
                    onPressed: _launchBankCardGenerator,
                    style: ElevatedButton.styleFrom(
                      // backgroundColor: Colors.teal, // Optional: for distinct styling
                    ),
                  ),
                ),
              const SizedBox(height: 10), // Adjusted spacing
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
