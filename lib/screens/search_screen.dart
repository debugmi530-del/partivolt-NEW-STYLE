import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/component.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../widgets/component_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<Component> _results = [];
  bool _searched = false;

  final _recentSearches = [
    'RTX 4090', 'Ryzen 9', 'DDR5', 'NVMe SSD', 'AIO 360mm',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String q, AppProvider provider) {
    final results = provider.searchAll(q);
    setState(() {
      _results = results;
      _searched = q.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use watch so that sort/filter changes in provider trigger a rebuild
    // and results are re-computed with the latest ordering.
    final provider = context.watch<AppProvider>();

    // Always recompute from provider when the user has an active search query
    // so that sort/filter changes are immediately reflected in the list.
    final liveResults = _searched && _controller.text.isNotEmpty
        ? provider.searchAll(_controller.text)
        : _results;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          cursorColor: Colors.white,
          decoration: InputDecoration(
            hintText: 'Поиск по каталогу...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white),
                    onPressed: () {
                      _controller.clear();
                      setState(() {
                        _results = [];
                        _searched = false;
                      });
                    },
                  )
                : null,
          ),
          onChanged: (q) => _search(q, provider),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: _searched
          ? _buildResults(liveResults)
          : _buildSuggestions(provider),
    );
  }

  Widget _buildResults(List<Component> results) {
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 64, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            Text(
              'По запросу «${_controller.text}» ничего не найдено',
              style: const TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Group by category
    final grouped = <ComponentCategory, List<Component>>{};
    for (final c in results) {
      grouped.putIfAbsent(c.category, () => <Component>[]).add(c);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'Найдено: ${results.length}',
            style: const TextStyle(
                fontSize: 13, color: AppTheme.textSecondary),
          ),
        ),
        ...grouped.entries.expand<Widget>((entry) => [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Icon(entry.key.icon, size: 16, color: entry.key.color),
                const SizedBox(width: 8),
                Text(
                  entry.key.displayName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: entry.key.color,
                  ),
                ),
                const SizedBox(width: 8),
                Text('(${entry.value.length})',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          ...entry.value.map((c) => ComponentCard(
            component: c,
            onTap: () => context.push('/component/${c.id}'),
          )),
        ]),
      ],
    );
  }

  Widget _buildSuggestions(AppProvider provider) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Category quick links
        const Text('Категории',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ComponentCategory.values.map((cat) {
            return ActionChip(
              avatar: Icon(cat.icon, size: 16, color: cat.color),
              label: Text(cat.displayName),
              onPressed: () => context.push('/category/${cat.key}'),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: cat.color.withValues(alpha: 0.4)),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),

        // Popular queries
        const Text('Популярные запросы',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ..._recentSearches.map((q) => ListTile(
          leading: const Icon(Icons.trending_up, color: AppTheme.primary, size: 20),
          title: Text(q),
          dense: true,
          onTap: () {
            _controller.text = q;
            _search(q, provider);
          },
          trailing: const Icon(Icons.north_west, size: 16, color: AppTheme.textSecondary),
        )),
      ],
    );
  }
}
