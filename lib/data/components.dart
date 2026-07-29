import '../models/component.dart';
import 'cpu_components.dart';
import 'gpu_components.dart';
import 'ram_components.dart';
import 'storage_components.dart';
import 'psu_components.dart';
import 'motherboard_components.dart';
import 'case_components.dart';
import 'cooling_components.dart';

final List<Component> allComponents = [
  ...cpuComponents,
  ...gpuComponents,
  ...ramComponents,
  ...storageComponents,
  ...psuComponents,
  ...motherboardComponents,
  ...caseComponents,
  ...coolingComponents,
];

// O(1) lookup by id — built once on first access
Map<String, Component>? _componentIndex;

Map<String, Component> get _index {
  _componentIndex ??= {for (final c in allComponents) c.id: c};
  return _componentIndex!;
}

Component? findComponentById(String id) => _index[id];

// Grouped by category
Map<ComponentCategory, List<Component>> get componentsByCategory {
  final map = <ComponentCategory, List<Component>>{};
  for (final c in allComponents) {
    map.putIfAbsent(c.category, () => []).add(c);
  }
  return map;
}

List<Component> getByCategory(ComponentCategory cat) =>
    allComponents.where((c) => c.category == cat).toList();
