import 'package:flutter/material.dart';
import '../models/checkpoint.dart';

class CheckpointCard extends StatefulWidget {
  final Checkpoint checkpoint;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final String relativeTime; // نستخدمه بدلاً من حساب التاريخ داخل الكارد
  final Color statusColor;
  final IconData statusIcon;

  const CheckpointCard({
    super.key,
    required this.checkpoint,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.relativeTime,
    required this.statusColor,
    required this.statusIcon,
  });

  @override
  State<CheckpointCard> createState() => _CheckpointCardState();
}

class _CheckpointCardState extends State<CheckpointCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // فلترة: إخفاء الكارد إذا أقدم من 24 ساعة
    if (widget.checkpoint.effectiveAtDateTime == null ||
        DateTime.now()
            .difference(widget.checkpoint.effectiveAtDateTime!)
            .inHours > 24) {
      return const SizedBox.shrink();
    }

    // تحديد لون الحالة والأيقونة داخلياً
    Color statusColor;
    IconData statusIcon;
    switch (widget.checkpoint.status.toLowerCase()) {
      case 'مفتوح':
      case 'سالكة':
      case 'سالكه':
      case 'سالك':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'مغلق':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'ازدحام':
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
        break;
    }

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
                  onPressed: widget.onToggleFavorite,
                ),
              ],
            ),

            const SizedBox(height: 8),

            // الصف الثاني: المدينة + الحالة
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
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
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: (0.1)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        widget.checkpoint.status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
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
                      maxLines: _isExpanded ? null : 3, // 3 أسطر بدل 2
                      overflow: _isExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                    ),
                    if (_shouldShowExpandButton()) ...[
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () =>
                            setState(() => _isExpanded = !_isExpanded),
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
                              _isExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: Theme.of(context).primaryColor,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // الوقت النسبي
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
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

  // التحقق إذا النص يحتاج زر "إظهار المزيد"
  bool _shouldShowExpandButton() {
    if (widget.checkpoint.sourceText.isEmpty) return false;
    final textPainter = TextPainter(
      text: TextSpan(
        text: widget.checkpoint.sourceText,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.grey[700],
          height: 1.3,
        ),
      ),
      maxLines: 3,
      textDirection: TextDirection.rtl,
    );
    textPainter.layout(maxWidth: MediaQuery.of(context).size.width - 64);
    return textPainter.didExceedMaxLines;
  }
}
