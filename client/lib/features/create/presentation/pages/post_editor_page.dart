// lib/features/create/presentation/pages/post_editor_page.dart
//
// Bridge: delegates directly to the existing FilterEditPage.
// Receives the first pre-selected [file] from MediaPickerPage.

import 'dart:io';

import 'package:flutter/cupertino.dart';

import '../../../post/presentation/pages/filter_edit_page.dart';

class PostEditorPage extends StatelessWidget {
  final List<File> files;

  const PostEditorPage({super.key, required this.files});

  @override
  Widget build(BuildContext context) {
    return FilterEditPage(images: files);
  }
}
