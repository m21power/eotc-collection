// about_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mezgebe_sibhat/features/songs/presentation/bloc/song_bloc.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final _feedbackController = TextEditingController();
  final _telegramController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1800,
      maxHeight: 1800,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  void _showSuccess(String username) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          username == 'Not provided'
              ? 'Thank you for your feedback!'
              : 'Thank you! @$username, for your report! We will get back to you soon.',
        ),
        backgroundColor: Colors.green,
      ),
    );
    _resetForm();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _resetForm() {
    _feedbackController.clear();
    _telegramController.clear();
    setState(() => _selectedImage = null);
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    _telegramController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
      ),
      body: SafeArea(
        child: BlocConsumer<SongBloc, SongState>(
          listener: (context, songState) {
            if (songState is FeedbackSubmittedState) {
              _showSuccess(
                _telegramController.text.trim().isEmpty
                    ? 'Not provided'
                    : _telegramController.text.trim(),
              );
            } else if (songState is FeedbackSubmissionFailedState) {
              _showError(songState.message);
            }
          },
          builder: (context, songState) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // About Section
                  Text('መዝገበ ስብሐት', style: theme.textTheme.displayMedium),
                  const SizedBox(height: 12),

                  Center(
                    child: Text(
                      'Treasury of Ethiopian Orthodox Tewahedo Church Teachings',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 28),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: RichText(
                      textAlign: TextAlign.justify,
                      text: TextSpan(
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
                        children: [
                          const TextSpan(
                            text:
                                'This application is dedicated to every soul who desires to learn the sacred teachings of the '
                                'Ethiopian Orthodox Tewahedo Church, yet has not had the opportunity to do so in traditional settings. '
                                'Whether due to distance, time, or circumstance, this digital treasury brings centuries of spiritual wisdom '
                                ' preserved through chant, scripture, and oral tradition directly to your fingertips.\n\n',
                          ),
                          const TextSpan(
                            text:
                                'First and foremost, all glory and thanksgiving belong to God Almighty, '
                                'who inspired, guided, and empowered the creation of this app. '
                                'It is by His grace alone that this work has come to fruition.\n\n',
                          ),
                          const TextSpan(
                            text:
                                'We extend our deepest gratitude to our fathers  the monks, scholars, deacons, and faithful servants '
                                'across generations who recorded, preserved, and transmitted the sacred hymns, liturgical texts, '
                                'and theological teachings of our Church. '
                                'Though many of their names remain unknown to us today, their labor of love echoes through time '
                                'and now reaches a global audience in digital form.\n\n',
                          ),

                          TextSpan(
                            text:
                                'Version 1.0.0\n'
                                '© 2025 Mezgebe Sibhat',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withOpacity(0.7),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ──────────────────────────────────────────────────────
                  // Contact / Bug-Report Section
                  // ──────────────────────────────────────────────────────
                  Text(
                    'Contact Us – Report a Bug or Issue',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // ── Message (required) ─────────────────────────────────────
                        TextFormField(
                          controller: _feedbackController,
                          maxLines: 6,
                          decoration: InputDecoration(
                            hintText:
                                'Describe the bug, missing feature, or any issue…',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.black.withOpacity(0.03),
                          ),
                          validator: (v) => v!.trim().isEmpty
                              ? 'Please describe the issue'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // ── Telegram Username (optional) ────────────────────────
                        TextFormField(
                          controller: _telegramController,
                          decoration: InputDecoration(
                            hintText:
                                'Telegram username (optional, for follow-up)',
                            prefixText: '@',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.black.withOpacity(0.03),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Image Picker ────────────────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickImage,
                                icon: const Icon(Icons.attach_file),
                                label: Text(
                                  _selectedImage == null
                                      ? 'Attach Screenshot'
                                      : 'Change Screenshot',
                                ),
                              ),
                            ),
                            if (_selectedImage != null) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.red,
                                ),
                                onPressed: () =>
                                    setState(() => _selectedImage = null),
                              ),
                            ],
                          ],
                        ),

                        // ── Image Preview (optional) ─────────────────────────────
                        if (_selectedImage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _selectedImage!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),

                        const SizedBox(height: 24),

                        // ── Submit Button ────────────────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              if (songState.connectionEnabled == false) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: const [
                                        Icon(
                                          Icons.wifi_off,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            "Please enable your internet connection",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: Colors.redAccent,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    margin: const EdgeInsets.all(16),
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                                return;
                              }
                              if (_formKey.currentState!.validate()) {
                                BlocProvider.of<SongBloc>(context).add(
                                  SubmitFeedbackEvent(
                                    feedback: _feedbackController.text.trim(),
                                    fullname: _telegramController.text.trim(),
                                    imageFile: _selectedImage,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: songState is! SubmitFeedbackLoadingState
                                ? Text(
                                    'Send Report',
                                    style: TextStyle(fontSize: 16),
                                  )
                                : CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).splashColor,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
