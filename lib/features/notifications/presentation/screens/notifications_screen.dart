import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class _NotificationItem {
  const _NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  factory _NotificationItem.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final rawCreated = data['createdAt'];
    DateTime created;
    if (rawCreated is Timestamp) {
      created = rawCreated.toDate();
    } else if (rawCreated is String) {
      created = DateTime.tryParse(rawCreated) ?? DateTime.now();
    } else {
      created = DateTime.now();
    }

    return _NotificationItem(
      id: doc.id,
      title: data['title'] as String? ?? 'Bildirim',
      body: data['body'] as String? ?? '',
      isRead: data['isRead'] as bool? ?? false,
      createdAt: created,
    );
  }
}

final _notificationsStreamProvider =
    StreamProvider.autoDispose.family<List<_NotificationItem>, String>(
  (ref, userId) {
    if (userId.isEmpty) return Stream.value(const []);
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(_NotificationItem.fromDoc).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  },
);

/// Uygulama içi bildirimler ekranı (Öğretmen ve Veli ortak)
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _markAllRead(List<_NotificationItem> items) async {
    final unread = items.where((i) => !i.isRead).toList();
    if (unread.isEmpty) return;

    final firestore = FirebaseFirestore.instance;
    for (var i = 0; i < unread.length; i += 400) {
      final chunk = unread.skip(i).take(400);
      final batch = firestore.batch();
      for (final item in chunk) {
        batch.update(
          firestore.collection('notifications').doc(item.id),
          {'isRead': true},
        );
      }
      await batch.commit();
    }
  }

  Future<void> _markRead(String id) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(id)
        .update({'isRead': true});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final notificationsAsync =
        ref.watch(_notificationsStreamProvider(user?.uid ?? ''));
    final primaryColor = (user?.isTeacher ?? true)
        ? AppColors.teacherPrimary
        : AppColors.parentPrimary;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          notificationsAsync.whenOrNull(
                data: (items) => items.any((i) => !i.isRead)
                    ? TextButton(
                        onPressed: () => _markAllRead(items),
                        child: Text(
                          'Tümünü Okundu İşaretle',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null,
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => ErrorState(
          message: 'Bildirimler şu anda yüklenemedi.',
          onRetry: () =>
              ref.invalidate(_notificationsStreamProvider(user?.uid ?? '')),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Bildirim Bulunmuyor',
              subtitle:
                  'Yeni duyurular ve güncellemeler burada listelenecektir.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSizes.pagePadding),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return InkWell(
                borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                onTap: item.isRead ? null : () => _markRead(item.id),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: item.isRead
                        ? AppColors.surface
                        : primaryColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                    border: Border.all(
                      color: item.isRead
                          ? AppColors.border
                          : primaryColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: item.isRead ? Colors.transparent : primaryColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: AppTextStyles.h4.copyWith(
                                      fontSize: 15,
                                      fontWeight: item.isRead
                                          ? FontWeight.w600
                                          : FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  item.createdAt.toShortTurkishDate(),
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            if (item.body.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.body,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
