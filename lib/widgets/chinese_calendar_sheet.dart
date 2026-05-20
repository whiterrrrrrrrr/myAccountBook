import 'package:my_account_book/constants/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ChineseCalendarSheet extends StatefulWidget {
  const ChineseCalendarSheet({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<ChineseCalendarSheet> createState() => _ChineseCalendarSheetState();
}

class _ChineseCalendarSheetState extends State<ChineseCalendarSheet> {
  late DateTime _selectedDate;
  late DateTime _displayMonth;
  int _monthSlideDirection = 1;
  static const List<String> _weekdays = <String>[
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '日',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _displayMonth = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      1,
    );
  }

  bool _canGoPrevMonth() {
    final DateTime prev = DateTime(
      _displayMonth.year,
      _displayMonth.month - 1,
      1,
    );
    return !prev.isBefore(
      DateTime(widget.firstDate.year, widget.firstDate.month, 1),
    );
  }

  bool _canGoNextMonth() {
    final DateTime next = DateTime(
      _displayMonth.year,
      _displayMonth.month + 1,
      1,
    );
    return !next.isAfter(
      DateTime(widget.lastDate.year, widget.lastDate.month, 1),
    );
  }

  void _changeMonth(int delta) {
    final DateTime next = DateTime(
      _displayMonth.year,
      _displayMonth.month + delta,
      1,
    );
    if (next.isBefore(
          DateTime(widget.firstDate.year, widget.firstDate.month, 1),
        ) ||
        next.isAfter(
          DateTime(widget.lastDate.year, widget.lastDate.month, 1),
        )) {
      return;
    }
    setState(() {
      _monthSlideDirection = delta >= 0 ? 1 : -1;
      _displayMonth = next;
    });
  }

  Future<void> _openYearMonthPicker() async {
    final DateTime? picked = await showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return _YearMonthPickerSheet(initialMonth: _displayMonth);
      },
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _displayMonth = DateTime(picked.year, picked.month, 1);
    });
  }

  void _handleMonthSwipe(DragEndDetails details) {
    final double? velocity = details.primaryVelocity;
    if (velocity == null) {
      return;
    }
    if (velocity < -120) {
      _changeMonth(1);
    } else if (velocity > 120) {
      _changeMonth(-1);
    }
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateTime firstDay = DateTime(
      _displayMonth.year,
      _displayMonth.month,
      1,
    );
    final int offset = (firstDay.weekday + 6) % 7;
    final int daysInMonth = DateTime(
      _displayMonth.year,
      _displayMonth.month + 1,
      0,
    ).day;
    final DateTime today = DateTime.now();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: _canGoPrevMonth() ? () => _changeMonth(-1) : null,
                  icon: const Icon(
                    Icons.chevron_left,
                    color: AppColors.calendarAccent,
                  ),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _openYearMonthPicker,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          '${_displayMonth.year}年${_displayMonth.month}月',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.arrow_drop_down,
                          color: AppColors.calendarAccent,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _canGoNextMonth() ? () => _changeMonth(1) : null,
                  icon: const Icon(
                    Icons.chevron_right,
                    color: AppColors.calendarAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: _weekdays
                  .map(
                    (String w) => Expanded(
                      child: Center(
                        child: Text(
                          w,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onHorizontalDragEnd: _handleMonthSwipe,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final Offset begin = Offset(_monthSlideDirection * 0.35, 0);
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: begin,
                      end: Offset.zero,
                    ).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: GridView.builder(
                  key: ValueKey<String>(
                    '${_displayMonth.year}-${_displayMonth.month}',
                  ),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 42,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    final int day = index - offset + 1;
                    if (day <= 0 || day > daysInMonth) {
                      return const SizedBox.shrink();
                    }
                    final DateTime date = DateTime(
                      _displayMonth.year,
                      _displayMonth.month,
                      day,
                    );
                    final bool disabled =
                        date.isBefore(widget.firstDate) ||
                        date.isAfter(widget.lastDate);
                    final bool selected = _sameDay(date, _selectedDate);
                    final bool isToday = _sameDay(date, today);
                    return InkWell(
                      onTap: disabled
                          ? null
                          : () => setState(() => _selectedDate = date),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: selected
                              ? AppColors.calendarAccent
                              : Colors.transparent,
                          border: isToday && !selected
                              ? Border.all(
                                  color: AppColors.calendarAccent.withValues(
                                    alpha: 0.65,
                                  ),
                                )
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected
                                  ? AppColors.calendarSelectedForeground
                                  : disabled
                                  ? scheme.outline
                                  : scheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      final DateTime now = DateTime.now();
                      if (now.isBefore(widget.firstDate) ||
                          now.isAfter(widget.lastDate)) {
                        return;
                      }
                      setState(() {
                        _selectedDate = now;
                        _displayMonth = DateTime(now.year, now.month, 1);
                      });
                    },
                    child: const Text('今天'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.calendarAccent,
                      foregroundColor: AppColors.calendarSelectedForeground,
                    ),
                    onPressed: () => Navigator.of(context).pop(_selectedDate),
                    child: const Text('确定'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _YearMonthPickerSheet extends StatefulWidget {
  const _YearMonthPickerSheet({required this.initialMonth});

  final DateTime initialMonth;

  @override
  State<_YearMonthPickerSheet> createState() => _YearMonthPickerSheetState();
}

class _YearMonthPickerSheetState extends State<_YearMonthPickerSheet> {
  static const int _minYear = 1970;
  static const int _maxYear = 2100;
  late int _year;
  late int _month;
  late final FixedExtentScrollController _yearController;
  late final FixedExtentScrollController _monthController;

  @override
  void initState() {
    super.initState();
    _year = widget.initialMonth.year.clamp(_minYear, _maxYear);
    _month = widget.initialMonth.month;
    _yearController = FixedExtentScrollController(
      initialItem: _year - _minYear,
    );
    _monthController = FixedExtentScrollController(initialItem: _month - 1);
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              '快速切换年月',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Container(
              height: 210,
              decoration: BoxDecoration(
                color: AppColors.calendarAccent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: _yearController,
                      itemExtent: 44,
                      magnification: 1.08,
                      useMagnifier: true,
                      onSelectedItemChanged: (int index) {
                        setState(() => _year = _minYear + index);
                      },
                      children: <Widget>[
                        for (int y = _minYear; y <= _maxYear; y++)
                          Center(child: Text('$y年')),
                      ],
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: _monthController,
                      itemExtent: 44,
                      magnification: 1.08,
                      useMagnifier: true,
                      onSelectedItemChanged: (int index) {
                        setState(() => _month = index + 1);
                      },
                      children: <Widget>[
                        for (int m = 1; m <= 12; m++)
                          Center(child: Text('$m月')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.calendarAccent,
                      foregroundColor: AppColors.calendarSelectedForeground,
                    ),
                    onPressed: () =>
                        Navigator.of(context).pop(DateTime(_year, _month, 1)),
                    child: const Text('切换'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
