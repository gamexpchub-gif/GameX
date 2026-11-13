import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/app_user.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/providers/orders_provider.dart';
import '../../wishlist/providers/wishlist_provider.dart';
import '../providers/theme_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final orders = ref.watch(ordersProvider).length;
    final wish = ref.watch(wishlistProvider).length;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          user == null ? const _GuestCard() : _UserCard(user: user),
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat(
                label: 'Orders',
                value: '$orders',
                onTap: () => context.push('/orders'),
              ),
              const SizedBox(width: 10),
              _Stat(
                label: 'Wishlist',
                value: '$wish',
                onTap: () => context.go('/wishlist'),
              ),
              const SizedBox(width: 10),
              _Stat(
                label: 'Coupons',
                value: '2',
                onTap: () => _showCoupons(context),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _Group(
            children: [
              _Item(
                Icons.receipt_long_outlined,
                'My Orders',
                onTap: () => context.push('/orders'),
              ),
              _Item(
                Icons.location_on_outlined,
                'Saved Addresses',
                onTap: () => showAppSnack(
                  context,
                  'Your last address is saved at checkout',
                ),
              ),
              _Item(
                Icons.local_offer_outlined,
                'Coupons & Offers',
                onTap: () => _showCoupons(context),
              ),
              _Item(
                Icons.payments_outlined,
                'Payment Methods',
                onTap: () =>
                    showAppSnack(context, 'bKash, Nagad, Card & COD supported'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Group(
            children: [
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: const Text('Appearance'),
                trailing: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined, size: 18),
                    ),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (s) =>
                      ref.read(themeModeProvider.notifier).set(s.first),
                ),
              ),
              _Item(
                Icons.notifications_none_rounded,
                'Notifications',
                onTap: () =>
                    showAppSnack(context, 'Notification settings coming soon'),
              ),
              _Item(
                Icons.language_rounded,
                'Language',
                trailing: 'English',
                onTap: () => showAppSnack(context, 'বাংলা support coming soon'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Group(
            children: [
              _Item(
                Icons.support_agent_rounded,
                'Help & Support',
                onTap: () =>
                    showAppSnack(context, 'Support: 16XXX (9am – 10pm)'),
              ),
              _Item(Icons.privacy_tip_outlined, 'Privacy Policy', onTap: () {}),
              _Item(
                Icons.info_outline_rounded,
                'About GameX Shop',
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'GameX Shop',
                    applicationVersion: '1.0.0',
                    applicationLegalese: '© 2026 GameX',
                  );
                },
              ),
            ],
          ),
          if (user != null) ...[
            const SizedBox(height: 14),
            _Group(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.danger,
                  ),
                  title: const Text(
                    'Log out',
                    style: TextStyle(color: AppColors.danger),
                  ),
                  onTap: () async {
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
                          TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Log out'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await ref.read(authProvider.notifier).logout();
                    }
                  },
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Version 1.0.0',
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCoupons(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.local_offer_rounded,
                  color: AppColors.accent,
                ),
                title: Text('GAMEX10'),
                subtitle: Text('10% off on any order'),
              ),
              ListTile(
                leading: Icon(
                  Icons.local_offer_rounded,
                  color: AppColors.accent,
                ),
                title: Text('WELCOME20'),
                subtitle: Text('20% off for new customers'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserCard extends ConsumerWidget {
  const _UserCard({required this.user});
  final AppUser user;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController(text: user.name);
    final phone = TextEditingController(text: user.phone ?? '');
    final form = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Edit profile'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => Validators.required(v, 'Name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobile number'),
                validator: Validators.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(c, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true) {
      await ref
          .read(authProvider.notifier)
          .updateProfile(name: name.text.trim(), phone: phone.text.trim());
    }
    name.dispose();
    phone.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Text(
              user.initials,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(user.email, style: const TextStyle(color: Colors.white70)),
                if (user.phone != null && user.phone!.isNotEmpty)
                  Text(
                    user.phone!,
                    style: const TextStyle(color: Colors.white70),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _edit(context, ref),
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _GuestCard extends StatelessWidget {
  const _GuestCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome to GameX Shop',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Sign in to track orders and get exclusive offers.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              minimumSize: const Size(140, 44),
            ),
            onPressed: () =>
                context.push('/login?from=${Uri.encodeComponent('/profile')}'),
            child: const Text('Sign in / Register'),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item(this.icon, this.title, {required this.onTap, this.trailing});
  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: onTap,
    );
  }
}
