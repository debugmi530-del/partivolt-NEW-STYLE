import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/component.dart';
import '../models/pc_build.dart';
import '../data/components.dart';

/// Результат импорта сборки из шер-кода.
class ImportResult {
  /// Готовая сборка (null если код невалиден).
  final PcBuild? build;

  /// Короткие названия категорий, чьи компоненты не нашлись в каталоге.
  final List<String> missingCategories;

  const ImportResult({this.build, required this.missingCategories});

  bool get success => build != null;
  bool get hasWarnings => missingCategories.isNotEmpty;
}

class AppProvider extends ChangeNotifier {
  // ── Build state ──
  PcBuild _currentBuild = PcBuild(
    id: 'current',
    name: 'Моя сборка',
    createdAt: DateTime.now(),
    components: {},
    storageList: [],
    ramList: [],
  );
  List<PcBuild> _savedBuilds = [];

  // ── Deep link pending import ──
  String? _pendingImportCode;
  String? get pendingImportCode => _pendingImportCode;
  void setPendingImportCode(String code) {
    _pendingImportCode = code;
    notifyListeners();
  }
  void clearPendingImportCode() {
    _pendingImportCode = null;
    // не notifyListeners — чтобы не зациклить rebuild
  }

  // ── Comparison ──
  List<Component> _compareComponents = [];

  // ── Filters & Search ──
  String _searchQuery = '';
  Map<String, Set<String>> _activeFilters = {};
  String _sortBy = 'price_asc';

  // ── Compatibility filter ──
  bool _compatibilityFilterEnabled = false;

  PcBuild get currentBuild => _currentBuild;
  List<PcBuild> get savedBuilds => _savedBuilds;
  List<Component> get compareComponents => _compareComponents;
  String get searchQuery => _searchQuery;
  Map<String, Set<String>> get activeFilters => _activeFilters;
  String get sortBy => _sortBy;
  bool get compatibilityFilterEnabled => _compatibilityFilterEnabled;

  AppProvider() {
    _load();
  }

  // ─── Build Management ───

  void addToBuild(Component component) {
    if (component.category == ComponentCategory.storage) {
      addStorageDrive(component);
      return;
    }
    if (component.category == ComponentCategory.ram) {
      addRamStick(component);
      return;
    }
    final updated = Map<ComponentCategory, Component>.from(_currentBuild.components);
    updated[component.category] = component;
    _currentBuild = _currentBuild.copyWith(components: updated);
    notifyListeners();
    _save();
  }

  void removeFromBuild(ComponentCategory category) {
    if (category == ComponentCategory.storage) return; // use removeStorageDriveAt
    if (category == ComponentCategory.ram) return; // use removeRamStickAt
    final updated = Map<ComponentCategory, Component>.from(_currentBuild.components);
    updated.remove(category);
    _currentBuild = _currentBuild.copyWith(components: updated);
    notifyListeners();
    _save();
  }

  // ─── Storage management ───

  /// Максимальное количество накопителей, которое поддерживает выбранный корпус.
  /// Если корпус не выбран — разрешаем до 6 штук по умолчанию.
  int get maxStorageSlots {
    final pcCase = _currentBuild.components[ComponentCategory.pcCase];
    return _maxStorageSlotsForCase(pcCase);
  }

  int _maxStorageSlotsForCase(Component? pcCase) {
    if (pcCase == null) return 6;
    final slots25 = int.tryParse(pcCase.specs['Отсеки 2.5"'] ?? '0') ?? 0;
    final slots35 = int.tryParse(pcCase.specs['Отсеки 3.5"'] ?? '0') ?? 0;
    return (slots25 + slots35).clamp(1, 99);
  }

  /// Возвращает null если можно добавить, иначе текст ошибки.
  String? canAddStorageDrive(Component component) {
    if (_currentBuild.storageList.length >= maxStorageSlots) {
      return 'Корпус поддерживает максимум $maxStorageSlots накопителя(-ей)';
    }
    return null;
  }

  void addStorageDrive(Component component) {
    if (_currentBuild.storageList.length >= maxStorageSlots) return;
    final newList = List<Component>.from(_currentBuild.storageList)..add(component);
    _currentBuild = _currentBuild.copyWith(storageList: newList);
    notifyListeners();
    _save();
  }

  /// Удаляет накопитель по индексу (поддерживает дубликаты).
  void removeStorageDriveAt(int index) {
    if (index < 0 || index >= _currentBuild.storageList.length) return;
    final newList = List<Component>.from(_currentBuild.storageList)..removeAt(index);
    _currentBuild = _currentBuild.copyWith(storageList: newList);
    notifyListeners();
    _save();
  }

  /// Количество накопителей с данным id в текущей сборке.
  int storageCountInBuild(String componentId) {
    return _currentBuild.storageList.where((c) => c.id == componentId).length;
  }

  /// Удаляет первый найденный накопитель с данным id (для экрана деталей).
  void removeFirstStorageDriveOccurrence(String componentId) {
    final idx = _currentBuild.storageList.indexWhere((c) => c.id == componentId);
    if (idx != -1) removeStorageDriveAt(idx);
  }

  // ─── RAM management ───

  /// Максимальное количество планок RAM, которое поддерживает выбранная мат. плата.
  /// Если мат. плата не выбрана — разрешаем до 4 штук по умолчанию.
  int get maxRamSlots {
    final mb = _currentBuild.components[ComponentCategory.motherboard];
    return _maxRamSlotsForMotherboard(mb);
  }

