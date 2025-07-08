import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:collection';
import 'package:flutter/services.dart';

void main() => runApp(
  MaterialApp(
    home: SeatScreen(),
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      primarySwatch: Colors.blue,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    ),
  ),
);

// ===================== Struktur Data =====================

class SeatArray {
  final List<bool> seats;
  SeatArray(int size) : seats = List.filled(size, false);

  bool isAvailable(int n) => !seats[n - 1];
  void occupy(int n) => seats[n - 1] = true;
  void free(int n) => seats[n - 1] = false;

  int get available => seats.where((s) => !s).length;
  int get occupied => seats.where((s) => s).length;
}

class StudentSession {
  final String nim;
  final int seat;
  final DateTime entryTime;
  DateTime? exitTime;

  StudentSession(this.nim, this.seat) : entryTime = DateTime.now();

  void exit() {
    exitTime = DateTime.now();
  }

  bool get isActive => exitTime == null;
  String get formattedEntryTime => entryTime.toString().substring(0, 19);
  String get formattedExitTime =>
      exitTime?.toString().substring(0, 19) ?? 'Belum keluar';
}

class AssignmentNode {
  final String nim;
  final int seat;
  final DateTime time;
  AssignmentNode? next;

  AssignmentNode(this.nim, this.seat) : time = DateTime.now();
}

class AssignmentHistory {
  AssignmentNode? head;
  int count = 0;

  void add(String nim, int seat) {
    head = AssignmentNode(nim, seat)..next = head;
    count++;
  }

  AssignmentNode? undo() {
    if (head == null) return null;
    final removed = head;
    head = head!.next;
    count--;
    return removed;
  }

  List<AssignmentNode> all() {
    List<AssignmentNode> list = [];
    for (var n = head; n != null; n = n.next) list.add(n);
    return list;
  }
}

class WaitingStudent {
  final String nim;
  final DateTime joinTime;

  WaitingStudent(this.nim) : joinTime = DateTime.now();

  String get formattedJoinTime => joinTime.toString().substring(0, 19);
}

class WaitingQueue {
  final _q = Queue<WaitingStudent>();

  void add(String nim) {
    if (!_q.any((student) => student.nim == nim)) {
      _q.add(WaitingStudent(nim));
    }
  }

  WaitingStudent? next() => _q.isNotEmpty ? _q.removeFirst() : null;

  List<WaitingStudent> get all => _q.toList();
  int get length => _q.length;
  void clear() => _q.clear();

  void removeByNIM(String nim) {
    _q.removeWhere((student) => student.nim == nim);
  }
}

class SeatNode {
  final int seat;
  String? nim;
  bool occupied = false;
  DateTime? occupiedTime;
  SeatNode? left, right;

  SeatNode(this.seat);

  void assignTo(String studentNim) {
    nim = studentNim;
    occupied = true;
    occupiedTime = DateTime.now();
  }

  void free() {
    nim = null;
    occupied = false;
    occupiedTime = null;
  }
}

class SeatBST {
  SeatNode? root;

  void insert(int seat) => root = _insert(root, seat);

  SeatNode _insert(SeatNode? node, int seat) {
    if (node == null) return SeatNode(seat);
    if (seat < node.seat) {
      node.left = _insert(node.left, seat);
    } else if (seat > node.seat) {
      node.right = _insert(node.right, seat);
    }
    return node;
  }

  SeatNode? search(int seat) => _search(root, seat);

  SeatNode? _search(SeatNode? node, int seat) {
    if (node == null || node.seat == seat) return node;
    return seat < node.seat
        ? _search(node.left, seat)
        : _search(node.right, seat);
  }

  List<int> available() {
    List<int> out = [];
    void walk(SeatNode? n) {
      if (n != null) {
        walk(n.left);
        if (!n.occupied) out.add(n.seat);
        walk(n.right);
      }
    }

    walk(root);
    return out;
  }
}

class SeatSearcher {
  static int? nearest(List<int> seats, int target) {
    int? res;
    int minDiff = 1 << 30;
    for (var s in seats) {
      int d = (s - target).abs();
      if (d < minDiff) {
        minDiff = d;
        res = s;
      }
    }
    return res;
  }
}

