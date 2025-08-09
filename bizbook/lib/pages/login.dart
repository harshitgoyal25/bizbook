import 'package:bizbook/backend/auth.dart';
import 'package:bizbook/cus_page/cus_dashboard.dart';
import 'package:bizbook/pages/dashboard.dart'; // Import AuthService
import 'package:bizbook/pages/forget.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  bool _obscureText = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String _selectedUserType = 'Admin'; // Default user type
  final List<String> _userTypes = ['Admin', 'Customer'];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Color(0xFF5F7C58),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(
                        text: 'BiZ',
                        style: TextStyle(color: Color(0xFFE2AD38))),
                    TextSpan(
                        text: 'Book', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Login!',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
              SizedBox(height: 20),
              Container(
                width: width - width / 30,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome Back!',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Login to your account securely.',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'User Type',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButton<String>(
                      value: _selectedUserType,
                      isExpanded: true,
                      items: _userTypes.map((String userType) {
                        return DropdownMenuItem<String>(
                          value: userType,
                          child: Text(userType),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedUserType = newValue!;
                        });
                      },
                    ),
                    SizedBox(height: 15),
                    Text(
                      'Email Address',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'Enter Email Address',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 15),
                    Text(
                      'Password',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscureText,
                      decoration: InputDecoration(
                        hintText: 'Enter password',
                        border: OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureText
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureText = !_obscureText;
                            });
                          },
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        child: Text(
                          'Forgot your password?',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => ForgetPage(),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 15),
                    _isLoading
                        ? Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(double.infinity, 50),
                            ),
                            onPressed: () async {
                              if (_emailController.text.isEmpty ||
                                  _passwordController.text.isEmpty) {
                                AuthService().showToast(
                                  context,
                                  'Please enter email and password',
                                  false,
                                );
                                return;
                              }

                              setState(() {
                                _isLoading = true;
                              });

                              if (_selectedUserType == 'Admin') {
                                // Admin login using Firebase Auth
                                final user = await _authService
                                    .signInWithEmailAndPassword(
                                  _emailController.text,
                                  _passwordController.text,
                                );

                                setState(() {
                                  _isLoading = false;
                                });

                                if (user != null) {
                                  if (!context.mounted) return;

                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const Dashboard(),
                                    ),
                                  );
                                } else {
                                  if (!context.mounted) return;
                                  AuthService().showToast(
                                    context,
                                    "Invalid email or password!",
                                    false,
                                  );
                                }
                              } else if (_selectedUserType == 'Customer') {
                                // Customer login using Firebase Realtime Database
                                final customerSnapshot = await FirebaseDatabase
                                    .instance
                                    .ref()
                                    .child('customers')
                                    .orderByChild('email')
                                    .equalTo(_emailController.text)
                                    .once();

                                setState(() {
                                  _isLoading = false;
                                });

                                if (customerSnapshot.snapshot.value != null) {
                                  final customerData =
                                      (customerSnapshot.snapshot.value as Map)
                                          .values
                                          .first;

                                  if (customerData['password'] ==
                                      _passwordController.text) {
                                    // Save customer details in SharedPreferences
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.setString('customerId',
                                        customerData['customerId']);
                                    await prefs.setString(
                                        'customerName', customerData['name']);

                                    if (!context.mounted) return;

                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const CusDashboard(),
                                      ),
                                    );
                                  } else {
                                    if (!context.mounted) return;
                                    AuthService().showToast(
                                      context,
                                      "Invalid email or password!",
                                      false,
                                    );
                                  }
                                } else {
                                  if (!context.mounted) return;

                                  AuthService().showToast(
                                    context,
                                    "Customer not found!",
                                    false,
                                  );
                                }
                              }
                            },
                            child: Text('Login'),
                          ),
                    SizedBox(height: 15),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
