import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Session search shared by Home and its contextual area routes.
class HomeSearchQuery extends Notifier<String> {
  @override
  String build() => '';
  void change(String value) => state = value;
}