  int _maxRamSlotsForMotherboard(Component? mb) {
    if (mb == null) return 4;
    final slots = int.tryParse(mb.specs['Слоты памяти'] ?? '');
    if (slots != null && slots > 0) return slots;
    return 4;
  }

  /// Возвращает null если можно добавить планку RAM, иначе текст ошибки.
  String? canAddRamStick(Component component) {
    if (_currentBuild.ramList.length >= maxRamSlots) {
      return 'Материнская плата поддерживает максимум $maxRamSlots слота(-ов) памяти';
    }
    // Проверка совместимости типа с уже установленной памятью
    if (_currentBuild.ramList.isNotEmpty) {
      final existingType = _currentBuild.ramList.first.memoryType;
      if (existingType != null && component.memoryType != null &&
          existingType != component.memoryType) {
        return 'Нельзя смешивать разные типы памяти ($existingType и ${component.memoryType})';
      }
    }
    return null;
  }

  void addRamStick(Component component) {
    if (canAddRamStick(component) != null) return;
    final newList = List<Component>.from(_currentBuild.ramList)..add(component);
    _currentBuild = _currentBuild.copyWith(ramList: newList);
    notifyListeners();
    _save();
  }

  /// Удаляет планку RAM по индексу (поддерживает дубликаты).
  void removeRamStickAt(int index) {
    if (index < 0 || index >= _currentBuild.ramList.length) return;
    final newList = List<Component>.from(_currentBuild.ramList)..removeAt(index);
    _currentBuild = _currentBuild.copyWith(ramList: newList);
    notifyListeners();
    _save();
  }

  /// Количество планок RAM с данным id в текущей сборке.
  int ramCountInBuild(String componentId) {
    return _currentBuild.ramList.where((c) => c.id == componentId).length;
  }

  /// Удаляет первую найденную планку RAM с данным id (для экрана деталей).
  void removeFirstRamStickOccurrence(String componentId) {
    final idx = _currentBuild.ramList.indexWhere((c) => c.id == componentId);
    if (idx != -1) removeRamStickAt(idx);
  }

  // ─── Other build ops ───

  void setBuildName(String name) {
    _currentBuild = _currentBuild.copyWith(name: name);
    notifyListeners();
    _save();
  }

  void clearBuild() {
    _currentBuild = PcBuild(
      id: 'current',
      name: 'Моя сборка',
      createdAt: DateTime.now(),
      components: {},
      storageList: [],
      ramList: [],
    );
    notifyListeners();
    _save();
  }

  void saveBuild() {
    final build = PcBuild(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _currentBuild.name,
      createdAt: DateTime.now(),
      components: Map.from(_currentBuild.components),
      storageList: List.from(_currentBuild.storageList),
      ramList: List.from(_currentBuild.ramList),
    );
    _savedBuilds = [build, ..._savedBuilds];
    notifyListeners();
    _save();
  }

  void deleteSavedBuild(String id) {
    _savedBuilds = _savedBuilds.where((b) => b.id != id).toList();
    notifyListeners();
    _save();
  }

  void loadSavedBuild(PcBuild build) {
    _currentBuild = PcBuild(
      id: 'current',
      name: build.name,
      createdAt: DateTime.now(),
      components: Map.from(build.components),
      storageList: List.from(build.storageList),
      ramList: List.from(build.ramList),
    );
    notifyListeners();
    _save();
  }

  // ─── Sharing ───

  /// Декодирует шер-код и возвращает [ImportResult].
  ImportResult importBuildFromCode(String rawCode) {
    try {
      final trimmed = rawCode.trim();
      final jsonStr = utf8.decode(base64Url.decode(base64Url.normalize(trimmed)));
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Поддерживаем версии 1 и 2
      final version = data['v'] as int? ?? 1;
      if (version != 1 && version != 2) {
        return const ImportResult(missingCategories: ['Неизвестный формат кода']);
      }

      final name = (data['n'] as String?)?.trim();
      if (name == null || name.isEmpty) {
        return const ImportResult(missingCategories: ['Повреждённый код: нет названия']);
      }

      final rawComponents = data['c'] as Map<String, dynamic>?;
      if (rawComponents == null || rawComponents.isEmpty) {
        return const ImportResult(missingCategories: ['В коде нет компонентов']);
      }

      final components = <ComponentCategory, Component>{};
      final missingCategories = <String>[];

      for (final entry in rawComponents.entries) {
        final cat = _categoryFromKey(entry.key);
        if (cat == null) continue;
        // RAM теперь хранится в ramIds, пропускаем старый ключ 'ram' из components
        if (cat == ComponentCategory.ram) continue;

        final comp = findComponentById(entry.value as String);
        if (comp != null) {
          components[cat] = comp;
        } else {
          missingCategories.add(cat.shortName);
        }
      }

      // Восстанавливаем список накопителей
      final storageList = <Component>[];
      final rawStorage = data['s'] as List<dynamic>?;
      if (rawStorage != null) {
        for (final id in rawStorage) {
          final comp = findComponentById(id as String);
          if (comp != null) {
            storageList.add(comp);
          } else {
            missingCategories.add('Накопитель');
          }
        }
      }

      // Восстанавливаем список RAM
      final ramList = <Component>[];
      final rawRam = data['r'] as List<dynamic>?;
      if (rawRam != null) {
        for (final id in rawRam) {
          final comp = findComponentById(id as String);
          if (comp != null) {
            ramList.add(comp);
          } else {
            missingCategories.add('RAM');
          }
        }
      } else if (rawComponents.containsKey('ram')) {
        // Обратная совместимость: v1 код с RAM в components
        final comp = findComponentById(rawComponents['ram'] as String);
        if (comp != null) ramList.add(comp);
      }

      final build = PcBuild(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        createdAt: DateTime.now(),
        components: components,
        storageList: storageList,
        ramList: ramList,
      );

      return ImportResult(build: build, missingCategories: missingCategories);
    } catch (_) {
      return const ImportResult(missingCategories: ['Неверный код — проверьте и попробуйте снова']);
    }
  }

