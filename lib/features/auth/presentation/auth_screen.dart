import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/app_config.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/storage.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common.dart';
import '../../splash/presentation/splash_screen.dart';
import '../providers/auth_provider.dart';
import 'otp_sheet.dart';

const _img = 'assets/images/home';
const _bg = Color(0xFFF3F4F8);
const _ink = Color(0xFF0B1230);
const _muted = Color(0xFF5B6380);
const _blue = Color(0xFF2F5CFF);
const _rememberKey = 'remember_id_v1';

/// Short screens (e.g. 360×740) get slightly shorter controls so the
/// whole form still fits without scrolling.
bool _compact(BuildContext c) {
  final mq = MediaQuery.of(c);
  return mq.size.height - mq.padding.vertical < 720;
}

/// Brand gradient used on the active tab and the primary button.
const _brandGradient = LinearGradient(
  colors: [Color(0xFF12B3F6), Color(0xFF2F5CFF), Color(0xFF8B3DFF)],
  stops: [0, 0.5, 1],
);

/// Login + Create Account in one 3D glass card (tabs switch between them).
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.initialTab = 0, this.redirectTo});

  /// 0 = Login, 1 = Create Account.
  final int initialTab;
  final String? redirectTo;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late int _tab = widget.initialTab;

  void _done() {
    ref.read(localStoreProvider).writeString(onboardedKey, '1');
    final to = widget.redirectTo;
    if (to == null) {
      context.go('/home');
    } else {
      context.pushReplacement(to);
    }
  }

  final _cardKey = GlobalKey();

  /// Last measured card height; the header artwork shrinks so that
  /// header + card + podium fit the screen without scrolling.
  double _cardH = 560;

  void _measure() {
    final box = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && (box.size.height - _cardH).abs() > 1) {
      setState(() => _cardH = box.size.height);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final s = w / 1024; // artwork scale
    final keyboard = mq.viewInsets.bottom > 0;
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

    final podiumH = 184 * s;
    final podiumOverlap = 30 * s;
    final screenH = mq.size.height - mq.padding.top - mq.padding.bottom;
    final headerMax = 318 * s;
    final free = screenH - _cardH - 6;
    // Drop the podium when there is not enough room for it.
    final showPodium = !keyboard && free - (podiumH - podiumOverlap) >= 80;
    final headerH = keyboard
        ? 0.0
        : (free - (showPodium ? podiumH - podiumOverlap : 0))
              .clamp(70.0, headerMax)
              .floorToDouble();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFEFF1F5),
                      Color(0xFFF7F8FB),
                      Color(0xFFF1F3F8),
                    ],
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(
                top: mq.padding.top + (keyboard ? 8 : 0),
              ),
              child: Column(
                children: [
                  // Logo, swirl and 3D bag from the design; shrinks to fit and
                  // collapses while the keyboard is open.
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    height: headerH,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.bottomCenter,
                        maxHeight: headerMax,
                        child: SizedBox(
                          height: headerMax,
                          child: Transform.scale(
                            scale: headerH == 0
                                ? 1
                                : (headerH / headerMax).clamp(0.55, 1.0),
                            alignment: Alignment.bottomCenter,
                            child: ShaderMask(
                              blendMode: BlendMode.dstIn,
                              shaderCallback: (r) => const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black,
                                  Colors.black,
                                  Colors.transparent,
                                ],
                                stops: [0, 0.14, 0.86, 1],
                              ).createShader(r),
                              child: Image.asset(
                                '$_img/auth_top.jpg',
                                width: w,
                                height: headerMax,
                                fit: BoxFit.fill,
                                filterQuality: FilterQuality.medium,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (!keyboard) ...[
                        Positioned(
                          right: 0,
                          top: 90 * s,
                          child: Image.asset(
                            '$_img/auth_ring_r.jpg',
                            width: 110 * s,
                            height: 690 * s,
                            fit: BoxFit.fill,
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: 420 * s,
                          child: Image.asset(
                            '$_img/auth_ring_l.jpg',
                            width: 108 * s,
                            height: 506 * s,
                            fit: BoxFit.fill,
                          ),
                        ),
                      ],
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: RepaintBoundary(
                          child: _GlassCard(
                            key: _cardKey,
                            child: Column(
                              children: [
                                _Tabs(
                                  index: _tab,
                                  onChanged: (i) => setState(() => _tab = i),
                                ),
                                const SizedBox(height: 16),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  switchInCurve: Curves.easeOut,
                                  transitionBuilder: (c, a) =>
                                      FadeTransition(opacity: a, child: c),
                                  layoutBuilder: (current, previous) => Stack(
                                    alignment: Alignment.topCenter,
                                    children: [...previous, ?current],
                                  ),
                                  child: _tab == 0
                                      ? _LoginForm(
                                          key: const ValueKey('login'),
                                          onDone: _done,
                                        )
                                      : _RegisterForm(
                                          key: const ValueKey('register'),
                                          onDone: _done,
                                        ),
                                ),
                                if (_tab == 0) ...[
                                  const SizedBox(height: 14),
                                  const _TrustRow(),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (showPodium)
                    Transform.translate(
                      offset: Offset(0, -podiumOverlap),
                      child: Image.asset(
                        '$_img/auth_podium.jpg',
                        width: w,
                        height: podiumH,
                        fit: BoxFit.fill,
                      ),
                    )
                  else
                    SizedBox(height: keyboard ? 24 : 6),
                ],
              ),
            ),
            if (!keyboard)
              if (widget.redirectTo == null)
                SafeArea(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12, top: 4),
                      child: TextButton(
                        onPressed: _done,
                        style: TextButton.styleFrom(
                          foregroundColor: _ink,
                          backgroundColor: Colors.white.withValues(alpha: 0.85),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: const StadiumBorder(
                            side: BorderSide(color: Colors.white),
                          ),
                        ),
                        child: const Text(
                          'Skip',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                )
              else
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: _ink,
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

// ───────────────────────────── Card + tabs ─────────────────────────────

/// Frosted glass slab with a visible thickness edge for a 3D look.
class _GlassCard extends StatelessWidget {
  const _GlassCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          // Slab thickness.
          const BoxShadow(color: Color(0xFFDCE1EC), offset: Offset(0, 7)),
          // Ambient drop shadow.
          BoxShadow(
            color: const Color(0xFF2A3D8F).withValues(alpha: 0.12),
            blurRadius: 40,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: Colors.white, width: 2),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFF6F7FB), Color(0xFFF1F3F9)],
          ),
        ),
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget label(int i, IconData icon, String text) => Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(i);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: index == i ? Colors.white : _ink),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: index == i ? FontWeight.w700 : FontWeight.w500,
                    color: index == i ? Colors.white : _ink,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2A3D8F).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: index == 0
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  gradient: _brandGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: _blue.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Row(
              children: [
                label(0, Icons.person_rounded, 'Login'),
                label(1, Icons.person_add_alt_outlined, 'Create Account'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Shared bits ─────────────────────────────

class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: _ink,
          letterSpacing: -0.6,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 15, color: _muted),
      ),
    ],
  );
}

