import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../widgets/custom_input.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _fullnameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6C63FF),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.06 * 255).toInt()),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    'Create Account',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: const Color(0xFF6C63FF),
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text('Username',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                CustomInput(
                    hintText: 'Enter your username',
                    controller: _usernameController,
                    enabled: !_isLoading),
                const SizedBox(height: 18),
                const Text('Full Name',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                CustomInput(
                    hintText: 'Enter your full name',
                    controller: _fullnameController,
                    enabled: !_isLoading),
                const SizedBox(height: 18),
                const Text('Email',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                CustomInput(
                    hintText: 'Enter your email',
                    controller: _emailController,
                    enabled: !_isLoading),
                const SizedBox(height: 18),
                const Text('Password',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                CustomInput(
                    hintText: 'Enter your password',
                    controller: _passwordController,
                    obscureText: true,
                    enabled: !_isLoading),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _isLoading
                        ? null
                        : () async {
                            final username = _usernameController.text.trim();
                            final fullname = _fullnameController.text.trim();
                            final email = _emailController.text.trim();
                            final password = _passwordController.text.trim();

                            if (email.isEmpty ||
                                password.isEmpty ||
                                username.isEmpty ||
                                fullname.isEmpty) {
                              // ignore: use_build_context_synchronously
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Please fill in all fields')),
                              );
                              return;
                            }

                            setState(() {
                              _isLoading = true;
                            });

                            try {
                              // Check if email already exists
                              final existingUser = await Supabase
                                  .instance.client
                                  .from('users')
                                  .select()
                                  .eq('email', email)
                                  .maybeSingle();

                              if (existingUser != null) {
                                if (!mounted) return;
                                // ignore: use_build_context_synchronously
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Email already registered'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                if (mounted) {
                                  setState(() {
                                    _isLoading = false;
                                  });
                                }
                                return;
                              }

                              // Generate a proper UUID for the user
                              const uuid = Uuid();
                              final userId = uuid.v4();

                              // Insert user profile data with plaintext password
                              await Supabase.instance.client
                                  .from('users')
                                  .insert({
                                'id': userId,
                                'username': username,
                                'full_name': fullname,
                                'email': email,
                                'password': password,
                              });

                              if (!mounted) return;
                              // ignore: use_build_context_synchronously
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('✓ Signup successful!')),
                              );
                              // ignore: use_build_context_synchronously
                              Navigator.pushReplacementNamed(context, '/login');
                            } catch (e) {
                              // Check mounted before using context in catch
                              if (!mounted) return;
                              // ignore: use_build_context_synchronously
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            }
                          },
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Sign Up',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
