import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/models/job_bid_model.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/services/artisan_service.dart';

class JobBidCard extends StatefulWidget {
  final JobBid bid;
  final bool isOwner;
  final bool isJobOpen;
  final bool isUrdu;
  final String fontFamily;
  final VoidCallback onAccept;

  const JobBidCard({
    super.key,
    required this.bid,
    required this.isOwner,
    required this.isJobOpen,
    required this.isUrdu,
    required this.fontFamily,
    required this.onAccept,
  });

  @override
  State<JobBidCard> createState() => _JobBidCardState();
}

class _JobBidCardState extends State<JobBidCard> {
  bool _isExpanded = false;

  void _callArtisan() async {
    final phone = Formatters.normalizePhoneNumber(widget.bid.artisanPhone);
    if (phone != null) {
      final uri = Uri(scheme: 'tel', path: phone);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  void _whatsappArtisan() async {
    final phone = Formatters.normalizePhoneNumber(widget.bid.artisanPhone);
    if (phone != null) {
      final message = widget.isUrdu
          ? 'سلام! میں نے آپ کی بولی دیکھی ہے، اس بارے میں بات کرنی ہے۔'
          : 'Salam! I saw your bid and want to discuss it further.';
      final uri = Uri.parse(
        'https://wa.me/${phone.replaceAll('+', '')}?text=${Uri.encodeComponent(message)}',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bid = widget.bid;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ProfileInfoWidget(
                  name: bid.artisanName,
                  phone: '',
                  profileImage: bid.artisanPhotoUrl,
                  customSize: 42,
                  borderRadius: 6,
                  bottom: Row(
                    children: [
                      Icon(Icons.star, size: 12, color: Colors.amber[700]),
                      const SizedBox(width: 2),
                      Text(bid.artisanRating.toStringAsFixed(1), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Text(
                        '${bid.artisanExperience} ${widget.isUrdu ? 'سال تجربہ' : 'yrs exp'}', 
                        style: TextStyle(fontSize: 11, color: Colors.grey[600], fontFamily: widget.fontFamily)
                      ),
                    ],
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rs. ${bid.amount.toStringAsFixed(0)}', 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)
                  ),
                  Text(Formatters.formatDate(bid.createdAt), style: const TextStyle(fontSize: 9, color: Colors.grey)),
                ],
              ),
            ],
          ),
          
          if (bid.message.isNotEmpty) ...[
            const Divider(height: 20),
            GestureDetector(
              onTap: () {
                if (bid.message.length > 120) {
                  setState(() => _isExpanded = !_isExpanded);
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bid.message,
                    maxLines: _isExpanded ? null : 4,
                    overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: Colors.grey[800], fontFamily: widget.fontFamily, height: 1.4),
                  ),
                  if (bid.message.length > 120)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _isExpanded 
                            ? (widget.isUrdu ? 'کم دکھائیں' : 'Show Less') 
                            : (widget.isUrdu ? 'مزید پڑھیں...' : 'Read More...'),
                        style: TextStyle(color: AppTheme.themeColor, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: widget.fontFamily),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // 🆕 ایکشن بٹنز (صرف جاب کے مالک کے لیے جب کام کھلا ہو)
          if (widget.isOwner && widget.isJobOpen) ...[
            const SizedBox(height: 16),
            FutureBuilder<ArtisanProfile?>(
              future: ArtisanService().getProfile(bid.artisanId),
              builder: (context, snapshot) {
                final profile = snapshot.data;
                final bool showWhatsApp = profile?.showWhatsApp ?? true;
                final bool isPending = bid.status == 'pending';

                return Row(
                  children: [
                    // واٹس ایپ بٹن
                    if (showWhatsApp) ...[
                      _buildCircularActionButton(
                        icon: PhosphorIcons.whatsappLogo(PhosphorIconsStyle.fill),
                        color: isPending ? const Color(0xFF25D366) : Colors.grey,
                        onTap: isPending ? _whatsappArtisan : () {},
                      ),
                      const SizedBox(width: 12),
                    ],
                    // کام فائنل کریں بٹن
                    Expanded(
                      child: AppButton(
                        text: isPending 
                          ? (widget.isUrdu ? 'کام فائنل کریں' : 'Finalize Work')
                          : (bid.status == 'accepted' ? (widget.isUrdu ? 'منظور شدہ' : 'Accepted') : (widget.isUrdu ? 'مسترد' : 'Rejected')),
                        size: AppButtonSize.small,
                        color: isPending ? AppTheme.themeColor : Colors.grey,
                        onPressed: isPending ? widget.onAccept : null,
                      ),
                    ),
                  ],
                );
              },
            ),
          ]
          else if (bid.status != 'pending' || !widget.isJobOpen) ...[
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: _buildStatusBadge(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCircularActionButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    String text;

    switch (widget.bid.status) {
      case 'accepted':
        color = Colors.green;
        text = widget.isUrdu ? 'منظور شدہ' : 'Accepted';
        break;
      case 'rejected':
        color = Colors.red;
        text = widget.isUrdu ? 'مسترد' : 'Rejected';
        break;
      default:
        color = Colors.orange;
        text = widget.isUrdu ? 'زیرِ غور' : 'Pending';
    }

    if (widget.bid.status == 'pending' && !widget.isOwner) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: widget.fontFamily),
      ),
    );
  }
}
