import 'dart:math' show max;
import 'package:flutter/material.dart';

// ── Определяет тип накопителя для умного сопоставления ──────────────────────
// Порядок проверки важен: сначала NVMe (может быть SATA+NVMe у редких моделей),
// потом HDD (есть «Скорость вращения»), остальное — SSD SATA.
String _storageType(Component c) {
  final iface = (c.specs['Интерфейс'] ?? '').toLowerCase();
  final hasNvmeKey = c.specs.containsKey('NVMe') &&
      (c.specs['NVMe'] ?? '').toLowerCase() == 'есть';
  if (hasNvmeKey || iface.contains('nvme') || iface.contains('pcie')) {
    return 'NVMe SSD';
  }
  if (c.specs.containsKey('Скорость вращения шпинделя')) return 'HDD';
  return 'SSD SATA';
}

// Нужный порядок секций для накопителей
const _kStorageTypeOrder = ['NVMe SSD', 'SSD SATA', 'HDD'];
import 'package:provider/provider.dart';
import '../models/component.dart';
import '../models/pc_build.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../utils/format_utils.dart';

// Pre-computed colors to avoid withOpacity() on every frame
const _kAccentFaint = Color(0x0FFF6B35);   // AppTheme.accent @ 6%
const _kAccentLight = Color(0x14FF6B35);   // AppTheme.accent @ 8%
const _kPrimaryFaint = Color(0x12006FFF); // AppTheme.primary @ 7%
const _kRowAlt = Color(0xFFF7F8FA);        // alternating row

/// Данные одной секции — вычисляются один раз и кэшируются.
class _SectionItem {
  final ComponentCategory cat;
  final Component? component1;
  final Component? component2;
  final String? labelOverride;

  const _SectionItem({
    required this.cat,
    required this.component1,
    required this.component2,
    this.labelOverride,
  });
}

class BuildComparisonScreen extends StatelessWidget {
  final String buildId1;
  final String buildId2;

  const BuildComparisonScreen({
    super.key,
    required this.buildId1,
    required this.buildId2,
  });

  @override
  Widget build(BuildContext context) {
    // Подписываемся только на savedBuilds — не на весь провайдер.
    final savedBuilds = context.select<AppProvider, List<PcBuild>>(
      (p) => p.savedBuilds,
    );
    final b1 = savedBuilds.where((b) => b.id == buildId1).firstOrNull;
    final b2 = savedBuilds.where((b) => b.id == buildId2).firstOrNull;

    if (b1 == null || b2 == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Сравнение сборок')),
        body: const Center(child: Text('Сборки не найдены')),
      );
    }

    return _BuildComparisonView(build1: b1, build2: b2);
  }
}

/// Вычисляет список секций один раз в [initState] / [didUpdateWidget]
/// и не пересчитывает их при не связанных ребилдах.
class _BuildComparisonView extends StatefulWidget {
  final PcBuild build1;
  final PcBuild build2;

  const _BuildComparisonView({required this.build1, required this.build2});

  @override
  State<_BuildComparisonView> createState() => _BuildComparisonViewState();
}

class _BuildComparisonViewState extends State<_BuildComparisonView> {
  late List<_SectionItem> _sections;

  @override
  void initState() {
    super.initState();
    _sections = _buildSections(widget.build1, widget.build2);
  }

  @override
  void didUpdateWidget(_BuildComparisonView old) {
    super.didUpdateWidget(old);
    // Пересчитываем только если сами сборки изменились.
    if (old.build1 != widget.build1 || old.build2 != widget.build2) {
      _sections = _buildSections(widget.build1, widget.build2);
    }
  }

