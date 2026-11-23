import 'package:material_ui/material_ui.dart';

import '../../data/models/order.dart';
import '../theme/app_colors.dart';

/// Brand-coloured mark for each payment method (drawn, no image assets).
class PaymentMark extends StatelessWidget {
  const PaymentMark(this.method, {super.key, this.size = 44});
  final PaymentMethod method;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget box(Color bg, Widget child) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.26),
      ),
      alignment: Alignment.center,
      child: child,
    );
    switch (method) {
      case PaymentMethod.cashOnDelivery:
        return box(
          const Color(0xFFE3F6EA),
          Icon(
            Icons.payments_rounded,
            color: AppColors.success,
            size: size * 0.55,
          ),
        );
      case PaymentMethod.bkash:
        return box(
          const Color(0xFF0F7A3B),
          Text(
            'UPI',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.32,
            ),
          ),
        );
      case PaymentMethod.nagad:
        return box(
          const Color(0xFF5F259F),
          Text(
            'Wallet',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.25,
            ),
          ),
        );
      case PaymentMethod.card:
        return box(
          const Color(0xFF14213D),
          Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: Offset(-size * 0.11, 0),
                child: CircleAvatar(
                  radius: size * 0.17,
                  backgroundColor: const Color(0xFFEB001B),
                ),
              ),
              Transform.translate(
                offset: Offset(size * 0.11, 0),
                child: CircleAvatar(
                  radius: size * 0.17,
                  backgroundColor: const Color(0xFFF79E1B)
                      .withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        );
      case PaymentMethod.emi:
        return box(
          const Color(0xFFEDE7FF),
          Text(
            'EMI',
            style: TextStyle(
              color: const Color(0xFF6D28D9),
              fontWeight: FontWeight.w900,
              fontSize: size * 0.3,
            ),
          ),
        );
      case PaymentMethod.payLater:
        return box(
          const Color(0xFFFFF1E0),
          Icon(
            Icons.schedule_rounded,
            color: const Color(0xFFEA580C),
            size: size * 0.55,
          ),
        );
    }
  }
}
