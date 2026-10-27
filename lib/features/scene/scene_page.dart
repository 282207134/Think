import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/design_catalog.dart';
import '../../core/design/design_painter.dart';
import '../../core/state/app_state.dart';
import 'scene_controls.dart';

const thinkPrimary = Color(0xff6470d3);

class ScenePage extends StatefulWidget {
  const ScenePage({
    super.key,
    required this.catalog,
    required this.screen,
    required this.state,
    required this.openCatalog,
    required this.openScreen,
  });
  final DesignCatalog catalog;
  final DesignNode screen;
  final AppState state;
  final VoidCallback openCatalog;
  final ValueChanged<String> openScreen;

  @override
  State<ScenePage> createState() => _ScenePageState();
}

class _ScenePageState extends State<ScenePage> {
  final _fields = <String, TextEditingController>{};
  final _selection = <String, String>{};
  late final List<SceneControl> _controls;
  late final List<DesignNode> _nodes;
  late final Set<String> _fixed;
  late final List<DesignNode> _carousels;
  late final Set<String> _carouselIds;
  late final double _extent;
  final _scroll = ScrollController();
  AppState get state => widget.state;
  DesignNode get screen => widget.screen;
  DesignNode? get _track => _nodes
      .where((n) => n.name == 'Track' && n.width > 200 && n.height < 100)
      .firstOrNull;