  /// Сохраняет уже готовую сборку (например, импортированную) в список.
  void saveImportedBuild(PcBuild build) {
    _savedBuilds = [build, ..._savedBuilds];
    notifyListeners();
    _save();
  }

  // ─── Compatibility Check ───

  CompatibilityResult checkCompatibility() {
    final components = _currentBuild.components;
    final storageList = _currentBuild.storageList;
    final ramList = _currentBuild.ramList;
    final errors = <String>[];
    final warnings = <String>[];

    final cpu = components[ComponentCategory.cpu];
    final mb = components[ComponentCategory.motherboard];
    final gpu = components[ComponentCategory.gpu];
    final psu = components[ComponentCategory.psu];
    final pcCase = components[ComponentCategory.pcCase];
    final cooling = components[ComponentCategory.cooling];

    if (cpu != null && mb != null) {
      if (cpu.socket != mb.socket) {
        errors.add('Процессор ${cpu.brand} ${cpu.model} (${cpu.socket}) несовместим с платой ${mb.brand} ${mb.model} (${mb.socket})');
      }
    }

    // Проверка RAM для каждой планки
    for (final ram in ramList) {
      if (mb != null) {
        if (mb.memoryTypes.isNotEmpty && ram.memoryType != null &&
            !mb.memoryTypes.contains(ram.memoryType)) {
          errors.add('Память ${ram.brand} ${ram.model} (${ram.memoryType}) несовместима с платой ${mb.brand} ${mb.model}');
          break; // достаточно одной ошибки для одинаковых планок
        }
      }
      if (cpu != null) {
        if (cpu.memoryTypes.isNotEmpty && ram.memoryType != null &&
            !cpu.memoryTypes.contains(ram.memoryType)) {
          warnings.add('Процессор ${cpu.model} поддерживает ${cpu.memoryTypes.join('/')}, установлена ${ram.memoryType}');
          break;
        }
      }
    }

    // Проверка количества планок RAM vs слоты мат. платы
    if (mb != null && ramList.isNotEmpty) {
      final maxSlots = _maxRamSlotsForMotherboard(mb);
      if (ramList.length > maxSlots) {
        errors.add(
          'Материнская плата ${mb.brand} ${mb.model} имеет $maxSlots слота(-ов) памяти, '
          'установлено ${ramList.length}',
        );
      }
    }

    if (cooling != null && cpu != null && cpu.socket != null) {
      if (cooling.supportedSockets.isNotEmpty &&
          !cooling.supportedSockets.contains(cpu.socket)) {
        errors.add('Кулер ${cooling.brand} ${cooling.model} не поддерживает сокет ${cpu.socket}');
      }
    }

    if (pcCase != null && mb != null) {
      if (mb.formFactor != null &&
          pcCase.supportedFormFactors.isNotEmpty &&
          !pcCase.supportedFormFactors.contains(mb.formFactor)) {
        errors.add('Корпус ${pcCase.brand} ${pcCase.model} не поддерживает форм-фактор ${mb.formFactor}');
      }
    }

    // ── Проверка длины видеокарты ──
    if (gpu != null && pcCase != null) {
      final gpuLenStr = gpu.specs['Длина карты'];
      final maxLenStr = pcCase.specs['Макс. длина GPU'];
      if (gpuLenStr != null && maxLenStr != null) {
        final gpuLen = int.tryParse(gpuLenStr.replaceAll(RegExp(r'[^\d]'), ''));
        final maxLen = int.tryParse(maxLenStr.replaceAll(RegExp(r'[^\d]'), ''));
        if (gpuLen != null && maxLen != null && gpuLen > maxLen) {
          errors.add(
            'Видеокарта ${gpu.brand} ${gpu.model} (${gpuLen} мм) не помещается в корпус '
            '${pcCase.brand} ${pcCase.model} (макс. ${maxLen} мм)',
          );
        }
      }
    }

    // ── Проверка количества накопителей (слоты корпуса) ──
    if (pcCase != null && storageList.isNotEmpty) {
      final maxSlots = _maxStorageSlotsForCase(pcCase);
      if (storageList.length > maxSlots) {
        errors.add(
          'Корпус ${pcCase.brand} ${pcCase.model} поддерживает максимум $maxSlots '
          'накопителя(-ей), установлено ${storageList.length}',
        );
      }
    }

    // ── Высота воздушного кулера vs корпус ──
    if (cooling != null && pcCase != null) {
      final heightStr = cooling.specs['Высота'];
      final maxHeightStr = pcCase.specs['Макс. высота CPU-кулера'];
      if (heightStr != null && maxHeightStr != null) {
        final height = _parseMm(heightStr);
        final maxHeight = _parseMm(maxHeightStr);
        if (height != null && maxHeight != null && height > maxHeight) {
          errors.add(
            'Кулер ${cooling.brand} ${cooling.model} (${height} мм) не помещается в корпус '
            '${pcCase.brand} ${pcCase.model} (макс. ${maxHeight} мм)',
          );
        }
      }
    }

    // ── Размер радиатора СЖО vs корпус ──
    if (cooling != null && pcCase != null) {
      final radStr = cooling.specs['Монтажный размер радиатора'];
      if (radStr != null) {
        final radSize = _parseMm(radStr);
        if (radSize != null && !_caseSupportsRadiator(pcCase, radSize)) {
          errors.add(
            'Корпус ${pcCase.brand} ${pcCase.model} не поддерживает '
            'радиатор ${radSize} мм кулера ${cooling.brand} ${cooling.model}',
          );
        }
      }
    }

    // ── NVMe-накопители vs слоты M.2 на материнской плате ──
    if (mb != null && storageList.isNotEmpty) {
      final nvmeCount = storageList.where((s) => s.specs['NVMe'] == 'Есть').length;
      if (nvmeCount > 0) {
        final m2SlotStr = mb.specs['Слоты M.2'];
        if (m2SlotStr != null) {
          final m2Slots = int.tryParse(
              RegExp(r'\d+').firstMatch(m2SlotStr)?.group(0) ?? '');
          if (m2Slots != null && nvmeCount > m2Slots) {
            errors.add(
              'Материнская плата ${mb.brand} ${mb.model} имеет $m2Slots слота(-ов) M.2, '
              'установлено $nvmeCount NVMe-накопителя(-ей)',
            );
          }
        }
      }
    }

    // ── SATA-накопители vs порты SATA материнской платы ──
    if (mb != null && storageList.isNotEmpty) {
      final sataCount = storageList
          .where((s) =>
              (s.specs['Интерфейс'] ?? '').contains('SATA') &&
              s.specs['NVMe'] != 'Есть')
          .length;
      if (sataCount > 0) {
        final sataPortStr = mb.specs['Количество портов SATA'];
        if (sataPortStr != null) {
          final sataPorts = int.tryParse(sataPortStr.trim());
          if (sataPorts != null && sataCount > sataPorts) {
            errors.add(
              'Материнская плата ${mb.brand} ${mb.model} имеет $sataPorts порта(-ов) SATA, '
              'установлено $sataCount SATA-накопителя(-ей)',
            );
          }
        }
      }
    }

    // ── Длина БП vs корпус ──
    if (psu != null && pcCase != null) {
      final sizeStr = psu.specs['Размеры'];
      final maxLenStr = pcCase.specs['Макс. длина БП'];
      if (sizeStr != null && maxLenStr != null) {
        final psuLen = _parsePsuLength(sizeStr);
        final maxLen = _parseMm(maxLenStr);
        if (psuLen != null && maxLen != null && psuLen > maxLen) {
          errors.add(
            'Блок питания ${psu.brand} ${psu.model} (${psuLen} мм) не помещается в корпус '
            '${pcCase.brand} ${pcCase.model} (макс. ${maxLen} мм)',
          );
        }
      }
    }

    int totalTdp = 0;
    if (cpu != null) totalTdp += cpu.tdp ?? 0;
    if (gpu != null) totalTdp += gpu.powerDraw ?? 0;
    totalTdp += 100;

    int requiredPower = (totalTdp * 1.3).round();

    if (psu != null) {
      if ((psu.powerDraw ?? 0) < requiredPower) {
        errors.add('Блок питания ${psu.brand} ${psu.model} (${psu.powerDraw} Вт) может не хватить для системы (рекомендуется ${requiredPower} Вт)');
      } else if ((psu.powerDraw ?? 0) < totalTdp + 50) {
        warnings.add('Блок питания работает на высокой нагрузке. Рекомендуется запас 20-30%');
      }
    }

    if (cooling != null && cpu != null) {
      final coolerTdp = cooling.tdp ?? 0;
      final cpuTdp = cpu.tdp ?? 0;
      if (coolerTdp < cpuTdp) {
        warnings.add('TDP кулера (${coolerTdp} Вт) может быть недостаточен для процессора (${cpuTdp} Вт)');
      }
    }

    return CompatibilityResult(
      isCompatible: errors.isEmpty,
      warnings: warnings,
      errors: errors,
      totalTdp: totalTdp,
      requiredPower: requiredPower,
    );
  }

