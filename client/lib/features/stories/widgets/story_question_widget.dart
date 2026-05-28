import 'package:flutter/material.dart';
import '../models/story_model.dart';

class StoryQuestionWidget extends StatelessWidget {
  final StoryQuestionData question;
  final VoidCallback? onTap;

  const StoryQuestionWidget({
    super.key,
    required this.question,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 16,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gradient Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFF007F), // Neon Pink
                      Color(0xFFFF7F00), // Orange
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.help_outline_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      question.prompt,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Answer visual field
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                child: Container(
                  height: 48,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    question.myAnswer ?? 'Type something...',
                    style: TextStyle(
                      color: question.myAnswer != null
                          ? Colors.black87
                          : Colors.black38,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
