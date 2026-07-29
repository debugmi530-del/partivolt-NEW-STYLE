import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/component.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../widgets/component_card.dart';
import '../widgets/filter_panel.dart'; // exports FilterScreen

class CategoryScreen extends StatefulWidget {
  final String categoryKey;
  const CategoryScreen({super.key, required this.categoryKey});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  late ComponentCategory _category;
  final _searchCtrl = TextEditingController();
  String _localSearch = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _category = ComponentCategory.values.firstWhere(
      (c) => c.key == widget.categoryKey,
      orElse: () => ComponentCategory.cpu,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _localSearch = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    var components = provider.filteredComponents(_category);

    // Local search filter on top of provider filter
    if (_localSearch.isNotEmpty) {
      final q = _localSearch.toLowerCase();
      components = components.where((c) =>
        c.name.toLowerCase().contains(q) ||
        c.brand.toLowerCase().contains(q)
      ).toList();
    }

    final sortOptions = {
      'price_asc': 'Сначала дешевле',
      'price_desc': 'Сначала дороже',
      'name_asc': 'По названию (А-Я)',
      'name_desc': 'По названию (Я-А)',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(_category.displayName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: provider.activeFilters.isNotEmpty,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: () => _showFilterPanel(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: provider.setSortBy,
            itemBuilder: (_) => sortOptions.entries
                .map((e) => PopupMenuItem(
                      value: e.key,
                      child: Row(
                        children: [
                          if (provider.sortBy == e.key)
                            const Icon(Icons.check, size: 16, color: AppTheme.primary),
                          if (provider.sortBy != e.key)
                            const SizedBox(width: 16),
                          const SizedBox(width: 8),
                          Text(e.value),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Поиск в ${_category.displayName.toLowerCase()}...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _localSearch.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _localSearch = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // Active filters row
          if (provider.activeFilters.isNotEmpty)
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  ...provider.activeFilters.entries.expand((entry) =>
                    entry.value.map((v) => Container(
                      margin: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text('${entry.key}: $v'),
                        onDeleted: () => provider.toggleFilter(entry.key, v),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        backgroundColor: AppTheme.chip,
                        labelStyle: const TextStyle(
                          fontSize: 11, color: AppTheme.chipText),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ))
                  ),
                  TextButton(
                    onPressed: () => provider.clearFiltersForCategory(_category.key),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Сбросить всё',
                        style: TextStyle(fontSize: 12, color: Colors.red)),
                  ),
                ],
              ),
            ),

          // Results count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  'Найдено: ${components.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Component list
          Expanded(
            child: components.isEmpty
                ? Center(
                    child: _buildEmptyState(provider),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 20),
                    itemCount: components.length,
                    itemBuilder: (ctx, i) => ComponentCard(
                      component: components[i],
                      onTap: () =>
                          context.push('/component/${components[i].id}'),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppProvider provider) {
    // Специальное сообщение когда фильтр совместимости скрыл накопители/RAM
    // потому что слоты заполнены
    if (provider.compatibilityFilterEnabled) {
      final build = provider.currentBuild;
      if (_category == ComponentCategory.storage &&
          build.components.containsKey(ComponentCategory.pcCase) &&
          build.storageList.length >= provider.maxStorageSlots) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 64, color: AppTheme.warning),
            const SizedBox(height: 12),
            const Text(
              'Слоты накопителей заполнены',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Все отсеки корпуса заняты.\nУдалите один из накопителей в сборщике.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        );
      }
      if (_category == ComponentCategory.ram &&
          build.ramList.length >= provider.maxRamSlots) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.memory_outlined,
                size: 64, color: AppTheme.warning),
            const SizedBox(height: 12),
            const Text(
              'Все слоты памяти заняты',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Материнская плата не поддерживает\nбольше планок памяти.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        );
      }
    }
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.search_off, size: 64, color: AppTheme.textSecondary),
        SizedBox(height: 12),
        Text('Ничего не найдено',
            style: TextStyle(color: AppTheme.textSecondary)),
      ],
    );
  }

  void _showFilterPanel(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FilterScreen(category: _category),
        fullscreenDialog: true,
      ),
    );
  }
}