  // ─── Compatibility Filter ───

  /// Включает/выключает фильтр совместимости.
  void toggleCompatibilityFilter() {
    _compatibilityFilterEnabled = !_compatibilityFilterEnabled;
    notifyListeners();
  }

  /// Количество компонентов в категории, совместимых с текущей сборкой.
  int compatibleCount(ComponentCategory category) {
    return _applyCompatibilityFilter(getByCategory(category), category).length;
  }

  /// Применяет только фильтр совместимости — без поиска и спек-фильтров.
  List<Component> rawFilteredForCategory(
    ComponentCategory category, {
    String? excludeFilterKey,
  }) {
    var list = getByCategory(category);

    if (_compatibilityFilterEnabled) {
      list = _applyCompatibilityFilter(list, category);
    }

    for (final entry in _activeFilters.entries) {
      if (entry.key == excludeFilterKey) continue;
      final key = entry.key;
      final values = entry.value;
      list = list.where((c) {
        if (key == 'Бренд') return values.contains(c.brand);
        final specVal = c.specs[key];
        return specVal != null && values.contains(specVal);
      }).toList();
    }

    return list;
  }

  /// Фильтрует список компонентов по совместимости с текущей сборкой.
  List<Component> _applyCompatibilityFilter(
    List<Component> list,
    ComponentCategory category,
  ) {
    final sel = _currentBuild.components;
    final ramList = _currentBuild.ramList;

    final cpu = sel[ComponentCategory.cpu];
    final mb = sel[ComponentCategory.motherboard];
    final gpu = sel[ComponentCategory.gpu];
    final pcCase = sel[ComponentCategory.pcCase];

    switch (category) {
      case ComponentCategory.cpu:
        return list.where((c) {
          if (mb != null && mb.socket != null && c.socket != null) {
            if (c.socket != mb.socket) return false;
          }
          if (ramList.isNotEmpty) {
            final existingType = ramList.first.memoryType;
            if (existingType != null && c.memoryTypes.isNotEmpty) {
              if (!c.memoryTypes.contains(existingType)) return false;
            }
          }
          return true;
        }).toList();

      case ComponentCategory.motherboard:
        return list.where((c) {
          if (cpu != null && cpu.socket != null && c.socket != null) {
            if (c.socket != cpu.socket) return false;
          }
          if (ramList.isNotEmpty) {
            final existingType = ramList.first.memoryType;
            if (existingType != null && c.memoryTypes.isNotEmpty) {
              if (!c.memoryTypes.contains(existingType)) return false;
            }
          }
          if (pcCase != null &&
              pcCase.supportedFormFactors.isNotEmpty &&
              c.formFactor != null) {
            if (!pcCase.supportedFormFactors.contains(c.formFactor)) return false;
          }
          return true;
        }).toList();

      case ComponentCategory.ram:
        return list.where((c) {
          if (mb != null && mb.memoryTypes.isNotEmpty && c.memoryType != null) {
            if (!mb.memoryTypes.contains(c.memoryType)) return false;
          }
          if (cpu != null && cpu.memoryTypes.isNotEmpty && c.memoryType != null) {
            if (!cpu.memoryTypes.contains(c.memoryType)) return false;
          }
          // Если уже есть планки, новая должна быть того же типа
          if (ramList.isNotEmpty) {
            final existingType = ramList.first.memoryType;
            if (existingType != null && c.memoryType != null &&
                c.memoryType != existingType) return false;
          }
          // Нет смысла показывать если уже заполнены все слоты
          if (ramList.length >= maxRamSlots) return false;
          return true;
        }).toList();

      case ComponentCategory.cooling:
        return list.where((c) {
          if (cpu != null && cpu.socket != null && c.supportedSockets.isNotEmpty) {
            if (!c.supportedSockets.contains(cpu.socket)) return false;
          }
          if (pcCase != null) {
            // Высота воздушного кулера
            final heightStr = c.specs['Высота'];
            final maxHeightStr = pcCase.specs['Макс. высота CPU-кулера'];
            if (heightStr != null && maxHeightStr != null) {
              final height = _parseMm(heightStr);
              final maxHeight = _parseMm(maxHeightStr);
              if (height != null && maxHeight != null && height > maxHeight) return false;
            }
            // Размер радиатора СЖО
            final radStr = c.specs['Монтажный размер радиатора'];
            if (radStr != null) {
              final radSize = _parseMm(radStr);
              if (radSize != null && !_caseSupportsRadiator(pcCase, radSize)) return false;
            }
          }
          return true;
        }).toList();

      case ComponentCategory.pcCase:
        return list.where((c) {
          if (mb != null && mb.formFactor != null && c.supportedFormFactors.isNotEmpty) {
            if (!c.supportedFormFactors.contains(mb.formFactor)) return false;
          }
          return true;
        }).toList();

      case ComponentCategory.gpu:
        // Фильтрация по длине видеокарты
        return list.where((c) {
          if (pcCase != null) {
            final gpuLenStr = c.specs['Длина карты'];
            final maxLenStr = pcCase.specs['Макс. длина GPU'];
            if (gpuLenStr != null && maxLenStr != null) {
              final gpuLen = int.tryParse(gpuLenStr.replaceAll(RegExp(r'[^\d]'), ''));
              final maxLen = int.tryParse(maxLenStr.replaceAll(RegExp(r'[^\d]'), ''));
              if (gpuLen != null && maxLen != null && gpuLen > maxLen) return false;
            }
          }
          return true;
        }).toList();

      case ComponentCategory.psu:
        // Показываем БП с достаточной мощностью для текущей сборки
        final cpuTdp = cpu?.tdp ?? 0;
        final gpuDraw = gpu?.powerDraw ?? 0;
        if (cpuTdp == 0 && gpuDraw == 0) return list;
        final minWattage = ((cpuTdp + gpuDraw + 100) * 1.3).round();
        return list.where((c) => (c.powerDraw ?? 0) >= minWattage).toList();

      case ComponentCategory.storage:
        // Фильтрация по доступным слотам
        if (pcCase != null) {
          final maxSlots = _maxStorageSlotsForCase(pcCase);
          if (_currentBuild.storageList.length >= maxSlots) return [];
        }
        return list;

      default:
        return list;
    }
  }

