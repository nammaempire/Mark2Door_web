import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/env.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/storefront.dart';

/// What a delivery partner submitted in the delivery app after their
/// first login: date of birth, permanent address, driving licence and
/// Aadhaar card. Read from `rider_documents/{10-digit phone}`.
class _Documents {
  const _Documents({
    required this.dateOfBirth,
    required this.address,
    required this.licenceNumber,
    required this.aadhaarNumber,
    required this.licenceUrl,
    required this.aadhaarUrl,
    required this.submittedAt,
  });

  final String dateOfBirth;
  final String address;
  final String licenceNumber;
  final String aadhaarNumber;
  final String licenceUrl;
  final String aadhaarUrl;
  final DateTime? submittedAt;
}

Future<_Documents?> _load(String phone) async {
  if (!Env.useFirebase) {
    // Sample mode: the first sample rider has submitted, the rest not.
    return phone.endsWith('1')
        ? _Documents(
            dateOfBirth: '1996-04-12',
            address: '18, 3rd Cross, Ejipura, Bengaluru 560047',
            licenceNumber: 'KA0120150012345',
            aadhaarNumber: '123412341234',
            licenceUrl: '',
            aadhaarUrl: '',
            submittedAt: DateTime.now().subtract(const Duration(days: 20)),
          )
        : null;
  }
  final doc = await FirebaseFirestore.instance
      .collection('rider_documents')
      .doc(phone)
      .get();
  final data = doc.data();
  if (data == null) return null;
  return _Documents(
    dateOfBirth: data['dateOfBirth'] as String? ?? '',
    address: data['address'] as String? ?? '',
    licenceNumber: data['licenceNumber'] as String? ?? '',
    aadhaarNumber: data['aadhaarNumber'] as String? ?? '',
    licenceUrl: data['licenceUrl'] as String? ?? '',
    aadhaarUrl: data['aadhaarUrl'] as String? ?? '',
    submittedAt: data['submittedAt'] is int
        ? DateTime.fromMillisecondsSinceEpoch(data['submittedAt'] as int)
        : null,
  );
}

/// "1996-04-12" as "12 Apr 1996"; anything else is shown as it is.
String readableDate(String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? iso : formatDate(d);
}

/// Aadhaar numbers are shown in groups of four.
String groupedAadhaar(String digits) => digits.length == 12
    ? '${digits.substring(0, 4)} ${digits.substring(4, 8)} '
        '${digits.substring(8)}'
    : digits;

class RiderDocumentsDialog extends StatelessWidget {
  const RiderDocumentsDialog({super.key, required this.rider});

  final Rider rider;

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 170,
              child: Text(
                label,
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
            Expanded(
              child: SelectableText(
                value.isEmpty ? 'Not given' : value,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );

  Widget _photo(String title, String url) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 170,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: url.startsWith('http')
                  ? Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Text('Photo could not be loaded'),
                    )
                  : const Text(
                      'No photo',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Documents: ${rider.name}'),
      content: SizedBox(
        width: 560,
        child: FutureBuilder<_Documents?>(
          future: _load(rider.phone),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Text('Could not load the documents.');
            }
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final d = snap.data;
            if (d == null) {
              return const Text(
                'Not submitted yet. The delivery partner is asked for these '
                'when they first log in to the delivery app.',
                key: ValueKey('documents-missing'),
                style: TextStyle(color: AppColors.textMuted),
              );
            }
            return SingleChildScrollView(
              child: Column(
                key: const ValueKey('documents-details'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _line('Mobile', rider.phone),
                  _line('Date of birth', readableDate(d.dateOfBirth)),
                  _line('Permanent address', d.address),
                  _line('Driving licence number', d.licenceNumber),
                  _line('Aadhaar number', groupedAadhaar(d.aadhaarNumber)),
                  if (d.submittedAt != null)
                    _line('Submitted', formatOrderDate(d.submittedAt!)),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _photo('Driving licence', d.licenceUrl),
                      const SizedBox(width: 12),
                      _photo('Aadhaar card', d.aadhaarUrl),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
