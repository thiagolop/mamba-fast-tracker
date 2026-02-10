import 'package:flutter/material.dart';

class AuthInputField extends StatelessWidget {
  const AuthInputField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.focusNode,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.errorText,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: focusNode.hasFocus
            ? [
                BoxShadow(
                  color: colorScheme.primary.withAlpha(0x26),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            autocorrect: false,
            obscureText: obscureText,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              suffixIcon: suffixIcon,
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: errorText == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      errorText!,
                      style: TextStyle(
                        color: colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
