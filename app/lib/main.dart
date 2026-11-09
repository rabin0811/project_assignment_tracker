import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AssignmentDatabase.instance.database;
  runApp(const AssignmentTrackerApp());
}

final moneyFormat = NumberFormat.currency(
  locale: 'en_IN',
  symbol: 'NPR ',
  decimalDigits: 0,
);

String formatDate(DateTime? date) =>
    date == null ? 'Not set' : DateFormat('dd MMM yyyy').format(date);

enum WorkStatus { notStarted, inProgress, completed, onHold }

extension WorkStatusText on WorkStatus {
  String get label {
    switch (this) {
      case WorkStatus.notStarted:
        return 'Not started';
      case WorkStatus.inProgress:
        return 'In progress';
      case WorkStatus.completed:
        return 'Completed';
      case WorkStatus.onHold:
        return 'On hold';
    }
  }
}

class Assignment {
  final int? id;
  final String title;
  final String client;
  final DateTime? dateAdded;
  final DateTime? dueDate;
  final double totalFee;
  final double amountPaid;
  final String workStatus;
  final String notes;

  const Assignment({
    this.id,
    required this.title,
    required this.client,
    this.dateAdded,
    this.dueDate,
    required this.totalFee,
    required this.amountPaid,
    required this.workStatus,
    required this.notes,
  });

  double get balance => (totalFee - amountPaid).clamp(0, double.infinity);

  String get paymentStatus {
    if (totalFee <= 0) return 'Fee not set';
    if (balance <= 0) return 'Paid';
    if (amountPaid > 0) return 'Partially paid';
    return 'Pending';
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'client': client,
        'dateAdded': dateAdded?.millisecondsSinceEpoch,
        'dueDate': dueDate?.millisecondsSinceEpoch,
        'totalFee': totalFee,
        'amountPaid': amountPaid,
        'workStatus': workStatus,
        'notes': notes,
      };

  factory Assignment.fromMap(Map<String, Object?> map) => Assignment(
        id: map['id'] as int?,
        title: map['title'] as String,
        client: (map['client'] as String?) ?? '',
        dateAdded: map['dateAdded'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['dateAdded'] as int),
        dueDate: map['dueDate'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['dueDate'] as int),
        totalFee: (map['totalFee'] as num).toDouble(),
        amountPaid: (map['amountPaid'] as num).toDouble(),
        workStatus: map['workStatus'] as String,
        notes: (map['notes'] as String?) ?? '',
      );
}

