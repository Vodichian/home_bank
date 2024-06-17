import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:home_bank/bank/user.dart'; // Import the User class

class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  _CreateUserScreenState createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {final _formKey = GlobalKey<FormState>();
final _fullNameController = TextEditingController();
final _userIdController = TextEditingController();
final _nicknameController = TextEditingController();
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
                if (value == null || value.isEmpty) {return 'Please enter a full name';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _userIdController,
              decoration: const InputDecoration(labelText: 'User ID'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a user ID';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _nicknameController,
              decoration: const InputDecoration(labelText: 'Nickname (Optional)'),
            ),
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
                  User newUser = User(
                    fullName: _fullNameController.text,
                    userId: _userIdController.text,
                    nickname: _nicknameController.text.isNotEmpty
                        ? _nicknameController.text
                        : null,
                    imagePath: _imagePath,
                  );

                  // TODO: Handle saving the newUser object (e.g., to a database)
                  // You can use Navigator.pop(context, newUser) to return the user object
                  // to the previous screen if needed.

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User created!')),
                  );
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
  _userIdController.dispose();
  _nicknameController.dispose();
  super.dispose();
}
}