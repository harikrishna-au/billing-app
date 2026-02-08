import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme/app_colors.dart';
import '../../../data/models/machine_model.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../providers/machine_provider.dart';

class MachineSelectionScreen extends ConsumerStatefulWidget {
  const MachineSelectionScreen({super.key});

  @override
  ConsumerState<MachineSelectionScreen> createState() =>
      _MachineSelectionScreenState();
}

class _MachineSelectionScreenState
    extends ConsumerState<MachineSelectionScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final machineState = ref.watch(machineProvider);
    final filteredMachines = machineState.machines
        .where((m) =>
            m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            m.location.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Select Machine',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                style: GoogleFonts.inter(
                    fontSize: 15, color: const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Search machines...',
                  hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                  border: InputBorder.none,
                  prefixIcon:
                      const Icon(Icons.search, color: Color(0xFF94A3B8)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          // Machine List
          Expanded(
            child: machineState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredMachines.isEmpty
                    ? Center(
                        child: Text(
                          'No machines found',
                          style:
                              GoogleFonts.inter(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: filteredMachines.length,
                        itemBuilder: (context, index) {
                          final machine = filteredMachines[index];
                          return _MachineCard(
                            machine: machine,
                            onTap: () {
                              ref
                                  .read(machineProvider.notifier)
                                  .selectMachine(machine);
                              context.go('/new');
                            },
                          )
                              .animate()
                              .fadeIn(duration: 300.ms, delay: (index * 50).ms)
                              .slideY(begin: 0.1, end: 0);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _MachineCard extends StatelessWidget {
  final Machine machine;
  final VoidCallback onTap;

  const _MachineCard({
    required this.machine,
    required this.onTap,
  });

  Color _getStatusColor() {
    switch (machine.status) {
      case MachineStatus.online:
        return Colors.green;
      case MachineStatus.offline:
        return Colors.red;
      case MachineStatus.maintenance:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon() {
    switch (machine.status) {
      case MachineStatus.online:
        return Icons.check_circle;
      case MachineStatus.offline:
        return Icons.cancel;
      case MachineStatus.maintenance:
        return Icons.build_circle;
    }
  }

  String _getLastSyncText() {
    if (machine.lastSync == null) return 'Never';
    final diff = DateTime.now().difference(machine.lastSync!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.point_of_sale_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            machine.name,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                machine.location,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(),
                            size: 14,
                            color: _getStatusColor(),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            machine.statusDisplay,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Today\'s Collection',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.format(machine.totalCollection),
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: const Color(0xFFE2E8F0),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Last Sync',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getLastSyncText(),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