  // ─── Compare Components ───

  bool addToCompare(Component component) {
    if (_compareComponents.length >= 40) return false;
    if (_compareComponents.any((c) => c.id == component.id)) return false;
    _compareComponents = [..._compareComponents, component];
    notifyListeners();
    return true;
  }

  void removeFromCompare(String id) {
    _compareComponents = _compareComponents.where((c) => c.id != id).toList();
    notifyListeners();
  }

  void swapComparePositions(int index1, int index2) {
    if (index1 >= _compareComponents.length ||
        index2 >= _compareComponents.length) return;
    final updated = List<Component>.from(_compareComponents);
    final tmp = updated[index1];
    updated[index1] = updated[index2];
    updated[index2] = tmp;
    _compareComponents = updated;
    notifyListeners();
  }

  void clearCompare() {
    _compareComponents = [];
    notifyListeners();
  }

  bool isInCompare(String id) => _compareComponents.any((c) => c.id == id);

  // ─── Lookup ───

  Component? findById(String id) => findComponentById(id);

  // ─── Filters & Sorting ───

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSortBy(String sort) {
    _sortBy = sort;
    notifyListeners();
  }

  void toggleFilter(String key, String value) {
    final current = Map<String, Set<String>>.from(_activeFilters);
    final set = Set<String>.from(current[key] ?? {});
    if (set.contains(value)) {
      set.remove(value);
    } else {
      set.add(value);
    }
    if (set.isEmpty) {
      current.remove(key);
    } else {
      current[key] = set;
    }
    _activeFilters = current;
    notifyListeners();
  }

