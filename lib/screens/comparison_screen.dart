import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/component.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../utils/format_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Группы характеристик (DNS-стиль)
// ─────────────────────────────────────────────────────────────────────────────
class _SpecGroup {
  final String title;
  final List<String> keywords;
  const _SpecGroup(this.title, this.keywords);
}

const _specGroups = [
  _SpecGroup('Общие характеристики', [
    'год', 'сокет', 'техпроцесс', 'кодовое', 'производитель',
    'страна', 'гарантия', 'тип ', 'форм-фактор', 'серия',
  ]),
  _SpecGroup('Производительность', [
    'ядр', 'поток', 'частот', 'turbo', 'boost', 'кэш',
    'базовая', 'максимальная', 'takt', 'операци',
  ]),
  _SpecGroup('Память', [
    'память', 'ddr', 'объём', 'канал', 'ram', 'vram', 'видеопамять',
    'тип памяти', 'частота памяти', 'пропускн',
  ]),
  _SpecGroup('Графика', [
    'gpu', 'видеоп', 'графич', 'шейдер', 'cuda', 'ray tracing',
    'rasteriz', 'тмюниты', 'stream processor',
  ]),
  _SpecGroup('Экран', [
    'экран', 'дисплей', 'разрешение', 'диагональ', 'герц', 'hz',
    'покрытие экрана', 'яркость', 'контраст', 'refresh', 'матриц',
    'тип матрицы',
  ]),
  _SpecGroup('Тепловыделение и питание', [
    'tdp', 'тепловыдел', 'температур', 'охлажд', 'кулер',
    'питание', 'мощность', 'ватт', 'разъём питания', 'pfc',
  ]),
  _SpecGroup('Интерфейсы', [
    'pcie', 'usb', 'sata', 'nvme', 'm.2', 'thunderbolt',
    'интерфейс', 'порт', 'слот', 'hdmi', 'displayport', 'подключ',
  ]),
  _SpecGroup('Совместимость', [
    'поддержк', 'совмест', 'стандарт', 'протокол', 'спецификация',
    'сертификат', 'ecc',
  ]),
  _SpecGroup('Габариты и масса', [
    'размер', 'габарит', 'вес', 'высота', 'ширина', 'длина',
    'толщина', 'мм', ' кг',
  ]),
];

// ─────────────────────────────────────────────────────────────────────────────
// Вспомогательные функции
// ─────────────────────────────────────────────────────────────────────────────

/// Определяет группу для ключа характеристики
String _groupForKey(String key) {
  final lower = key.toLowerCase();
  for (final g in _specGroups) {
    if (g.keywords.any((kw) => lower.contains(kw))) return g.title;
  }
  return 'Прочее';
}

/// Извлекает первое числовое значение из строки (для сравнения «лучше/хуже»)
double? _parseNum(String val) {
  final m = RegExp(r'[\d]+(?:[.,][\d]+)?').firstMatch(val.replaceAll(' ', ''));
  if (m == null) return null;
  return double.tryParse(m.group(0)!.replaceAll(',', '.'));
}

/// «Меньше лучше» для известных полей
bool _lowerIsBetter(String key) {
  final k = key.toLowerCase();
  return k.contains('tdp') ||
      k.contains('тепловыдел') ||
      k.contains('мощность') ||
      k.contains('температур') ||
      k.contains('вес') ||
      k.contains('ватт');
}

/// Tooltip-подсказки для конкретных ключей
const _hints = <String, String>{
  'Техпроцесс': 'Размер транзистора в нм. Меньше — эффективнее.',
  'Тип памяти': 'Поколение оперативной памяти. DDR5 быстрее DDR4.',
  'PCIe': 'Версия шины PCI Express. Влияет на пропускную способность.',
  'TDP': 'Расчётная тепловая мощность. Показывает, сколько тепла рассеивает чип.',
  'Базовое тепловыделение (TDP)': 'Расчётная тепловая мощность в штатном режиме.',
  'Максимальное тепловыделение (MTP)': 'Пиковое тепловыделение при максимальной нагрузке.',
  'Тип экрана': 'Технология матрицы. IPS — лучшие углы обзора, TN — быстрый отклик.',
  'Разрешение экрана': 'Количество пикселей. Больше — чётче изображение.',
  'ECC': 'Error Correcting Code — коррекция ошибок памяти. Важно для серверов.',
};

// ─────────────────────────────────────────────────────────────────────────────
// Виджет
// ─────────────────────────────────────────────────────────────────────────────
class ComparisonScreen extends StatefulWidget {
  const ComparisonScreen({super.key});

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  int _selectedCatIdx = 0;
  int _slot1Idx = 0;
  int _slot2Idx = 1;

  bool _showOnlyDiff = false;
  final Set<String> _collapsed = {};

  // ── Группировка по категории ──────────────────────────────────────────────
  Map<ComponentCategory, List<Component>> _groupByCategory(
      List<Component> items) {
    final map = <ComponentCategory, List<Component>>{};
    for (final c in items) {
      map.putIfAbsent(c.category, () => []).add(c);
    }
    return map;
  }

