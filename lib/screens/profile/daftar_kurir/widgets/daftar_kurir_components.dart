import 'package:flutter/material.dart';
import 'daftar_kurir_constants.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: DaftarKurirColors.primary,
          disabledBackgroundColor: DaftarKurirColors.textMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                text,
                style: DaftarKurirTextStyles.buttonText,
              ),
      ),
    );
  }
}

class OutlineButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const OutlineButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: DaftarKurirColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          text,
          style: DaftarKurirTextStyles.buttonText.copyWith(
              color: DaftarKurirColors.textDark,
          ),
        ),
      ),
    );
  }
}

class StepProgressIndicator extends StatelessWidget {
  final int totalSteps;
  final int currentStep;

  const StepProgressIndicator({
    super.key,
    required this.totalSteps,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    List<Widget> indicators = [];
    for (int i = 0; i < totalSteps; i++) {
      bool isCompleted = i <= currentStep; // including current step as active
      
      indicators.add(
        Container(
          width: 24,
          height: 4,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: isCompleted 
                ? DaftarKurirColors.primary 
                : DaftarKurirColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: indicators,
    );
  }
}

class ScreenLayout extends StatelessWidget {
  final String? title;
  final Widget child;
  final Widget? bottomAction;
  final int? currentStep;
  final int? totalSteps;
  final VoidCallback? onBackPressed;
  final bool transparentBottomAction;

  const ScreenLayout({
    super.key,
    this.title,
    required this.child,
    this.bottomAction,
    this.currentStep,
    this.totalSteps,
    this.onBackPressed,
    this.transparentBottomAction = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DaftarKurirColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DaftarKurirColors.textDark),
          onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
        ),
        title: title != null 
            ? Text(
                title!,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: DaftarKurirColors.textDark,
                  ),
              )
            : null,
        actions: [
          if (currentStep != null && totalSteps != null)
            Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: Center(
                child: StepProgressIndicator(
                  currentStep: currentStep!,
                  totalSteps: totalSteps!,
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: DaftarKurirColors.border,
            height: 1.0,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: child,
              ),
            ),
            if (bottomAction != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: transparentBottomAction
                    ? null
                    : const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: DaftarKurirColors.border),
                        ),
                      ),
                child: bottomAction,
              ),
          ],
        ),
      ),
    );
  }
}

class CustomTextField extends StatelessWidget {
  final String label;
  final String hintText;
  final IconData? prefixIcon;
  final TextInputType keyboardType;
  final int maxLines;
  final bool isRequired;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  const CustomTextField({
    super.key,
    required this.label,
    required this.hintText,
    this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.isRequired = false,
    this.controller,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: DaftarKurirTextStyles.label,
            children: [
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: DaftarKurirColors.error),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: DaftarKurirColors.textDark,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              fontWeight: FontWeight.w400,
              color: DaftarKurirColors.textMuted,
            ),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: DaftarKurirColors.textMuted)
                : null,
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: DaftarKurirColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: DaftarKurirColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: DaftarKurirColors.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
