import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/storefront.dart';
import 'faq_drafts.dart';
import 'legal_drafts.dart';

/// Text the customer app shows under Account: help questions, terms and
/// conditions, and the privacy policy. Everything here can be edited or
/// deleted, and changes show in the app straight away.
class ContentScreen extends ConsumerWidget {
  const ContentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faqs = ref.watch(faqsProvider);
    final pages = ref.watch(legalPagesProvider);

    return AdminPage(
      title: 'Help and legal',
      subtitle: 'Help questions for the customer and delivery apps, terms '
          'and privacy policy.',
      children: [
        AsyncView(
          value: pages,
          data: (saved) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Panel(
                title: 'Customer app legal pages',
                child: Column(
                  children: [
                    for (final (i, id) in LegalPage.ids.indexed) ...[
                      if (i > 0) const Divider(),
                      _LegalRow(pageId: id, page: saved[id]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Panel(
                title: 'Delivery app legal pages',
                child: Column(
                  children: [
                    for (final (i, id) in LegalPage.deliveryIds.indexed) ...[
                      if (i > 0) const Divider(),
                      _LegalRow(pageId: id, page: saved[id]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AsyncView(
          value: faqs,
          data: (list) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FaqPanel(app: Faq.customer, all: list),
              const SizedBox(height: 20),
              _FaqPanel(app: Faq.delivery, all: list),
            ],
          ),
        ),
      ],
    );
  }
}

/// The help questions of one app, with add, edit and delete, and a
/// button that adds the ready-written questions.
class _FaqPanel extends ConsumerWidget {
  const _FaqPanel({required this.app, required this.all});

  final String app;
  final List<Faq> all;

  bool get _delivery => app == Faq.delivery;

  /// Keys keep their old names for the customer app.
  String _key(String name) => _delivery ? '$name-delivery' : name;

  Future<void> _addSuggested(
    BuildContext context,
    WidgetRef ref,
    List<Faq> list,
  ) async {
    final have = {for (final f in list) f.question.trim().toLowerCase()};
    final missing = [
      for (final d in faqDrafts(app))
        if (!have.contains(d.question.toLowerCase())) d,
    ];
    if (missing.isEmpty) {
      showMessage(context, 'All suggested questions are already here.');
      return;
    }
    try {
      final repo = ref.read(contentRepositoryProvider);
      for (final d in missing) {
        await repo.saveFaq(
          Faq(id: '', question: d.question, answer: d.answer, app: app),
        );
      }
      if (context.mounted) {
        showMessage(context, '${missing.length} questions added');
      }
    } catch (_) {
      if (context.mounted) {
        showMessage(context, "Couldn't add the questions. Try again.");
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = [
      for (final f in all)
        if (f.app == app) f,
    ];
    void openFaq([Faq? faq]) => showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _FaqDialog(faq: faq, app: app),
        );

    return Panel(
      key: ValueKey(_key('faq-panel')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                _delivery
                    ? 'Delivery app questions (${list.length})'
                    : 'Customer app questions (${list.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    key: ValueKey(_key('suggest-faq-button')),
                    onPressed: () => _addSuggested(context, ref, list),
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Add suggested questions'),
                  ),
                  OutlinedButton.icon(
                    key: ValueKey(_key('add-faq-button')),
                    onPressed: openFaq,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(160, 44),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add question'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  _delivery
                      ? 'No questions yet. The delivery app\'s Help page is '
                          'empty.'
                      : 'No questions yet. The help page shows only the '
                          'email button.',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ),
            ),
          for (final (i, faq) in list.indexed) ...[
            if (i > 0) const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                faq.question,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  faq.answer,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: ValueKey('edit-faq-${faq.id}'),
                    tooltip: 'Edit question',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => openFaq(faq),
                  ),
                  IconButton(
                    key: ValueKey('delete-faq-${faq.id}'),
                    tooltip: 'Delete question',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () async {
                      final ok = await confirm(
                        context,
                        title: 'Delete this question?',
                        message: 'It will be removed from the help page.',
                        action: 'Delete',
                      );
                      if (ok) {
                        await ref
                            .read(contentRepositoryProvider)
                            .deleteFaq(faq.id);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LegalRow extends ConsumerWidget {
  const _LegalRow({required this.pageId, required this.page});

  final String pageId;

  /// Null when the page has not been written, or was deleted.
  final LegalPage? page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = LegalPage.titleOf(pageId);
    final updated = page?.updatedAt;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        LegalPage.isPrivacy(pageId)
            ? Icons.privacy_tip_outlined
            : Icons.description_outlined,
        color: AppColors.primary,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
      subtitle: Text(
        page == null
            ? 'Not published. Open the pencil for a ready-made draft.'
            : updated == null
                ? 'Published'
                : 'Published · updated ${formatOrderDate(updated)}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusPill(
            page == null ? 'Draft' : 'Live',
            page == null ? AppColors.textMuted : AppColors.success,
          ),
          const SizedBox(width: 8),
          IconButton(
            key: ValueKey('edit-page-$pageId'),
            tooltip: page == null ? 'Write $title' : 'Edit $title',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => _LegalDialog(pageId: pageId, page: page),
            ),
          ),
          IconButton(
            key: ValueKey('delete-page-$pageId'),
            tooltip: 'Delete $title',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: page == null
                ? null
                : () async {
                    final ok = await confirm(
                      context,
                      title: 'Delete the ${title.toLowerCase()}?',
                      message: 'The app will show it as not available '
                          'until you write it again.',
                      action: 'Delete',
                    );
                    if (!ok) return;
                    await ref
                        .read(contentRepositoryProvider)
                        .deletePage(pageId);
                    if (context.mounted) showMessage(context, '$title deleted');
                  },
          ),
        ],
      ),
    );
  }
}

class _LegalDialog extends ConsumerStatefulWidget {
  const _LegalDialog({required this.pageId, this.page});

  final String pageId;
  final LegalPage? page;

  @override
  ConsumerState<_LegalDialog> createState() => _LegalDialogState();
}

class _LegalDialogState extends ConsumerState<_LegalDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _body;
  bool _saving = false;

  /// True when the page was never written and the editor opens with the
  /// ready-made draft; nothing is published until Save.
  bool get _isDraft => widget.page == null;

  @override
  void initState() {
    super.initState();
    _body = TextEditingController(
      text: widget.page?.body ??
          legalDraft(
            widget.pageId,
            ref.read(storeSettingsProvider).valueOrNull,
            DateTime.now(),
          ),
    );
    _body.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final title = LegalPage.titleOf(widget.pageId);
    try {
      await ref
          .read(contentRepositoryProvider)
          .savePage(widget.pageId, _body.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop();
      showMessage(context, '$title saved');
    } catch (_) {
      if (mounted) showMessage(context, "Couldn't save the page.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(LegalPage.titleOf(widget.pageId)),
      content: SizedBox(
        width: 680,
        child: Form(
          key: _formKey,
          // Scrolls when the hints and error leave no room on a short window.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isDraft
                      ? 'A ready-made draft is filled in. It is not published '
                          'until you press Save. Edit it to match how your '
                          'store works, and have a lawyer check it.'
                      : 'Line breaks are kept, and customers see the text '
                          'exactly as written here.',
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                if (hasPlaceholder(_body.text)) ...[
                  const SizedBox(height: 8),
                  const Row(
                    key: ValueKey('placeholder-warning'),
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: AppColors.danger,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Replace everything in [SQUARE BRACKETS] with your '
                          'own details before saving.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('page-body'),
                  controller: _body,
                  autofocus: true,
                  minLines: 14,
                  maxLines: 22,
                  keyboardType: TextInputType.multiline,
                  validator: (v) {
                    final text = v?.trim() ?? '';
                    if (text.isEmpty) {
                      return 'Write the page, or use Delete to remove it';
                    }
                    // Customers must never see an unfilled blank.
                    if (hasPlaceholder(text)) {
                      return 'Replace the details in [SQUARE BRACKETS] first';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(alignLabelWithHint: true),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        // A page that is already published can be replaced with the
        // latest ready-made text; nothing changes until Save.
        if (!_isDraft)
          TextButton.icon(
            key: const ValueKey('load-draft-button'),
            onPressed: _saving
                ? null
                : () async {
                    final ok = await confirm(
                      context,
                      title: 'Replace with the latest draft?',
                      message: 'The text in the box is replaced with the '
                          'ready-made draft. The live page changes only '
                          'when you press Save.',
                      action: 'Replace',
                    );
                    if (!ok) return;
                    _body.text = legalDraft(
                      widget.pageId,
                      ref.read(storeSettingsProvider).valueOrNull,
                      DateTime.now(),
                    );
                  },
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Load latest draft'),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('save-page-button'),
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}

class _FaqDialog extends ConsumerStatefulWidget {
  const _FaqDialog({this.faq, required this.app});

  final Faq? faq;

  /// The app a new question is for.
  final String app;

  @override
  ConsumerState<_FaqDialog> createState() => _FaqDialogState();
}

class _FaqDialogState extends ConsumerState<_FaqDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _question = TextEditingController(text: widget.faq?.question);
  late final _answer = TextEditingController(text: widget.faq?.answer);
  bool _saving = false;

  @override
  void dispose() {
    _question.dispose();
    _answer.dispose();
    super.dispose();
  }

  String? _required(String? v) =>
      (v?.trim().isEmpty ?? true) ? 'Required' : null;

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(contentRepositoryProvider).saveFaq(
            Faq(
              id: widget.faq?.id ?? '',
              question: _question.text.trim(),
              answer: _answer.text.trim(),
              sortOrder: widget.faq?.sortOrder ?? 0,
              app: widget.faq?.app ?? widget.app,
            ),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      showMessage(context, 'Question saved');
    } catch (_) {
      if (mounted) showMessage(context, "Couldn't save the question.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.faq == null ? 'Add question' : 'Edit question'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('faq-question'),
                controller: _question,
                autofocus: true,
                maxLength: 120,
                validator: _required,
                decoration: const InputDecoration(labelText: 'Question'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const ValueKey('faq-answer'),
                controller: _answer,
                minLines: 3,
                maxLines: 8,
                validator: _required,
                decoration: const InputDecoration(
                  labelText: 'Answer',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('save-faq-button'),
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}
