// communication_compose_dialog.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import 'communication_models.dart';
import 'communication_notification_service.dart';
import 'communication_service.dart';

// ─── Recipient chip field ─────────────────────────────────────────────────────
class _RecipientField extends StatefulWidget {
  final String label;
  final List<MessageParticipant> selected;
  final List<MessageParticipant> suggestions;
  final ValueChanged<List<MessageParticipant>> onChanged;

  const _RecipientField({
    required this.label,
    required this.selected,
    required this.suggestions,
    required this.onChanged,
  });

  @override
  State<_RecipientField> createState() => _RecipientFieldState();
}

class _RecipientFieldState extends State<_RecipientField> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  // _showDropdown removed — overlay presence itself tracks visibility
  List<MessageParticipant> _filtered = [];
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTextChanged);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _hideOverlay();
    });
  }

  void _onTextChanged() {
    final query = _ctrl.text.trim().toLowerCase();
    if (query.isEmpty) {
      _hideOverlay();
      return;
    }
    final selectedUids = widget.selected.map((p) => p.uid).toSet();
    _filtered = widget.suggestions
        .where((p) =>
            !selectedUids.contains(p.uid) &&
            (p.email.toLowerCase().contains(query) ||
                p.username.toLowerCase().contains(query)))
        .take(8)
        .toList();

    if (_filtered.isEmpty) {
      _hideOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    _hideOverlay();
    _overlayEntry = _buildOverlay();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _buildOverlay() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 2),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final p = _filtered[i];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF0A2E5A),
                      child: Text(
                        p.username.isNotEmpty
                            ? p.username[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13),
                      ),
                    ),
                    title: Text(p.username,
                        style: GoogleFonts.poppins(fontSize: 13)),
                    subtitle: Text(p.email,
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: Colors.grey[600])),
                    onTap: () => _selectParticipant(p),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectParticipant(MessageParticipant p) {
    _hideOverlay();
    _ctrl.clear();
    final updated = [...widget.selected, p];
    widget.onChanged(updated);
  }

  void _removeParticipant(MessageParticipant p) {
    final updated = widget.selected.where((x) => x.uid != p.uid).toList();
    widget.onChanged(updated);
  }

  @override
  void dispose() {
    _hideOverlay();
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Colors.grey.shade300)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 60,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  widget.label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...widget.selected.map((p) => Chip(
                        label: Text(
                          p.email,
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        backgroundColor: const Color(0xFF0A2E5A)
                            .withValues(alpha: 0.08),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () => _removeParticipant(p),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 4),
                      )),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focusNode,
                      style: GoogleFonts.poppins(fontSize: 13),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: widget.selected.isEmpty
                            ? 'Type email or name…'
                            : '',
                        hintStyle: GoogleFonts.poppins(
                            fontSize: 13, color: Colors.grey[400]),
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 8),
                      ),
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
}

// ─── Main Compose Dialog ───────────────────────────────────────────────────────
class CommunicationComposeDialog extends StatefulWidget {
  final String projectId;
  final CommunicationService service;
  final MessageParticipant currentUser;
  final List<MessageParticipant> projectUsers;

  /// Pre-filled fields for Reply / Forward
  final List<MessageParticipant>? initialTo;
  final List<MessageParticipant>? initialCc;
  final String? initialSubject;
  final String? initialBodyDelta;
  final String? replyToMessageId;
  final String? threadId;
  final MessageType messageType;

  final VoidCallback? onSent;

  const CommunicationComposeDialog({
    super.key,
    required this.projectId,
    required this.service,
    required this.currentUser,
    required this.projectUsers,
    this.initialTo,
    this.initialCc,
    this.initialSubject,
    this.initialBodyDelta,
    this.replyToMessageId,
    this.threadId,
    this.messageType = MessageType.original,
    this.onSent,
  });

  @override
  State<CommunicationComposeDialog> createState() =>
      _CommunicationComposeDialogState();
}

