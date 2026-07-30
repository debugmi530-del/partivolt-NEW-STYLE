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

  // Track last computed sort key so didChangeDependencies re-runs search
  // only when sort actually changes — not on every provider notification.
  String _lastSortBy = '';

  // Популярные запросы: генерируются из каталога при открытии экрана.
  // Список фиксируется на полдня и меняется в 00:00 и 12:00.
  late List<String> _popularSuggestions;

  @override
  void initState() {
    super.initState();
    _popularSuggestions =
        context.read<AppProvider>().getPopularSuggestions();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Called whenever an InheritedWidget dependency (i.e. AppProvider) changes.
  /// Re-runs the search when sort order changes so results stay ordered without
  /// calling provider.searchAll() inside build().
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_searched || _controller.text.isEmpty) return;
    final provider = context.read<AppProvider>();
    final newSortBy = provider.sortBy;
    if (newSortBy == _lastSortBy) return;
    _lastSortBy = newSortBy;
    // Update _results directly — didChangeDependencies runs before build(),
    // so the new value will be picked up in the same frame.
    _results = provider.searchAll(_controller.text);
  }

  void _search(String q, AppProvider provider) {
    final results = provider.searchAll(q);
    _lastSortBy = provider.sortBy;
    setState(() {
      _results = results;
      _searched = q.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch so that ComponentCard badges (in-build counts) update live.
    // Search results are managed via _results / didChangeDependencies instead
    // of being recomputed here to avoid an O(n) scan on every frame.
    final provider = context.watch<AppProvider>();

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
                        _lastSortBy = '';
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
          ? _buildResults(_results)
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
        ..._popularSuggestions.map((q) => ListTile(
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
