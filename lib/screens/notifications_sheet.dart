import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'haptic.dart';

/// زر جرس الإشعارات مع عدّاد أحمر للرسائل غير المقروءة
class NotificationBellButton extends StatelessWidget {
  final bool asPill;
  const NotificationBellButton({super.key, this.asPill = false});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final unread = state.unreadNotificationsCount;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bellIcon = Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          unread > 0
              ? Icons.notifications_active_rounded
              : Icons.notifications_outlined,
          size: asPill ? 18 : 23,
          color: unread > 0 ? TIColors.orangeDeep : null,
        ),
        if (unread > 0)
          Positioned(
            top: -5,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: const BoxDecoration(
                color: TIColors.danger,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );

    if (asPill) {
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showNotificationsSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? TIColors.darkLine : const Color(0xFFE2E8F0),
            ),
          ),
          child: bellIcon,
        ),
      );
    }

    return IconButton(
      onPressed: () => showNotificationsSheet(context),
      icon: bellIcon,
    );
  }
}

/// نافذة عرض الإشعارات الحية مع تمييز المقروء والأنواع
void showNotificationsSheet(BuildContext context) {
  Haptics.light();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Consumer<AppState>(
      builder: (ctx, state, _) {
        final l = ctx.l;
        final live = state.liveNotifications;
        final local = state.notifications;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        IconData iconFor(String type) {
          switch (type) {
            case 'offer':
              return Icons.local_offer_rounded;
            case 'new_booking':
              return Icons.receipt_long_rounded;
            case 'booking_status':
              return Icons.check_circle_rounded;
            case 'wallet':
              return Icons.account_balance_wallet_rounded;
            default:
              return Icons.notifications_active_rounded;
          }
        }

        Color colorFor(String type) {
          switch (type) {
            case 'offer':
              return TIColors.orangeDeep;
            case 'new_booking':
              return TIColors.cardRent;
            case 'booking_status':
              return TIColors.success;
            case 'wallet':
              return TIColors.gold;
            default:
              return TIColors.orange;
          }
        }

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, ctrl) => Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                child: Row(
                  children: [
                    Text(
                      l.t('notifications'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    if (state.unreadNotificationsCount > 0)
                      TextButton.icon(
                        onPressed: () => state.markAllNotificationsRead(),
                        icon: const Icon(Icons.done_all, size: 17),
                        label: Text(
                          l.isArabic ? 'تحديد الكل كمقروء' : 'Mark all read',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: live.isEmpty && local.isEmpty
                    ? Center(
                        child: Text(
                          l.t('noNotifications'),
                          style: TextStyle(color: Theme.of(ctx).hintColor),
                        ),
                      )
                    : ListView(
                        controller: ctrl,
                        padding: const EdgeInsets.all(14),
                        children: [
                          ...live.map((n) {
                            final read = state.isNotificationRead(n);
                            final type = (n['type'] ?? 'general').toString();
                            final c = colorFor(type);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: read
                                    ? Theme.of(ctx).cardColor
                                    : (isDark
                                        ? TIColors.orangeDeep.withOpacity(0.12)
                                        : TIColors.orangeTint),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: read
                                      ? Theme.of(ctx)
                                          .dividerColor
                                          .withOpacity(0.4)
                                      : TIColors.orangeSoft,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: c.withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: Icon(iconFor(type), color: c, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                (n['title'] ?? '').toString(),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13.5,
                                                ),
                                              ),
                                            ),
                                            if (!read)
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  color: TIColors.orangeDeep,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          (n['body'] ?? '').toString(),
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: Theme.of(ctx).hintColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          if (live.isEmpty)
                            ...local.map(
                              (txt) => ListTile(
                                leading: const Icon(Icons.notifications_active,
                                    color: TIColors.orange),
                                title: Text(txt,
                                    style: const TextStyle(fontSize: 13.5)),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
