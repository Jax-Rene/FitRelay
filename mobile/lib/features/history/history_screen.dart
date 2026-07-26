import 'package:flutter/material.dart';

import '../../models/workout_record.dart';
import '../../theme/app_theme.dart';
import '../summary/summary_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.records});

  final List<WorkoutRecord> records;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('训练历史')),
    body: records.isEmpty
        ? const Center(
            child: Text(
              '完成第一次训练后，记录会出现在这里。',
              style: TextStyle(color: AppColors.muted),
            ),
          )
        : ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            itemCount: records.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final record = records[index];
              return ListTile(
                tileColor: AppColors.panel,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.line),
                ),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF25321C),
                  foregroundColor: AppColors.lime,
                  child: Text('${record.completedAt.day}'),
                ),
                title: Text(
                  '${record.completedAt.month} 月 ${record.completedAt.day} 日训练',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${_durationLabel(record.durationSeconds)} · ${record.completedSets} 个有效组',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => SummaryScreen.fromRecord(record),
                  ),
                ),
              );
            },
          ),
  );
}

String _durationLabel(int seconds) {
  if (seconds < 60) return '不足 1 分钟';
  return '${seconds ~/ 60} 分钟';
}
