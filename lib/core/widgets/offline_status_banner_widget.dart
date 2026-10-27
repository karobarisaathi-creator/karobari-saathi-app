// lib/core/widgets/offline_status_banner_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/services/offline_queue_service.dart';
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

        // Colorful, borderless, vibrant config
        final backgroundColor = isOffline
            ? const Color(0xFFEF4444) // Vibrant Red
            : (pendingCount > 0 ? const Color(0xFFF59E0B) : const Color(0xFF22C55E)); // Vibrant Amber or Green

        final iconData = isOffline
            ? PhosphorIcons.wifiSlash()
            : (pendingCount > 0 ? PhosphorIcons.cloudArrowUp() : PhosphorIcons.wifiHigh());

        final titleText = isOffline
            ? (isUrdu ? 'انٹرنیٹ منقطع ہے (آف لائن موڈ)' : 'Internet Disconnected (Offline)')
            : (pendingCount > 0
                ? (isUrdu ? 'پینڈنگ ڈیٹا سنک کے لیے تیار ہے' : 'Pending Data Ready to Sync')
                : (isUrdu ? 'انٹرنیٹ بحال ہے (آن لائن موڈ)' : 'Internet Connected (Online)'));

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                iconData,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: UrduAwareText(
                        titleText,
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (pendingCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: UrduAwareText(
                          '$pendingCount',
                          style: TextStyle(
                            fontFamily: fontFamily,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
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
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFD97706),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  icon: offlineQueue.isSyncing
                      ? const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFFD97706)),
                        )
                      : Icon(PhosphorIcons.arrowsClockwise(), size: 12),
                  label: UrduAwareText(
                    isUrdu ? 'سنک' : 'Sync',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 10.5,
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