  static List<_SectionItem> _buildSections(PcBuild b1, PcBuild b2) {
    final sections = <_SectionItem>[];

    for (final cat in ComponentCategory.values) {
      if (cat == ComponentCategory.storage || cat == ComponentCategory.ram) continue;
      final c1 = b1.components[cat];
      final c2 = b2.components[cat];
      if (c1 == null && c2 == null) continue;
      sections.add(_SectionItem(cat: cat, component1: c1, component2: c2));
    }

    final maxRam = max(b1.ramList.length, b2.ramList.length);
    for (int i = 0; i < maxRam; i++) {
      sections.add(_SectionItem(
        cat: ComponentCategory.ram,
        component1: i < b1.ramList.length ? b1.ramList[i] : null,
        component2: i < b2.ramList.length ? b2.ramList[i] : null,
        labelOverride: maxRam > 1 ? 'RAM ${i + 1}' : null,
      ));
    }

    // ── Умное сопоставление накопителей по типу ──────────────────────────
    // Группируем накопители каждой сборки по типу, затем попарно сравниваем
    // одинаковые типы. Это корректно работает когда:
    //   • сборки имеют разное количество дисков
    //   • у сборок диски разных типов (NVMe vs HDD vs SSD SATA)
    //   • один из типов присутствует только в одной сборке
    final Map<String, List<Component>> byType1 = {};
    final Map<String, List<Component>> byType2 = {};
    for (final c in b1.storageList) {
      byType1.putIfAbsent(_storageType(c), () => []).add(c);
    }
    for (final c in b2.storageList) {
      byType2.putIfAbsent(_storageType(c), () => []).add(c);
    }

    // Все типы, присутствующие хотя бы в одной сборке, в нужном порядке
    final allTypes = <String>{...byType1.keys, ...byType2.keys};
    final orderedTypes = [
      ..._kStorageTypeOrder.where(allTypes.contains),
      ...allTypes.where((t) => !_kStorageTypeOrder.contains(t)),
    ];

    for (final type in orderedTypes) {
      final drives1 = byType1[type] ?? const [];
      final drives2 = byType2[type] ?? const [];
      final count = max(drives1.length, drives2.length);
      for (int i = 0; i < count; i++) {
        // Метка: тип + номер если несколько одинаковых (напр. «NVMe SSD 2»)
        final label = count > 1 ? '$type ${i + 1}' : type;
        sections.add(_SectionItem(
          cat: ComponentCategory.storage,
          component1: i < drives1.length ? drives1[i] : null,
          component2: i < drives2.length ? drives2[i] : null,
          labelOverride: label,
        ));
      }
    }

    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final build1 = widget.build1;
    final build2 = widget.build2;
    final cheaper = build1.totalPrice <= build2.totalPrice ? 0 : 1;
    final priceDiff = (build1.totalPrice - build2.totalPrice).abs();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Сравнение сборок'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Header — two build names + prices
          ColoredBox(
            color: Colors.white,
            child: Row(
              children: [
                const SizedBox(width: 100),
                _BuildHeader(pcBuild: build1, isCheaper: cheaper == 0),
                _BuildHeader(pcBuild: build2, isCheaper: cheaper == 1),
              ],
            ),
          ),

          // Price diff banner
          if (priceDiff > 0)
            ColoredBox(
              color: _kPrimaryFaint,
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.savings_outlined,
                          size: 14, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        '${cheaper == 0 ? build1.name : build2.name} дешевле на ${formatPrice(priceDiff)} ₽',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Legend
          const ColoredBox(
            color: Color(0xFFFFF3CD),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  _LegendDot(),
                  SizedBox(width: 8),
                  Text(
                    'Подсвечены отличающиеся характеристики',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),

          // Category rows — виртуализованный список, рендерит только видимые секции
          Expanded(
            child: ListView.builder(
              itemCount: _sections.length,
              itemBuilder: (ctx, i) => _CategorySection(
                cat: _sections[i].cat,
                component1: _sections[i].component1,
                component2: _sections[i].component2,
                labelOverride: _sections[i].labelOverride,
              ),
            ),
          ),

          // Bottom totals
          ColoredBox(
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  0, 12, 0, 12 + MediaQuery.of(context).padding.bottom),
              child: Row(
                children: [
                  const SizedBox(width: 100),
                  Expanded(
                    child: _PriceTotal(
                        pcBuild: build1, isCheaper: cheaper == 0),
                  ),
                  Expanded(
                    child: _PriceTotal(
                        pcBuild: build2, isCheaper: cheaper == 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}

// ── Category section — one per component type ──
// Kept as a separate StatelessWidget so Flutter can skip rebuilding
// individual sections when unrelated state changes.
class _CategorySection extends StatelessWidget {
  final ComponentCategory cat;
  final Component? component1;
  final Component? component2;
  final String? labelOverride;

  const _CategorySection({
    required this.cat,
    required this.component1,
    required this.component2,
    this.labelOverride,
  });

  @override
  Widget build(BuildContext context) {
    final c1 = component1;
    final c2 = component2;
    final componentsDiffer = c1?.id != c2?.id;

    // Collect spec keys once — O(n) total, not per-row
    final allSpecKeys = <String>[
      ...?c1?.specs.keys,
      if (c2 != null)
        for (final k in c2.specs.keys)
          if (c1 == null || !c1.specs.containsKey(k)) k,
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.divider, width: 2),
          left: componentsDiffer
              ? const BorderSide(color: AppTheme.accent, width: 3)
              : BorderSide.none,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Component name / price header ──
          ColoredBox(
            color: componentsDiffer ? _kAccentFaint : Colors.white,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(cat.icon, size: 16, color: cat.color),
                        const SizedBox(height: 4),
                        Text(
                          labelOverride ?? cat.shortName,
                          style: TextStyle(
                            fontSize: 11,
                            color: cat.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _ComponentNameCell(component: c1, isDiff: componentsDiffer),
                _ComponentNameCell(component: c2, isDiff: componentsDiffer),
              ],
            ),
          ),

          // ── Spec rows — index already known, no indexOf() ──
          for (var i = 0; i < allSpecKeys.length; i++)
            _SpecRow(
              specKey: allSpecKeys[i],
              val1: c1?.specs[allSpecKeys[i]],
              val2: c2?.specs[allSpecKeys[i]],
              isEvenRow: i.isEven,
            ),
        ],
      ),
    );
  }
}

// ── Single spec row — const-friendly, cheap to build ──
class _SpecRow extends StatelessWidget {
  final String specKey;
  final String? val1;
  final String? val2;
  final bool isEvenRow;

  const _SpecRow({
    required this.specKey,
    required this.val1,
    required this.val2,
    required this.isEvenRow,
  });

  @override
  Widget build(BuildContext context) {
    final differs = val1 != val2;
    final bg = differs
        ? _kAccentLight
        : (isEvenRow ? _kRowAlt : Colors.white);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        border: const Border(
          top: BorderSide(color: AppTheme.divider, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(
                specKey,
                style: TextStyle(
                  fontSize: 10,
                  color: differs ? AppTheme.accent : AppTheme.textSecondary,
                  fontWeight:
                      differs ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
          _SpecValueCell(value: val1, isDiff: differs),
          _SpecValueCell(value: val2, isDiff: differs),
        ],
      ),
    );
  }
}

// ── Spec value cell ──
class _SpecValueCell extends StatelessWidget {
  final String? value;
  final bool isDiff;

  const _SpecValueCell({required this.value, required this.isDiff});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(
          value ?? '—',
          style: TextStyle(
            fontSize: 11,
            color: isDiff ? AppTheme.textPrimary : AppTheme.textSecondary,
            fontWeight: isDiff ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ── Component name / price header cell ──
class _ComponentNameCell extends StatelessWidget {
  final Component? component;
  final bool isDiff;

  const _ComponentNameCell({this.component, required this.isDiff});

  @override
  Widget build(BuildContext context) {
    final c = component;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: c == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.remove_circle_outline,
                        size: 18, color: AppTheme.divider),
                    const SizedBox(height: 4),
                    const Text(
                      'Нет в сборке',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.brand,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDiff
                          ? AppTheme.accent
                          : AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    c.model,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isDiff ? FontWeight.w700 : FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatPrice(c.price)} ₽',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

}

// ── Build name/price header ──
class _BuildHeader extends StatelessWidget {
  final PcBuild pcBuild;
  final bool isCheaper;

  const _BuildHeader({required this.pcBuild, required this.isCheaper});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: _kPrimaryFaint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.computer,
                    color: AppTheme.primary, size: 24),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              pcBuild.name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${pcBuild.components.length + pcBuild.storageList.length + pcBuild.ramList.length} комп.',
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary),
            ),
            if (!pcBuild.isComplete)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Text(
                    'Неполная',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 2),
            if (isCheaper)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Text(
                    'Дешевле',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Price totals footer ──
class _PriceTotal extends StatelessWidget {
  final PcBuild pcBuild;
  final bool isCheaper;

  const _PriceTotal({required this.pcBuild, required this.isCheaper});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Итого',
          style:
              TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          '${formatPrice(pcBuild.totalPrice)} ₽',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isCheaper ? AppTheme.success : AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

}

// ── Legend dot — const widget ──
class _LegendDot extends StatelessWidget {
  const _LegendDot();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _kAccentLight,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: AppTheme.accent),
      ),
      child: const SizedBox(width: 12, height: 12),
    );
  }
}
