import 'package:flutter/material.dart';

class StudentOnboarding extends StatefulWidget {
  const StudentOnboarding({super.key});

  @override
  State<StudentOnboarding> createState() => _StudentOnboardingState();
}

class _StudentOnboardingState extends State<StudentOnboarding> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _parentNameController = TextEditingController();
  final TextEditingController _studentNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _parentNameController.dispose();
    _studentNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _createAccountAndContinue() {
    if (!_formKey.currentState!.validate()) return;

    // In this PoC we don't persist an account; just pass studentName forward
    Navigator.pushNamed(context, '/questionnaire', arguments: {
      'studentName': _studentNameController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _parentNameController,
                decoration: const InputDecoration(labelText: 'Parent / Guardian Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _studentNameController,
                decoration: const InputDecoration(labelText: 'Student Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter student name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email (optional)'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _createAccountAndContinue,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 20),
                  child: Text('Create account and start questionnaire'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