class _CommunicationComposeDialogState
    extends State<CommunicationComposeDialog> {
  final TextEditingController _subjectCtrl = TextEditingController();
  late quill.QuillController _quillCtrl;
  final FocusNode _quillFocus = FocusNode();
  final ScrollController _quillScroll = ScrollController();
  final Uuid _uuid = const Uuid();

  List<MessageParticipant> _toList = [];
  List<MessageParticipant> _ccList = [];

  // _showCc removed — it was unused; _showCcField is the active flag
  bool _showCcField = false;

  // final: the list itself is never reassigned, only its contents are read
  final List<MessageAttachment> _attachments = [];
  final List<_PendingAttachment> _pendingAttachments = [];

  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _toList = List<MessageParticipant>.from(widget.initialTo ?? []);
    _ccList = List<MessageParticipant>.from(widget.initialCc ?? []);
    _showCcField = _ccList.isNotEmpty;

    if (widget.initialSubject != null) {
      _subjectCtrl.text = widget.initialSubject!;
    }

    // Initialise Quill — attempt to decode a pre-filled bodyDelta
    if (widget.initialBodyDelta != null &&
        widget.initialBodyDelta!.isNotEmpty) {
      try {
        final ops = parseDeltaJson(widget.initialBodyDelta!);
        if (ops.isNotEmpty) {
          final doc = quill.Document.fromJson(ops);
          _quillCtrl = quill.QuillController(
            document: doc,
            selection: const TextSelection.collapsed(offset: 0),
          );
        } else {
          _quillCtrl = quill.QuillController.basic();
        }
      } catch (_) {
        _quillCtrl = quill.QuillController.basic();
      }
    } else {
      _quillCtrl = quill.QuillController.basic();
    }
  }

  // ─── Body serialisation ──────────────────────────────────────────────────

  /// Serialise the Quill document to a JSON array string for Firestore.
  String _buildDeltaJson() {
    try {
      return jsonEncode(_quillCtrl.document.toDelta().toJson());
    } catch (_) {
      return '[]';
    }
  }

  String _buildPlainText() =>
      _quillCtrl.document.toPlainText().trim();

  // ─── Attachment picking ──────────────────────────────────────────────────

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'doc', 'docx', 'xls', 'xlsx', 'csv',
        'png', 'jpg', 'jpeg', 'gif', 'webp',
      ],
      withData: true,
    );
    if (result == null) return;

    for (final file in result.files) {
      if (file.bytes == null) continue;
      setState(() {
        _pendingAttachments.add(_PendingAttachment(
          id: _uuid.v4(),
          name: file.name,
          bytes: file.bytes!,
          mimeType: _mimeFromExtension(file.extension ?? ''),
        ));
      });
    }
  }

  String _mimeFromExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument'
            '.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument'
            '.spreadsheetml.sheet';
      case 'csv':
        return 'text/csv';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  // ─── Send ────────────────────────────────────────────────────────────────

  Future<void> _send() async {
    if (_toList.isEmpty) {
      _snack('Please add at least one recipient in the To field.');
      return;
    }
    if (_subjectCtrl.text.trim().isEmpty) {
      _snack('Please enter a subject.');
      return;
    }

    setState(() => _isSending = true);

    try {
      // Upload pending attachments first
      final List<MessageAttachment> uploaded = [];
      for (final pending in _pendingAttachments) {
        final att = await widget.service.uploadAttachment(
          bytes: pending.bytes,
          fileName: pending.name,
          mimeType: pending.mimeType,
          projectId: widget.projectId,
        );
        if (att != null) uploaded.add(att);
      }
      // Merge with any pre-existing attachments (e.g. forwarded)
      uploaded.addAll(_attachments);

      final bodyDelta = _buildDeltaJson();
      final bodyPlain = _buildPlainText();

      final messageId = await widget.service.sendMessage(
        projectId: widget.projectId,
        from: widget.currentUser,
        to: _toList,
        cc: _ccList,
        subject: _subjectCtrl.text.trim(),
        bodyDelta: bodyDelta,
        bodyPlainText: bodyPlain,
        attachments: uploaded,
        parentId: widget.replyToMessageId,
        threadId: widget.threadId,
        type: widget.messageType,
      );

      if (messageId != null) {
        // Enqueue push notifications for all recipients
        final msg = CommunicationMessage(
          id: messageId,
          projectId: widget.projectId,
          threadId: widget.threadId ?? messageId,
          parentId: widget.replyToMessageId,
          subject: _subjectCtrl.text.trim(),
          bodyDelta: bodyDelta,
          bodyPlainText: bodyPlain,
          from: widget.currentUser,
          to: _toList,
          cc: _ccList,
          attachments: uploaded,
          sentAt: DateTime.now(),
          type: widget.messageType,
          readByUids: [widget.currentUser.uid],
          deletedByUids: [],
        );
        await CommunicationNotificationService()
            .enqueueNotificationsForMessage(msg);

        if (mounted) {
          Navigator.of(context).pop();
          widget.onSent?.call();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Message sent!', style: GoogleFonts.poppins()),
            backgroundColor: const Color(0xFF0A2E5A),
          ));
        }
      } else {
        _snack('Failed to send. Please try again.');
      }
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ─── Save Draft ──────────────────────────────────────────────────────────

  Future<void> _saveDraftAndClose() async {
    final draft = DraftMessage(
      id: _uuid.v4(),
      projectId: widget.projectId,
      to: _toList,
      cc: _ccList,
      subject: _subjectCtrl.text,
      bodyDelta: _buildDeltaJson(),
      attachments: _attachments,
      savedAt: DateTime.now(),
    );
    await widget.service.saveDraft(draft);
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('Draft saved.', style: GoogleFonts.poppins()),
        backgroundColor: Colors.grey[700],
      ));
    }
  }

  // ─── Discard ─────────────────────────────────────────────────────────────

  void _discard() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Discard message?', style: GoogleFonts.poppins()),
        content: Text(
          'This message will not be saved.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close confirmation
              Navigator.pop(context); // close compose dialog
            },
            child: Text('Discard',
                style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg, style: GoogleFonts.poppins())));
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _quillCtrl.dispose();
    _quillFocus.dispose();
    _quillScroll.dispose();
    super.dispose();
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Dialog(
      backgroundColor: Colors.white,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: isMobile
          ? const EdgeInsets.all(8)
          : const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 760,
          maxHeight: screenHeight * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTitleBar(),
            Flexible(child: _buildBody()),
            _buildToolbar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0A2E5A),
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _composeTitle(),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          IconButton(
            icon:
                const Icon(Icons.close, color: Colors.white, size: 20),
            onPressed: _discard,
            tooltip: 'Discard',
          ),
        ],
      ),
    );
  }

  String _composeTitle() {
    switch (widget.messageType) {
      case MessageType.reply:
        return 'Reply';
      case MessageType.replyAll:
        return 'Reply All';
      case MessageType.forward:
        return 'Forward';
      default:
        return 'New Message';
    }
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── To ─────────────────────────────────────────────────────────
          _RecipientField(
            label: 'To',
            selected: _toList,
            suggestions: widget.projectUsers,
            onChanged: (v) => setState(() => _toList = v),
          ),

          // ── Cc toggle / field ───────────────────────────────────────────
          if (!_showCcField)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _showCcField = true),
                child: Text(
                  'Cc',
                  style: GoogleFonts.poppins(
                      color: Colors.grey[600], fontSize: 13),
                ),
              ),
            )
          else
            _RecipientField(
              label: 'Cc',
              selected: _ccList,
              suggestions: widget.projectUsers,
              onChanged: (v) => setState(() => _ccList = v),
            ),

          // ── Subject ────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
                border: Border(
                    bottom:
                        BorderSide(color: Colors.grey.shade300))),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    'Subject',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _subjectCtrl,
                    style: GoogleFonts.poppins(fontSize: 13),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Subject',
                      hintStyle: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.grey[400]),
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Quill toolbar ──────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
                border: Border(
                    bottom:
                        BorderSide(color: Colors.grey.shade200))),
            child: quill.QuillSimpleToolbar(
              controller: _quillCtrl,
              // multiRowsToolbar removed — not a valid parameter in this
              // version of flutter_quill. Toolbar rows are controlled by
              // the available width automatically.
              config: const quill.QuillSimpleToolbarConfig(
                showFontFamily: false,
                showFontSize: false,
                showCodeBlock: false,
                showInlineCode: false,
                showSubscript: false,
                showSuperscript: false,
                showClearFormat: true,
                showSearchButton: false,
              ),
            ),
          ),

          // ── Quill editor ───────────────────────────────────────────────
          Container(
            constraints: const BoxConstraints(minHeight: 220),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            child: quill.QuillEditor(
              controller: _quillCtrl,
              focusNode: _quillFocus,
              scrollController: _quillScroll,
              config: quill.QuillEditorConfig(
                placeholder: 'Write your message here…',
                scrollable: true,
                expands: false,
                padding: EdgeInsets.zero,
                customStyles: quill.DefaultStyles(
                  paragraph: quill.DefaultTextBlockStyle(
                    GoogleFonts.poppins(
                        fontSize: 13, color: Colors.grey[800]),
                    const quill.HorizontalSpacing(0, 0),
                    const quill.VerticalSpacing(0, 0),
                    const quill.VerticalSpacing(0, 0),
                    null,
                  ),
                ),
              ),
            ),
          ),

          // ── Pending attachment chips ───────────────────────────────────
          if (_pendingAttachments.isNotEmpty) _buildAttachmentPreview(),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildAttachmentPreview() {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.grey[50],
          border: Border(
              top: BorderSide(color: Colors.grey.shade200))),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: _pendingAttachments.map((pa) {
          return Chip(
            avatar: Icon(
              _iconForMime(pa.mimeType),
              size: 16,
              color: const Color(0xFF0A2E5A),
            ),
            label: Text(
              pa.name,
              style: GoogleFonts.poppins(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
            deleteIcon: const Icon(Icons.close, size: 14),
            onDeleted: () =>
                setState(() => _pendingAttachments.remove(pa)),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(color: Colors.grey.shade300),
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _iconForMime(String mime) {
    if (mime.startsWith('image/')) return Icons.image;
    if (mime == 'application/pdf') return Icons.picture_as_pdf;
    if (mime.contains('word') || mime.contains('document')) {
      return Icons.description;
    }
    if (mime.contains('sheet') ||
        mime.contains('excel') ||
        mime.contains('csv')) {
      return Icons.table_chart;
    }
    return Icons.attach_file;
  }

  // ─── Bottom toolbar ──────────────────────────────────────────────────────
  Widget _buildToolbar() {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // SEND
          ElevatedButton.icon(
            onPressed: _isSending ? null : _send,
            icon: _isSending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send, size: 16),
            label: Text(
              _isSending ? 'Sending…' : 'Send',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A2E5A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),

          // ATTACH
          _ToolbarAction(
            icon: Icons.attach_file,
            tooltip: 'Attach files',
            onTap: _pickAttachment,
          ),

          const Spacer(),

          // SAVE DRAFT
          _ToolbarAction(
            icon: Icons.save_outlined,
            tooltip: 'Save draft',
            onTap: _saveDraftAndClose,
          ),

          // DISCARD
          _ToolbarAction(
            icon: Icons.delete_outline,
            tooltip: 'Discard',
            onTap: _discard,
            color: Colors.red[400]!,
          ),
        ],
      ),
    );
  }
}

// ─── Toolbar icon button ──────────────────────────────────────────────────────
class _ToolbarAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  const _ToolbarAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = const Color(0xFF555555),
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}

// ─── Pending attachment (local, before upload) ────────────────────────────────
class _PendingAttachment {
  final String id;
  final String name;
  final Uint8List bytes;
  final String mimeType;

  const _PendingAttachment({
    required this.id,
    required this.name,
    required this.bytes,
    required this.mimeType,
  });
}