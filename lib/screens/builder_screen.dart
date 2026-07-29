import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/component.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../utils/format_utils.dart';

class BuilderScreen extends StatefulWidget {
  const BuilderScreen({super.key});
  @override
  State<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends State<BuilderScreen> {
  bool _showCompatibility = false;

  static String _pluralErrors(int n) {
    if (n % 100 >= 11 && n % 100 <= 19) return '$n ошибок';
    switch (n % 10) {
      case 1: return '$n ошибка';
      case 2:
      case 3:
      case 4: return '$n ошибки';
      default: return '$n ошибок';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final build = provider.currentBuild;
    final compat = provider.checkCompatibility();

    // Все категории кроме storage и ram (они рендерятся отдельно)
    final nonListCategories = ComponentCategory.values
        .where((c) => c != ComponentCategory.storage && c != ComponentCategory.ram)
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _editBuildName(context, provider),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(build.name),
              const SizedBox(width: 6),
              const Icon(Icons.edit, size: 16),
            ],
          ),
        ),
        actions: [
          if (build.components.isNotEmpty ||
              build.storageList.isNotEmpty ||
              build.ramList.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Сохранить сборку',
              onPressed: () {
                provider.saveBuild();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Сборка сохранена!')),
                );
              },
            ),
          if (build.components.isNotEmpty ||
              build.storageList.isNotEmpty ||
              build.ramList.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Очистить',
              onPressed: () => _confirmClear(context, provider),
            ),
        ],
      ),
      body: Column(
        children: [
          // Summary bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Итого',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                      Text(
                        '${formatPrice(build.totalPrice)} ₽',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                // Compatibility status
                GestureDetector(
                  onTap: () =>
                      setState(() => _showCompatibility = !_showCompatibility),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: compat.errors.isEmpty
                          ? AppTheme.success.withValues(alpha: 0.1)
                          : AppTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: compat.errors.isEmpty
                            ? AppTheme.success
                            : AppTheme.error,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          compat.errors.isEmpty
                              ? Icons.check_circle
                              : Icons.warning,
                          size: 16,
                          color: compat.errors.isEmpty
                              ? AppTheme.success
                              : AppTheme.error,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          compat.errors.isEmpty
                              ? 'Совместимо'
                              : _pluralErrors(compat.errors.length),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: compat.errors.isEmpty
                                ? AppTheme.success
                                : AppTheme.error,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _showCompatibility
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Compatibility panel
          if (_showCompatibility &&
              (build.components.isNotEmpty ||
                  build.storageList.isNotEmpty ||
                  build.ramList.isNotEmpty))
            Container(
              color: const Color(0xFFF8F9FA),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (compat.errors.isNotEmpty) ...[
                    ...compat.errors.map((e) => _CompatRow(
                          icon: Icons.error,
                          color: AppTheme.error,
                          text: e,
                        )),
                  ],
                  if (compat.warnings.isNotEmpty) ...[
                    ...compat.warnings.map((w) => _CompatRow(
                          icon: Icons.warning_amber,
                          color: AppTheme.warning,
                          text: w,
                        )),
                  ],
                  if (compat.errors.isEmpty && compat.warnings.isEmpty)
                    const _CompatRow(
                      icon: Icons.check_circle,
                      color: AppTheme.success,
                      text: 'Все компоненты совместимы',
                    ),
                  // Power budget
                  if (build.components.containsKey(ComponentCategory.cpu) ||
                      build.components.containsKey(ComponentCategory.gpu))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Потребление: ~${compat.totalTdp} Вт  |  Рекомендуется БП: ${compat.requiredPower} Вт',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: build.components
                                          .containsKey(ComponentCategory.psu)
                                      ? (compat.totalTdp /
                                              (build.components[ComponentCategory
                                                      .psu]!.powerDraw ??
                                                  1))
                                          .clamp(0.0, 1.0)
                                      : 0.0,
                              backgroundColor: AppTheme.divider,
                              color: compat.totalTdp >
                                      (build
                                              .components[ComponentCategory.psu]
                                              ?.powerDraw ??
                                          1000)
                                  ? AppTheme.error
                                  : AppTheme.success,
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

          const Divider(height: 1),

          // Slots list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                // Обычные категории (не storage, не ram)
                ...nonListCategories.map((cat) {
                  final component = build.components[cat];
                  return _SlotCard(
                    category: cat,
                    component: component,
                    onAdd: () => context.push('/category/${cat.key}'),
                    onReplace: component != null
                        ? () => context.push('/category/${cat.key}')
                        : null,
                    onRemove: component != null
                        ? () => provider.removeFromBuild(cat)
                        : null,
                    onTap: component != null
                        ? () => context.push('/component/${component.id}')
                        : null,
                  );
                }),

                // ── Слоты оперативной памяти ──
                ...build.ramList.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final ram = entry.value;
                  return _SlotCard(
                    category: ComponentCategory.ram,
                    component: ram,
                    label: 'RAM ${idx + 1}',
                    onAdd: () => context.push(
                        '/category/${ComponentCategory.ram.key}'),
                    onReplace: () {
                      provider.removeRamStickAt(idx);
                      context.push('/category/${ComponentCategory.ram.key}');
                    },
                    onRemove: () => provider.removeRamStickAt(idx),
                    onTap: () => context.push('/component/${ram.id}'),
                  );
                }),

                // Кнопка «Добавить планку RAM» если есть свободные слоты
                _AddRamSlot(
                  currentCount: build.ramList.length,
                  maxSlots: provider.maxRamSlots,
                  onAdd: () =>
                      context.push('/category/${ComponentCategory.ram.key}'),
                ),

                // ── Слоты накопителей ──
                ...build.storageList.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final drive = entry.value;
                  return _SlotCard(
                    category: ComponentCategory.storage,
                    component: drive,
                    label: 'Накопитель ${idx + 1}',
                    onAdd: () => context.push(
                        '/category/${ComponentCategory.storage.key}'),
                    onReplace: () {
                      provider.removeStorageDriveAt(idx);
                      context.push('/category/${ComponentCategory.storage.key}');
                    },
                    onRemove: () => provider.removeStorageDriveAt(idx),
                    onTap: () => context.push('/component/${drive.id}'),
                  );
                }),

                // Кнопка «Добавить накопитель» если есть свободные слоты
                _AddStorageSlot(
                  currentCount: build.storageList.length,
                  maxSlots: provider.maxStorageSlots,
                  onAdd: () =>
                      context.push('/category/${ComponentCategory.storage.key}'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _editBuildName(BuildContext context, AppProvider provider) {
    final ctrl = TextEditingController(text: provider.currentBuild.name);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Название сборки'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Моя игровая сборка'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = ctrl.text.trim();
              Navigator.pop(dialogCtx);
              if (name.isNotEmpty) provider.setBuildName(name);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    ).whenComplete(ctrl.dispose);
  }

  void _confirmClear(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Очистить сборку?'),
        content: const Text('Все компоненты будут удалены из текущей сборки.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            onPressed: () {
              Navigator.pop(dialogContext);
              provider.clearBuild();
            },
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
  }

}