class AssignmentResult {
  final bool success;
  final String message;
  final int? seat;
  final bool isWaiting;

  AssignmentResult(
    this.success,
    this.message, {
    this.seat,
    this.isWaiting = false,
  });
}

class SeatStatistics {
  final int total, occupied, available, waiting, history;
  final double averageWaitingTime;
  final List<StudentSession> activeSessions;

  SeatStatistics(
    this.total,
    this.occupied,
    this.available,
    this.waiting,
    this.history,
    this.averageWaitingTime,
    this.activeSessions,
  );
}

class WaitingListAssignment {
  final String nim;
  final int seat;
  final DateTime assignedTime;
  final DateTime originalWaitingTime;

  WaitingListAssignment(
    this.nim,
    this.seat,
    this.assignedTime,
    this.originalWaitingTime,
  );

  String get formattedAssignedTime => assignedTime.toString().substring(0, 19);
  String get formattedWaitingTime =>
      originalWaitingTime.toString().substring(0, 19);
}

class EnhancedSeatManager {
  int total;
  late SeatArray array;
  late SeatBST bst;
  final WaitingQueue queue = WaitingQueue();
  late AssignmentHistory history;
  final Map<String, int> assigned = {};
  final Map<String, StudentSession> sessions = {};
  final List<StudentSession> completedSessions = [];
  final List<WaitingListAssignment> waitingListAssignments = [];

  EnhancedSeatManager(this.total) {
    reset();
  }

  AssignmentResult assign(String nim, {int? pref}) {
    if (assigned.containsKey(nim)) {
      return AssignmentResult(
        false,
        'NIM $nim sudah mendapat kursi ${assigned[nim]}',
        seat: assigned[nim],
      );
    }

    queue.removeByNIM(nim);

    if (array.available == 0) {
      queue.add(nim);
      return AssignmentResult(
        false,
        'Kursi penuh. Ditambahkan ke waiting list.',
        isWaiting: true,
      );
    }

    List<int> free = bst.available();
    int seat = (pref != null && array.isAvailable(pref))
        ? pref
        : (SeatSearcher.nearest(free, 1) ??
              free[Random().nextInt(free.length)]);

    array.occupy(seat);
    assigned[nim] = seat;
    history.add(nim, seat);

    var node = bst.search(seat);
    if (node != null) {
      node.assignTo(nim);
    }

    sessions[nim] = StudentSession(nim, seat);

    return AssignmentResult(true, 'NIM $nim mendapat kursi $seat', seat: seat);
  }

  void assignWaitingList() {
    final waitingStudents = queue.all.toList();
    List<WaitingListAssignment> newAssignments = [];

    for (var student in waitingStudents) {
      if (array.available > 0) {
        final res = assign(student.nim);
        if (res.success) {
          newAssignments.add(
            WaitingListAssignment(
              student.nim,
              res.seat!,
              DateTime.now(),
              student.joinTime,
            ),
          );
          queue.removeByNIM(student.nim);
        }
      } else {
        break;
      }
    }

    waitingListAssignments.addAll(newAssignments);
  }

  bool removeByNIM(String nim) {
    if (!assigned.containsKey(nim)) return false;

    int seat = assigned[nim]!;
    assigned.remove(nim);
    array.free(seat);

    var node = bst.search(seat);
    if (node != null) {
      node.free();
    }

    if (sessions.containsKey(nim)) {
      sessions[nim]!.exit();
      completedSessions.add(sessions[nim]!);
      sessions.remove(nim);
    }

    assignWaitingList();

    return true;
  }

  SeatStatistics stats() {
    return SeatStatistics(
      total,
      array.occupied,
      array.available,
      queue.length,
      history.count,
      0.0,
      sessions.values.toList(),
    );
  }

  void reset() {
    for (var session in sessions.values) {
      session.exit();
      completedSessions.add(session);
    }

    array = SeatArray(total);
    bst = SeatBST();
    history = AssignmentHistory();
    for (int i = 1; i <= total; i++) {
      bst.insert(i);
    }
    assigned.clear();
    sessions.clear();
  }

