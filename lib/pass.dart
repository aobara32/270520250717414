import 'package:flutter/material.dart';
import 'package:master/env/env.dart';

class PasswordGate extends StatefulWidget {
  final void Function() onAuthenticated;
  const PasswordGate({super.key, required this.onAuthenticated});

  @override
  State<PasswordGate> createState() => _PasswordGateState();
}

class _PasswordGateState extends State<PasswordGate> {
  final TextEditingController _controller = TextEditingController();
  final String _fixedPassword = Env.KEY; // 固定パスワード（アップデート以外で変更不可）
  String? _error;

  void _checkPassword() {
    if (_controller.text == _fixedPassword) {
      widget.onAuthenticated();
    } else {
      setState(() {
        _error = 'Incorrect password';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Employee Only Password',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Password',
                  errorText: _error,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _checkPassword(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _checkPassword,
                  child: const Text('Login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
