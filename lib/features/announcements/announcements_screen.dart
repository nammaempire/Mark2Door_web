import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// A notification the store sent to every customer, for example a sudden
/// offer. Collection `announcements/{id}`; a server function sends each
/// new one to all customer phones and marks it `sent`.
@immutable
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.status = 'sending',
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;

  /// `sending` until the server has sent it, then `sent`; `failed` if the
  /// server could not send it.
  final String status;

  static const maxTitle = 50;
  static const maxBody = 160;

  factory Announcement.fromMap(String id, Map<String, dynamic> map) =>
      Announcement(
        id: id,
        title: map['title'] as String? ?? '',
        body: map['body'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['createdAt'] as num?)?.toInt() ?? 0,
        ),
        status: map['status'] as String? ?? 'sending',
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'status': status,
      };
}

abstract interface class AnnouncementsRepository {
  /// Newest first.
  Stream<List<Announcement>> watch();

  /// Queues a notification for every customer.
  Future<void> send({required String title, required String body});
}

class FirestoreAnnouncementsRepository implements AnnouncementsRepository {
  FirestoreAnnouncementsRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<Announcement>> watch() => _db
      .collection('announcements')
      .orderBy('createdAt', descending: true)
      .limit(30)
      .snapshots()
      .map(
        (s) => [for (final d in s.docs) Announcement.fromMap(d.id, d.data())],
      );

  @override
  Future<void> send({required String title, required String body}) =>
      _db.collection('announcements').add(
            Announcement(
              id: '',
              title: title.trim(),
              body: body.trim(),
              createdAt: DateTime.now(),
            ).toMap(),
          );
}

/// Sample-mode store: keeps what was "sent" in memory.
class FakeAnnouncementsRepository implements AnnouncementsRepository {
  final _items = <Announcement>[
    Announcement(
      id: 'a1',
      title: 'Weekend fruit fest',
      body: 'Up to 30% off on fresh fruits today and tomorrow.',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      status: 'sent',
    ),
  ];
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<List<Announcement>> watch() async* {
    yield List.unmodifiable(_items);
    await for (final _ in _changes.stream) {
      yield List.unmodifiable(_items);
    }
  }

  @override
  Future<void> send({required String title, required String body}) async {
    _items.insert(
      0,
      Announcement(
        id: 'a${_items.length + 1}',
        title: title.trim(),
        body: body.trim(),
        createdAt: DateTime.now(),
        status: 'sent',
      ),
    );
    _changes.add(null);
  }
}

final announcementsRepositoryProvider = Provider<AnnouncementsRepository>(
  (ref) => Env.useFirebase
      ? FirestoreAnnouncementsRepository(FirebaseFirestore.instance)
      : FakeAnnouncementsRepository(),
);

final announcementsProvider = StreamProvider<List<Announcement>>(
  (ref) => ref.watch(announcementsRepositoryProvider).watch(),
);

/// "Notify customers": the store types a title and a message and sends it
/// to every customer's phone at once.
class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() =>
      _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || !_formKey.currentState!.validate()) return;
    final ok = await confirm(
      context,
      title: 'Send to all customers?',
      message: 'Every customer with the app gets this notification now. '
          'It cannot be taken back.\n\n'
          '${_title.text.trim()}\n${_body.text.trim()}',
      action: 'Send',
    );
    if (!ok || !mounted) return;
    setState(() => _sending = true);
    try {
      await ref.read(announcementsRepositoryProvider).send(
            title: _title.text,
            body: _body.text,
          );
      _title.clear();
      _body.clear();
      if (mounted) showMessage(context, 'Notification sent to customers');
    } catch (_) {
      if (mounted) showMessage(context, 'Could not send. Try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sent = ref.watch(announcementsProvider);
    return AdminPage(
      title: 'Notify customers',
      subtitle: 'Send an offer or a message to every customer\'s phone. Use '
          'it sparingly: too many notifications make people switch them off.',
      children: [
        Panel(
          title: 'New notification',
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 520,
                  child: TextFormField(
                    key: const ValueKey('announce-title'),
                    controller: _title,
                    maxLength: Announcement.maxTitle,
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Enter a title, like "Flat 20% off today"'
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'Flat 20% off today',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 520,
                  child: TextFormField(
                    key: const ValueKey('announce-body'),
                    controller: _body,
                    maxLength: Announcement.maxBody,
                    maxLines: 3,
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Enter the message customers will read'
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      hintText: 'Use code SAVE20 on orders above ₹499. '
                          'Today only.',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  key: const ValueKey('announce-send'),
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.campaign_rounded),
                  label: Text(_sending ? 'Sending' : 'Send to all customers'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        AsyncView(
          value: sent,
          data: (items) => Panel(
            title: 'Sent notifications',
            child: items.isEmpty
                ? const Text(
                    'Nothing sent yet.',
                    style: TextStyle(color: AppColors.textMuted),
                  )
                : Column(
                    children: [
                      for (final a in items)
                        Padding(
                          key: ValueKey('announcement-${a.id}'),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.notifications_rounded,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(a.body),
                                    Text(
                                      formatOrderDate(a.createdAt),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              StatusPill(
                                switch (a.status) {
                                  'sent' => 'Sent',
                                  'failed' => 'Failed',
                                  _ => 'Sending',
                                },
                                switch (a.status) {
                                  'sent' => AppColors.success,
                                  'failed' => AppColors.danger,
                                  _ => AppColors.accentDark,
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
