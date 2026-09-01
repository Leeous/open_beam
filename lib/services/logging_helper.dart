import 'package:flutter/foundation.dart';

void dPrint(Object? o1, [Object? o2, Object? o3, Object? o4]) {
  if (kDebugMode) {
    final items = [o1, o2, o3, o4].where((e) => e != null);
    print(items);
  }
}
