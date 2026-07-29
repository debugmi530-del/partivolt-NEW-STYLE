import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/component.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../utils/format_utils.dart';

class ComponentCard extends StatelessWidget {
  final Component component;
  final VoidCallback onTap;

  const ComponentCard({
    super.key,
    required this.component,
    required this.onTap,
  });

  void _onCompareTap(BuildContext context, AppProvider provider, bool inCompare) {
    final messenger = ScaffoldMessenger.of(context);

    if (inCompare) {
      provider.removeFromCompare(component.id);
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF2D2D2D),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            duration: const Duration(seconds: 2),
            content: const Text(
              'Убрано из сравнения',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        );
    } else {
      final added = provider.addToCompare(component);
      if (added) {
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF0D2137),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              duration: const Duration(seconds: 3),
              content: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(component.category.icon,
                        color: AppTheme.accent, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Добавлено к сравнению',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          component.name,
                          style: const TextStyle(
                              color: Color(0xFF8BA8BF), fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              action: SnackBarAction(
                label: 'Сравнить →',
                textColor: AppTheme.accent,
                onPressed: () {
                  messenger.clearSnackBars();
                  context.push('/compare');
                },
              ),
            ),
          );
      } else {
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF0D2137),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              duration: const Duration(seconds: 2),
              content: const Text(
                'В сравнении уже 40 товаров',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final inCompare = provider.isInCompare(component.id);

    // Для RAM и storage поддерживаем кратные добавления
    final isStorage = component.category == ComponentCategory.storage;
    final isRam = component.category == ComponentCategory.ram;
    final isMultiSlot = isStorage || isRam;

    final countInBuild = isStorage
        ? provider.storageCountInBuild(component.id)
        : isRam
            ? provider.ramCountInBuild(component.id)
            : 0;

    // Для обычных категорий — стандартное поведение
    final inBuild = isMultiSlot
        ? countInBuild > 0
        : provider.isInCurrentBuild(component.id);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: inBuild
            ? const BorderSide(color: AppTheme.success, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon placeholder
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: component.category.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        component.category.icon,
                        color: component.category.color,
                        size: 34,
                      ),
                    ),
                    // Для multi-slot показываем счётчик вместо просто галочки
                    if (isMultiSlot && countInBuild > 0)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.success,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$countInBuild',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                    else if (!isMultiSlot && inBuild)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: AppTheme.success,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check,
                              size: 10, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      component.brand,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      component.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: component.keySpecs.take(3).map((s) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.chip,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            s,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.chipText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${formatPrice(component.price)} ₽',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.accent,
                          ),
                        ),
                        const Spacer(),

                        // Compare button
                        GestureDetector(
                          onTap: () =>
                              _onCompareTap(context, provider, inCompare),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: inCompare
                                  ? AppTheme.primary.withValues(alpha: 0.1)
                                  : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(6),
                              border: inCompare
                                  ? Border.all(color: AppTheme.primary)
                                  : null,
                            ),
                            child: Icon(
                              Icons.compare_arrows,
                              size: 16,
                              color: inCompare
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // ── Кнопки для multi-slot (RAM / накопители) ──
                        if (isMultiSlot && countInBuild > 0)
                          _MultiSlotCounter(
                            count: countInBuild,
                            onDecrement: () => _onDecrement(context, provider),
                            onIncrement: () =>
                                _onAddToBuild(context, provider, inBuild),
                          )
                        else
                          // Add to build button (обычный вид)
                          GestureDetector(
                            onTap: () =>
                                _onAddToBuild(context, provider, inBuild),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isMultiSlot
                                    ? AppTheme.accent
                                    : (inBuild
                                        ? AppTheme.success
                                        : AppTheme.accent),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isMultiSlot
                                        ? Icons.add
                                        : (inBuild
                                            ? Icons.check
                                            : Icons.add),
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isMultiSlot
                                        ? 'В сборку'
                                        : (inBuild ? 'В сборке' : 'В сборку'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onDecrement(BuildContext context, AppProvider provider) {
    final isStorage = component.category == ComponentCategory.storage;
    if (isStorage) {
      provider.removeFirstStorageDriveOccurrence(component.id);
    } else {
      provider.removeFirstRamStickOccurrence(component.id);
    }
  }

  void _onAddToBuild(BuildContext context, AppProvider provider, bool inBuild) {
    final messenger = ScaffoldMessenger.of(context);
    final isStorage = component.category == ComponentCategory.storage;
    final isRam = component.category == ComponentCategory.ram;

    if (isStorage) {
      final limitErr = provider.canAddStorageDrive(component);
      if (limitErr != null) {
        messenger
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(limitErr)));
      } else {
        provider.addToBuild(component);
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('${component.model} добавлен в сборку'),
              duration: const Duration(seconds: 2),
            ),
          );
      }
    } else if (isRam) {
      final limitErr = provider.canAddRamStick(component);
      if (limitErr != null) {
        messenger
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(limitErr)));
      } else {
        provider.addToBuild(component);
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('${component.model} добавлен в сборку'),
              duration: const Duration(seconds: 2),
            ),
          );
      }
    } else {
      // Обычная категория — toggle
      if (inBuild) {
        provider.removeFromBuild(component.category);
      } else {
        provider.addToBuild(component);
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('${component.model} добавлен в сборку'),
              duration: const Duration(seconds: 2),
            ),
          );
      }
    }
  }

}

// ── Виджет счётчика [−] n [+] для RAM и накопителей ──
class _MultiSlotCounter extends StatelessWidget {
  final int count;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _MultiSlotCounter({
    required this.count,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.accent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Кнопка −
          GestureDetector(
            onTap: onDecrement,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: const Icon(Icons.remove, size: 14, color: Colors.white),
            ),
          ),
          // Счётчик
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // Кнопка +
          GestureDetector(
            onTap: onIncrement,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: const Icon(Icons.add, size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
