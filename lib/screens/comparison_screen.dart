import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/component.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../utils/format_utils.dart';

class ComparisonScreen extends StatefulWidget {
  const ComparisonScreen({super.key});

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  int _selectedCatIdx = 0;
  int _slot1Idx = 0;
  int _slot2Idx = 1;

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

  /// Листает слот [slot] на [direction] (+1 или -1), пропуская индекс другого слота.
  void _navigate(int slot, int direction, int total) {
    // При 2 товарах нет куда переключаться — слоты заняты оба
    if (total <= 2) return;

    final other = slot == 1 ? _slot2Idx : _slot1Idx;
    final current = slot == 1 ? _slot1Idx : _slot2Idx;

    int next = (current + direction + total) % total;
    if (next == other) {
      next = (next + direction + total) % total;
    }

    setState(() {
      if (slot == 1) {
        _slot1Idx = next;
      } else {
        _slot2Idx = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final allItems = provider.compareComponents;

    if (allItems.isEmpty) {
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('Добавьте до 40 компонентов для сравнения',
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

    final grouped = _groupByCategory(allItems);
    final categories = grouped.keys.toList();

    // Защита от выхода за пределы при удалении категории
    final catIdx = _selectedCatIdx.clamp(0, categories.length - 1);
    final selectedCat = categories[catIdx];
    final catItems = grouped[selectedCat]!;

    // Защита индексов слотов
    final s1 = _slot1Idx.clamp(0, catItems.length - 1);
    final s2 = catItems.length > 1 ? _slot2Idx.clamp(0, catItems.length - 1) : -1;

    final item1 = catItems[s1];
    final item2 = s2 >= 0 ? catItems[s2] : null;

    // Ключи характеристик и отличия
    final allKeys = <String>{...item1.specs.keys};
    if (item2 != null) allKeys.addAll(item2.specs.keys);

    final differingKeys = item2 == null
        ? <String>{}
        : allKeys.where((k) => item1.specs[k] != item2.specs[k]).toSet();

    return Scaffold(
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
          // ── Вкладки категорий ──
          Container(
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
          ),

          const Divider(height: 1),

          // ── Два слота сравнения ──
          Container(
            color: Colors.white,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildSlot(
                        context, provider, item1, 1, s1, catItems.length),
                  ),
                  VerticalDivider(
                      width: 1, color: AppTheme.divider, thickness: 1),
                  Expanded(
                    child: item2 != null
                        ? _buildSlot(context, provider, item2, 2, s2,
                            catItems.length)
                        : _buildEmptySlot(context, selectedCat),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // ── Легенда ──
          if (item2 != null)
            Container(
              color: const Color(0xFFFFF3CD),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: AppTheme.accent),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Подсвечены отличающиеся характеристики',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),

          // ── Таблица характеристик ──
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: allKeys.map((key) {
                  final isDiff = differingKeys.contains(key);
                  final v1 = item1.specs[key] ?? '—';
                  final v2 = item2?.specs[key] ?? '—';

                  return Container(
                    decoration: BoxDecoration(
                      color: isDiff
                          ? AppTheme.accent.withValues(alpha: 0.06)
                          : Colors.white,
                      border: Border(
                        bottom: BorderSide(color: AppTheme.divider),
                        left: isDiff
                            ? const BorderSide(
                                color: AppTheme.accent, width: 3)
                            : BorderSide.none,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 110,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              key,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              v1,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isDiff
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: isDiff
                                    ? AppTheme.textPrimary
                                    : AppTheme.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        if (item2 != null)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              child: Text(
                                v2,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isDiff
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: isDiff
                                      ? AppTheme.textPrimary
                                      : AppTheme.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlot(BuildContext context, AppProvider provider,
      Component item, int slot, int currentIdx, int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Кнопка удаления
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => provider.removeFromCompare(item.id),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.close,
                    size: 14, color: AppTheme.error),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Иконка категории
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: item.category.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.category.icon, color: item.category.color),
          ),
          const SizedBox(height: 6),
          Text(
            item.brand,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            item.model,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${formatPrice(item.price)} ₽',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(height: 8),
          // Стрелки навигации
          if (total > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _navigate(slot, -1, total),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.chip,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.chevron_left, size: 18),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${currentIdx + 1} из $total',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _navigate(slot, 1, total),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.chip,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.chevron_right, size: 18),
                  ),
                ),
              ],
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
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
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
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

}
