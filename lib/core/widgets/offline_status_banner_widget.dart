// lib/core/widgets/offline_status_banner_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/services/offline_queue_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/app_toast.dart';

class OfflineStatusBannerWidget extends StatelessWidget {
  final bool isUrdu;
  final String fontFamily;

  const OfflineStatusBannerWidget({
    super.key,
    required this.isUrdu,
    required this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snapshot) {
        final connectivityResults = snapshot.data ?? [ConnectivityResult.wifi];
        final isOffline = connectivityResults.contains(ConnectivityResult.none);
        final offlineQueue = Provider.of<OfflineQueueService>(context);
        final pendingCount = offlineQueue.pendingCount;

        if (!isOffline && pendingCount == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isOffline
                ? const Color(0xFFFEF2F2)
                : const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isOffline
                  ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isOffline
                      ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOffline ? PhosphorIcons.wifiSlash() : PhosphorIcons.cloudArrowUp(),
                  size: 16,
                  color: isOffline ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UrduAwareText(
                      isOffline
                          ? (isUrdu ? 'آف لائن موڈ — انٹرنیٹ منقطع ہے' : 'Offline Mode — No Internet')
                          : (isUrdu ? 'پینڈنگ ڈیٹا سنک کے لیے تیار ہے' : 'Pending Data Ready to Sync'),
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: isOffline ? const Color(0xFF991B1B) : const Color(0xFF92400E),
                      ),
                    ),
                    if (pendingCount > 0) ...[
                      const SizedBox(height: 2),
                      UrduAwareText(
                        isUrdu
                            ? 'محفوظ شدہ ٹرانزیکشنز: $pendingCount'
                            : 'Queued operations: $pendingCount',
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isOffline ? const Color(0xB2991B1B) : const Color(0xB292400E),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isOffline && pendingCount > 0)
                TextButton.icon(
                  onPressed: offlineQueue.isSyncing
                      ? null
                      : () async {
                          await offlineQueue.processQueue();
                          if (context.mounted) {
                            AppToast.success(
                              context,
                              isUrdu ? 'سنک مکمل ہو گیا' : 'Sync completed',
                            );
                          }
                        },
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: offlineQueue.isSyncing
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(PhosphorIcons.arrowsClockwise(), size: 14),
                  label: UrduAwareText(
                    isUrdu ? 'سنک کریں' : 'Sync',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
