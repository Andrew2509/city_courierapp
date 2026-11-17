import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
            : Text(text, style: DaftarKurirTextStyles.buttonText),
      ),
    );
  }
}

class OutlineButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const OutlineButton({super.key, required this.text, required this.onPressed});

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

    return Row(mainAxisSize: MainAxisSize.min, children: indicators);
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
          child: Container(color: DaftarKurirColors.border, height: 1.0),
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
  final String? helperText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final bool isRequired;
  final bool readOnly;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;

  const CustomTextField({
    super.key,
    required this.label,
    required this.hintText,
    this.helperText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.maxLines = 1,
    this.isRequired = false,
    this.readOnly = false,
    this.controller,
    this.onChanged,
    this.onTap,
    this.validator,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    Widget buildField(String text) {
      // Tampilkan centang hijau hanya saat isi kolom lolos validasi.
      final isValid =
          validator != null && text.isNotEmpty && validator!(text) == null;

      return TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onChanged: onChanged,
        readOnly: readOnly,
        onTap: onTap,
        inputFormatters: inputFormatters,
        validator: validator,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: DaftarKurirColors.textDark,
        ),
        decoration: buildDaftarKurirFieldDecoration(
          hintText: hintText,
          helperText: helperText,
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: DaftarKurirColors.textMuted)
              : null,
          suffixIcon: isValid
              ? const Icon(
                  Icons.check_circle_rounded,
                  color: DaftarKurirColors.success,
                  size: 20,
                )
              : suffixIcon,
        ),
        errorBuilder: (context, errorText) =>
            DaftarKurirFieldError(message: errorText),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DaftarKurirFieldLabel(label: label, isRequired: isRequired),
        const SizedBox(height: 8),
        if (controller == null)
          buildField('')
        else
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller!,
            builder: (context, value, _) => buildField(value.text),
          ),
      ],
    );
  }
}

class CustomDropdownField<T> extends StatelessWidget {
  final String label;
  final String hintText;
  final String? helperText;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T>? validator;
  final bool isRequired;

  const CustomDropdownField({
    super.key,
    required this.label,
    required this.hintText,
    required this.items,
    this.helperText,
    this.value,
    this.onChanged,
    this.validator,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    final isValid = validator != null && value != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DaftarKurirFieldLabel(label: label, isRequired: isRequired),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          isDense: false,
          icon: const Icon(
            Icons.arrow_drop_down,
            color: DaftarKurirColors.textMuted,
          ),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: DaftarKurirColors.textDark,
          ),
          hint: Text(
            hintText,
            style: const TextStyle(
              fontWeight: FontWeight.w400,
              color: DaftarKurirColors.textMuted,
            ),
          ),
          items: items,
          onChanged: onChanged,
          validator: validator,
          decoration: buildDaftarKurirFieldDecoration(
            helperText: helperText,
            suffixIcon: isValid
                ? const Icon(
                    Icons.check_circle_rounded,
                    color: DaftarKurirColors.success,
                    size: 20,
                  )
                : null,
          ),
          errorBuilder: (context, errorText) =>
              DaftarKurirFieldError(message: errorText),
        ),
      ],
    );
  }
}

/// Label seragam untuk seluruh kolom formulir pendaftaran kurir.
class DaftarKurirFieldLabel extends StatelessWidget {
  final String label;
  final bool isRequired;

  const DaftarKurirFieldLabel({
    super.key,
    required this.label,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
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
    );
  }
}

/// Pesan kesalahan di bawah kolom, lengkap dengan ikon peringatan.
class DaftarKurirFieldError extends StatelessWidget {
  final String message;

  const DaftarKurirFieldError({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline,
              size: 14,
              color: DaftarKurirColors.error,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                height: 1.3,
                color: DaftarKurirColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dekorasi dasar kolom: border default, focus, error, dan teks keterangan.
InputDecoration buildDaftarKurirFieldDecoration({
  String? hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? helperText,
}) {
  final OutlineInputBorder defaultBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: DaftarKurirColors.border),
  );

  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      fontWeight: FontWeight.w400,
      color: DaftarKurirColors.textMuted,
    ),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    helperText: helperText,
    helperStyle: const TextStyle(
      fontSize: 12,
      height: 1.3,
      color: DaftarKurirColors.textSub,
    ),
    helperMaxLines: 2,
    errorMaxLines: 2,
    contentPadding: const EdgeInsets.all(16),
    border: defaultBorder,
    enabledBorder: defaultBorder,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: DaftarKurirColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: DaftarKurirColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: DaftarKurirColors.error, width: 2),
    ),
  );
}
