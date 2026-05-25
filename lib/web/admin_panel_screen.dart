import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/admin_service.dart';
import '../utils/app_error_messages.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  bool _isBusy = false;
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _sortBy = 'Joined Date (Newest)';
  late final TextEditingController _searchController;

  String? _tokenUid;
  Future<IdTokenResult>? _tokenFuture;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  Future<IdTokenResult> _getAdminToken(User user) {
    if (_tokenUid != user.uid || _tokenFuture == null) {
      _tokenUid = user.uid;
      _tokenFuture = user
          .getIdTokenResult(true)
          .timeout(const Duration(seconds: 12));
    }
    return _tokenFuture!;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showCreateDialog() async {
    final _AdminUserDraft? draft = await showDialog<_AdminUserDraft>(
      context: context,
      builder: (context) => const _AdminUserDialog(),
    );
    if (draft == null) {
      return;
    }
    await _runAdminAction(() {
      return AdminService.instance.createUserProfile(
        uid: draft.uid,
        displayName: draft.displayName,
        email: draft.email,
        disabled: draft.disabled,
      );
    }, successMessage: 'User profile created.');
  }

  Future<void> _showEditDialog(AdminUserProfile user) async {
    final _AdminUserDraft? draft = await showDialog<_AdminUserDraft>(
      context: context,
      builder: (context) => _AdminUserDialog(existing: user),
    );
    if (draft == null) {
      return;
    }
    await _runAdminAction(() {
      return AdminService.instance.updateUserProfile(
        uid: user.uid,
        displayName: draft.displayName,
        email: draft.email,
        disabled: draft.disabled,
      );
    }, successMessage: 'User profile updated.');
  }

  Future<void> _confirmDelete(AdminUserProfile user) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete user profile?'),
        content: Text(
          'This removes the Firestore profile for ${user.email.isEmpty ? user.uid : user.email}. It does not delete the Firebase Authentication account.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _runAdminAction(() {
      return AdminService.instance.deleteUserProfile(uid: user.uid);
    }, successMessage: 'User profile deleted.');
  }

  Future<void> _toggleDisabled(AdminUserProfile user, bool value) async {
    await _runAdminAction(() {
      return AdminService.instance.setUserDisabled(
        uid: user.uid,
        disabled: value,
      );
    });
  }

  Future<void> _runAdminAction(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    if (_isBusy) {
      return;
    }
    setState(() {
      _isBusy = true;
    });
    try {
      await action();
      if (!mounted || successMessage == null) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      debugPrint('Admin action failed: $error');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyAdminError(error))));
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required MaterialColor color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.08)),
      ),
      color: isDark
          ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
          : colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isDark ? color.shade300 : color.shade700,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid({
    required BuildContext context,
    required BoxConstraints constraints,
    required int total,
    required int active,
    required int disabled,
    required int active24h,
  }) {
    final width = constraints.maxWidth;
    int crossAxisCount = 4;
    double childAspectRatio = 2.4;

    if (width < 600) {
      crossAxisCount = 1;
      childAspectRatio = 4.2;
    } else if (width < 1100) {
      crossAxisCount = 2;
      childAspectRatio = 2.8;
    }

    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: childAspectRatio,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          context: context,
          title: 'Total Users',
          value: total.toString(),
          icon: Icons.people_alt_rounded,
          color: Colors.blue,
        ),
        _buildStatCard(
          context: context,
          title: 'Active Accounts',
          value: active.toString(),
          icon: Icons.check_circle_rounded,
          color: Colors.green,
        ),
        _buildStatCard(
          context: context,
          title: 'Disabled Accounts',
          value: disabled.toString(),
          icon: Icons.block_rounded,
          color: Colors.red,
        ),
        _buildStatCard(
          context: context,
          title: 'Active (24h)',
          value: active24h.toString(),
          icon: Icons.offline_bolt_rounded,
          color: Colors.amber,
        ),
      ],
    );
  }

  Widget _buildSearchAndFiltersCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.08)),
      ),
      color: isDark
          ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.15)
          : colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune_rounded, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Filters & Search',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 700;

                final searchField = TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by display name, email, or UID...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                );

                final statusFilterWidget = Row(
                  children: [
                    Text(
                      'Status:  ',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: ['All', 'Active', 'Disabled'].map((status) {
                        final isSelected = _statusFilter == status;
                        return ChoiceChip(
                          label: Text(status),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _statusFilter = status;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                );

                final sortWidget = Row(
                  children: [
                    Text(
                      'Sort by:  ',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _sortBy,
                          icon: const Icon(Icons.arrow_drop_down_rounded),
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _sortBy = newValue;
                              });
                            }
                          },
                          items:
                              <String>[
                                'Joined Date (Newest)',
                                'Joined Date (Oldest)',
                                'Name (A-Z)',
                                'Name (Z-A)',
                                'Last Active',
                              ].map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                        ),
                      ),
                    ),
                  ],
                );

                if (isWide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      searchField,
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [statusFilterWidget, sortWidget],
                      ),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      searchField,
                      const SizedBox(height: 16),
                      statusFilterWidget,
                      const SizedBox(height: 12),
                      sortWidget,
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 72,
                color: colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Users Found',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search query or status filter to find users.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                  _statusFilter = 'All';
                });
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reset Filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.1)),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'User Info',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              'Email / UID',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Status',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Created At',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Last Active',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            width: 140,
            child: Text(
              'Actions',
              style: TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserRow(BuildContext context, AdminUserProfile user) {
    final colorScheme = Theme.of(context).colorScheme;
    final formatter = DateFormat('MMM d, yyyy hh:mm a');
    final createdStr = user.createdAt != null
        ? formatter.format(user.createdAt!)
        : 'N/A';
    final activeStr = user.lastSeen != null
        ? formatter.format(user.lastSeen!)
        : 'N/A';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.08),
          ),
          left: BorderSide(color: colorScheme.primary.withValues(alpha: 0.08)),
          right: BorderSide(color: colorScheme.primary.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          // User Info (Avatar + Name)
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                  foregroundColor: colorScheme.primary,
                  child: Text(
                    user.displayName.isEmpty
                        ? '?'
                        : user.displayName[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    user.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Email / UID
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.email.isEmpty ? 'No email' : user.email,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Row(
                  children: [
                    Text(
                      'UID: ${user.uid.length > 8 ? "${user.uid.substring(0, 8)}..." : user.uid}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Copy UID',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: user.uid));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('User UID copied to clipboard.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Status Badge
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: user.disabled
                      ? Colors.red.withValues(alpha: 0.1)
                      : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: user.disabled
                        ? Colors.red.withValues(alpha: 0.3)
                        : Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  user.disabled ? 'Disabled' : 'Active',
                  style: TextStyle(
                    color: user.disabled
                        ? Colors.red.shade700
                        : Colors.green.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          // Created At
          Expanded(
            flex: 3,
            child: Text(createdStr, style: const TextStyle(fontSize: 13)),
          ),
          // Last Active
          Expanded(
            flex: 3,
            child: Text(activeStr, style: const TextStyle(fontSize: 13)),
          ),
          // Actions
          SizedBox(
            width: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: _isBusy ? null : () => _showEditDialog(user),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit user profile',
                  color: colorScheme.primary,
                ),
                IconButton(
                  onPressed: _isBusy ? null : () => _confirmDelete(user),
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Delete user profile',
                  color: colorScheme.error,
                ),
                Switch(
                  value: !user.disabled,
                  onChanged: _isBusy
                      ? null
                      : (value) => _toggleDisabled(user, !value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, AdminUserProfile user) {
    final colorScheme = Theme.of(context).colorScheme;
    final formatter = DateFormat('MMM d, yyyy hh:mm a');
    final createdStr = user.createdAt != null
        ? formatter.format(user.createdAt!)
        : 'N/A';
    final activeStr = user.lastSeen != null
        ? formatter.format(user.lastSeen!)
        : 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                  foregroundColor: colorScheme.primary,
                  child: Text(
                    user.displayName.isEmpty
                        ? '?'
                        : user.displayName[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email.isEmpty ? 'No email' : user.email,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: user.disabled
                        ? Colors.red.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: user.disabled
                          ? Colors.red.withValues(alpha: 0.2)
                          : Colors.green.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    user.disabled ? 'Disabled' : 'Active',
                    style: TextStyle(
                      color: user.disabled
                          ? Colors.red.shade700
                          : Colors.green.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            _buildDetailRow(
              context,
              Icons.fingerprint_rounded,
              'UID',
              Row(
                children: [
                  Expanded(
                    child: Text(
                      user.uid,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Copy UID',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: user.uid));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('User UID copied to clipboard.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              context,
              Icons.calendar_today_rounded,
              'Created',
              Text(createdStr, style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              context,
              Icons.schedule_rounded,
              'Last Active',
              Text(activeStr, style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Account Active',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: !user.disabled,
                      onChanged: _isBusy
                          ? null
                          : (value) => _toggleDisabled(user, !value),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _isBusy ? null : () => _showEditDialog(user),
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit user profile',
                      color: colorScheme.primary,
                    ),
                    IconButton(
                      onPressed: _isBusy ? null : () => _confirmDelete(user),
                      icon: const Icon(Icons.delete_outline_rounded),
                      tooltip: 'Delete user profile',
                      color: colorScheme.error,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    Widget valueWidget,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 16,
          color: colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: valueWidget),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const Scaffold(body: Center(child: Text('Admin is web only.')));
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.admin_panel_settings_rounded,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Text('Admin Panel'),
          ],
        ),
        actions: <Widget>[
          if (_isBusy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              onPressed: _isBusy ? null : _showCreateDialog,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              tooltip: 'Add user profile',
            ),
        ],
      ),
      body: FutureBuilder<IdTokenResult>(
        future: () {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            return null;
          }
          return _getAdminToken(user);
        }(),
        builder: (context, tokenSnapshot) {
          if (FirebaseAuth.instance.currentUser == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 40),
                    const SizedBox(height: 12),
                    const Text(
                      'Please sign in to access the admin panel.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pushReplacementNamed('/admin-login');
                      },
                      child: const Text('Go to admin login'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (tokenSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (tokenSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Admin access could not be verified. Please check your connection and try reloading.\n\n${tokenSnapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!tokenSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (tokenSnapshot.data?.claims?['admin'] != true) {
            return const Center(child: Text('Admin access required.'));
          }

          return StreamBuilder<List<AdminUserProfile>>(
            stream: AdminService.instance.watchUsers(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Admin access is unavailable. Confirm your account has the admin custom claim and Firestore rules are deployed.\n\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final users = snapshot.data!;

              // Calculate statistics
              final totalCount = users.length;
              final activeCount = users.where((u) => !u.disabled).length;
              final disabledCount = users.where((u) => u.disabled).length;

              final now = DateTime.now();
              final active24hCount = users.where((u) {
                if (u.lastSeen == null) return false;
                return now.difference(u.lastSeen!).inHours <= 24;
              }).length;

              // Apply filtering and sorting
              final query = _searchQuery.trim().toLowerCase();
              final filteredUsers = users.where((user) {
                final matchesSearch =
                    query.isEmpty ||
                    user.displayName.toLowerCase().contains(query) ||
                    user.email.toLowerCase().contains(query) ||
                    user.uid.toLowerCase().contains(query);

                final matchesStatus = switch (_statusFilter) {
                  'Active' => !user.disabled,
                  'Disabled' => user.disabled,
                  _ => true,
                };

                return matchesSearch && matchesStatus;
              }).toList();

              filteredUsers.sort((a, b) {
                if (_sortBy == 'Joined Date (Newest)') {
                  final aTime = a.createdAt ?? DateTime(0);
                  final bTime = b.createdAt ?? DateTime(0);
                  return bTime.compareTo(aTime);
                } else if (_sortBy == 'Joined Date (Oldest)') {
                  final aTime = a.createdAt ?? DateTime(0);
                  final bTime = b.createdAt ?? DateTime(0);
                  return aTime.compareTo(bTime);
                } else if (_sortBy == 'Name (A-Z)') {
                  return a.displayName.compareTo(b.displayName);
                } else if (_sortBy == 'Name (Z-A)') {
                  return b.displayName.compareTo(a.displayName);
                } else if (_sortBy == 'Last Active') {
                  final aTime = a.lastSeen ?? a.createdAt ?? DateTime(0);
                  final bTime = b.lastSeen ?? b.createdAt ?? DateTime(0);
                  return bTime.compareTo(aTime);
                }
                return 0;
              });

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;

                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      isWide ? 32 : 16,
                      16,
                      isWide ? 32 : 16,
                      40,
                    ),
                    children: <Widget>[
                      // Page title & subtitle
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'User Directory',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Create, update, disable, or remove Firestore user profiles from here.',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: colorScheme.onSurface.withValues(
                                          alpha: 0.65,
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          FilledButton.icon(
                            onPressed: _isBusy ? null : _showCreateDialog,
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: const Text('Add User'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // KPI Stats Grid
                      _buildStatsGrid(
                        context: context,
                        constraints: constraints,
                        total: totalCount,
                        active: activeCount,
                        disabled: disabledCount,
                        active24h: active24hCount,
                      ),
                      const SizedBox(height: 24),

                      // Search & Filter controls card
                      _buildSearchAndFiltersCard(context),
                      const SizedBox(height: 24),

                      // Users List / Table section
                      if (filteredUsers.isEmpty)
                        _buildEmptyState(context)
                      else if (isWide) ...[
                        // Table Layout
                        _buildTableHeader(context),
                        ...filteredUsers.map(
                          (user) => _buildUserRow(context, user),
                        ),
                      ] else ...[
                        // Cards Layout
                        ...filteredUsers.map(
                          (user) => _buildUserCard(context, user),
                        ),
                      ],
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _AdminUserDraft {
  const _AdminUserDraft({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.disabled,
  });

  final String uid;
  final String displayName;
  final String email;
  final bool disabled;
}

class _AdminUserDialog extends StatefulWidget {
  const _AdminUserDialog({this.existing});

  final AdminUserProfile? existing;

  @override
  State<_AdminUserDialog> createState() => _AdminUserDialogState();
}

class _AdminUserDialogState extends State<_AdminUserDialog> {
  late final TextEditingController _uidController;
  late final TextEditingController _displayNameController;
  late final TextEditingController _emailController;
  late bool _disabled;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _uidController = TextEditingController(text: widget.existing?.uid ?? '');
    _displayNameController = TextEditingController(
      text: widget.existing?.displayName ?? '',
    );
    _emailController = TextEditingController(
      text: widget.existing?.email ?? '',
    );
    _disabled = widget.existing?.disabled ?? false;
  }

  @override
  void dispose() {
    _uidController.dispose();
    _displayNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    final String uid = _uidController.text.trim();
    final String displayName = _displayNameController.text.trim();
    final String email = _emailController.text.trim();

    if (uid.isEmpty) {
      setState(() {
        _error = 'UID is required.';
      });
      return;
    }
    if (email.isEmpty) {
      setState(() {
        _error = 'Email is required.';
      });
      return;
    }

    Navigator.of(context).pop(
      _AdminUserDraft(
        uid: uid,
        displayName: displayName,
        email: email,
        disabled: _disabled,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _isEditing ? Icons.edit_rounded : Icons.person_add_rounded,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(_isEditing ? 'Edit User Profile' : 'Create User Profile'),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (!_isEditing) ...[
                Text(
                  'Enter the user details below. The UID must match the Firebase Authentication UID for the user.',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _uidController,
                readOnly: _isEditing,
                decoration: InputDecoration(
                  labelText: 'User ID (UID)',
                  hintText: 'Firebase Auth UID',
                  prefixIcon: const Icon(Icons.fingerprint_rounded),
                  filled: true,
                  fillColor: _isEditing
                      ? colorScheme.onSurface.withValues(alpha: 0.05)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  hintText: 'e.g., Jane Doe',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'e.g., jane.doe@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                  ),
                ),
                child: SwitchListTile(
                  value: !_disabled,
                  onChanged: (value) {
                    setState(() {
                      _disabled = !value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Status: Active',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: Text(
                    !_disabled
                        ? 'User can log in and access their data.'
                        : 'User is blocked from signing in.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: colorScheme.error,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: colorScheme.error,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEditing ? 'Save Changes' : 'Create Profile'),
        ),
      ],
    );
  }
}