// ─── Add RAM Slot ───

class _AddRamSlot extends StatelessWidget {
  final int currentCount;
  final int maxSlots;
  final VoidCallback onAdd;

  const _AddRamSlot({
    required this.currentCount,
    required this.maxSlots,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final canAdd = currentCount < maxSlots;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: canAdd ? onAdd : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: canAdd
                      ? ComponentCategory.ram.color.withValues(alpha: 0.1)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  ComponentCategory.ram.icon,
                  color: canAdd
                      ? ComponentCategory.ram.color
                      : AppTheme.textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RAM ${currentCount + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        color: canAdd
                            ? ComponentCategory.ram.color
                            : AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      canAdd
                          ? 'Добавить планку памяти ($currentCount / $maxSlots)'
                          : 'Заполнены все слоты памяти ($maxSlots)',
                      style: TextStyle(
                        fontSize: 14,
                        color: canAdd
                            ? AppTheme.textSecondary
                            : AppTheme.error,
                      ),
                    ),
                  ],
                ),
              ),
              if (canAdd)
                const Icon(Icons.add_circle_outline,
                    color: AppTheme.primary, size: 24)
              else
                const Icon(Icons.block, color: AppTheme.error, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Add Storage Slot ───

class _AddStorageSlot extends StatelessWidget {
  final int currentCount;
  final int maxSlots;
  final VoidCallback onAdd;

  const _AddStorageSlot({
    required this.currentCount,
    required this.maxSlots,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final canAdd = currentCount < maxSlots;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: canAdd ? onAdd : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: canAdd
                      ? ComponentCategory.storage.color.withValues(alpha: 0.1)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  ComponentCategory.storage.icon,
                  color: canAdd
                      ? ComponentCategory.storage.color
                      : AppTheme.textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Накопитель ${currentCount + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        color: canAdd
                            ? ComponentCategory.storage.color
                            : AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      canAdd
                          ? 'Добавить накопитель ($currentCount / $maxSlots)'
                          : 'Достигнут лимит слотов корпуса ($maxSlots)',
                      style: TextStyle(
                        fontSize: 14,
                        color: canAdd
                            ? AppTheme.textSecondary
                            : AppTheme.error,
                      ),
                    ),
                  ],
                ),
              ),
              if (canAdd)
                const Icon(Icons.add_circle_outline,
                    color: AppTheme.primary, size: 24)
              else
                const Icon(Icons.block, color: AppTheme.error, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Slot Card ───

class _SlotCard extends StatelessWidget {
  final ComponentCategory category;
  final dynamic component;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;
  final VoidCallback? onReplace;
  final VoidCallback? onTap;
  final String? label;

  const _SlotCard({
    required this.category,
    required this.component,
    required this.onAdd,
    this.onRemove,
    this.onReplace,
    this.onTap,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final hasComponent = component != null;
    final displayLabel = label ?? category.shortName;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasComponent
              ? category.color.withValues(alpha: 0.3)
              : AppTheme.divider,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: hasComponent
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: category.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(category.icon,
                          color: category.color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: category.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            component.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            component.keySpecs.take(2).join(' · '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${formatPrice(component.price)} ₽',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accent,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Кнопка «Заменить»
                            GestureDetector(
                              onTap: onReplace,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.swap_horiz,
                                    size: 14, color: AppTheme.primary),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Кнопка «Удалить»
                            GestureDetector(
                              onTap: onRemove,
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
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(category.icon,
                          color: AppTheme.textSecondary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Выбрать ${category.displayName.toLowerCase()}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.add_circle_outline,
                        color: AppTheme.primary, size: 24),
                  ],
                ),
              ),
            ),
    );
  }

}

class _CompatRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _CompatRow(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: color, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
