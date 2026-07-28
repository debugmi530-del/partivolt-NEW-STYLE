import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/component.dart';
import '../models/pc_build.dart';
import '../providers/app_provider.dart';
import '../theme.dart';

class BuildsScreen extends StatelessWidget {
  const BuildsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final builds = provider.savedBuilds;

    // Если пришла ссылка — автоматически запускаем импорт
    final pending = provider.pendingImportCode;
    if (pending != null) {
      provider.clearPendingImportCode();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) _doImport(context, pending);
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Мои сборки'),
        actions: [
          // ── Кнопка импорта ──
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Импортировать сборку',
            onPressed: () => _showImportDialog(context),
          ),
          if (builds.length >= 2)
            TextButton.icon(
              icon: const Icon(Icons.compare_arrows, color: Colors.white, size: 18),
              label: const Text('Сравнить', style: TextStyle(color: Colors.white)),
              onPressed: () => _showCompareBuildPicker(context, builds),
            ),
        ],
      ),
      body: builds.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bookmark_border,
                      size: 80, color: AppTheme.textSecondary),
                  const SizedBox(height: 16),
                  const Text('Нет сохранённых сборок',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text(
                    'Создайте сборку и сохраните её\nдля сравнения или повторного просмотра',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Импортировать сборку'),
                    onPressed: () => _showImportDialog(context),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Создать сборку'),
                    onPressed: () => context.go('/builder'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: builds.length,
              itemBuilder: (ctx, i) => _BuildCard(
                pcBuild: builds[i],
                onShare: () => _shareBuild(ctx, builds[i]),
                onLoad: () {
                  context.read<AppProvider>().loadSavedBuild(builds[i]);
                  context.go('/builder');
                },
                onDelete: () {
                  context.read<AppProvider>().deleteSavedBuild(builds[i].id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Сборка удалена')),
                  );
                },
              ),
            ),
    );
  }

  // ── Поделиться: показывает диалог с кодом и кнопкой копирования ──
  void _shareBuild(BuildContext context, PcBuild build) {
    final code = build.toShareCode();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Поделиться сборкой'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '«${build.name}»',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 12),
            const Text(
              'Отправьте этот код другу. Он откроет Partivolt → «Сборки» → кнопка ↓ → вставит код.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
              ),
              child: SelectableText(
                code,
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Скопировать код'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Код сборки «${build.name}» скопирован',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  duration: const Duration(seconds: 3),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Диалог импорта ──
  void _showImportDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Импорт сборки'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Вставьте ссылку или код сборки:',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'partivolt://import?code=... или eyJ2...',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = controller.text.trim();
              if (code.isEmpty) return;
              Navigator.pop(ctx);
              _doImport(context, code);
            },
            child: const Text('Импортировать'),
          ),
        ],
      ),
    );
  }

  // ── Выполняет импорт и показывает результат ──
  void _doImport(BuildContext context, String raw) {
    // Принимаем как полную ссылку partivolt://import?code=..., так и голый код
    String code = raw.trim();
    if (code.startsWith('partivolt://')) {
      final uri = Uri.tryParse(code);
      code = uri?.queryParameters['code'] ?? code;
    }

    final provider = context.read<AppProvider>();
    final result = provider.importBuildFromCode(code);

    if (!result.success) {
      // Код невалиден
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.missingCategories.first,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.error,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Сохраняем импортированную сборку
    provider.saveImportedBuild(result.build!);

    if (result.hasWarnings) {
      // Импорт прошёл, но часть компонентов не перенеслась
      final missing = result.missingCategories.join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$missing не перенеслись — компоненты незнакомы этой версии приложения. Обновите приложение.',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.warning,
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      // Всё перенеслось без потерь
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Сборка «${result.build!.name}» импортирована',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showCompareBuildPicker(BuildContext context, List<PcBuild> builds) {
    final selectedIds = <String>[];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Выберите 2 сборки'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Выберите ровно 2 сборки для сравнения',
                  style:
                      TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: builds.length,
                    itemBuilder: (_, i) {
                      final b = builds[i];
                      final isSelected = selectedIds.contains(b.id);
                      final isDisabled =
                          selectedIds.length >= 2 && !isSelected;
                      return CheckboxListTile(
                        dense: true,
                        title: Text(
                          b.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDisabled
                                ? AppTheme.textSecondary
                                : AppTheme.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${b.components.length} компонентов · ${_fmt(b.totalPrice)} ₽',
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: isSelected,
                        activeColor: AppTheme.primary,
                        onChanged: isDisabled
                            ? null
                            : (v) {
                                setState(() {
                                  if (v == true) {
                                    selectedIds.add(b.id);
                                  } else {
                                    selectedIds.remove(b.id);
                                  }
                                });
                              },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: selectedIds.length == 2
                  ? () {
                      Navigator.pop(ctx);
                      context.push(
                        '/compare-builds?id1=${selectedIds[0]}&id2=${selectedIds[1]}',
                      );
                    }
                  : null,
              child: Text(
                selectedIds.isEmpty
                    ? 'Выберите 2'
                    : selectedIds.length == 1
                        ? 'Ещё одну'
                        : 'Сравнить',
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(double p) => p.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]} ',
      );
}

class _BuildCard extends StatelessWidget {
  final PcBuild pcBuild;
  final VoidCallback onShare;
  final VoidCallback onLoad;
  final VoidCallback onDelete;

  const _BuildCard({
    required this.pcBuild,
    required this.onShare,
    required this.onLoad,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final categories = ComponentCategory.values
        .where((c) => pcBuild.components.containsKey(c))
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.computer, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pcBuild.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${_fmt(pcBuild.totalPrice)} ₽',
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          // Component chips
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: categories.map((cat) {
                final comp = pcBuild.components[cat]!;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cat.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: cat.color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cat.icon, size: 12, color: cat.color),
                      const SizedBox(width: 4),
                      Text(
                        comp.model,
                        style: TextStyle(
                          fontSize: 11,
                          color: cat.color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          if (!pcBuild.isComplete)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: AppTheme.warning),
                  const SizedBox(width: 4),
                  Text(
                    'Сборка неполная (${pcBuild.components.length}/8 компонентов)',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.warning),
                  ),
                ],
              ),
            ),

          // Actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text(
                  '${pcBuild.components.length} компонентов',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
                const Spacer(),
                // ── Кнопка «Поделиться» ──
                OutlinedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.share_outlined, size: 14),
                  label: const Text('Поделиться', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child:
                      const Text('Удалить', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 6),
                ElevatedButton(
                  onPressed: onLoad,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Загрузить',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(double p) => p.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]} ',
      );
}
