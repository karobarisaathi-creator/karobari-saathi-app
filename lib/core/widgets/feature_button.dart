import 'package:flutter/material.dart';

class FeatureButton extends StatelessWidget {
  final IconData? icon;
  final String? imageAsset;
  final String title;
  final String fontFamily;
  final int? count;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;

  const FeatureButton({
    Key? key,
    this.icon,
    this.imageAsset,
    required this.title,
    required this.fontFamily,
    this.count,
    required this.color,
    this.isLoading = false,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: Colors.green.withOpacity(0.2),
        highlightColor: Colors.green.withOpacity(0.1),
        child: Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with count badge on top
              Stack(
                alignment: Alignment.topRight,
                children: [
                  // Icon or Image
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.green.withOpacity(0.2),
                        width: 2,
                      ),
                    ),
                    child: imageAsset != null
                        ? ClipOval(
                            child: Image.asset(
                              imageAsset!,
                              width: 24,
                              height: 24,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(
                            icon,
                            size: 24,
                            color: Colors.green.shade600,
                          ),
                  ),

                  // Count badge - آئیکن کے اوپر
                  if (count != null)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade500,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 1.5,
                          ),
                        ),
                        constraints: BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          count.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'NotoSans',
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              SizedBox(height: 10),

              // Title - بڑا سائز
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14, // بڑا سائز
                  fontWeight: FontWeight.w600,
                  fontFamily: fontFamily,
                  color: Colors.grey.shade800,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}