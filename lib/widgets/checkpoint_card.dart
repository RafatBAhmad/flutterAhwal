import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/checkpoint.dart';
import '../utils/date_time_utils.dart';
import '../services/share_service.dart';

class CheckpointCard extends StatefulWidget {
  final Checkpoint checkpoint;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final String relativeTime;
  final IconData statusIcon;
  final Color statusColor;

  const CheckpointCard({
    super.key,
    required this.checkpoint,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.relativeTime,
    required this.statusIcon,
    required this.statusColor,
  });

  @override
  State<CheckpointCard> createState() => _CheckpointCardState();
}

class _CheckpointCardState extends State<CheckpointCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.checkpoint.effectiveAtDateTime == null ||
        DateTime.now()
            .difference(widget.checkpoint.effectiveAtDateTime!)
            .inHours >
            24) {
      return const SizedBox.shrink();
    }

    // تحديد لون الحالة والأيقونة
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
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).cardColor,
      elevation: 2,
      child: GestureDetector(
        // 🔥 إضافة Long Press للمشاركة السريعة
        onLongPress: () async {
          // اهتزاز خفيف
          HapticFeedback.mediumImpact();

          // إظهار قائمة خيارات
          final result = await showModalBottomSheet<String>(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.checkpoint.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 6),
                        Text(
                          widget.checkpoint.status,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: const Icon(Icons.share, color: Colors.blue),
                    title: const Text('مشاركة الحاجز', textDirection: TextDirection.rtl),
                    onTap: () => Navigator.pop(context, 'share'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.copy, color: Colors.green),
                    title: const Text('نسخ النص المصدر', textDirection: TextDirection.rtl),
                    onTap: () => Navigator.pop(context, 'copy'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.text_snippet, color: Colors.purple),
                    title: const Text('مشاركة سريعة', textDirection: TextDirection.rtl),
                    subtitle: const Text('الاسم والحالة فقط', textDirection: TextDirection.rtl),
                    onTap: () => Navigator.pop(context, 'quick_share'),
                  ),
                  ListTile(
                    leading: Icon(
                      widget.isFavorite ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                    title: Text(
                      widget.isFavorite ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
                      textDirection: TextDirection.rtl,
                    ),
                    onTap: () => Navigator.pop(context, 'favorite'),
                  ),
                ],
              ),
            ),
          );

          // تنفيذ الإجراء المختار
          if (result != null && mounted) {
            switch (result) {
              case 'share':
                await ShareService.shareCheckpoint(widget.checkpoint);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم مشاركة تفاصيل الحاجز'),
                      duration: Duration(seconds: 2),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
                break;
              case 'copy':
                await ShareService.copyToClipboard(widget.checkpoint.sourceText);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم نسخ النص المصدر للحافظة'),
                      duration: Duration(seconds: 2),
                      backgroundColor: Colors.blue,
                    ),
                  );
                }
                break;
              case 'quick_share':
                await ShareService.shareQuickStatus(widget.checkpoint.name, widget.checkpoint.status);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم مشاركة الحالة بشكل سريع'),
                      duration: Duration(seconds: 2),
                      backgroundColor: Colors.purple,
                    ),
                  );
                }
                break;
              case 'favorite':
                widget.onToggleFavorite();
                break;
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الصف الأول: اسم الحاجز يمين + الأزرار يسار
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.checkpoint.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                  // 🔥 زر المشاركة
                  IconButton(
                    icon: const Icon(Icons.share, size: 20),
                    color: Colors.blue,
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      await ShareService.shareCheckpoint(widget.checkpoint);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم مشاركة تفاصيل الحاجز'),
                            duration: Duration(seconds: 2),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    tooltip: 'مشاركة الحاجز',
                  ),
                  // زر النجمة
                  IconButton(
                    icon: Icon(
                      widget.isFavorite ? Icons.star : Icons.star_border,
                      color: widget.isFavorite ? Colors.amber : Colors.grey,
                      size: 20,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      widget.onToggleFavorite();
                    },
                    tooltip: widget.isFavorite ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
                  ),
                ].reversed.toList(), // ✅ عكسنا الترتيب
              ),

              const SizedBox(height: 6),

              // الصف الثاني: المدينة + الحالة
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    widget.checkpoint.city.isNotEmpty
                        ? widget.checkpoint.city
                        : 'غير محدد',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.grey[500]),
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

              // النص المصدر يمين مع إمكانية التوسيع + تلوين الكلمات
              if (widget.checkpoint.sourceText.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerRight, // ✅ النص يمين
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[900]
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[700]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end, // ✅ النص يمين
                      children: [
                        RichText(
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.right,
                          maxLines: _isExpanded ? null : 3,
                          overflow: _isExpanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                          text: TextSpan(
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[300],
                              height: 1.4,
                            ),
                            children:
                            _highlightText(widget.checkpoint.sourceText),
                          ),
                        ),
                        if (_shouldShowExpandButton()) ...[
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () =>
                                setState(() => _isExpanded = !_isExpanded),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment:
                              MainAxisAlignment.end, // ✅ زر يمين
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
                ),
                const SizedBox(height: 8),
              ],

              // التاريخ يمين + زر نسخ النص
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // زر نسخ النص المصدر (يسار)
                  if (widget.checkpoint.sourceText.isNotEmpty)
                    TextButton.icon(
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        await ShareService.copyToClipboard(widget.checkpoint.sourceText);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم نسخ النص المصدر للحافظة'),
                              duration: Duration(seconds: 2),
                              backgroundColor: Colors.blue,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy, size: 14),
                      label: const Text('نسخ النص', style: TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: const Size(0, 0),
                      ),
                    ),

                  // التاريخ (يمين)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        DateTimeUtils.formatCheckpointDate(
                            widget.checkpoint.effectiveAtDateTime),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _shouldShowExpandButton() {
    if (widget.checkpoint.sourceText.isEmpty) return false;
    final textPainter = TextPainter(
      text: TextSpan(
        text: widget.checkpoint.sourceText,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Colors.grey[700], height: 1.3),
      ),
      maxLines: 3,
      textDirection: TextDirection.rtl,
    );
    textPainter.layout(maxWidth: MediaQuery.of(context).size.width - 64);
    return textPainter.didExceedMaxLines;
  }

  /// 🔹 دالة تلوين الكلمات المهمة
  List<TextSpan> _highlightText(String text) {
    final words = text.split(' ');
    return words.map((word) {
      if (word.contains('مغلق') || word.contains('XXX')) {
        return TextSpan(
          text: '$word ',
          style:
          const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        );
      } else if (word.contains('مفتوح') ||
          word.contains('سالكة') ||
          word.contains('سالكه') ||
          word.contains('سالك')) {
        return TextSpan(
          text: '$word ',
          style: const TextStyle(
              color: Colors.green, fontWeight: FontWeight.bold),
        );
      } else if (word.contains('ازدحام') ||
          word.contains('كثافة سير') ||
          word.contains('ازمة') ||
          word.contains('أزمة') ||
          word.contains('تفتيش') ||
          word.contains('الحادث') ||
          word.contains('حادث') ||
          word.contains('اصطدام') ||
          word.contains('إصطدام')) {
        return TextSpan(
          text: '$word ',
          style: const TextStyle(
              color: Colors.orange, fontWeight: FontWeight.bold),
        );
      } else {
        return TextSpan(text: '$word ');
      }
    }).toList();
  }
}