  void clearFiltersForCategory(String category) {
    final keysToRemove = _specFilterKeysForCategory(category);
    if (keysToRemove.isEmpty) {
      // Unknown category — fall back to clearing everything
      _activeFilters = {};
    } else {
      final current = Map<String, Set<String>>.from(_activeFilters);
      current.removeWhere((key, _) => keysToRemove.contains(key));
      _activeFilters = current;
    }
    _compatibilityFilterEnabled = false;
    notifyListeners();
  }

  /// Returns the set of filter-panel spec keys that belong to [categoryKey].
  static Set<String> _specFilterKeysForCategory(String categoryKey) {
    const Map<String, List<String>> _keys = {
      'cpu': [
        'Бренд', 'Сокет', 'Техпроцесс', 'Кодовое название ядра', 'Год релиза',
        'Ядра (всего)', 'Потоки', 'Базовая частота',
        'Максимальная частота (P-core)', 'Максимальная частота', 'Кэш L3',
        'Тип памяти', 'Каналы памяти', 'Максимальный объём памяти',
        'Частота памяти JEDEC', 'Частота памяти в разгоне',
        'Базовое тепловыделение (TDP)', 'Максимальное тепловыделение (MTP)',
        'Максимальное тепловыделение (PPT)', 'Встроенная графика',
        'Встроенный контроллер PCIe', 'Свободный множитель',
        'Поддержка ECC-памяти', 'NPU (нейронный процессор)',
        'Технология виртуализации', 'Система охлаждения в комплекте',
      ],
      'gpu': [
        'Бренд', 'Графический процессор', 'Архитектура (микроархитектура)',
        'Техпроцесс', 'Видеопамять', 'Разрядность шины памяти',
        'Эффективная частота памяти', 'Пропускная способность памяти', 'TDP',
        'Boost-частота GPU', 'Базовая частота GPU', 'Разъём питания',
        'Рекомендуемый блок питания', 'Интерфейс', 'Версия HDMI',
        'Версия DisplayPort', 'Количество подключаемых мониторов',
        'Длина карты', 'Тип охлаждения', 'Количество вентиляторов',
        'Количество занимаемых слотов', 'Подсветка', 'Переключатель BIOS',
        'Предназначена для майнинга',
      ],
      'ram': [
        'Бренд', 'Тип', 'Тип модуля', 'Объём', 'Количество модулей',
        'Объём одного модуля', 'Частота', 'Тайминги', 'Напряжение',
        'Intel XMP', 'AMD EXPO', 'ECC', 'Регистровая', 'Радиатор',
        'Высота модуля', 'Цвет радиатора', 'Подсветка', 'Низкопрофильная',
        'Гарантия',
      ],
      'storage': [
        'Бренд', 'Форм-фактор', 'Интерфейс', 'NVMe', 'Объём', 'Ёмкость',
        'Структура памяти', 'Технология записи', 'DRAM буфер', 'Контроллер',
        'Последовательное чтение', 'Последовательная запись',
        'Скорость чтения', 'Скорость записи',
        'Скорость вращения шпинделя', 'Оптимизация под RAID',
        'Ресурс записи (TBW)', 'Нагрузка (TBW/год)', 'Назначение',
        'Шифрование', 'Охлаждение', 'Гарантия',
      ],
      'psu': [
        'Бренд', 'Мощность', 'Сертификат', 'Соответствие стандарту',
        'Модульность', 'Оплётка проводов', 'Разъёмы PCIe', 'Разъёмы CPU',
        'Разъёмы SATA', 'Разъёмы Molex', 'PCIe 5.0', 'Форм-фактор',
        'Вентилятор', 'Цвет', 'PFC', 'Режим Fanless', 'Уровень шума',
        'Дисплей', 'Защиты', 'Конденсаторы', 'Гарантия',
      ],
      'motherboard': [
        'Бренд', 'Сокет', 'Чипсет', 'Форм-фактор', 'Тип памяти',
        'Слоты памяти', 'Максимальный объём памяти', 'Каналы памяти',
        'Частота памяти JEDEC', 'Частота памяти в разгоне',
        'Версия PCIe (основной слот)', 'Слоты PCIe x16', 'Слоты M.2',
        'Количество портов SATA', 'Количество фаз питания',
        'Охлаждение VRM', 'Охлаждение M.2', 'Wi-Fi', 'Bluetooth',
        'Сетевой адаптер', 'Скорость сети', 'Звуковая схема',
        'USB на задней панели (Type-C)', 'USB на задней панели (Type-A)',
        'Разъёмы вентиляторов', 'Разъёмы ARGB', 'Разъёмы RGB',
        'Поддержка SLI/CrossFire', 'Подсветка', 'Цвет',
      ],
      'case': [
        'Бренд', 'Типоразмер', 'Форм-факторы плат',
        'Макс. высота CPU-кулера', 'Макс. длина GPU', 'Макс. длина БП',
        'Материал корпуса', 'Материал окна', 'Материал фронт. панели',
        'Цвет', 'Тип подсветки', 'Фронт. вентиляторы',
        'Тыловые вентиляторы', 'Верхние вентиляторы', 'Боковые вентиляторы',
        'СЖО спереди', 'СЖО сверху', 'СЖО сзади', 'Предустановленные вент.',
        'Горизонт. слоты расширения', 'Верт. слоты расширения',
        'Отсеки 2.5"', 'Отсеки 3.5"',
        'USB Type-A (передняя панель)', 'USB Type-C (передняя панель)',
        'Кардридер', 'Прокладка кабелей', 'Пылевые фильтры', 'Звукоизоляция',
      ],
      'cooling': [
        'Бренд', 'Тип конструкции', 'Монтажный размер радиатора',
        'Толщина радиатора', 'TDP', 'Уровень шума', 'Вентиляторы',
        'Макс. скорость вентилятора', 'Мин. скорость вентилятора',
        'Сокеты Intel', 'Сокеты AMD', 'Высота', 'Материал основания',
        'Количество тепловых трубок', 'Никелированное покрытие',
        'Тип подшипника', 'VRM-вентилятор', 'Помпа', 'Скорость помпы',
        'Совместимость с RAM', 'Тип подсветки', 'LCD дисплей', 'Управление',
        'Термопаста в комплекте',
      ],
    };
    return Set<String>.from(_keys[categoryKey] ?? []);
  }

