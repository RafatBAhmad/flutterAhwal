import 'package:flutter/material.dart';
import '../models/checkpoint.dart';

class CheckpointCard extends StatefulWidget {
  final Checkpoint checkpoint;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final Color statusColor;
  final IconData statusIcon;
  final String relativeTime;

  const CheckpointCard({
    super.key,
    required this.checkpoint,
    required this.isFavorite,
    required this.onFavoriteToggle,
    required this.statusColor,
    required this.statusIcon,
    required this.relativeTime,
  });

  @override
  State<CheckpointCard> createState() => _CheckpointCardState();
}

class _CheckpointCardState extends State<CheckpointCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الصف الأول: اسم الحاجز والمفضلة
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.checkpoint.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    widget.isFavorite ? Icons.star : Icons.star_border,
                    color: widget.isFavorite ? Colors.amber : Colors.grey,
                  ),
                  onPressed: widget.onFavoriteToggle,
                ),
              ],
            ),

            const SizedBox(height: 8),

            // الصف الثاني: المدينة والحالة
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  widget.checkpoint.city,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: widget.statusColor, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.statusIcon,
                        size: 16,
                        color: widget.statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.checkpoint.status,
                        style: TextStyle(
                          color: widget.statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // النص المصدر مع إمكانية التوسيع
            if (widget.checkpoint.sourceText.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.checkpoint.sourceText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[700],
                        height: 1.3,
                      ),
                      textDirection: TextDirection.rtl,
                      maxLines: _isExpanded ? null : 2,
                      overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    ),

                    // زر إظهار المزيد/أقل
                    if (_shouldShowExpandButton()) ...[
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _isExpanded = !_isExpanded;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _isExpanded ? 'إظهار أقل' : 'إظهار المزيد',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _isExpanded ? Icons.expand_less : Icons.expand_more,
                                color: Theme.of(context).primaryColor,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // الصف الأخير: التوقيت
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  widget.relativeTime,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                    fontSize: 11,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // تحديد ما إذا كان يجب إظهار زر التوسيع
  bool _shouldShowExpandButton() {
    if (widget.checkpoint.sourceText.isEmpty) return false;

    // حساب عدد الأسطر التقريبي
    final textPainter = TextPainter(
      text: TextSpan(
        text: widget.checkpoint.sourceText,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.grey[700],
          height: 1.3,
        ),
      ),
      maxLines: 2,
      textDirection: TextDirection.rtl,
    );

    textPainter.layout(maxWidth: MediaQuery.of(context).size.width - 64);

    return textPainter.didExceedMaxLines;
  }
}