  @override
  void initState() {
    super.initState();
    _nodes = screen.descendants.toList();
    _controls = controlsFor(screen)
      ..sort(
        (a, b) => (b.rect.width * b.rect.height).compareTo(
          a.rect.width * a.rect.height,
        ),
      );
    for (final control in _controls.where((c) => c.kind == ControlKind.input)) {
      _fields[control.node.id] = TextEditingController();
    }
    _fixed = {
      for (final n in screen.children)
        if (const [
          'Header',
          'Status Bar',
          'Home Indicator',
          'Navbar',
          'Bottom',
        ].contains(n.name))
          ...n.descendants.map((c) => c.id),
    };
    _carousels = screen.children
        .where(
          (n) =>
              n.type == 'GROUP' &&
              n.rect.left >= 0 &&
              n.rect.right > 375 &&
              n.height < 400 &&
              const [
                'Items',
                'Stories',
                'Albums',
                'New Albums',
                'Genres',
                'Filters',
              ].contains(n.name),
        )
        .toList();
    _carouselIds = {
      for (final n in _carousels) ...n.descendants.map((n) => n.id),
    };
    if (screen.name.startsWith('Music')) {
      state.playing = screen.name != 'Music Pause';
    }
    // Off-canvas artwork is often an intentional carousel neighbour. Only
    // visible-width content contributes to the vertical scroll extent.
    _extent = _nodes
        .where(
          (n) =>
              !_fixed.contains(n.id) &&
              !n.id.startsWith('I') &&
              n.rect.left >= 0 &&
              n.rect.right <= 396 &&
              n.rect.top > 110 &&
              (n.type == 'TEXT' ||
                  n.type == 'GROUP' &&
                      !const ['Screen', 'Pull', 'Background'].contains(n.name)),
        )
        .fold(812.0, (maxY, n) => math.max(maxY, n.rect.bottom + 100));
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  void _go(String name) {
    FocusManager.instance.primaryFocus?.unfocus();
    widget.openScreen(name);
  }

  void _notice(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
  );
  void _back() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      widget.openCatalog();
    }
  }

  Future<void> _information(String title, String text) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('知道了'),
        ),
      ],
    ),
  );

  String _value(String label) {
    final control = _controls
        .where(
          (c) =>
              c.kind == ControlKind.input &&
              c.label.toLowerCase() == label.toLowerCase(),
        )
        .firstOrNull;
    return control == null ? '' : _fields[control.node.id]!.text.trim();
  }

  bool _validate({bool registration = false}) {
    final email = _value('E-Mail');
    if (email.isEmpty ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      _notice('请输入有效的邮箱地址');
      return false;
    }
    if (_value('Password').length < 6) {
      _notice('密码至少需要 6 个字符');
      return false;
    }
    if (registration && _value('Name').isEmpty) {
      _notice('请输入姓名');
      return false;
    }
    return true;
  }

  Future<String?> _choose(String title, List<String> choices) =>
      showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              for (final choice in choices)
                ListTile(
                  title: Text(choice),
                  onTap: () => Navigator.pop(context, choice),
                ),
            ],
          ),
        ),
      );

  Future<void> _compose({bool task = false}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(task ? '新建任务' : '发表评论'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: task ? 1 : 3,
          decoration: InputDecoration(hintText: task ? '任务名称' : '分享你的想法'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      task ? state.addTask(result) : state.sendMessage(result);
    }
    // The route's closing animation still uses its controller for one frame.
    Future<void>.delayed(const Duration(milliseconds: 350), controller.dispose);
  }

  Future<void> _tap(SceneControl control) async {
    final label = control.label.trim();
    final key = label.toLowerCase();
    final category = widget.catalog.categories.firstWhere(
      (c) => c.screens.contains(screen),
    );
    if (control.kind == ControlKind.tab) {
      setState(() => _selection['tab'] = label);
      return;
    }
    if (category.id == '0:1129' && control.kind == ControlKind.link) {
      final route = <String, String>{
        'home': 'News Feed 1',
        'profile': 'Profile 1',
        'shop': 'Home Shop 1',
        'settings': 'Settings Notifications',
        'favorites': 'Profile 2',
        'friends': 'Friends',
        'messages': 'Dialogs',
        'music': 'Songs',
        'video': 'Video Player',
        'flights': 'Tickets',
        'travels': 'Hot Tours',
        'hotels': 'Tour Search',
        'inbox': 'Inbox',
        'balance': 'Crypto Wallet',
        'history': 'Spending',
        'payment info': 'Pay With Card',
        'chats': 'Dialogs',
        'notes': 'Todo',
        'work': 'Todo',
        'shopping': 'Shopping Cart',
        'travel': 'Hot Tours',
        'completed': 'Todo',
        'sign in': 'Sign In 1',
        'notifications': 'Settings Notifications',
      }[key];
      if (route != null) {
        _go(route);
        return;
      }
    }
    if (RegExp(r'^\d$').hasMatch(key) &&
        (screen.name == 'Enter Password' || screen.name.contains('Phone'))) {
      if (screen.name.contains('Phone')) {
        final input = _controls
            .where(
              (c) => c.kind == ControlKind.input && c.label == 'Phone number',
            )
            .firstOrNull;
        if (input != null) setState(() => _fields[input.node.id]!.text += key);
      } else {
        final pin = (_selection['pin'] ?? '') + key;
        setState(() => _selection['pin'] = pin);
        if (pin.length == 6) {
          state.signIn('');
          _go('News Feed 1');
        }
      }
      return;
    }
    if (key == 'delete' &&
        (screen.name == 'Enter Password' || screen.name.contains('Phone'))) {
      final input = _controls
          .where(
            (c) => c.kind == ControlKind.input && c.label == 'Phone number',
          )
          .firstOrNull;
      final text = input == null
          ? (_selection['pin'] ?? '')
          : _fields[input.node.id]!.text;
      setState(() {
        if (input == null) {
          _selection['pin'] = text.isEmpty
              ? ''
              : text.substring(0, text.length - 1);
        } else {
          _fields[input.node.id]!.text = text.isEmpty
              ? ''
              : text.substring(0, text.length - 1);
        }
      });
      return;
    }
    if (key == 'continue' && screen.name.contains('Phone')) {
      if (_value('Phone number').replaceAll(RegExp(r'\D'), '').length < 6) {
        _notice('请输入有效的电话号码');
        return;
      }
      _go('Enter Password');
      return;
    }
    if (key == 'skip') {
      _go('Sign In 1');
      return;
    }
    if (control.kind == ControlKind.checkbox) {
      state.toggleFlag(
        'task:${control.node.id}',
        initial: control.node.name.contains('Active'),
      );
      return;
    }
    if (control.kind == ControlKind.toggle) {
      state.toggleFlag(control.node.id, initial: key.endsWith('/on'));
      return;
    }
    if (control.kind == ControlKind.counter) {
      final choice = await _choose('商品数量', ['1', '2', '3', '4', '5', '移除商品']);
      if (choice != null) {
        state.changeQuantity(
          control.node.id,
          (int.tryParse(choice) ?? 0) - state.quantity(control.node.id),
        );
      }
      return;
    }
    if (key == 'back' || key == 'close' || key == 'no, thanks') {
      _back();
      return;
    }
    if (key.contains('menu')) {
      widget.openCatalog();
      return;
    }
    if (key == 'privacy policy' || key == 'terms & conditions') {
      await _information(
        label,
        '这是 Think UI Kit 的本地界面演示。输入仅用于当前演示，不会发送到服务器；正式条款需由产品方提供。',
      );
      return;
    }
    if (key.contains('forgot')) {
      _go('Forgot Password');
      return;
    }
    if (key == 'create account') {
      _go('Sign Up 1');
      return;
    }
    if (key == 'sign out') {
      state.signOut();
      _go('Sign In 1');
      return;
    }
    if (key.contains('facebook') || key.contains('twitter')) {
      await _information('第三方登录', '此界面保留设计中的入口。当前演示使用邮箱登录，尚未接入第三方授权。');
      return;
    }
    if (key == 'sign in') {
      if (category.id == '0:1') {
        _go('Sign In 1');
        return;
      }
      if (screen.name == 'Sign In 1' ||
          screen.name == 'Sign In 2' ||
          screen.name == 'Sign Up 1') {
        if (!_validate(registration: screen.name == 'Sign Up 1')) return;
      }
      state.signIn(_value('Name'));
      _go('News Feed 1');
      return;
    }
    if (key == 'sign up') {
      if (screen.name == 'Sign In 2') {
        _go('Sign Up 2');
        return;
      }
      if (screen.name.contains('Phone')) {
        _go('Sign Up Phone 2');
        return;
      }
      if (screen.name == 'Sign Up 1' && !_validate(registration: true)) return;
      state.signIn(_value('Name'));
      _go('News Feed 1');
      return;
    }
    if (screen.name == 'Forgot Password' &&
        control.kind == ControlKind.button) {
      if (_value('E-Mail').isEmpty) {
        _notice('请输入邮箱地址');
        return;
      }
      await _information('重置密码', '演示已收到重置请求。当前未连接邮件服务，不会发送邮件。');
      return;
    }
    if (key.contains('face') ||
        screen.name == 'Face ID' && control.kind == ControlKind.button) {
      await _information('身份验证演示', '这是 Face ID 界面演示，没有调用设备生物识别。');
      return;
    }
    if (key.contains('follow')) {
      state.toggleFlag(control.node.id);
      _notice(state.flags[control.node.id]! ? '已关注' : '已取消关注');
      return;
    }
    if (key.contains('heart') ||
        key.contains('favorite') ||
        key.contains('bookmark')) {
      state.toggleLike(control.node.id);
      return;
    }
    if (key.contains('search')) {
      _go(
        category.id == '0:3483'
            ? 'Shop Search'
            : category.id == '0:4015'
            ? 'Tour Search'
            : category.id == '0:416'
            ? 'Find people'
            : 'Shop Search',
      );
      return;
    }
    if ((key.contains('cart') || key.contains('bag')) &&
        !key.contains('add to')) {
      _go('Shopping Cart');
      return;
    }
    if (key.contains('add to') ||
        key == 'buy!' ||
        key == 'buy' ||
        key == 'buy now') {
      state.addToCart();
      _go('Shopping Cart');
      return;
    }
    if (key.contains('check out')) {
      if (state.cartCount == 0) {
        _notice('请先添加商品');
        return;
      }
      state.beginCheckout();
      _go('Pay With Card');
      return;
    }
    if (key == 'pay' || key.startsWith('pay ') || key.contains('apple pay')) {
      _go('Success Shop');
      return;
    }
    if (key == 'continue shopping' ||
        screen.name == 'Success Shop' && control.kind == ControlKind.button) {
      _go('Home Shop 1');
      return;
    }
    if (key.contains('select size') ||
        const ['xs', 's', 'm', 'l', 'xl', 'xxl'].contains(key)) {
      final size = key == 'select size'
          ? await _choose('选择尺码', ['XS', 'S', 'M', 'L', 'XL', 'XXL'])
          : label;
      if (size != null && mounted) setState(() => _selection['size'] = size);
      return;
    }
    if (key.contains('filter') || key.contains('adjust')) {
      _go(category.id == '0:3483' ? '0:3731' : '0:2137');
      return;
    }
    if (key == 'apply') {
      _notice('筛选条件已应用');
      _go('Category');
      return;
    }
    if (key == 'clear') {
      setState(_selection.clear);
      _notice('筛选条件已清除');
      return;
    }
    if (key.contains('play') || key.contains('pause')) {
      _selection['playback'] = 'changed';
      state.togglePlayer();
      return;
    }
    if (key.contains('next') || key.contains('forward')) {
      _go('Music Play 2');
      return;
    }
    if (key.contains('previous') || key.contains('rewind')) {
      _go('Music Play 1');
      return;
    }
    if (key.contains('list') && category.id == '0:2037') {
      _go('Playlist');
      return;
    }
    if (key.contains('plus') || key == 'write') {
      if (screen.name == 'Todo' || category.id == '0:2480') {
        await _compose(task: true);
      } else {
        _go('Create Post');
      }
      return;
    }
    if (key.contains('send') || key.contains('mic')) {
      final message = _value('Type a message');
      if (message.isNotEmpty) {
        state.sendMessage(message);
        for (final field in _fields.values) {
          field.clear();
        }
      } else {
        _notice('请输入消息后发送');
      }
      return;
    }
    if (key.contains('bubble') || key.contains('message')) {
      _go('Chat');
      return;
    }
    if (key.contains('photo') || key.contains('camera')) {
      _go('Camera');
      return;
    }
    if (key.contains('user') || key == 'profile') {
      _go('Profile 1');
      return;
    }
    if (key.contains('compass') || key == 'home') {
      _go('News Feed 1');
      return;
    }
    if (key.contains('grid') || key == 'shop') {
      _go('Home Shop 1');
      return;
    }
    if (key == 'zip' || key.contains('activity')) {
      _go('Activity');
      return;
    }
    if (key.contains('bell') || key.contains('notification')) {
      _go('Notifications');
      return;
    }
    if (key.contains('phone') || key.contains('call')) {
      _go(screen.name == 'Incoming Call' ? 'Conversation' : 'Incoming Call');
      return;
    }
    if (key.contains('dots') ||
        key.contains('kebab') ||
        key.contains('share') ||
        key.contains('copy')) {
      final action = await _choose('更多操作', ['收藏', '复制页面名称', '查看个人主页']);
      if (action == '收藏') state.toggleLike(control.node.id);
      if (action == '复制页面名称') {
        await Clipboard.setData(ClipboardData(text: screen.name));
        _notice('已复制');
      }
      if (action == '查看个人主页') _go('Profile 1');
      return;
    }
    if (category.id == '0:4015') {
      if (screen.name == 'Tour Search') {
        _go('Tickets');
      } else if (screen.name == 'Tickets') {
        _go('Boarding Pass');
      } else if (screen.name == 'Tour') {
        _go('Tour Search');
      } else if (screen.name.contains('Route') || screen.name.contains('Map')) {
        _go('Route');
      } else if (screen.name == 'Settings Notifications') {
        _notice('通知偏好已保存');
      } else {
        _go('Tour');
      }
      return;
    }
    if (category.id == '0:4394') {
      if (key == 'try again') {
        _go('Success');
      } else if (key == 'close') {
        _back();
      } else if (key == 'rate') {
        _notice('感谢反馈，演示不会打开应用商店');
      } else {
        _go('News Feed 1');
      }
      return;
    }
    if (control.kind == ControlKind.row) {
      _go(switch (category.id) {
        '0:3483' => 'Item Shop 1',
        '0:2037' => 'Music Play 1',
        '0:416' => 'Chat',
        '0:4015' => 'Tour',
        _ => 'Post',
      });
      return;
    }
    if (screen.name == 'Create Post' && control.kind == ControlKind.button) {
      if (_value('Write something…').isEmpty && _value('Title').isEmpty) {
        _notice('请填写内容');
        return;
      }
      state.sendMessage(_value('Write something…'));
      _notice('已保存到本地动态');
      _go('News Feed 1');
      return;
    }
    if (category.id == '0:1129') {
      final destination = {
        'settings': 'Settings Notifications',
        'friends': 'Friends',
        'music': 'Songs',
        'video': 'Video Player',
        'flights': 'Tickets',
        'travels': 'Hot Tours',
        'inbox': 'Inbox',
        'balance': 'Crypto Wallet',
        'completed': 'Todo',
      }[key];
      if (destination != null) {
        _go(destination);
        return;
      }
    }
    if (category.id == '0:1') {
      _go('Sign In 1');
      return;
    }
    if (key == 'write a review') {
      await _compose();
      return;
    }
    if (key == 'invite') {
      await _information('邀请好友', '邀请流程演示。当前没有发送邀请或访问通讯录。');
      return;
    }
    _notice('已选择 $label');
  }

  Map<String, String> _overrides() {
    final out = <String, String>{};
    if (state.displayName != 'Helena Barnes') {
      for (final n in _nodes.where(
        (n) => n.type == 'TEXT' && n.text.toLowerCase() == 'helena barnes',
      )) {
        out[n.id] = state.displayName;
      }
    }
    if (screen.name.startsWith('Music') && state.seeked) {
      final seconds = (state.position * 200).round();
      for (final n in _nodes.where((n) => n.text == '01:40')) {
        out[n.id] =
            '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
      }
    }
    for (final control in _controls) {
      if (control.kind == ControlKind.counter) {
        for (final n in control.node.descendants.where(
          (n) => n.type == 'TEXT',
        )) {
          out[n.id] = '${state.quantity(control.node.id)}';
        }
      }
      if (control.label.toLowerCase().contains('follow') &&
          state.flags[control.node.id] == true) {
        for (final n in control.node.descendants.where(
          (n) => n.type == 'TEXT',
        )) {
          out[n.id] = 'Following';
        }
      }
    }
    if (_selection['size'] != null) {
      for (final n in _nodes.where((n) => n.text == 'SELECT SIZE')) {
        out[n.id] = _selection['size']!;
      }
    }
    if (screen.name == 'Shopping Cart') {
      out['0:3486'] = '${state.cartCount}';
      for (final n in _nodes.where(
        (n) =>
            n.type == 'TEXT' &&
            n.rect.top > 570 &&
            (n.text.contains('\$') || RegExp(r'^\d+\.\d{2}$').hasMatch(n.text)),
      )) {
        out[n.id] = '\$${state.cartTotal.toStringAsFixed(2)}';
      }
    }
    if (screen.name == 'Pay With Card' && state.checkoutTotal != null) {
      for (final n in _nodes.where((n) => n.text.startsWith('Pay \$'))) {
        out[n.id] = 'Pay \$${state.checkoutTotal!.toStringAsFixed(2)}';
      }
    }
    return out;
  }

  Widget _control(SceneControl c, {Offset origin = Offset.zero}) {
    final r = c.rect;
    final rect = c.kind == ControlKind.input
        ? r
        : Rect.fromCenter(
            center: r.center,
            width: math.max(r.width, 36),
            height: math.max(r.height, 36),
          );
    Widget child;
    if (c.kind == ControlKind.input) {
      final controller = _fields[c.node.id]!;
      final password = c.label == 'Password';
      child = TextField(
        key: ValueKey('field:${c.label}'),
        controller: controller,
        obscureText: password,
        enableSuggestions: !password,
        autocorrect: !password,
        keyboardType: c.label.toLowerCase().contains('mail')
            ? TextInputType.emailAddress
            : c.label == 'Phone number'
            ? TextInputType.phone
            : TextInputType.text,
        textInputAction:
            c.label == 'Type a message' || c.label == 'Write comment…'
            ? TextInputAction.send
            : TextInputAction.next,
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: (c.node.style['fontSize'] as num? ?? 15).toDouble(),
          color: _fieldColor(c),
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 7),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (text) {
          if (c.label == 'Type a message' || c.label == 'Write comment…') {
            state.sendMessage(text);
            controller.clear();
            setState(() {});
          } else if (c.label == 'Search') {
            _go(screen.name == 'Tour Search' ? 'Tickets' : 'Category');
          }
        },
      );
    } else if (c.kind == ControlKind.toggle) {
      child = FittedBox(
        child: CupertinoSwitch(
          value: state.flags[c.node.id] ?? c.label.endsWith('/On'),
          activeTrackColor: thinkPrimary,
          onChanged: (_) => _tap(c),
        ),
      );
    } else {
      child = Semantics(
        button: true,
        label: c.kind == ControlKind.counter
            ? '商品数量 ${state.quantity(c.node.id)}'
            : c.label,
        child: InkWell(
          key: ValueKey('action:${c.node.id}'),
          onTap: () => _tap(c),
          borderRadius: BorderRadius.circular(6),
          child: _changedControl(c),
        ),
      );
    }
    return Positioned(
      left: rect.left - origin.dx,
      top: rect.top - origin.dy,
      width: rect.width,
      height: rect.height,
      child: child,
    );
  }

  Color _fieldColor(SceneControl c) {
    final fills = (c.node.style['fills'] as List? ?? []).cast<Json>();
    return fills.isNotEmpty
        ? DesignPainter.color(fills.first['color'] ?? {})
        : const Color(0xff22242a);
  }

  Widget _changedControl(SceneControl c) {
    if (c.kind == ControlKind.tab && _selection['tab'] == c.label) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Container(width: c.node.width, height: 2, color: thinkPrimary),
      );
    }
    if (state.liked.contains(c.node.id)) {
      return const Icon(Icons.favorite, color: Color(0xffef4369), size: 22);
    }
    if (c.kind == ControlKind.checkbox &&
        state.flags.containsKey('task:${c.node.id}')) {
      return Center(
        child: Container(
          width: 25,
          height: 25,
          decoration: BoxDecoration(
            color: state.flags['task:${c.node.id}']!
                ? thinkPrimary
                : Colors.white,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: thinkPrimary),
          ),
          child: state.flags['task:${c.node.id}']!
              ? const Icon(Icons.check, color: Colors.white, size: 18)
              : null,
        ),
      );
    }
    if ((c.label.toLowerCase().contains('play') ||
            c.label.toLowerCase().contains('pause')) &&
        _selection.containsKey('playback')) {
      return Icon(
        state.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
        size: c.node.width,
        color: thinkPrimary,
      );
    }
    return const SizedBox.expand();
  }

  Widget _layer({required bool fixed}) {
    final hidden = <String>{
      for (final c in _controls)
        if (c.kind == ControlKind.toggle ||
            c.kind == ControlKind.checkbox &&
                state.flags.containsKey('task:${c.node.id}'))
          c.node.id,
      for (final entry in _fields.entries)
        if (entry.value.text.isNotEmpty) entry.key,
      if (screen.name.startsWith('Music') && state.seeked)
        for (final track in _nodes.where((n) => n.name == 'Track'))
          for (final child in track.children.where((n) => n.type != 'TEXT'))
            child.id,
      if (screen.name == 'Shopping Cart')
        for (final row in screen.children.where((n) => n.name == 'Line'))
          if (row.descendants.any(
            (n) => n.name == 'Counter' && state.quantity(n.id) == 0,
          ))
            row.id,
    };
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: DesignPainter(
              catalog: widget.catalog,
              screen: screen,
              hidden: hidden,
              overrides: _overrides(),
              only: fixed ? _fixed : null,
              excluded: fixed
                  ? const {}
                  : {..._fixed, ..._carousels.map((n) => n.id)},
            ),
          ),
        ),
        for (final c in _controls.where(
          (c) =>
              _fixed.contains(c.node.id) == fixed &&
              !_carouselIds.contains(c.node.id),
        ))
          _control(c),
        if (!fixed)
          for (final group in _carousels) _carousel(group, hidden),
        if (!fixed &&
            state.messages.isNotEmpty &&
            (screen.name == 'Chat' ||
                screen.name == 'Group Chat' ||
                screen.name == 'Chat Bot'))
          Positioned(
            left: 140,
            right: 20,
            top: 665,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: thinkPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  state.messages.last,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),
        if (!fixed && screen.name == 'Todo' && state.tasks.isNotEmpty)
          Positioned(
            left: 40,
            top: 665,
            right: 40,
            child: Material(
              color: Colors.white,
              child: ListTile(
                dense: true,
                leading: const Icon(
                  Icons.check_box_outline_blank,
                  color: thinkPrimary,
                ),
                title: Text(state.tasks.last),
              ),
            ),
          ),
        if (!fixed && screen.name.startsWith('Music'))
          Positioned(
            left: (_track?.rect.left ?? 40) - 10,
            top: (_track?.rect.bottom ?? 581) - 25.5,
            width: (_track?.width ?? 295) + 20,
            height: 38,
            child: Semantics(
              label: '播放进度',
              child: Opacity(
                opacity: state.seeked ? 1 : 0,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbColor: state.seeked
                        ? thinkPrimary
                        : Colors.transparent,
                    activeTrackColor: state.seeked
                        ? thinkPrimary
                        : Colors.transparent,
                    inactiveTrackColor: state.seeked
                        ? const Color(0xfff1f3f8)
                        : Colors.transparent,
                    overlayColor: Colors.transparent,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7.5,
                    ),
                  ),
                  child: Slider(value: state.position, onChanged: state.seek),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _carousel(DesignNode group, Set<String> hidden) {
    final ids = group.descendants.map((n) => n.id).toSet();
    final origin = group.rect.topLeft;
    return Positioned(
      left: origin.dx,
      top: origin.dy,
      width: 375 - origin.dx,
      height: group.height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: group.width,
          height: group.height,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: DesignPainter(
                    catalog: widget.catalog,
                    screen: screen,
                    hidden: hidden,
                    overrides: _overrides(),
                    only: ids,
                    origin: origin,
                  ),
                ),
              ),
              for (final c in _controls.where((c) => ids.contains(c.node.id)))
                _control(c, origin: origin),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: state,
    builder: (context, _) => Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xfff1f3f8),
      body: GestureDetector(
        onLongPress: widget.openCatalog,
        onHorizontalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0).abs() < 200) return;
          final screens = widget.catalog.categories
              .firstWhere((c) => c.screens.contains(screen))
              .screens;
          final index =
              screens.indexOf(screen) +
              ((details.primaryVelocity ?? 0) < 0 ? 1 : -1);
          if (index >= 0 && index < screens.length) {
            _go(
              screens[index].name == 'Filters'
                  ? screens[index].id
                  : screens[index].name,
            );
          }
        },
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 375,
              height: 812,
              child: Material(
                color: Colors.transparent,
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      controller: _scroll,
                      child: SizedBox(
                        width: 375,
                        height: _extent,
                        child: _layer(fixed: false),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: false,
                        child: _layer(fixed: true),
                      ),
                    ),
                    // Edge access leaves the design untouched and provides a discoverable
                    // semantic action for screen readers and hardware keyboards.
                    Positioned(
                      left: 0,
                      top: 0,
                      width: 22,
                      height: 44,
                      child: Semantics(
                        label: '打开全部界面',
                        button: true,
                        child: GestureDetector(
                          onTap: widget.openCatalog,
                          behavior: HitTestBehavior.translucent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