  List<Component> filteredComponents(ComponentCategory category) {
    var list = getByCategory(category);

    // Compatibility filter
    if (_compatibilityFilterEnabled) {
      list = _applyCompatibilityFilter(list, category);
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((c) =>
        c.name.toLowerCase().contains(q) ||
        c.brand.toLowerCase().contains(q) ||
        c.description.toLowerCase().contains(q) ||
        c.specs.values.any((v) => v.toLowerCase().contains(q))
      ).toList();
    }

    for (final entry in _activeFilters.entries) {
      final key = entry.key;
      final values = entry.value;
      list = list.where((c) {
        if (key == 'Бренд') return values.contains(c.brand);
        final specVal = c.specs[key];
        return specVal != null && values.contains(specVal);
      }).toList();
    }

    switch (_sortBy) {
      case 'price_asc':
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_desc':
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'name_asc':
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'name_desc':
        list.sort((a, b) => b.name.compareTo(a.name));
        break;
    }

    return list;
  }

  List<Component> searchAll(String query) {
    if (query.isEmpty) return [];
    final q = query.toLowerCase();
    return allComponents.where((c) =>
      c.name.toLowerCase().contains(q) ||
      c.brand.toLowerCase().contains(q) ||
      c.model.toLowerCase().contains(q) ||
      c.category.displayName.toLowerCase().contains(q)
    ).toList();
  }

  // ─── Persistence ───

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final buildMap = _currentBuild.components.map(
        (k, v) => MapEntry(k.key, v.id),
      );
      await prefs.setString('current_build_name', _currentBuild.name);
      await prefs.setString('current_build', jsonEncode(buildMap));
      await prefs.setStringList(
        'current_build_storage',
        _currentBuild.storageList.map((c) => c.id).toList(),
      );
      await prefs.setStringList(
        'current_build_ram',
        _currentBuild.ramList.map((c) => c.id).toList(),
      );

