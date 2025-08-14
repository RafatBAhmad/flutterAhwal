import 'package:flutter/material.dart';
import '../models/checkpoint.dart';
import '../services/share_service.dart';
import '../services/cache_service.dart';
import '../services/city_voting_service.dart';
import '../utils/theme.dart';

class CheckpointCard extends StatefulWidget {
  final Checkpoint checkpoint;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onTap;
  final bool showTimestamp;
  final ThemeMode themeMode;
  final bool isNew;
  final bool isDetailed;
  final bool showCityAndSource;
  final Color statusColor;
  final IconData statusIcon;
  final String relativeTime;

  const CheckpointCard({
    super.key,
    required this.checkpoint,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.statusColor,
    required this.statusIcon,
    required this.relativeTime,
    this.onTap,
    this.showTimestamp = true,
    this.themeMode = ThemeMode.light,
    this.isNew = false,
    this.isDetailed = false,
    this.showCityAndSource = false,
  });

  @override
  State<CheckpointCard> createState() => _CheckpointCardState();
}

class _CheckpointCardState extends State<CheckpointCard> {
  Map<String, int>? _customColors;

  @override
  void initState() {
    super.initState();
    _loadCustomColors();
  }

  Future<void> _loadCustomColors() async {
    final customColors = await CacheService.getCustomColors();
    if (mounted) {
      setState(() {
        _customColors = customColors;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Improved colors for both light and dark themes
    final primaryColor = isDark ? theme.colorScheme.primary : const Color(0xFF9C4DCC);
    final surfaceColor = isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white;
    final textColor = isDark ? theme.colorScheme.onSurface : const Color(0xFF1A1A1A);
    final subtitleColor = isDark ? theme.colorScheme.onSurface.withValues(alpha: 0.7) : Colors.grey[600];

    return Container(
      margin: EdgeInsets.only(bottom: widget.isDetailed ? 16 : 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: widget.isNew
                  ? Border.all(color: primaryColor, width: 1.5)
                  : Border.all(color: Colors.grey.withValues(alpha: 0.2), width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black26 : primaryColor.withValues(alpha: 0.1),
                  blurRadius: widget.isNew ? 8 : 4,
                  offset: const Offset(0, 2),
                  spreadRadius: widget.isNew ? 1 : 0,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // الصف الأول: اسم الحاجز + المفضلة + مشاركة
                  Row(
                    children: [
                      // أيقونة الحالة
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getStatusColor().withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getStatusColor().withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          _getStatusIcon(),
                          color: _getStatusColor(),
                          size: 20,
                        ),
                      ),

                      const SizedBox(width: 12),

                      // اسم الحاجز
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.checkpoint.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                              textDirection: TextDirection.rtl,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                            if (widget.isDetailed || widget.showCityAndSource) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: subtitleColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: widget.checkpoint.city == 'غير معروف' || widget.checkpoint.city.isEmpty
                                        ? Row(
                                            children: [
                                              Text(
                                                'مدينة غير محددة',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.orange[600],
                                                  fontStyle: FontStyle.italic,
                                                ),
                                                textDirection: TextDirection.rtl,
                                              ),
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                                onTap: () => _showCityVotingDialog(context),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(
                                                      color: Colors.blue.withValues(alpha: 0.3),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.how_to_vote,
                                                        size: 12,
                                                        color: Colors.blue[700],
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'اقترح',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.blue[700],
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                        : Text(
                                            widget.checkpoint.city,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: subtitleColor,
                                            ),
                                            textDirection: TextDirection.rtl,
                                          ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      // إشارة الرسالة الجديدة
                      if (widget.isNew) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'جديد',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // زر المفضلة
                      IconButton(
                        onPressed: widget.onToggleFavorite,
                        icon: Icon(
                          widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: widget.isFavorite ? Colors.red : Colors.grey[400],
                          size: 22,
                        ),
                        tooltip: widget.isFavorite ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
                      ),

                      // زر المشاركة
                      IconButton(
                        onPressed: () => _shareCheckpoint(context),
                        icon: Icon(
                          Icons.share,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                        tooltip: 'مشاركة',
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // الصف الثاني: الحالة + التوقيت
                  Row(
                    children: [
                      // حالة الحاجز
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _getStatusColor().withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _getStatusColor().withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getStatusIcon(),
                                color: _getStatusColor(),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  widget.checkpoint.status,
                                  style: TextStyle(
                                    color: _getStatusColor(),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textDirection: TextDirection.rtl,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // التوقيت إذا كان مطلوباً
                      if (widget.showTimestamp) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? theme.colorScheme.surface : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 12,
                                color: subtitleColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatRelativeTime(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: subtitleColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),

                  // عرض النص المصدر إذا كان متوفراً ومطلوباً
                  if (widget.showCityAndSource && widget.checkpoint.sourceText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? theme.colorScheme.surface.withValues(alpha: 0.5) : Colors.grey[50],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? theme.colorScheme.outline.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        widget.checkpoint.sourceText,
                        style: TextStyle(
                          fontSize: 12,
                          color: subtitleColor,
                          height: 1.3,
                        ),
                        textDirection: TextDirection.rtl,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],

                  // معلومات إضافية للعرض المفصل
                  if (widget.isDetailed) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),

                    // معلومات إضافية
                    if (widget.checkpoint.sourceText.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? theme.colorScheme.surface.withValues(alpha: 0.5) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? theme.colorScheme.outline.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: subtitleColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'معلومات إضافية:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: subtitleColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.checkpoint.sourceText,
                              style: TextStyle(
                                fontSize: 12,
                                color: subtitleColor,
                                height: 1.4,
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                          ],
                        ),
                      ),
                    ],

                    // تواريخ مفصلة
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (widget.checkpoint.effectiveAt != null) ...[
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: subtitleColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'آخر تحديث: ${_formatDetailedTime(widget.checkpoint.effectiveAtDateTime)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    return AppTheme.getStatusColor(widget.checkpoint.status, customColors: _customColors);
  }

  IconData _getStatusIcon() {
    return AppTheme.getStatusIcon(widget.checkpoint.status);
  }

  String _formatRelativeTime() {
    final effectiveDate = widget.checkpoint.effectiveAtDateTime ?? widget.checkpoint.updatedAtDateTime;
    if (effectiveDate == null) return 'غير معروف';

    return _formatTimeWithRelative(effectiveDate);
  }

  String _formatTimeWithRelative(DateTime dateTime) {
    final timeStr = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    String relativeStr;
    if (difference.inMinutes < 1) {
      relativeStr = 'الآن';
    } else if (difference.inMinutes < 60) {
      relativeStr = 'منذ ${difference.inMinutes}د';
    } else if (difference.inHours < 24) {
      relativeStr = 'منذ ${difference.inHours}س';
    } else if (difference.inDays == 1) {
      relativeStr = 'أمس';
    } else if (difference.inDays < 7) {
      relativeStr = 'منذ ${difference.inDays}ي';
    } else {
      relativeStr = '${dateTime.day}/${dateTime.month}';
    }

    return '$timeStr ($relativeStr)';
  }

  String _formatDetailedTime(DateTime? dateTime) {
    if (dateTime == null) return 'غير معروف';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays < 1) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  void _shareCheckpoint(BuildContext context) {
    ShareService.shareCheckpoint(widget.checkpoint);

    // عرض رسالة تأكيد
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ معلومات ${widget.checkpoint.name}'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showCityVotingDialog(BuildContext context) async {
    final deviceId = await CityVotingService.getDeviceId();
    if (context.mounted) {
      CityVotingService.showCityVotingDialog(
        context,
        widget.checkpoint,
        deviceId,
      );
    }
  }
}