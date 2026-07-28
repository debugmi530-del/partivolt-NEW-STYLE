import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/component.dart';
import '../providers/app_provider.dart';
import '../theme.dart';

class ComponentDetailScreen extends StatelessWidget {
  final String componentId;
  const ComponentDetailScreen({super.key, required this.componentId});

  @override
  Widget build(BuildContext context) {
    // findComponentById is accessible via provider
    final provider = context.read<AppProvider>();
    final component = provider.findById(componentId);
    if (component == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ошибка')),
        body: const Center(child: Text('Компонент не найден')),
      );
    }
    return _ComponentDetailView(component: component);
  }
}

class _ComponentDetailView extends StatelessWidget {
  final Component component;
  const _ComponentDetailView({required this.component});

  void _showAddedToCompareSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context)
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
                  color: AppTheme.accent, size: 18),
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
                      color: Color(0xFF8BA8BF),
                      fontSize: 11,
                    ),
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
          onPressed: () => context.push('/compare'),
        ),
      ),
    );
  }

  void _showRemovedFromCompareSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context)
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
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final inBuild = provider.isInCurrentBuild(component.id);
    final inCompare = provider.isInCompare(component.id);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero App Bar
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: AppTheme.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  inCompare ? Icons.compare_arrows : Icons.compare_arrows_outlined,
                  color: inCompare ? AppTheme.accent : Colors.white,
                ),
                tooltip: 'Сравнить',
                onPressed: () {
                  final messenger = ScaffoldMessenger.of(context);
                  if (inCompare) {
                    provider.removeFromCompare(component.id);
                    _showRemovedFromCompareSnackbar(context);
                  } else {
                    final added = provider.addToCompare(component);
                    if (added) {
                      _showAddedToCompareSnackbar(context);
                    } else {
                      messenger
                        ..clearSnackBars()
                        ..showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: const Color(0xFF0D2137),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                            duration: const Duration(seconds: 2),
                            content: const Text(
                              'В сравнении уже 3 товара',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        );
                    }
                  }
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      component.category.color.withValues(alpha: 0.8),
                      AppTheme.primaryDark,
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 60),
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          component.category.icon,
                          size: 56,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: component.category.color.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          component.category.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name & Price
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        component.brand,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        component.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            '${_formatPrice(component.price)} ₽',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.accent,
                            ),
                          ),
                          const Spacer(),
                          Wrap(
                            spacing: 4,
                            children: component.keySpecs
                                .take(2)
                                .map((s) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.chip,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        s,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.chipText,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Key specs row
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ключевые характеристики',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          )),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: component.keySpecs
                            .map((s) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.chip,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.2)),
                                  ),
                                  child: Text(
                                    s,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.chipText,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Description
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Описание',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          )),
                      const SizedBox(height: 8),
                      Text(
                        component.description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Full specs table
                Container(
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Text('Характеристики',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            )),
                      ),
                      ...component.specs.entries.toList().asMap().entries.map(
                        (entry) {
                          final idx = entry.key;
                          final spec = entry.value;
                          return Container(
                            color: idx.isEven
                                ? Colors.white
                                : const Color(0xFFF8FAFC),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    spec.key,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    spec.value,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),

      // Bottom action bar
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: Icon(
                  inCompare ? Icons.check_circle : Icons.compare_arrows,
                  size: 18,
                ),
                label: Text(inCompare ? 'В сравнении' : 'Сравнить'),
                onPressed: () {
                  final messenger = ScaffoldMessenger.of(context);
                  if (inCompare) {
                    provider.removeFromCompare(component.id);
                    _showRemovedFromCompareSnackbar(context);
                  } else {
                    final added = provider.addToCompare(component);
                    if (added) {
                      _showAddedToCompareSnackbar(context);
                    } else {
                      messenger
                        ..clearSnackBars()
                        ..showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: const Color(0xFF0D2137),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                            duration: const Duration(seconds: 2),
                            content: const Text(
                              'В сравнении уже 3 товара',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        );
                    }
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                icon: Icon(
                  inBuild ? Icons.check_circle : Icons.add_shopping_cart,
                  size: 18,
                ),
                label: _buildButtonLabel(provider),
                onPressed: () {
                  final messenger = ScaffoldMessenger.of(context);
                  final isStorage = component.category == ComponentCategory.storage;
                  final isRam = component.category == ComponentCategory.ram;

                  if (isStorage) {
                    final limitErr = provider.canAddStorageDrive(component);
                    if (limitErr != null) {
                      messenger
                        ..clearSnackBars()
                        ..showSnackBar(SnackBar(
                          content: Text(limitErr),
                          duration: const Duration(seconds: 2),
                        ));
                    } else {
                      provider.addToBuild(component);
                      messenger
                        ..clearSnackBars()
                        ..showSnackBar(SnackBar(
                          content: Text('${component.model} добавлен в сборку'),
                          duration: const Duration(seconds: 2),
                          action: SnackBarAction(
                            label: 'Сборка',
                            onPressed: () {
                              messenger.clearSnackBars();
                              context.push('/builder');
                            },
                          ),
                        ));
                    }
                  } else if (isRam) {
                    final limitErr = provider.canAddRamStick(component);
                    if (limitErr != null) {
                      messenger
                        ..clearSnackBars()
                        ..showSnackBar(SnackBar(
                          content: Text(limitErr),
                          duration: const Duration(seconds: 2),
                        ));
                    } else {
                      provider.addToBuild(component);
                      messenger
                        ..clearSnackBars()
                        ..showSnackBar(SnackBar(
                          content: Text('${component.model} добавлен в сборку'),
                          duration: const Duration(seconds: 2),
                          action: SnackBarAction(
                            label: 'Сборка',
                            onPressed: () {
                              messenger.clearSnackBars();
                              context.push('/builder');
                            },
                          ),
                        ));
                    }
                  } else if (inBuild) {
                    provider.removeFromBuild(component.category);
                    messenger
                      ..clearSnackBars()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text('Удалено из сборки'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                  } else {
                    provider.addToBuild(component);
                    messenger
                      ..clearSnackBars()
                      ..showSnackBar(
                        SnackBar(
                          content: Text('${component.model} добавлен в сборку'),
                          duration: const Duration(seconds: 2),
                          action: SnackBarAction(
                            label: 'Сборка',
                            onPressed: () {
                              messenger.clearSnackBars();
                              context.push('/builder');
                            },
                          ),
                        ),
                      );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      inBuild ? AppTheme.success : AppTheme.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Возвращает текст кнопки «В сборку» с учётом типа компонента.
  /// Для накопителей и RAM — всегда «В сборку» (можно добавить несколько).
  Widget _buildButtonLabel(AppProvider provider) {
    final isStorage = component.category == ComponentCategory.storage;
    final isRam = component.category == ComponentCategory.ram;

    if (isStorage) {
      final count = provider.storageCountInBuild(component.id);
      return Text(count > 0 ? 'В сборку (×$count)' : 'В сборку');
    }
    if (isRam) {
      final count = provider.ramCountInBuild(component.id);
      return Text(count > 0 ? 'В сборку (×$count)' : 'В сборку');
    }
    final inBuild = provider.isInCurrentBuild(component.id);
    return Text(inBuild ? 'В сборке' : 'В сборку');
  }

  String _formatPrice(double price) {
    return price.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );
  }
}