/// Pill input with a soft raised 3D look and inline error text.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.icon,
    required this.hint,
    this.error,
    this.obscure = false,
    this.keyboard,
    this.action = TextInputAction.next,
    this.suffix,
    this.onSubmitted,
    this.capitalization = TextCapitalization.none,
    this.autofill,
    this.onChanged,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final String? error;
  final bool obscure;
  final TextInputType? keyboard;
  final TextInputAction action;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final TextCapitalization capitalization;
  final Iterable<String>? autofill;

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: _compact(context) ? 46 : 52,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: hasError ? const Color(0xFFE5283B) : Colors.white,
              width: 1.5,
            ),
            boxShadow: [
              const BoxShadow(
                color: Colors.white,
                offset: Offset(-2, -2),
                blurRadius: 6,
              ),
              BoxShadow(
                color: const Color(0xFF2A3D8F).withValues(alpha: 0.09),
                offset: const Offset(2, 5),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 20),
              Icon(icon, size: 24, color: _ink),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  keyboardType: keyboard,
                  textInputAction: action,
                  textCapitalization: capitalization,
                  autofillHints: autofill,
                  onSubmitted: onSubmitted,
                  onChanged: onChanged,
                  style: const TextStyle(
                    fontSize: 16,
                    color: _ink,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(
                      color: Color(0xFF6E7591),
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (suffix != null) suffix! else const SizedBox(width: 20),
            ],
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 6, 0, 0),
            child: Text(
              error!,
              style: const TextStyle(color: Color(0xFFE5283B), fontSize: 12.5),
            ),
          ),
      ],
    );
  }
}