  void _selectCategory(int idx) {
    setState(() {
      _selectedCatIdx = idx;
      _slot1Idx = 0;
      _slot2Idx = 1;
    });
  }

  void _navigate(int slot, int direction, int total) {
    if (total <= 2) return;
    final other = slot == 1 ? _slot2Idx : _slot1Idx;
    final current = slot == 1 ? _slot1Idx : _slot2Idx;
    int next = (current + direction + total) % total;
    if (next == other) next = (next + direction + total) % total;
    setState(() {
      if (slot == 1) {
        _slot1Idx = next;
      } else {
        _slot2Idx = next;
      }
    });
  }

  // ── Экран «нет товаров» ────────────────────────────────────────────────────
  Widget _buildEmpty(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Сравнение')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.compare_arrows,
                size: 80, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            const Text('Нет товаров для сравнения',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Добавьте компоненты для сравнения',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('В каталог'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Основной экран ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final allItems = provider.compareComponents;

    if (allItems.isEmpty) return _buildEmpty(context);

    final grouped = _groupByCategory(allItems);
    final categories = grouped.keys.toList();
    final catIdx = _selectedCatIdx.clamp(0, categories.length - 1);
    final selectedCat = categories[catIdx];
    final catItems = grouped[selectedCat]!;

    final s1 = _slot1Idx.clamp(0, catItems.length - 1);
    final s2 =
        catItems.length > 1 ? _slot2Idx.clamp(0, catItems.length - 1) : -1;

    final item1 = catItems[s1];
    final item2 = s2 >= 0 ? catItems[s2] : null;

    // Все ключи + отличающиеся
    final allKeys = <String>{...item1.specs.keys};
    if (item2 != null) allKeys.addAll(item2.specs.keys);
    final differingKeys = item2 == null
        ? <String>{}
        : allKeys
            .where((k) => item1.specs[k] != item2.specs[k])
            .toSet();

    // Группировка ключей по секциям
    final sectionMap = <String, List<String>>{};
    for (final key in allKeys) {
      if (_showOnlyDiff && !differingKeys.contains(key)) continue;
      final group = _groupForKey(key);
      sectionMap.putIfAbsent(group, () => []).add(key);
    }
    // Упорядочим секции по _specGroups, Прочее в конец
    final orderedSections = [
      ..._specGroups.map((g) => g.title).where(sectionMap.containsKey),
      if (sectionMap.containsKey('Прочее')) 'Прочее',
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Сравнение'),
        actions: [
          TextButton(
            onPressed: () => provider.clearCompare(),
            child: const Text('Очистить',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Вкладки категорий ─────────────────────────────────────────────
          _buildCategoryTabs(categories, catIdx, grouped, provider),

          // ── Шапка: два товара ─────────────────────────────────────────────
          _buildProductHeader(
              context, provider, item1, item2, s1, s2, catItems),

          const Divider(height: 1, color: AppTheme.divider),

          // ── Переключатель «Только различающиеся» ──────────────────────────
          _buildDiffToggle(differingKeys.length),

          // ── Таблица характеристик ─────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              itemCount: orderedSections.length,
              itemBuilder: (ctx, i) {
                final section = orderedSections[i];
                final keys = sectionMap[section]!;
                return _buildSection(
                    section, keys, item1, item2, differingKeys);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Вкладки категорий ──────────────────────────────────────────────────────
  Widget _buildCategoryTabs(
    List<ComponentCategory> categories,
    int catIdx,
    Map<ComponentCategory, List<Component>> grouped,
    AppProvider provider,
  ) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: categories.asMap().entries.map((e) {
            final isSelected = e.key == catIdx;
            final cat = e.value;
            final count = grouped[cat]!.length;
            return GestureDetector(
              onTap: () => _selectCategory(e.key),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : AppTheme.chip,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${cat.displayName} $count',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        for (final item in grouped[cat]!) {
                          provider.removeFromCompare(item.id);
                        }
                      },
                      child: Icon(Icons.close,
                          size: 14,
                          color: isSelected
                              ? Colors.white70
                              : AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Шапка с товарами (DNS-стиль) ──────────────────────────────────────────
  Widget _buildProductHeader(
    BuildContext context,
    AppProvider provider,
    Component item1,
    Component? item2,
    int s1,
    int s2,
    List<Component> catItems,
  ) {
    return Container(
      color: Colors.white,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
                child: _buildProductCard(
                    context, provider, item1, 1, s1, catItems)),
            Container(width: 1, color: AppTheme.divider),
            Expanded(
              child: item2 != null
                  ? _buildProductCard(
                      context, provider, item2, 2, s2, catItems)
                  : _buildEmptySlot(context, item1.category),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    AppProvider provider,
    Component item,
    int slot,
    int currentIdx,
    List<Component> catItems,
  ) {
    final total = catItems.length;
    final canNavigate = total > 2;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        children: [
          // Стрелки + иконка
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavArrow(
                icon: Icons.chevron_left,
                enabled: canNavigate,
                onTap: () => _navigate(slot, -1, total),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: item.category.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: item.category.color.withValues(alpha: 0.25)),
                ),
                child: Icon(item.category.icon,
                    color: item.category.color, size: 28),
              ),
              _NavArrow(
                icon: Icons.chevron_right,
                enabled: canNavigate,
                onTap: () => _navigate(slot, 1, total),
              ),
            ],
          ),
          // Счётчик позиции
          if (total > 1) ...[
            const SizedBox(height: 4),
            Text(
              '${currentIdx + 1} из $total',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Название
          Text(
            item.fullName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          // Цена
          Text(
            '${formatPrice(item.price)} ₽',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          // Кнопка удалить
          GestureDetector(
            onTap: () => provider.removeFromCompare(item.id),
            child: const Text(
              'Удалить',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySlot(BuildContext context, ComponentCategory category) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.chip,
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                Icon(category.icon, color: AppTheme.textSecondary, size: 24),
          ),
          const SizedBox(height: 8),
          const Text(
            'Добавьте ещё\nтовар для\nсравнения',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => context.push('/category/${category.key}'),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '+ Добавить',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Переключатель «Только различающиеся» ──────────────────────────────────
  Widget _buildDiffToggle(int diffCount) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Text(
            'Только различающиеся',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          // Оранжевый кружок-счётчик
          if (diffCount > 0)
            Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$diffCount',
                style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w700),
              ),
            ),
          const Spacer(),
          Switch(
            value: _showOnlyDiff,
            onChanged: (v) => setState(() => _showOnlyDiff = v),
            activeColor: AppTheme.accent,
            activeTrackColor: AppTheme.accent.withValues(alpha: 0.3),
            inactiveThumbColor: AppTheme.textSecondary,
            inactiveTrackColor: AppTheme.divider,
          ),
        ],
      ),
    );
  }

  // ── Секция характеристик ───────────────────────────────────────────────────
  Widget _buildSection(
    String title,
    List<String> keys,
    Component item1,
    Component? item2,
    Set<String> differingKeys,
  ) {
    final isCollapsed = _collapsed.contains(title);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок секции
        InkWell(
          onTap: () => setState(() {
            if (isCollapsed) {
              _collapsed.remove(title);
            } else {
              _collapsed.add(title);
            }
          }),
          child: Container(
            color: AppTheme.background,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Icon(
                  isCollapsed
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_up,
                  size: 20,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
        // Строки характеристик
        if (!isCollapsed)
          ...keys.map((key) =>
              _buildSpecRow(key, item1, item2, differingKeys)),
      ],
    );
  }

  // ── Строка характеристики (DNS-стиль) ─────────────────────────────────────
  Widget _buildSpecRow(
    String key,
    Component item1,
    Component? item2,
    Set<String> differingKeys,
  ) {
    final isDiff = differingKeys.contains(key);
    final v1 = item1.specs[key] ?? '—';
    final v2 = item2?.specs[key] ?? '—';
    final hint = _hints[key];

    // Определяем «лучшее» значение для зелёной подсветки
    bool v1Better = false;
    bool v2Better = false;
    if (isDiff && item2 != null && v1 != '—' && v2 != '—') {
      final n1 = _parseNum(v1);
      final n2 = _parseNum(v2);
      if (n1 != null && n2 != null && n1 != n2) {
        final lowerBetter = _lowerIsBetter(key);
        v1Better = lowerBetter ? n1 < n2 : n1 > n2;
        v2Better = lowerBetter ? n2 < n1 : n2 > n1;
      }
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppTheme.divider),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Название характеристики + оранжевая точка + ?
          Padding(
            padding:
                const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Оранжевая точка отличия
                if (isDiff) ...[
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 6, top: 1),
                    decoration: const BoxDecoration(
                      color: AppTheme.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ] else ...[
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Text(
                    key,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isDiff
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                // Иконка-подсказка
                if (hint != null)
                  GestureDetector(
                    onTap: () => _showHint(key, hint),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.help_outline,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Значения в двух колонках
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                    child: _buildValue(v1, v1Better, isDiff)),
                Container(width: 1, color: AppTheme.divider),
                Expanded(
                    child: _buildValue(
                        item2 != null ? v2 : '', v2Better, isDiff)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValue(String value, bool isBetter, bool isDiff) {
    Color textColor;
    FontWeight fontWeight;

    if (isBetter) {
      textColor = AppTheme.success;
      fontWeight = FontWeight.w700;
    } else if (isDiff) {
      textColor = AppTheme.textPrimary;
      fontWeight = FontWeight.w600;
    } else {
      textColor = AppTheme.textSecondary;
      fontWeight = FontWeight.w400;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      color: isBetter
          ? AppTheme.success.withValues(alpha: 0.05)
          : Colors.transparent,
      child: Text(
        value.isEmpty ? '—' : value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: fontWeight,
          color: value.isEmpty ? AppTheme.textSecondary : textColor,
        ),
      ),
    );
  }

  void _showHint(String title, String hint) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700)),
        content: Text(hint,
            style: const TextStyle(
                fontSize: 14, color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Кнопка-стрелка навигации
// ─────────────────────────────────────────────────────────────────────────────
class _NavArrow extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _NavArrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: enabled ? AppTheme.chip : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? AppTheme.textPrimary : Colors.transparent,
        ),
      ),
    );
  }
}
