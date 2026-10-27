import 'package:flutter/material.dart';
import '../../core/design/design_catalog.dart';
import '../../core/design/design_painter.dart';
import '../scene/scene_page.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({
    super.key,
    required this.catalog,
    required this.openScreen,
  });
  final DesignCatalog catalog;
  final ValueChanged<String> openScreen;
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  String _query = '';
  int? _category;
  static const _icons = [
    Icons.auto_awesome_outlined,
    Icons.lock_outline,
    Icons.chat_bubble_outline,
    Icons.menu_open,
    Icons.person_outline,
    Icons.newspaper,
    Icons.headphones,
    Icons.insights,
    Icons.shopping_bag_outlined,
    Icons.flight_takeoff,
    Icons.web_asset,
  ];
  bool _matches(DesignNode s, DesignCategory c) =>
      _query.isEmpty ||
      '${s.name} ${c.title} ${c.name}'.toLowerCase().contains(_query);

  @override
  Widget build(BuildContext context) {
    final categories = widget.catalog.categories;
    final filtered = categories
        .where((c) => _category == null || categories.indexOf(c) == _category)
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xfff7f8fa),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'THINK',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 2),
        ),
        actions: [
          IconButton(
            tooltip: '开始引导',
            onPressed: () => widget.openScreen('Walkthrough 1'),
            icon: const Icon(Icons.play_circle_outline),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EXPLORE\nYOUR NEXT IDEA.',
                        style: TextStyle(
                          fontFamily: 'Bebas Neue',
                          fontSize: MediaQuery.sizeOf(context).width < 500
                              ? 48
                              : 64,
                          height: .98,
                          color: const Color(0xff22242a),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '11 个分类 · 120 个界面\n根据 Pixso Think UI Kit 实现的 Flutter 交互演示',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xff8d92a3),
                          height: 1.7,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        key: const ValueKey('catalog-search'),
                        onChanged: (value) =>
                            setState(() => _query = value.toLowerCase()),
                        decoration: InputDecoration(
                          hintText: '搜索界面，例如 Chat / 购物 / Profile',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: const Text('全部'),
                                selected: _category == null,
                                onSelected: (_) =>
                                    setState(() => _category = null),
                              ),
                            ),
                            for (var i = 0; i < categories.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(categories[i].title),
                                  selected: _category == i,
                                  onSelected: (_) =>
                                      setState(() => _category = i),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '选择界面可体验交互。界面内长按空白处或点按左上角边缘可返回目录。',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xff8d92a3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              for (final category in filtered)
                ..._section(category, categories.indexOf(category)),
              if (!filtered.any((c) => c.screens.any((s) => _matches(s, c))))
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('没有匹配的界面，试试其他关键词。')),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _section(DesignCategory category, int index) {
    final screens = category.screens
        .where((s) => _matches(s, category))
        .toList();
    if (screens.isEmpty) return [];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: thinkPrimary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icons[index], color: thinkPrimary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      category.name,
                      style: const TextStyle(
                        color: Color(0xff8d92a3),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${screens.length}',
                style: const TextStyle(
                  color: thinkPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) => SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: constraints.crossAxisExtent > 900
                  ? 5
                  : constraints.crossAxisExtent > 650
                  ? 4
                  : constraints.crossAxisExtent > 450
                  ? 3
                  : 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 16,
              childAspectRatio: .51,
            ),
            delegate: SliverChildBuilderDelegate((context, i) {
              final screen = screens[i];
              return Semantics(
                button: true,
                label: '打开 ${screen.name}',
                child: InkWell(
                  key: ValueKey('screen:${screen.id}'),
                  onTap: () => widget.openScreen(screen.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xffe6e8ef)),
                          ),
                          child: FittedBox(
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: 375,
                              height: 812,
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  painter: DesignPainter(
                                    catalog: widget.catalog,
                                    screen: screen,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        screen.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }, childCount: screens.length),
          ),
        ),
      ),
    ];
  }
}