  void clearAll() {
    assigned.clear();
    sessions.clear();
    completedSessions.clear();
    waitingListAssignments.clear();
    history = AssignmentHistory();
    queue.clear();
    array = SeatArray(total);
    bst = SeatBST();
    for (int i = 1; i <= total; i++) {
      bst.insert(i);
    }
  }

  void addSeat() {
    total++;
    bst.insert(total);
    array = SeatArray(total);
    for (var seat in assigned.values) {
      array.occupy(seat);
      var node = bst.search(seat);
      if (node != null) node.occupied = true;
    }

    assignWaitingList();
  }

  bool undoLastAssignment() {
    final last = history.undo();
    if (last == null) return false;

    assigned.remove(last.nim);
    array.free(last.seat);
    final node = bst.search(last.seat);
    if (node != null) {
      node.free();
    }

    if (sessions.containsKey(last.nim)) {
      sessions.remove(last.nim);
    }

    return true;
  }

  int assignWaitingListManually() {
    final waitingStudents = queue.all.toList();
    int assignedCount = 0;

    for (var student in waitingStudents) {
      if (array.available > 0) {
        final res = assign(student.nim);
        if (res.success) {
          waitingListAssignments.add(
            WaitingListAssignment(
              student.nim,
              res.seat!,
              DateTime.now(),
              student.joinTime,
            ),
          );
          queue.removeByNIM(student.nim);
          assignedCount++;
        }
      } else {
        break;
      }
    }

    return assignedCount;
  }

  WaitingQueue get waitingList => queue;
  List<StudentSession> get activeStudents => sessions.values.toList();
  List<StudentSession> get completedStudents => completedSessions;
  List<WaitingListAssignment> get waitingAssignments => waitingListAssignments;
}

// ===================== UI =====================

class SeatScreen extends StatefulWidget {
  const SeatScreen({super.key});

  @override
  State<SeatScreen> createState() => _SeatScreenState();
}

class _SeatScreenState extends State<SeatScreen> with TickerProviderStateMixin {
  final _nim = TextEditingController();
  final _manager = EnhancedSeatManager(3);
  String _msg = '';
  late AnimationController _messageController;
  late Animation<double> _messageAnimation;