      final buildsJson = _savedBuilds.map((b) => jsonEncode(b.toJson())).toList();
      await prefs.setStringList('saved_builds', buildsJson);
    } catch (e) {
      // ignore storage errors
    }
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final buildName = prefs.getString('current_build_name') ?? 'Моя сборка';
      final buildJson = prefs.getString('current_build');
      final storageIds = prefs.getStringList('current_build_storage') ?? [];
      final ramIds = prefs.getStringList('current_build_ram') ?? [];

      if (buildJson != null) {
        final map = jsonDecode(buildJson) as Map<String, dynamic>;
        final components = <ComponentCategory, Component>{};
        final legacyRamId = <String>[];

        for (final entry in map.entries) {
          final cat = _categoryFromKey(entry.key);
          if (cat == null || cat == ComponentCategory.storage) continue;
          // Обратная совместимость: старый RAM из components map
          if (cat == ComponentCategory.ram) {
            legacyRamId.add(entry.value as String);
            continue;
          }
          final comp = findComponentById(entry.value as String);
          if (comp != null) components[cat] = comp;
        }

        final storageList = <Component>[];
        for (final id in storageIds) {
          final comp = findComponentById(id);
          if (comp != null) storageList.add(comp);
        }

        final ramList = <Component>[];
        // Предпочитаем новый формат, иначе — старый
        final ramIdsToLoad = ramIds.isNotEmpty ? ramIds : legacyRamId;
        for (final id in ramIdsToLoad) {
          final comp = findComponentById(id);
          if (comp != null) ramList.add(comp);
        }

        _currentBuild = PcBuild(
          id: 'current',
          name: buildName,
          createdAt: DateTime.now(),
          components: components,
          storageList: storageList,
          ramList: ramList,
        );
      }

      final buildsJson = prefs.getStringList('saved_builds') ?? [];
      _savedBuilds = buildsJson.map((json) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        final compIds = (data['componentIds'] as Map<String, dynamic>?) ?? {};
        final components = <ComponentCategory, Component>{};
        final legacyRamId = <String>[];

        for (final entry in compIds.entries) {
          final cat = _categoryFromKey(entry.key);
          if (cat == null || cat == ComponentCategory.storage) continue;
          if (cat == ComponentCategory.ram) {
            legacyRamId.add(entry.value as String);
            continue;
          }
          final comp = findComponentById(entry.value as String);
          if (comp != null) components[cat] = comp;
        }

        // Восстанавливаем список накопителей (для новых сборок)
        final storageList = <Component>[];
        final rawStorageIds = (data['storageIds'] as List<dynamic>?) ?? [];
        for (final id in rawStorageIds) {
          final comp = findComponentById(id as String);
          if (comp != null) storageList.add(comp);
        }

        // Восстанавливаем список RAM
        final ramList = <Component>[];
        final rawRamIds = (data['ramIds'] as List<dynamic>?) ?? [];
        final ramIdsToLoad = rawRamIds.isNotEmpty
            ? rawRamIds.cast<String>()
            : legacyRamId;
        for (final id in ramIdsToLoad) {
          final comp = findComponentById(id);
          if (comp != null) ramList.add(comp);
        }

        return PcBuild(
          id: data['id'] ?? '',
          name: data['name'] ?? 'Сборка',
          createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
          components: components,
          storageList: storageList,
          ramList: ramList,
        );
      }).toList();

      notifyListeners();
    } catch (e) {
      // ignore load errors
    }
  }

  bool isInCurrentBuild(String componentId) {
    return _currentBuild.components.values.any((c) => c.id == componentId) ||
        _currentBuild.storageList.any((c) => c.id == componentId) ||
        _currentBuild.ramList.any((c) => c.id == componentId);
  }

  // ─── Helpers ───

  /// Есть ли в сборке хотя бы один компонент, с которым можно проверять совместимость.
  bool get hasBuildForCompatibility =>
      _currentBuild.components.isNotEmpty ||
      _currentBuild.storageList.isNotEmpty ||
      _currentBuild.ramList.isNotEmpty;

  /// Безопасный поиск категории по ключу. Возвращает null если ключ неизвестен.
  static ComponentCategory? _categoryFromKey(String key) {
    for (final c in ComponentCategory.values) {
      if (c.key == key) return c;
    }
    return null;
  }

  // ─── Dimension helpers ───

  /// Извлекает первое целое число из строки вида "165 мм", "360 мм (3 × 120 мм)" и т.п.
  static int? _parseMm(String s) {
    final match = RegExp(r'\d+').firstMatch(s);
    return match != null ? int.tryParse(match.group(0)!) : null;
  }

  /// Извлекает длину (последнее число) из строки размеров БП вида "150 × 86 × 160 мм".
  static int? _parsePsuLength(String sizeStr) {
    final numbers = RegExp(r'\d+')
        .allMatches(sizeStr)
        .map((m) => int.tryParse(m.group(0)!))
        .whereType<int>()
        .toList();
    // Формат: W × H × D — третье число это глубина/длина
    return numbers.length >= 3 ? numbers[2] : null;
  }

  /// Проверяет, поддерживает ли корпус радиатор заданного размера (мм).
  /// Анализирует все поля СЖО: "СЖО сверху", "СЖО спереди", "СЖО сзади", "СЖО снизу", "СЖО сбоку".
  static bool _caseSupportsRadiator(Component pcCase, int radSizeMm) {
    const sjoKeys = [
      'СЖО сверху', 'СЖО спереди', 'СЖО сзади',
      'СЖО снизу', 'СЖО сбоку',
    ];
    for (final key in sjoKeys) {
      final val = pcCase.specs[key];
      if (val == null) continue;
      // Делим по '/', из каждой части берём первое число до '('
      // "360 мм / 280 мм" → {360, 280}
      // "360 мм (3 × 120 мм)" → {360}
      final sizes = val.split('/').map((part) {
        final clean = part.split('(').first;
        final m = RegExp(r'\d+').firstMatch(clean.trim());
        return m != null ? int.tryParse(m.group(0)!) : null;
      }).whereType<int>().toSet();
      if (sizes.contains(radSizeMm)) return true;
    }
    return false;
  }
}
