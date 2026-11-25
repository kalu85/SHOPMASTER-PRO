import 'package:flutter/material.dart';

import '../../core/data/report_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';

/// Live profit snapshots for today, this month, and this year.
class ProfitOverviewCard extends StatefulWidget {
  const ProfitOverviewCard({super.key});

  @override
  State<ProfitOverviewCard> createState() => _ProfitOverviewCardState();
}

class _ProfitOverviewCardState extends State<ProfitOverviewCard> {
  bool _loading = true;
  String? _error;
  final Map<String, double> _gross = {};
  final Map<String, double> _net = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final today = isoDateFmt.format(now);
    final periods = <String, List<String>>{
      'Today': [today, today],
      'This month': [
        isoDateFmt.format(DateTime(now.year, now.month, 1)),
        today,
      ],
      'This year': [
        isoDateFmt.format(DateTime(now.year, 1, 1)),
        today,
      ],
    };
    try {
      for (final entry in periods.entries) {
        final report = await ReportRepository.instance.build(
          ReportType.profitLoss,
          from: entry.value[0],
          to: entry.value[1],
        );
        final gross = report.rows.length > 2
            ? double.tryParse(report.rows[2][1]) ?? 0
            : 0.0;
        final net = report.rows.length > 4
            ? double.tryParse(report.rows[4][1]) ?? 0
            : 0.0;
        _gross[entry.key] = gross;
        _net[entry.key] = net;
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() {
        _error = 'Profit data is unavailable';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights_rounded, color: AppColors.reports),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Profit Dashboard',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh profit',
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                      _gross.clear();
                      _net.clear();
                    });
                    _load();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Gross and net profit after recorded expenses',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            if (_loading)
              const LinearProgressIndicator()
            else if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.textMuted))
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 520;
                  final width = compact
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 24) / 3;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final label in const ['Today', 'This month', 'This year'])
                        SizedBox(
                          width: width,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.lightBlue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(label,
                                    style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                Text(
                                  inr.format(_net[label] ?? 0),
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: (_net[label] ?? 0) < 0
                                        ? AppColors.reports
                                        : AppColors.sales,
                                  ),
                                ),
                                const Text('Net profit',
                                    style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11)),
                                const SizedBox(height: 6),
                                Text('Gross: ${inr.format(_gross[label] ?? 0)}',
                                    style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