class AssignmentDatabase {
  AssignmentDatabase._();
  static final AssignmentDatabase instance = AssignmentDatabase._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'assignment_tracker.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE assignments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            client TEXT NOT NULL DEFAULT '',
            dateAdded INTEGER,
            dueDate INTEGER,
            totalFee REAL NOT NULL DEFAULT 0,
            amountPaid REAL NOT NULL DEFAULT 0,
            workStatus TEXT NOT NULL DEFAULT 'Not started',
            notes TEXT NOT NULL DEFAULT ''
          )
        ''');
      },
    );
    return _db!;
  }

  Future<List<Assignment>> getAll() async {
    final db = await database;
    final rows = await db.query('assignments', orderBy: 'dueDate IS NULL, dueDate ASC, id DESC');
    return rows.map(Assignment.fromMap).toList();
  }

  Future<int> insert(Assignment assignment) async {
    final db = await database;
    return db.insert('assignments', assignment.toMap()..remove('id'));
  }

  Future<int> update(Assignment assignment) async {
    final db = await database;
    return db.update(
      'assignments',
      assignment.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [assignment.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await database;
    return db.delete('assignments', where: 'id = ?', whereArgs: [id]);
  }
}

class AssignmentTrackerApp extends StatelessWidget {
  const AssignmentTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF2457C5));
    return MaterialApp(
      title: 'Assignment Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F7FB),
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: Color(0xFF17233D),
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDDE3EE)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDDE3EE)),
          ),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Assignment> assignments = [];
  bool loading = true;
  String filter = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await AssignmentDatabase.instance.getAll();
    if (!mounted) return;
    setState(() {
      assignments = items;
      loading = false;
    });
  }

  double get totalFees => assignments.fold(0, (sum, a) => sum + a.totalFee);
  double get totalPaid => assignments.fold(0, (sum, a) => sum + a.amountPaid);
  double get totalBalance => assignments.fold(0, (sum, a) => sum + a.balance);

  List<Assignment> get visibleAssignments {
    if (filter == 'All') return assignments;
    if (filter == 'Paid') return assignments.where((a) => a.paymentStatus == 'Paid').toList();
    if (filter == 'Pending') {
      return assignments.where((a) => a.paymentStatus == 'Pending' || a.paymentStatus == 'Partially paid').toList();
    }
    return assignments.where((a) => a.workStatus == filter).toList();
  }

  Future<void> _openForm([Assignment? assignment]) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AssignmentFormScreen(assignment: assignment)),
    );
    if (result == true) _load();
  }

  Future<void> _delete(Assignment assignment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete assignment?'),
        content: Text('Delete "${assignment.title}" permanently from this phone?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && assignment.id != null) {
      await AssignmentDatabase.instance.delete(assignment.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignment Tracker'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add assignment'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                children: [
                  const Text('Your work, organised.', style: TextStyle(fontSize: 15, color: Color(0xFF69758B))),
                  const SizedBox(height: 16),
                  _SummaryCard(
                    title: 'Outstanding balance',
                    amount: moneyFormat.format(totalBalance),
                    subtitle: '${assignments.where((a) => a.balance > 0).length} assignment(s) with money due',
                    icon: Icons.account_balance_wallet_rounded,
                    color: const Color(0xFF2457C5),
                    prominent: true,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          title: 'Total expected',
                          amount: moneyFormat.format(totalFees),
                          icon: Icons.payments_outlined,
                          color: const Color(0xFF6D55C7),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Received',
                          amount: moneyFormat.format(totalPaid),
                          icon: Icons.check_circle_outline_rounded,
                          color: const Color(0xFF16845B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Assignments', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF17233D))),
                      ),
                      Text('${assignments.length} total', style: const TextStyle(color: Color(0xFF69758B))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: ['All', 'Pending', 'Paid', 'In progress', 'Completed', 'Not started', 'On hold'].map((item) {
                        final selected = filter == item;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(item),
                            selected: selected,
                            onSelected: (_) => setState(() => filter = item),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (visibleAssignments.isEmpty)
                    _EmptyState(onAdd: () => _openForm())
                  else
                    ...visibleAssignments.map((a) => _AssignmentCard(
                          assignment: a,
                          onTap: () => _openForm(a),
                          onDelete: () => _delete(a),
                        )),
                ],
              ),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String amount;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final bool prominent;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    this.subtitle,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(prominent ? 20 : 16),
      decoration: BoxDecoration(
        color: prominent ? color : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: prominent ? null : Border.all(color: const Color(0xFFE7EBF3)),
        boxShadow: prominent
            ? [BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 20, offset: const Offset(0, 8))]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: prominent ? Colors.white : color, size: 21),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: prominent ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF69758B), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: TextStyle(color: prominent ? Colors.white : const Color(0xFF17233D), fontSize: prominent ? 28 : 19, fontWeight: FontWeight.w800),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 7),
            Text(subtitle!, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final Assignment assignment;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AssignmentCard({required this.assignment, required this.onTap, required this.onDelete});

  Color get statusColor {
    switch (assignment.paymentStatus) {
      case 'Paid':
        return const Color(0xFF16845B);
      case 'Partially paid':
        return const Color(0xFFB7791F);
      case 'Pending':
        return const Color(0xFFC2413B);
      default:
        return const Color(0xFF69758B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE7EBF3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: const Color(0xFFEAF0FF), borderRadius: BorderRadius.circular(13)),
                    child: const Icon(Icons.assignment_outlined, color: Color(0xFF2457C5)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(assignment.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF17233D))),
                        const SizedBox(height: 3),
                        Text(assignment.client.isEmpty ? 'Client / semester not set' : assignment.client,
                            style: const TextStyle(color: Color(0xFF69758B), fontSize: 12)),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') onTap();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _miniMetric('Fee', moneyFormat.format(assignment.totalFee))),
                  Expanded(child: _miniMetric('Paid', moneyFormat.format(assignment.amountPaid))),
                  Expanded(child: _miniMetric('Balance', moneyFormat.format(assignment.balance))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatusPill(label: assignment.paymentStatus, color: statusColor),
                  const SizedBox(width: 7),
                  _StatusPill(
                    label: assignment.workStatus,
                    color: assignment.workStatus == 'Completed' ? const Color(0xFF16845B) : const Color(0xFF52627A),
                  ),
                  const Spacer(),
                  if (assignment.dueDate != null)
                    Text('Due ${formatDate(assignment.dueDate)}', style: const TextStyle(fontSize: 11, color: Color(0xFF69758B))),
                ],
              ),
              if (assignment.notes.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(assignment.notes, style: const TextStyle(fontSize: 12, color: Color(0xFF69758B))),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniMetric(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF69758B), fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF17233D)),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      );
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(30)),
        child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE7EBF3))),
        child: Column(
          children: [
            const Icon(Icons.inbox_outlined, size: 42, color: Color(0xFF8B97AA)),
            const SizedBox(height: 12),
            const Text('No assignments here', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('Add your first assignment to start tracking fees and progress.', textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF69758B))),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add assignment')),
          ],
        ),
      );
}

class AssignmentFormScreen extends StatefulWidget {
  final Assignment? assignment;
  const AssignmentFormScreen({super.key, this.assignment});

  @override
  State<AssignmentFormScreen> createState() => _AssignmentFormScreenState();
}

class _AssignmentFormScreenState extends State<AssignmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _client;
  late final TextEditingController _fee;
  late final TextEditingController _paid;
  late final TextEditingController _notes;
  DateTime? _dateAdded;
  DateTime? _dueDate;
  String _workStatus = 'Not started';
  bool _saving = false;

  bool get isEditing => widget.assignment != null;

  @override
  void initState() {
    super.initState();
    final a = widget.assignment;
    _title = TextEditingController(text: a?.title ?? '');
    _client = TextEditingController(text: a?.client ?? '');
    _fee = TextEditingController(text: a == null || a.totalFee == 0 ? '' : a.totalFee.toStringAsFixed(0));
    _paid = TextEditingController(text: a == null || a.amountPaid == 0 ? '0' : a.amountPaid.toStringAsFixed(0));
    _notes = TextEditingController(text: a?.notes ?? '');
    _dateAdded = a?.dateAdded ?? DateTime.now();
    _dueDate = a?.dueDate;
    _workStatus = a?.workStatus ?? 'Not started';
  }

  @override
  void dispose() {
    _title.dispose();
    _client.dispose();
    _fee.dispose();
    _paid.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool due}) async {
    final initial = due ? (_dueDate ?? DateTime.now()) : (_dateAdded ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: due ? 'Choose due date' : 'Choose date added',
    );
    if (picked != null) {
      setState(() {
        if (due) {
          _dueDate = picked;
        } else {
          _dateAdded = picked;
        }
      });
    }
  }

  String? _validateMoney(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required. Enter 0 if unknown.';
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed < 0) return 'Enter a valid non-negative amount.';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final fee = double.parse(_fee.text.trim());
    final paid = double.parse(_paid.text.trim());
    if (paid > fee && fee > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount paid cannot be greater than the total fee.')),
      );
      return;
    }
    setState(() => _saving = true);
    final old = widget.assignment;
    final assignment = Assignment(
      id: old?.id,
      title: _title.text.trim(),
      client: _client.text.trim(),
      dateAdded: _dateAdded,
      dueDate: _dueDate,
      totalFee: fee,
      amountPaid: paid,
      workStatus: _workStatus,
      notes: _notes.text.trim(),
    );
    if (isEditing) {
      await AssignmentDatabase.instance.update(assignment);
    } else {
      await AssignmentDatabase.instance.insert(assignment);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit assignment' : 'New assignment')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            const Text('Assignment details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 14),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Assignment name *', hintText: 'e.g. Cloud Computing'),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => v == null || v.trim().isEmpty ? 'Enter an assignment name.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _client,
              decoration: const InputDecoration(labelText: 'Semester / client', hintText: 'e.g. 4th semester or Dhiraj'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _DateButton(label: 'Date added', value: formatDate(_dateAdded), onTap: () => _pickDate(due: false))),
                const SizedBox(width: 10),
                Expanded(child: _DateButton(label: 'Due date', value: formatDate(_dueDate), onTap: () => _pickDate(due: true))),
              ],
            ),
            const SizedBox(height: 22),
            const Text('Payment details (NPR)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _fee,
                    decoration: const InputDecoration(labelText: 'Total fee *', prefixText: 'NPR '),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => _validateMoney(v, 'Total fee'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _paid,
                    decoration: const InputDecoration(labelText: 'Amount paid *', prefixText: 'NPR '),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => _validateMoney(v, 'Amount paid'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Enter the amount you have actually received so far. The remaining balance is calculated automatically.',
                style: TextStyle(fontSize: 12, color: Color(0xFF69758B))),
            const SizedBox(height: 22),
            const Text('Work progress', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _workStatus,
              decoration: const InputDecoration(labelText: 'Work status'),
              items: WorkStatus.values.map((s) => DropdownMenuItem(value: s.label, child: Text(s.label))).toList(),
              onChanged: (value) => setState(() => _workStatus = value ?? 'Not started'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes / payment remarks', hintText: 'e.g. NPR 5,000 paid; rest due next week'),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Saving...' : (isEditing ? 'Save changes' : 'Save assignment')),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _DateButton({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_month_rounded)),
          child: Text(value, style: const TextStyle(fontSize: 12)),
        ),
      );
}
