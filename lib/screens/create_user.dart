import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:home_bank/bank/bank_facade.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  createState() => _CreateUserScreenState();
}

final Logger _logger = Logger(
  printer: PrettyPrinter(methodCount: 0),
);

class _CreateUserScreenState extends State<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  String? _imagePath; // Consider if you will use this for createUser

  // It's good practice to handle async operations in a separate async method
  Future<void> _createUserAndNavigate() async {
    // It's crucial that this check happens *before* any async gaps
    // if the BuildContext is needed *after* the gap.
    // However, for this specific case, we will check mounted *after* the async operation.
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final bank = context.read<BankFacade>();
    final String username = _usernameController.text;
    final String password = _passwordController.text;

    // It's good to show a loading indicator here if the operation might take time
    // For example, by setting a _isLoading state variable and rebuilding.

    try {
      // Use await to make the flow more sequential
      await bank.createUser(username, password);

      // Check if the widget is still mounted AFTER the await
      if (!mounted) return; // Primary guard

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User created!')),
      );
      // TODO: Find a way to include new user in navigation to HomeScreen
      context.go('/login'); // Safe to use context here

    } catch (onError) {
      _logger.d('Failed to create user: $onError');
      // Check if the widget is still mounted AFTER the await (or inside catchError)
      if (!mounted) return; // Primary guard

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to create user: $onError')));
    } finally {
      // Hide loading indicator if you showed one
      // if (mounted) {
      //   setState(() { _isLoading = false; });
      // }
    }
  }


  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    // Check mounted after await
    if (!mounted) return;

    if (pickedFile != null) {
      setState(() {
        _imagePath = pickedFile.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create User'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (mounted) { // Good practice for immediate context use too
                context.go('/login');
              }
            }
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true, // Good for passwords
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 6) { // Example: minimum password length
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Added spacing
              // FutureBuilder for username validation (as in your original code)
              // Ensure BankFacade is available here
              Consumer<
                  BankFacade>( // Or context.read<BankFacade>() directly if appropriate
                  builder: (context, bank, child) {
                    // Note: The FutureBuilder itself will rebuild when _usernameController changes if you
                    // trigger a rebuild of the parent widget (e.g., by calling setState for other reasons,
                    // or if _usernameController.text is used as a key or dependency for the future).
                    // For real-time validation as the user types, you'd typically use the onChanged
                    // property of TextFormField and manage state accordingly, possibly debouncing the check.
                    // This FutureBuilder setup will check when the widget initially builds or when it's explicitly rebuilt.
                    // To make FutureBuilder re-evaluate when usernameController changes text you need to ensure
                    // that the future itself changes. One way is to pass the text as a parameter to future:
                    // future: bank.hasUsername(_usernameController.text),
                    // and ensure that some parent widget rebuilds when text changes (e.g. via textfield's onChanged + setState)
                    return TextFormField(
                      controller: _usernameController,
                      decoration:
                      const InputDecoration(labelText: 'Username'),
                      // For async validation, it's often better to validate on blur or on explicit submit,
                      // or use a debounced onChanged. Real-time async validation in validator can be tricky.
                      // The FutureBuilder approach you had before `TextFormField` is one way to show
                      // status *outside* the validator.
                      // If you want validation *within* the validator using an async check,
                      // it's more complex as `validator` must be synchronous.
                      // A common pattern is to validate synchronously for format/emptiness,
                      // and use a separate mechanism (like your FutureBuilder or a state variable updated
                      // by `onChanged` and `bank.hasUsername`) to show availability.

                      // Let's stick to your original structure of having FutureBuilder *around* the TextFormField
                      // for the username availability, which is a reasonable approach.
                      // The following is just a simple synchronous validator.
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a username';
                        }
                        // Asynchronous username taken check is handled by the FutureBuilder in your original code.
                        // If you want it part of this validator, it becomes more complex.
                        return null;
                      },
                    );
                  }
              ),
              // This is how your FutureBuilder for username validation was structured.
              // We need to ensure it rebuilds when the username text potentially changes.
              // One way is to trigger a rebuild (e.g. setState in onChanged of username field)
              // This is a simplified version just to get the structure right
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _usernameController,
                builder: (context, value, child) {
                  // This builder will run whenever _usernameController.text changes.
                  // Now, use FutureBuilder inside this if you want to perform async validation based on current text.
                  return FutureBuilder<bool>(
                    future: context.read<BankFacade>().hasUsername(value.text),
                    // Pass current text
                    builder: (context, snapshot) {
                      String? errorText;
                      if (snapshot.connectionState == ConnectionState.active ||
                          snapshot.connectionState == ConnectionState.waiting) {
                        // Optionally show a small loading indicator next to the field or disable submit
                        // For simplicity, we won't add an error text while loading.
                      } else if (snapshot.hasError) {
                        // Handle error from hasUsername call itself (e.g., network issue)
                        // errorText = 'Error checking username';
                        // _logger.e("Error checking username: ${snapshot.error}");
                      } else if (snapshot.hasData && snapshot.data == true &&
                          value.text.isNotEmpty) {
                        // Only show "taken" if the field is not empty and hasUsername is true
                        errorText = 'Username is already taken';
                      }

                      // We are not directly returning TextFormField here as it's above.
                      // This FutureBuilder is meant to provide the error message to the TextFormField.
                      // A better way is to manage the errorText in the state and update the
                      // decoration of the TextFormField.

                      // For now, to keep it simple and similar to your original intent but fixing the update:
                      // If there is an errorText from the async validation, you could display it separately
                      // or use it to inform the Form's validation logic when submit is pressed.
                      // This particular placement of FutureBuilder is more for displaying info *next* to the field.

                      // Let's adjust for a more direct validation feedback on the field itself.
                      // This is better done by having the TextFormField's validator use state
                      // that is updated by this FutureBuilder's result or an onChanged handler.

                      // For the sake of completing the structure based on your initial FutureBuilder:
                      if (errorText != null) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(errorText, style: TextStyle(color: Theme
                              .of(context)
                              .colorScheme
                              .error, fontSize: 12)),
                        );
                      }
                      return const SizedBox.shrink(); // No error to show
                    },
                  );
                },
              ),


              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _pickImage, // Calls the refactored _pickImage
                child: const Text('Choose Image (Optional)'),
              ),
              if (_imagePath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Image.file(File(_imagePath!), height: 100),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _createUserAndNavigate, // Calls the new async method
                child: const Text('Create User'),
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
    super.dispose();
  }
}