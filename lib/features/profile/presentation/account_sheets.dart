import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/payment_marks.dart';
import '../../../data/models/order.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cart/providers/cart_provider.dart';
import '../../orders/providers/orders_provider.dart';
import '../providers/avatar_provider.dart';
import '../providers/theme_provider.dart';

Future<void> _sheet(
  BuildContext context,
  Widget Function(BuildContext) builder,
) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (c) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(c).bottom,
      ),
      child: SingleChildScrollView(child: builder(c)),
    ),
  ),
);

Widget _title(String t, [String? sub]) => Builder(
  builder: (c) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t,
          style: Theme.of(c).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (sub != null) ...[
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(color: Theme.of(c).colorScheme.outline)),
        ],
      ],
    ),
  ),
);

// ── Profile photo ──
void showAvatarSheet(BuildContext context) => _sheet(
  context,
  (c) => Consumer(
    builder: (c, ref, _) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('Profile photo'),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: const Text('Choose from gallery'),
          onTap: () async {
            Navigator.pop(c);
            await ref.read(avatarProvider.notifier).pick();
          },
        ),
        ListTile(
          leading: const Icon(Icons.photo_camera_outlined),
          title: const Text('Take a photo'),
          onTap: () async {
            Navigator.pop(c);
            await ref
                .read(avatarProvider.notifier)
                .pick(source: ImageSource.camera);
          },
        ),
        if (ref.watch(avatarProvider) != null)
          ListTile(
            leading: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.danger,
            ),
            title: const Text(
              'Remove photo',
              style: TextStyle(color: AppColors.danger),
            ),
            onTap: () {
              Navigator.pop(c);
              ref.read(avatarProvider.notifier).remove();
            },
          ),
      ],
    ),
  ),
);

// ── Edit profile ──
void showEditProfileSheet(BuildContext context) =>
    _sheet(context, (_) => const _EditProfile());

class _EditProfile extends ConsumerStatefulWidget {
  const _EditProfile();

  @override
  ConsumerState<_EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends ConsumerState<_EditProfile> {
  final _form = GlobalKey<FormState>();
  late final _user = ref.read(authProvider);
  late final _name = TextEditingController(text: _user?.name ?? '');
  late final _phone = TextEditingController(text: _user?.phone ?? '');
  late final _email = TextEditingController(text: _user?.email ?? '');

  @override
  void dispose() {
    for (final c in [_name, _phone, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Please sign in first.'),
      );
    }
    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title('My Profile', 'Customer ID ${_user.customerId}'),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) => Validators.required(v, 'Name'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Mobile number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: Validators.phone,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email (optional)',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? null : Validators.email(v),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () async {
              if (!_form.currentState!.validate()) return;
              await ref
                  .read(authProvider.notifier)
                  .updateProfile(
                    name: _name.text.trim(),
                    phone: _phone.text.trim(),
                    email: _email.text.trim(),
                  );
              if (context.mounted) {
                Navigator.pop(context);
                showAppSnack(context, 'Profile updated');
              }
            },
            child: const Text('Save changes'),
          ),
        ],
      ),
    );
  }
}

// ── Settings ──
void showSettingsSheet(BuildContext context) =>
    _sheet(context, (_) => const _Settings());

class _Settings extends ConsumerStatefulWidget {
  const _Settings();

  @override
  ConsumerState<_Settings> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<_Settings> {
  bool _orders = true;
  bool _offers = true;

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('Settings'),
        const Text('Appearance', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode_outlined),
              label: Text('Light'),
            ),
            ButtonSegment(
              value: ThemeMode.system,
              icon: Icon(Icons.brightness_auto_outlined),
              label: Text('Auto'),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode_outlined),
              label: Text('Dark'),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (s) =>
              ref.read(themeModeProvider.notifier).set(s.first),
        ),
        const SizedBox(height: 18),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _orders,
          onChanged: (v) => setState(() => _orders = v),
          title: const Text('Order updates'),
          subtitle: const Text('Shipping and delivery notifications'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _offers,
          onChanged: (v) => setState(() => _offers = v),
          title: const Text('Offers & flash deals'),
          subtitle: const Text('Price drops on your wishlist'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.language_rounded),
          title: const Text('Language'),
          trailing: const Text('English'),
          onTap: () => showAppSnack(context, 'বাংলা support is coming soon'),
        ),
      ],
    );
  }
}

// ── Coupons ──
void showCouponsListSheet(BuildContext context) => _sheet(
  context,
  (c) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _title('My Coupons', 'Apply them in your cart at checkout'),
      for (final cp in coupons)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFF3EEFF)],
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_offer_rounded,
                  color: Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cp.code,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(cp.title),
                    if (cp.minOrder > 0)
                      Text(
                        'Min. order ${formatPrice(cp.minOrder)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ],
  ),
);

