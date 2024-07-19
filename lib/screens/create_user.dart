import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:home_bank/bank/bank_facade.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart'; // Import the User class

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
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  String? _imagePath;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imagePath = pickedFile.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    BankFacade bank = context.read();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create User'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a full name';
                  }
                  return null;
                },
              ),
              FutureBuilder(
                  future: bank.hasUsername(_usernameController.text),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator(); // Show a loading indicator while checking
                    } else if (snapshot.hasError) {
                      return Text(
                          'Error: ${snapshot.error}'); // Display an error message
                    } else {
                      bool hasUsername =
                          snapshot.data ?? false; // Get the result
                      return TextFormField(
                        controller: _usernameController,
                        decoration:
                            const InputDecoration(labelText: 'Username'),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a username';
                          } else if (hasUsername) {
                            return 'User name is already taken';
                          }
                          return null;
                        },
                      );
                    }
                  }),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _pickImage,
                child: const Text('Choose Image'),
              ),
              if (_imagePath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Image.file(File(_imagePath!), height: 100),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // Create User object
                    try {
                      bank.createUser(_fullNameController.text,
                          _usernameController.text, _imagePath);
                    } on Exception catch (e) {
                      _logger.d('Failed to create user: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to create user: $e')));
                      return;
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User created!')),
                    );

                    // TODO: Find a way to include new user in navigation to HomeScreen
                    context.go('/login');
                  }
                },
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
    _fullNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }
}