  @override
  void initState() {
    super.initState();
    _messageController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _messageAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _messageController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    setState(() => _msg = message);
    _messageController.forward().then((_) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _messageController.reverse();
      });
    });
  }

  void _assign() {
    final nim = _nim.text.trim();
    if (!RegExp(r'^24010110\d{3}$').hasMatch(nim)) {
      _showMessage('Format NIM salah. Harus: 24010110XXX');
      return;
    }
    final result = _manager.assign(nim);
    _showMessage(result.message);
    if (result.success) _nim.clear();
  }

  void _exit() {
    final nim = _nim.text.trim();
    if (nim.isEmpty) {
      _showMessage('Masukkan NIM untuk keluar.');
      return;
    }

    final success = _manager.removeByNIM(nim);
    _showMessage(
      success ? 'NIM $nim berhasil keluar.' : 'NIM $nim tidak ditemukan.',
    );
    if (success) _nim.clear();
  }

  void _clearAll() {
    setState(() {
      _manager.clearAll();
      _showMessage('Semua data telah dihapus.');
    });
  }

  void _undo() {
    setState(() {
      final success = _manager.undoLastAssignment();
      _showMessage(
        success ? 'Undo berhasil.' : 'Tidak ada data untuk di-undo.',
      );
    });
  }

  void _assignWaitingListManually() {
    setState(() {
      final assignedCount = _manager.assignWaitingListManually();
      _showMessage(
        assignedCount > 0
            ? 'Waiting list dimasukkan. $assignedCount mahasiswa mendapat kursi.'
            : 'Tidak ada kursi tersedia untuk waiting list.',
      );
    });
  }

  Widget _buildStatCard(String title, int value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeatGrid() {
    final s = _manager.stats();
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_seat, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                'Layout Kursi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: min(6, _manager.total),
              childAspectRatio: 1,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _manager.total,
            itemBuilder: (context, index) {
              final seatNumber = index + 1;
              final node = _manager.bst.search(seatNumber);
              final isOccupied = node?.occupied ?? false;

              return GestureDetector(
                onTap: () {
                  if (isOccupied && node?.nim != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Kursi $seatNumber: ${node!.nim}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isOccupied
                          ? [Colors.red[400]!, Colors.red[600]!]
                          : [Colors.green[400]!, Colors.green[600]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: isOccupied
                            ? Colors.red.withOpacity(0.3)
                            : Colors.green.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isOccupied ? Icons.person : Icons.event_seat,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$seatNumber',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.green[500],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('Tersedia', style: TextStyle(fontSize: 12)),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.red[500],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('Terisi', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _manager.stats();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.school,
                  color: Colors.blue[600],
                  size: 24,
                ), //tandain
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Kursi Acak Ujian',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _undo,
            tooltip: 'Undo',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {
              final waiting = _manager.waitingList.all;
              _manager.reset();
              for (final student in waiting) {
                _manager.waitingList.add(student.nim);
              }
              _showMessage(
                'Data di-reset. ${waiting.length} mahasiswa kembali ke waiting list.',
              );
            }),
            tooltip: 'Reset',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearAll,
            tooltip: 'Clear All',
          ),
          IconButton(
            icon: const Icon(Icons.add_circle),
            onPressed: () => setState(() {
              _manager.addSeat();
              _showMessage('1 kursi ditambahkan.');
            }),
            tooltip: 'Add Seat',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statistics Dashboard
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total',
                    s.total,
                    Icons.event_seat,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Terisi',
                    s.occupied,
                    Icons.person,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Tersedia',
                    s.available,
                    Icons.event_available,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Waiting',
                    s.waiting,
                    Icons.hourglass_top,
                    Colors.orange,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Seat Visual Layout
            _buildSeatGrid(),

            const SizedBox(height: 20),

            // Input Section
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _nim,
                    decoration: InputDecoration(
                      labelText: 'NIM Mahasiswa',
                      hintText: '24010110XXX',
                      prefixIcon: const Icon(Icons.badge, color: Colors.blue),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.blue,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _assign,
                          icon: const Icon(Icons.login),
                          label: const Text('Masuk'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _exit,
                          icon: const Icon(Icons.logout),
                          label: const Text('Keluar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_manager.waitingList.length > 0 &&
                      _manager.stats().available > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _assignWaitingListManually,
                          icon: const Icon(Icons.assignment_turned_in),
                          label: Text(
                            'Masukkan Waiting List (${_manager.waitingList.length})',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Message Display
            AnimatedBuilder(
              animation: _messageAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _messageAnimation.value,
                  child: Opacity(
                    opacity: _messageAnimation.value,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _msg,
                              style: TextStyle(
                                color: Colors.blue[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // Active Students Section
            if (_manager.activeStudents.isNotEmpty)
              _buildSection(
                'Mahasiswa Aktif (${_manager.activeStudents.length})',
                Icons.people,
                _manager.activeStudents
                    .map(
                      (session) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Text(
                            '${session.seat}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text('NIM: ${session.nim}'),
                        subtitle: Text('Masuk: ${session.formattedEntryTime}'),
                        trailing: Icon(
                          Icons.circle,
                          color: Colors.green,
                          size: 12,
                        ),
                      ),
                    )
                    .toList(),
              ),

            // Waiting List Section
            if (_manager.waitingList.length > 0)
              _buildSection(
                'Daftar Tunggu (${_manager.waitingList.length})',
                Icons.hourglass_top,
                _manager.waitingList.all
                    .asMap()
                    .entries
                    .map(
                      (e) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange,
                          child: Text(
                            '${e.key + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text('NIM: ${e.value.nim}'),
                        subtitle: Text(
                          'Bergabung: ${e.value.formattedJoinTime}',
                        ),
                        trailing: Icon(Icons.schedule, color: Colors.orange),
                      ),
                    )
                    .toList(),
              ),

            // Recent Completed Sessions
            if (_manager.completedStudents.isNotEmpty)
              _buildSection(
                'Riwayat Keluar',
                Icons.history,
                _manager.completedStudents.reversed
                    .take(5)
                    .map(
                      (session) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey,
                          child: Text(
                            '${session.seat}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text('NIM: ${session.nim}'),
                        subtitle: Text('Keluar: ${session.formattedExitTime}'),
                        trailing: Icon(Icons.check_circle, color: Colors.grey),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}