// ── Rewards ──
void showRewardsSheet(BuildContext context, int points) {
  const tiers = [
    ('Silver', 0),
    ('Gold', 1000),
    ('Platinum', 5000),
    ('Diamond', 15000),
  ];
  var idx = 0;
  for (var i = 0; i < tiers.length; i++) {
    if (points >= tiers[i].$2) idx = i;
  }
  final next = idx + 1 < tiers.length ? tiers[idx + 1] : null;
  final progress = next == null
      ? 1.0
      : (points - tiers[idx].$2) / (next.$2 - tiers[idx].$2);
  _sheet(
    context,
    (c) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('GAMEX Rewards'),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF4F2CF0), Color(0xFF8A4FFF)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${tiers[idx].$1} member',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                '${NumberFormat.decimalPattern('en_IN').format(points)} points',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Worth ${formatPrice(points.toDouble())} on your next orders',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress.clamp(0, 1),
                  minHeight: 8,
                  color: Colors.white,
                  backgroundColor: Colors.white24,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                next == null
                    ? 'You are at the highest tier 🎉'
                    : '${next.$2 - points} more points to ${next.$1}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'How to earn',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        for (final t in const [
          (Icons.shopping_bag_outlined, '1 point for every ৳100 you spend'),
          (Icons.rate_review_outlined, '50 points for a review with photos'),
          (Icons.group_add_outlined, '500 points for every friend you refer'),
          (Icons.sync_rounded, '200 points when you trade in a phone'),
        ])
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(t.$1, color: AppColors.primary),
            title: Text(t.$2),
          ),
      ],
    ),
  );
}

// ── Wallet ──
void showWalletSheet(BuildContext context) => _sheet(
  context,
  (c) => Consumer(
    builder: (c, ref, _) {
      final orders = ref.watch(ordersProvider);
      final balance = (orders.fold(0.0, (s, o) => s + o.total) * 0.01)
          .roundToDouble();
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title('My Wallet', 'Cashback you can use on any order'),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF1F66FF), Color(0xFF7A3CF0)],
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 36,
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'GAMEX Balance',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                Text(
                  '${formatPrice(balance)}.00',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Recent activity',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          if (orders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Earn 1% cashback on every order')),
            ),
          for (final o in orders.take(8))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE3F6EA),
                child: Icon(Icons.south_west_rounded, color: AppColors.success),
              ),
              title: Text('Cashback • Order #${o.id}'),
              subtitle: Text(DateFormat('d MMM yyyy').format(o.createdAt)),
              trailing: Text(
                '+${formatPrice((o.total * 0.01).roundToDouble())}',
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      );
    },
  ),
);

// ── Payment methods ──
void showPaymentMethodsSheet(BuildContext context) => _sheet(
  context,
  (c) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _title('Payment Methods', 'All payments are 256-bit SSL encrypted'),
      for (final m in PaymentMethod.values)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: PaymentMark(m, size: 42),
          title: Text(
            m.label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(switch (m) {
            PaymentMethod.cashOnDelivery => 'Pay when the phone arrives',
            PaymentMethod.bkash => 'Instant wallet payment',
            PaymentMethod.nagad => 'Instant wallet payment',
            PaymentMethod.card => 'Visa, Mastercard, Amex • EMI',
          }),
          trailing: const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
          ),
        ),
    ],
  ),
);

// ── Security ──
void showSecuritySheet(BuildContext context) =>
    _sheet(context, (_) => const _Security());

class _Security extends StatefulWidget {
  const _Security();

  @override
  State<_Security> createState() => _SecurityState();
}

class _SecurityState extends State<_Security> {
  bool _twoFa = false;
  bool _biometric = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('Account Security'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.password_rounded),
          title: const Text('Change password'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => showAppSnack(
            context,
            'A reset code has been sent to your mobile',
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.sms_outlined),
          value: _twoFa,
          onChanged: (v) => setState(() => _twoFa = v),
          title: const Text('Two-factor authentication'),
          subtitle: const Text('OTP on every new device'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.fingerprint_rounded),
          value: _biometric,
          onChanged: (v) => setState(() => _biometric = v),
          title: const Text('Biometric login'),
          subtitle: const Text('Fingerprint / Face unlock'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.devices_rounded),
          title: const Text('Logged-in devices'),
          subtitle: const Text('This phone • Active now'),
        ),
      ],
    );
  }
}

// ── Help ──
void showHelpSheet(BuildContext context) => _sheet(
  context,
  (c) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _title('Help & Support', 'We are here 24×7'),
      for (final h in const [
        (Icons.call_outlined, 'Call us', '16XXX (24×7)'),
        (Icons.chat_outlined, 'WhatsApp chat', 'Replies in under 5 minutes'),
        (Icons.mail_outline_rounded, 'Email', 'support@gamex.shop'),
        (Icons.help_outline_rounded, 'FAQs', 'Orders, returns, warranty, EMI'),
      ])
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Icon(h.$1, color: AppColors.primary),
          ),
          title: Text(
            h.$2,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(h.$3),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => showAppSnack(c, '${h.$2}: ${h.$3}'),
        ),
    ],
  ),
);

// ── Logout ──
Future<void> confirmLogout(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text('You can sign in again anytime.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(88, 40),
            backgroundColor: AppColors.danger,
          ),
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Log out'),
        ),
      ],
    ),
  );
  if (ok == true) await ref.read(authProvider.notifier).logout();
}