class _EyeButton extends StatelessWidget {
  const _EyeButton({required this.obscure, required this.onTap});
  final bool obscure;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    padding: const EdgeInsets.only(right: 12),
    icon: Icon(
      obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      color: _ink,
    ),
  );
}

/// Big gradient call-to-action with glow and glossy top highlight.
class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: _compact(context) ? 50 : 56,
        decoration: BoxDecoration(
          gradient: _brandGradient,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: _blue.withValues(alpha: 0.38),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: const Color(0xFF8B3DFF).withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(10, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Glossy highlight on the upper half.
            Positioned(
              left: 18,
              right: 18,
              top: 3,
              height: 24,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.35),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: loading
                  ? const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: Colors.white, size: 26),
                        const SizedBox(width: 14),
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    Widget line(bool left) => Expanded(
      child: Container(
        height: 1.2,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: left
                ? [Colors.transparent, const Color(0xFF9AA6C8)]
                : [const Color(0xFF9AA6C8), Colors.transparent],
          ),
        ),
      ),
    );
    return Row(
      children: [
        line(true),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'Or continue with',
            style: TextStyle(color: _ink, fontSize: 14.5),
          ),
        ),
        line(false),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showAppSnack(
        context,
        'Google sign-in will be enabled with the backend',
      ),
      child: Container(
        height: _compact(context) ? 46 : 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE6E9F2)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2A3D8F).withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('$_img/brand_google.png', width: 46, height: 30),
            const SizedBox(width: 10),
            const Text(
              'Continue with Google',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.verified_user_outlined, 'Secure & Private'),
      (Icons.bolt_outlined, 'Fast Login'),
      (Icons.headset_mic_outlined, '24×7 Support'),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            Container(width: 1, height: 38, color: const Color(0xFFD5DAE6)),
          Expanded(
            child: Column(
              children: [
                Icon(items[i].$1, color: _blue, size: 27),
                const SizedBox(height: 6),
                Text(
                  items[i].$2,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: _ink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ───────────────────────────── Login ─────────────────────────────

class _LoginForm extends ConsumerStatefulWidget {
  const _LoginForm({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final _id = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _remember = true;
  bool _loading = false;
  String? _idError;
  String? _pwError;

  @override
  void initState() {
    super.initState();
    _id.text = ref.read(localStoreProvider).readString(_rememberKey) ?? '';
  }

  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validateId(String v) =>
      v.contains('@') ? Validators.email(v) : Validators.phone(v);

  Future<void> _submit() async {
    final id = _id.text.trim();
    setState(() {
      _idError = _validateId(id);
      _pwError = Validators.password(_password.text);
    });
    if (_idError != null || _pwError != null) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await ref
          .read(authProvider.notifier)
          .login(identifier: id, password: _password.text);
      final store = ref.read(localStoreProvider);
      _remember
          ? await store.writeString(_rememberKey, id)
          : await store.remove(_rememberKey);
      HapticFeedback.mediumImpact();
      if (mounted) widget.onDone();
    } on AuthException catch (e) {
      if (mounted) setState(() => _pwError = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Heading(
            title: 'Welcome Back 👋',
            subtitle: 'Login to your GAMEX account',
          ),
          const SizedBox(height: 18),
          _Field(
            controller: _id,
            icon: Icons.phone_outlined,
            hint: 'Mobile Number',
            keyboard: TextInputType.phone,
            autofill: const [
              AutofillHints.telephoneNumber,
              AutofillHints.email,
            ],
            error: _idError,
            onChanged: (_) =>
                _idError == null ? null : setState(() => _idError = null),
          ),
          const SizedBox(height: 12),
          _Field(
            controller: _password,
            icon: Icons.lock_outline_rounded,
            hint: 'Password',
            obscure: _obscure,
            action: TextInputAction.done,
            autofill: const [AutofillHints.password],
            onSubmitted: (_) => _submit(),
            error: _pwError,
            onChanged: (_) =>
                _pwError == null ? null : setState(() => _pwError = null),
            suffix: _EyeButton(
              obscure: _obscure,
              onTap: () => setState(() => _obscure = !_obscure),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 32,
                child: Checkbox(
                  value: _remember,
                  activeColor: _blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  onChanged: (v) => setState(() => _remember = v ?? false),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Remember me',
                style: TextStyle(fontSize: 15, color: _ink),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _showForgot(context, ref, _id.text.trim()),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: _blue,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _GradientButton(
            icon: Icons.login_rounded,
            label: 'Login to GAMEX'.tr(context),
            onTap: _submit,
            loading: _loading,
          ),
          const SizedBox(height: 16),
          const _OrDivider(),
          const SizedBox(height: 14),
          _OtpButton(onDone: widget.onDone),
        ],
      ),
    );
  }
}

/// "Login with OTP" (real SMS when the server has an SMS provider).
class _OtpButton extends ConsumerWidget {
  const _OtpButton({required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(appConfigProvider).asData?.value;
    if (cfg == null || !cfg.otpLogin) return const _GoogleButton();
    return GestureDetector(
      onTap: () async {
        if (await showOtpLogin(context)) onDone();
      },
      child: Container(
        height: _compact(context) ? 46 : 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE6E9F2)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2A3D8F).withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sms_rounded, color: _blue),
            const SizedBox(width: 10),
            Text(
              'Login with OTP'.tr(context),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showForgot(BuildContext context, WidgetRef ref, String prefill) {
  final c = TextEditingController(text: prefill);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        24 + MediaQuery.viewInsetsOf(sheet).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Reset password',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Enter your mobile number or email. We\'ll send you a one-time code.',
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 16),
          _Field(
            controller: c,
            icon: Icons.phone_outlined,
            hint: 'Mobile number or email',
            keyboard: TextInputType.emailAddress,
          ),
          const SizedBox(height: 18),
          _GradientButton(
            icon: Icons.sms_outlined,
            label: 'Send OTP',
            onTap: () async {
              final v = c.text.trim();
              final err = v.contains('@')
                  ? Validators.email(v)
                  : Validators.phone(v);
              if (err != null) {
                showAppSnack(sheet, err);
                return;
              }
              await ref.read(authProvider.notifier).requestPasswordReset(v);
              if (sheet.mounted) Navigator.pop(sheet);
              if (context.mounted) showAppSnack(context, 'OTP sent to $v');
            },
          ),
        ],
      ),
    ),
  );
}

// ───────────────────────────── Register ─────────────────────────────

class _RegisterForm extends ConsumerStatefulWidget {
  const _RegisterForm({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  ConsumerState<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends ConsumerState<_RegisterForm> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _agreed = false;
  bool _loading = false;
  final Map<String, String?> _errors = {};

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  /// 0..4 password strength.
  int get _strength {
    final p = _password.text;
    var s = 0;
    if (p.length >= 6) s++;
    if (p.length >= 10) s++;
    if (RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p)) s++;
    if (RegExp(r'[0-9]').hasMatch(p) && RegExp(r'[^A-Za-z0-9]').hasMatch(p)) {
      s++;
    }
    return s;
  }

  Future<void> _submit() async {
    setState(() {
      _errors
        ..['name'] = Validators.required(_name.text, 'Name')
        ..['phone'] = Validators.phone(_phone.text)
        ..['email'] = _email.text.trim().isEmpty
            ? null
            : Validators.email(_email.text)
        ..['password'] = Validators.password(_password.text);
    });
    if (_errors.values.any((e) => e != null)) return;
    if (!_agreed) {
      showAppSnack(context, 'Please accept the Terms & Privacy Policy');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await ref
          .read(authProvider.notifier)
          .register(
            name: _name.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim(),
            password: _password.text,
          );
      HapticFeedback.mediumImpact();
      if (mounted) {
        showAppSnack(
          context,
          'Welcome to GAMEX, ${_name.text.trim().split(' ').first}! 🎉',
        );
        widget.onDone();
      }
    } on AuthException catch (e) {
      if (mounted) showAppSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clear(String k) {
    if (_errors[k] != null) setState(() => _errors[k] = null);
  }

  @override
  Widget build(BuildContext context) {
    final strength = _strength;
    const strengthColors = [
      Color(0xFFE5283B),
      Color(0xFFE5283B),
      Color(0xFFF59E0B),
      Color(0xFF2F5CFF),
      Color(0xFF16A34A),
    ];
    const strengthLabels = ['Too short', 'Weak', 'Fair', 'Good', 'Strong'];
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Heading(
            title: 'Create Account ✨',
            subtitle: 'Join GAMEX in less than a minute',
          ),
          const SizedBox(height: 16),
          _Field(
            controller: _name,
            icon: Icons.person_outline_rounded,
            hint: 'Full Name',
            capitalization: TextCapitalization.words,
            autofill: const [AutofillHints.name],
            error: _errors['name'],
            onChanged: (_) => _clear('name'),
          ),
          const SizedBox(height: 10),
          _Field(
            controller: _phone,
            icon: Icons.phone_outlined,
            hint: 'Mobile Number',
            keyboard: TextInputType.phone,
            autofill: const [AutofillHints.telephoneNumber],
            error: _errors['phone'],
            onChanged: (_) => _clear('phone'),
          ),
          const SizedBox(height: 10),
          _Field(
            controller: _email,
            icon: Icons.mail_outline_rounded,
            hint: 'Email (optional)',
            keyboard: TextInputType.emailAddress,
            autofill: const [AutofillHints.email],
            error: _errors['email'],
            onChanged: (_) => _clear('email'),
          ),
          const SizedBox(height: 10),
          _Field(
            controller: _password,
            icon: Icons.lock_outline_rounded,
            hint: 'Create Password',
            obscure: _obscure,
            action: TextInputAction.done,
            autofill: const [AutofillHints.newPassword],
            onSubmitted: (_) => _submit(),
            error: _errors['password'],
            onChanged: (_) {
              _clear('password');
              setState(() {});
            },
            suffix: _EyeButton(
              obscure: _obscure,
              onTap: () => setState(() => _obscure = !_obscure),
            ),
          ),
          if (_password.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  for (var i = 0; i < 4; i++)
                    Expanded(
                      child: Container(
                        height: 5,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: i < strength
                              ? strengthColors[strength]
                              : const Color(0xFFE3E7F1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Text(
                    strengthLabels[strength],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: strengthColors[strength],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 32,
                child: Checkbox(
                  value: _agreed,
                  activeColor: _blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  onChanged: (v) => setState(() => _agreed = v ?? false),
                ),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text.rich(
                  TextSpan(
                    text: 'I agree to the ',
                    children: [
                      TextSpan(
                        text: 'Terms',
                        style: TextStyle(
                          color: _blue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(text: ' & '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(
                          color: _blue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  style: TextStyle(fontSize: 14, color: _ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _GradientButton(
            icon: Icons.person_add_alt_1_rounded,
            label: 'Create Account',
            onTap: _submit,
            loading: _loading,
          ),
          const SizedBox(height: 20),
          const _OrDivider(),
          const SizedBox(height: 14),
          const _GoogleButton(),
        ],
      ),
    );
  }
}
