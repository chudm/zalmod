import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InlineAd extends ConsumerStatefulWidget {
  const InlineAd({super.key, required this.adUnit});
  final String adUnit;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _InlineAdState();
}

class _InlineAdState extends ConsumerState<InlineAd> {
  @override
  Widget build(BuildContext context) {
    // This ignores everything and just returns a zero-size box.
    // No ads will ever load, and no connection to Google Ads will be made.
    return const SizedBox.shrink();
  }
}
