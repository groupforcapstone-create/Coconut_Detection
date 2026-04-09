import 'package:flutter/foundation.dart';

/// Notifies listeners when a new scan is added to history.
///
/// The value itself is an integer counter that increments each time a scan is saved.
final ValueNotifier<int> historyUpdateNotifier = ValueNotifier<int>(0);
