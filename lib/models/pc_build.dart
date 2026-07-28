import 'dart:convert';
import 'component.dart';

class PcBuild {
  final String id;
  final String name;
  final DateTime createdAt;
  /// All components except storage and RAM (one per category).
  final Map<ComponentCategory, Component> components;
  /// Supports multiple storage drives.
  final List<Component> storageList;
  /// Supports multiple RAM sticks (up to motherboard slot count).
  final List<Component> ramList;

  PcBuild({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.components,
    this.storageList = const [],
    this.ramList = const [],
  });

  double get totalPrice =>
      components.values.fold(0.0, (sum, c) => sum + c.price) +
      storageList.fold(0.0, (sum, c) => sum + c.price) +
      ramList.fold(0.0, (sum, c) => sum + c.price);

  int get totalTdp {
    int tdp = 0;
    if (components[ComponentCategory.cpu] != null) {
      tdp += components[ComponentCategory.cpu]!.tdp ?? 0;
    }
    if (components[ComponentCategory.gpu] != null) {
      tdp += components[ComponentCategory.gpu]!.powerDraw ?? 0;
    }
    return tdp;
  }

  int get recommendedPsu => (totalTdp * 1.3 + 100).round();

  bool get isComplete {
    const required = [
      ComponentCategory.cpu,
      ComponentCategory.gpu,
      ComponentCategory.psu,
      ComponentCategory.motherboard,
    ];
    return required.every((c) => components.containsKey(c)) &&
        storageList.isNotEmpty &&
        ramList.isNotEmpty;
  }

  PcBuild copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    Map<ComponentCategory, Component>? components,
    List<Component>? storageList,
    List<Component>? ramList,
  }) {
    return PcBuild(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      components: components ?? Map.from(this.components),
      storageList: storageList ?? List.from(this.storageList),
      ramList: ramList ?? List.from(this.ramList),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'componentIds': components.map(
        (k, v) => MapEntry(k.key, v.id),
      ),
      'storageIds': storageList.map((c) => c.id).toList(),
      'ramIds': ramList.map((c) => c.id).toList(),
    };
  }

  /// Кодирует сборку в текстовый код для шаринга.
  /// Формат: base64url({ v:2, n:"name", c:{ "cpu":"cpu_001", ... }, s:["storage-001"], r:["ram-001"] })
  String toShareCode() {
    final data = <String, dynamic>{
      'v': 2,
      'n': name,
      'c': components.map((k, v) => MapEntry(k.key, v.id)),
      's': storageList.map((c) => c.id).toList(),
      'r': ramList.map((c) => c.id).toList(),
    };
    return base64Url.encode(utf8.encode(jsonEncode(data)));
  }
}
