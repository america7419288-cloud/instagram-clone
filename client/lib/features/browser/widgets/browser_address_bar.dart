import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:instagram_client/core/theme/app_theme.dart';

class BrowserAddressBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isFocused;
  final bool isSecure;
  final String displayUrl;
  final String currentTitle;
  final bool isDark;
  final Function(String) onSubmit;
  final VoidCallback onClear;

  const BrowserAddressBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isFocused,
    required this.isSecure,
    required this.displayUrl,
    required this.currentTitle,
    required this.isDark,
    required this.onSubmit,
    required this.onClear,
  });

  @override
  State<BrowserAddressBar> createState() => _BrowserAddressBarState();
}

class _BrowserAddressBarState extends State<BrowserAddressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _expand;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: 200.ms);
    _expand = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(BrowserAddressBar old) {
    super.didUpdateWidget(old);
    if (old.isFocused != widget.isFocused) {
      widget.isFocused ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return GestureDetector(
      onTap: () {
        widget.focusNode.requestFocus();
      },
      child: AnimatedContainer(
        duration: 200.ms,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isDark
            ? const Color(0xFF2C2C2E)
            : const Color(0xFFEFEFEF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const SizedBox(width: 8),

            // Security icon
            AnimatedSwitcher(
              duration: 200.ms,
              child: widget.isSecure
                ? const Icon(
                    CupertinoIcons.lock_fill,
                    key: ValueKey('secure'),
                    size: 13,
                    color: Color(0xFF58C322),
                  )
                : Icon(
                    CupertinoIcons.info_circle,
                    key: const ValueKey('insecure'),
                    size: 13,
                    color: isDark
                      ? Colors.white54
                      : Colors.black45,
                  ),
            ),

            const SizedBox(width: 6),

            // URL text field
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                textAlign: widget.isFocused ? TextAlign.left : TextAlign.center,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.none,
                ),
                decoration: InputDecoration(
                  hintText: widget.isFocused
                    ? 'Search or enter URL'
                    : widget.displayUrl.isEmpty
                        ? 'Search or enter URL'
                        : null,
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontSize: 14,
                    decoration: TextDecoration.none,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                onSubmitted: (val) {
                  final url = _resolveInput(val);
                  widget.onSubmit(url);
                },
                onTap: () {
                  widget.controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: widget.controller.text.length,
                  );
                },
              ),
            ),

            // Clear button (when focused & has text)
            AnimatedBuilder(
              animation: _expand,
              builder: (context, child) {
                if (!widget.isFocused ||
                    widget.controller.text.isEmpty) {
                  return const SizedBox(width: 8);
                }
                return GestureDetector(
                  onTap: widget.onClear,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      size: 16,
                      color: isDark
                        ? Colors.white38
                        : Colors.black26,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _resolveInput(String input) {
    input = input.trim();
    if (input.startsWith('http://') || input.startsWith('https://')) {
      return input;
    }
    // Is it a domain?
    if (input.contains('.') && !input.contains(' ')) {
      return 'https://$input';
    }
    // Search query
    final query = Uri.encodeComponent(input);
    return 'https://www.google.com/search?q=$query';
  }
}
