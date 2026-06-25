import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../library/data/library_store.dart';
import '../../library/models/document_note.dart';
import '../../library/models/reading_document.dart';

class DocumentReaderPage extends StatefulWidget {
  const DocumentReaderPage({
    required this.document,
    super.key,
  });

  final ReadingDocument document;

  @override
  State<DocumentReaderPage> createState() => _DocumentReaderPageState();
}

class _DocumentReaderPageState extends State<DocumentReaderPage> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final store = LibraryStore();
  final pdfController = PdfViewerController();
  final searchController = TextEditingController();
  final pageController = TextEditingController();
  final commentController = TextEditingController();

  PdfTextSearchResult searchResult = PdfTextSearchResult();
  late ReadingDocument document;
  List<DocumentNote> notes = const [];
  String? selectedText;
  int currentPage = 1;
  int pageCount = 0;
  double zoomLevel = 1;
  PdfAnnotationMode annotationMode = PdfAnnotationMode.none;
  PdfInteractionMode interactionMode = PdfInteractionMode.selection;
  PdfPageLayoutMode pageLayoutMode = PdfPageLayoutMode.continuous;
  bool saving = false;
  bool hasUnsavedAnnotations = false;
  Timer? saveDebounce;

  @override
  void initState() {
    super.initState();
    document = widget.document;
    currentPage = document.lastPageNumber;
    _syncPageController(currentPage);
    notes = store.notesFor(document.id);
    _configureAnnotationDefaults();
    searchResult.addListener(_handleSearchResultChanged);
  }

  @override
  void dispose() {
    saveDebounce?.cancel();
    searchResult.removeListener(_handleSearchResultChanged);
    searchResult.clear();
    searchController.dispose();
    pageController.dispose();
    commentController.dispose();
    pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!document.canOpenInApp) {
      return Scaffold(
        appBar: AppBar(title: Text(document.title)),
        body: _UnsupportedDocument(document: document),
      );
    }

    final useDrawerNotes = MediaQuery.sizeOf(context).width < 920;

    return Scaffold(
      key: scaffoldKey,
      endDrawer: useDrawerNotes
          ? Drawer(
              child: SafeArea(child: _buildNotesPanel()),
            )
          : null,
      appBar: AppBar(
        title: Text(document.title),
        actions: [
          if (useDrawerNotes)
            IconButton(
              tooltip: 'Study notes',
              onPressed: _openNotesPanel,
              icon: const Icon(Icons.sticky_note_2_outlined),
            ),
          IconButton(
            tooltip: 'Save annotated PDF',
            onPressed: saving ? null : _saveAnnotatedPdf,
            icon: saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    hasUnsavedAnnotations
                        ? Icons.save_outlined
                        : Icons.cloud_done_outlined,
                  ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final showSidePanel = constraints.maxWidth >= 920;
          final viewer = _PdfViewerPane(
            document: document,
            controller: pdfController,
            interactionMode: interactionMode,
            pageLayoutMode: pageLayoutMode,
            onDocumentLoaded: _handleDocumentLoaded,
            onPageChanged: _handlePageChanged,
            onZoomLevelChanged: (details) {
              setState(() => zoomLevel = details.newZoomLevel);
            },
            onTextSelectionChanged: _handleTextSelectionChanged,
            onAnnotationChanged: _markAnnotationsDirty,
          );

          return Column(
            children: [
              _ReaderStatusBar(
                currentPage: currentPage,
                pageCount: pageCount,
                noteCount: notes.length,
                saving: saving,
                hasUnsavedAnnotations: hasUnsavedAnnotations,
              ),
              _ReaderToolbar(
                searchController: searchController,
                pageController: pageController,
                currentPage: currentPage,
                pageCount: pageCount,
                zoomLevel: zoomLevel,
                annotationMode: annotationMode,
                interactionMode: interactionMode,
                pageLayoutMode: pageLayoutMode,
                searchResult: searchResult,
                onZoomOut: () => _setZoom(zoomLevel - 0.25),
                onZoomIn: () => _setZoom(zoomLevel + 0.25),
                onResetZoom: () => _setZoom(1),
                onPreviousPage: pdfController.previousPage,
                onNextPage: pdfController.nextPage,
                onJumpToPage: _jumpToPage,
                onSearch: _search,
                onPreviousSearchResult: searchResult.previousInstance,
                onNextSearchResult: searchResult.nextInstance,
                onClearSearch: _clearSearch,
                onInteractionModeChanged: _setInteractionMode,
                onPageLayoutModeChanged: _setPageLayoutMode,
                onToggleHighlight: () => _toggleAnnotationMode(
                  PdfAnnotationMode.highlight,
                ),
                onToggleUnderline: () => _toggleAnnotationMode(
                  PdfAnnotationMode.underline,
                ),
                onToggleStickyNote: () => _toggleAnnotationMode(
                  PdfAnnotationMode.stickyNote,
                ),
              ),
              Expanded(
                child: showSidePanel
                    ? Row(
                        children: [
                          Expanded(child: viewer),
                          SizedBox(
                            width: 360,
                            child: _buildNotesPanel(),
                          ),
                        ],
                      )
                    : viewer,
              ),
              if (!showSidePanel)
                _SelectionBar(
                  selectedText: selectedText,
                  onCopy: _copySelectedText,
                  onClear: _clearSelectedText,
                  onComment: _openNotesPanel,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotesPanel() {
    return _NotesPanel(
      selectedText: selectedText,
      notes: notes,
      controller: commentController,
      onSaveComment: _saveComment,
      onDeleteNote: _deleteNote,
      onJumpToPage: pdfController.jumpToPage,
      onCopySelection: _copySelectedText,
      onClearSelection: _clearSelectedText,
    );
  }

  void _configureAnnotationDefaults() {
    pdfController.annotationSettings
      ..author = 'ReadFlow'
      ..highlight.color = const Color(0xFFFFD54F)
      ..underline.color = const Color(0xFF2D6A63)
      ..stickyNote.color = const Color(0xFFFFF176);
  }

  void _handleSearchResultChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleDocumentLoaded(PdfDocumentLoadedDetails details) {
    final totalPages = details.document.pages.count;
    final rememberedPage = document.lastPageNumber.clamp(1, totalPages).toInt();
    final loadedPage = pdfController.pageNumber == 0
        ? rememberedPage
        : pdfController.pageNumber;

    setState(() {
      pageCount = totalPages;
      currentPage = loadedPage;
      _syncPageController(currentPage);
    });

    if (rememberedPage != pdfController.pageNumber) {
      pdfController.jumpToPage(rememberedPage);
    }
  }

  void _handlePageChanged(PdfPageChangedDetails details) {
    final updatedDocument = store.updateDocumentProgress(
      document.id,
      pageNumber: details.newPageNumber,
    );

    setState(() {
      document = updatedDocument ?? document;
      currentPage = details.newPageNumber;
      _syncPageController(currentPage);
    });
  }

  void _handleTextSelectionChanged(PdfTextSelectionChangedDetails details) {
    final selection = details.selectedText?.trim();
    setState(() {
      selectedText = selection == null || selection.isEmpty ? null : selection;
    });
  }

  void _setZoom(double value) {
    final nextZoom = value.clamp(1, 5).toDouble();
    pdfController.zoomLevel = nextZoom;
    setState(() => zoomLevel = nextZoom);
  }

  void _jumpToPage(String value) {
    final parsedPage = int.tryParse(value.trim());
    if (parsedPage == null) {
      _syncPageController(currentPage);
      return;
    }

    final maxPage = pageCount == 0 ? 1 : pageCount;
    final page = parsedPage.clamp(1, maxPage).toInt();
    pdfController.jumpToPage(page);
    _syncPageController(page);
  }

  void _search(String value) {
    final query = value.trim();
    if (query.isEmpty) {
      _clearSearch();
      return;
    }

    searchResult.removeListener(_handleSearchResultChanged);
    searchResult.clear();
    searchResult = pdfController.searchText(query);
    searchResult.addListener(_handleSearchResultChanged);
    setState(() {});
  }

  void _clearSearch() {
    searchResult.clear();
    searchController.clear();
    setState(() {});
  }

  void _setInteractionMode(PdfInteractionMode mode) {
    setState(() {
      interactionMode = mode;
      if (mode == PdfInteractionMode.pan) {
        annotationMode = PdfAnnotationMode.none;
        pdfController.annotationMode = PdfAnnotationMode.none;
      }
    });
  }

  void _setPageLayoutMode(PdfPageLayoutMode mode) {
    setState(() => pageLayoutMode = mode);
  }

  void _toggleAnnotationMode(PdfAnnotationMode mode) {
    setState(() {
      annotationMode = annotationMode == mode ? PdfAnnotationMode.none : mode;
      interactionMode = PdfInteractionMode.selection;
      pdfController.annotationMode = annotationMode;
    });
  }

  void _saveComment() {
    final selection = selectedText?.trim();
    final comment = commentController.text.trim();
    if (selection == null || selection.isEmpty || comment.isEmpty) {
      return;
    }

    setState(() {
      notes = store.addNote(
        DocumentNote.create(
          documentId: document.id,
          pageNumber: pdfController.pageNumber,
          selectedText: selection,
          comment: comment,
        ),
      );
      selectedText = null;
      commentController.clear();
    });
    pdfController.clearSelection();
  }

  void _deleteNote(DocumentNote note) {
    setState(() {
      notes = store.deleteNote(document.id, note.id);
    });
  }

  void _copySelectedText() {
    final selection = selectedText?.trim();
    if (selection == null || selection.isEmpty) {
      return;
    }

    Clipboard.setData(ClipboardData(text: selection));
    _showMessage('Selection copied');
  }

  void _clearSelectedText() {
    setState(() {
      selectedText = null;
      commentController.clear();
    });
    pdfController.clearSelection();
  }

  void _openNotesPanel() {
    scaffoldKey.currentState?.openEndDrawer();
  }

  void _markAnnotationsDirty() {
    saveDebounce?.cancel();
    setState(() => hasUnsavedAnnotations = true);
    saveDebounce = Timer(
      const Duration(milliseconds: 900),
      () => _saveAnnotatedPdf(silent: true),
    );
  }

  Future<void> _saveAnnotatedPdf({bool silent = false}) async {
    if (saving) {
      return;
    }

    saveDebounce?.cancel();
    setState(() => saving = true);
    try {
      final bytes = Uint8List.fromList(await pdfController.saveDocument());
      final updatedDocument = store.updateDocumentBytes(document.id, bytes);
      if (updatedDocument != null && mounted) {
        setState(() {
          document = updatedDocument;
          hasUnsavedAnnotations = false;
        });
      }

      if (!silent && mounted) {
        _showMessage('Annotated PDF saved');
      }
    } catch (_) {
      if (!silent && mounted) {
        _showMessage('Could not save annotations');
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  void _syncPageController(int page) {
    final text = '$page';
    if (pageController.text == text) {
      return;
    }

    pageController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _PdfViewerPane extends StatelessWidget {
  const _PdfViewerPane({
    required this.document,
    required this.controller,
    required this.interactionMode,
    required this.pageLayoutMode,
    required this.onDocumentLoaded,
    required this.onPageChanged,
    required this.onZoomLevelChanged,
    required this.onTextSelectionChanged,
    required this.onAnnotationChanged,
  });

  final ReadingDocument document;
  final PdfViewerController controller;
  final PdfInteractionMode interactionMode;
  final PdfPageLayoutMode pageLayoutMode;
  final PdfDocumentLoadedCallback onDocumentLoaded;
  final PdfPageChangedCallback onPageChanged;
  final PdfZoomLevelChangedCallback onZoomLevelChanged;
  final PdfTextSelectionChangedCallback onTextSelectionChanged;
  final VoidCallback onAnnotationChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest),
      child: SfPdfViewer.memory(
        document.bytes!,
        key: ValueKey('${document.id}-${document.bytes!.length}'),
        controller: controller,
        initialPageNumber: document.lastPageNumber,
        maxZoomLevel: 5,
        pageSpacing: 8,
        canShowScrollHead: true,
        canShowPaginationDialog: true,
        enableDoubleTapZooming: true,
        enableTextSelection: true,
        canShowTextSelectionMenu: true,
        interactionMode: interactionMode,
        pageLayoutMode: pageLayoutMode,
        currentSearchTextHighlightColor: Colors.amber.withValues(alpha: 0.55),
        otherSearchTextHighlightColor: Colors.yellow.withValues(alpha: 0.35),
        onDocumentLoaded: onDocumentLoaded,
        onPageChanged: onPageChanged,
        onZoomLevelChanged: onZoomLevelChanged,
        onTextSelectionChanged: onTextSelectionChanged,
        onAnnotationAdded: (_) => onAnnotationChanged(),
        onAnnotationEdited: (_) => onAnnotationChanged(),
        onAnnotationRemoved: (_) => onAnnotationChanged(),
        onDocumentLoadFailed: (details) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(details.description)),
          );
        },
      ),
    );
  }
}

class _ReaderStatusBar extends StatelessWidget {
  const _ReaderStatusBar({
    required this.currentPage,
    required this.pageCount,
    required this.noteCount,
    required this.saving,
    required this.hasUnsavedAnnotations,
  });

  final int currentPage;
  final int pageCount;
  final int noteCount;
  final bool saving;
  final bool hasUnsavedAnnotations;

  @override
  Widget build(BuildContext context) {
    final saveLabel = saving
        ? 'Saving'
        : hasUnsavedAnnotations
            ? 'Unsaved'
            : 'Saved';
    final saveIcon = saving
        ? Icons.sync
        : hasUnsavedAnnotations
            ? Icons.edit_note
            : Icons.cloud_done_outlined;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatusChip(
              icon: Icons.description_outlined,
              label: '$currentPage / ${pageCount == 0 ? '-' : pageCount}',
            ),
            _StatusChip(
              icon: Icons.sticky_note_2_outlined,
              label: noteCount == 1 ? '1 note' : '$noteCount notes',
            ),
            _StatusChip(icon: saveIcon, label: saveLabel),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _ReaderToolbar extends StatelessWidget {
  const _ReaderToolbar({
    required this.searchController,
    required this.pageController,
    required this.currentPage,
    required this.pageCount,
    required this.zoomLevel,
    required this.annotationMode,
    required this.interactionMode,
    required this.pageLayoutMode,
    required this.searchResult,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onResetZoom,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onJumpToPage,
    required this.onSearch,
    required this.onPreviousSearchResult,
    required this.onNextSearchResult,
    required this.onClearSearch,
    required this.onInteractionModeChanged,
    required this.onPageLayoutModeChanged,
    required this.onToggleHighlight,
    required this.onToggleUnderline,
    required this.onToggleStickyNote,
  });

  final TextEditingController searchController;
  final TextEditingController pageController;
  final int currentPage;
  final int pageCount;
  final double zoomLevel;
  final PdfAnnotationMode annotationMode;
  final PdfInteractionMode interactionMode;
  final PdfPageLayoutMode pageLayoutMode;
  final PdfTextSearchResult searchResult;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onResetZoom;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;
  final ValueChanged<String> onJumpToPage;
  final ValueChanged<String> onSearch;
  final VoidCallback onPreviousSearchResult;
  final VoidCallback onNextSearchResult;
  final VoidCallback onClearSearch;
  final ValueChanged<PdfInteractionMode> onInteractionModeChanged;
  final ValueChanged<PdfPageLayoutMode> onPageLayoutModeChanged;
  final VoidCallback onToggleHighlight;
  final VoidCallback onToggleUnderline;
  final VoidCallback onToggleStickyNote;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final searchCount = searchResult.hasResult
        ? '${searchResult.currentInstanceIndex}/${searchResult.totalInstanceCount}'
        : searchResult.isSearchCompleted
            ? '0/0'
            : '';

    return Material(
      color: colorScheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous page',
                onPressed: currentPage <= 1 ? null : onPreviousPage,
                icon: const Icon(Icons.chevron_left),
              ),
              SizedBox(
                width: 112,
                child: TextField(
                  controller: pageController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.go,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'Page',
                    suffixText: pageCount == 0 ? null : '/ $pageCount',
                  ),
                  onSubmitted: onJumpToPage,
                ),
              ),
              IconButton(
                tooltip: 'Next page',
                onPressed: pageCount == 0 || currentPage >= pageCount
                    ? null
                    : onNextPage,
                icon: const Icon(Icons.chevron_right),
              ),
              const _ToolbarDivider(),
              IconButton(
                tooltip: 'Zoom out',
                onPressed: zoomLevel <= 1 ? null : onZoomOut,
                icon: const Icon(Icons.zoom_out),
              ),
              SizedBox(
                width: 46,
                child: Text(
                  '${(zoomLevel * 100).round()}%',
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                tooltip: 'Zoom in',
                onPressed: zoomLevel >= 5 ? null : onZoomIn,
                icon: const Icon(Icons.zoom_in),
              ),
              IconButton(
                tooltip: 'Reset zoom',
                onPressed: onResetZoom,
                icon: const Icon(Icons.center_focus_strong),
              ),
              const _ToolbarDivider(),
              SegmentedButton<PdfInteractionMode>(
                showSelectedIcon: false,
                selected: {interactionMode},
                onSelectionChanged: (selection) {
                  onInteractionModeChanged(selection.single);
                },
                segments: const [
                  ButtonSegment(
                    value: PdfInteractionMode.selection,
                    icon: Icon(Icons.text_fields),
                    label: Text('Select'),
                  ),
                  ButtonSegment(
                    value: PdfInteractionMode.pan,
                    icon: Icon(Icons.pan_tool_outlined),
                    label: Text('Pan'),
                  ),
                ],
              ),
              const _ToolbarDivider(),
              SegmentedButton<PdfPageLayoutMode>(
                showSelectedIcon: false,
                selected: {pageLayoutMode},
                onSelectionChanged: (selection) {
                  onPageLayoutModeChanged(selection.single);
                },
                segments: const [
                  ButtonSegment(
                    value: PdfPageLayoutMode.continuous,
                    icon: Icon(Icons.view_agenda_outlined),
                    label: Text('Scroll'),
                  ),
                  ButtonSegment(
                    value: PdfPageLayoutMode.single,
                    icon: Icon(Icons.crop_portrait),
                    label: Text('Page'),
                  ),
                ],
              ),
              const _ToolbarDivider(),
              SizedBox(
                width: 240,
                child: TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Find text',
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: onSearch,
                ),
              ),
              IconButton(
                tooltip: 'Search',
                onPressed: () => onSearch(searchController.text),
                icon: const Icon(Icons.search),
              ),
              SizedBox(
                width: 48,
                child: Text(searchCount, textAlign: TextAlign.center),
              ),
              IconButton(
                tooltip: 'Previous match',
                onPressed:
                    searchResult.hasResult ? onPreviousSearchResult : null,
                icon: const Icon(Icons.keyboard_arrow_up),
              ),
              IconButton(
                tooltip: 'Next match',
                onPressed: searchResult.hasResult ? onNextSearchResult : null,
                icon: const Icon(Icons.keyboard_arrow_down),
              ),
              IconButton(
                tooltip: 'Clear search',
                onPressed:
                    searchController.text.isNotEmpty || searchResult.hasResult
                        ? onClearSearch
                        : null,
                icon: const Icon(Icons.close),
              ),
              const _ToolbarDivider(),
              IconButton.filledTonal(
                tooltip: 'Highlighter',
                isSelected: annotationMode == PdfAnnotationMode.highlight,
                onPressed: onToggleHighlight,
                icon: const Icon(Icons.border_color_outlined),
                selectedIcon: const Icon(Icons.border_color),
              ),
              IconButton.filledTonal(
                tooltip: 'Underline',
                isSelected: annotationMode == PdfAnnotationMode.underline,
                onPressed: onToggleUnderline,
                icon: const Icon(Icons.format_underlined),
              ),
              IconButton.filledTonal(
                tooltip: 'Sticky note',
                isSelected: annotationMode == PdfAnnotationMode.stickyNote,
                onPressed: onToggleStickyNote,
                icon: const Icon(Icons.note_add_outlined),
                selectedIcon: const Icon(Icons.note_add),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.selectedText,
    required this.onCopy,
    required this.onClear,
    required this.onComment,
  });

  final String? selectedText;
  final VoidCallback onCopy;
  final VoidCallback onClear;
  final VoidCallback onComment;

  @override
  Widget build(BuildContext context) {
    final selection = selectedText;
    if (selection == null) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selection,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Copy selection',
                onPressed: onCopy,
                icon: const Icon(Icons.content_copy),
              ),
              IconButton(
                tooltip: 'Clear selection',
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
              FilledButton.icon(
                onPressed: onComment,
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('Comment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotesPanel extends StatelessWidget {
  const _NotesPanel({
    required this.selectedText,
    required this.notes,
    required this.controller,
    required this.onSaveComment,
    required this.onDeleteNote,
    required this.onJumpToPage,
    required this.onCopySelection,
    required this.onClearSelection,
  });

  final String? selectedText;
  final List<DocumentNote> notes;
  final TextEditingController controller;
  final VoidCallback onSaveComment;
  final ValueChanged<DocumentNote> onDeleteNote;
  final ValueChanged<int> onJumpToPage;
  final VoidCallback onCopySelection;
  final VoidCallback onClearSelection;

  @override
  Widget build(BuildContext context) {
    final selection = selectedText;
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Icon(Icons.sticky_note_2_outlined, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Study notes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text('${notes.length}'),
              ],
            ),
          ),
          if (selection != null)
            Card(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selection,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Comment',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Copy selection',
                          onPressed: onCopySelection,
                          icon: const Icon(Icons.content_copy),
                        ),
                        IconButton(
                          tooltip: 'Clear selection',
                          onPressed: onClearSelection,
                          icon: const Icon(Icons.close),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: onSaveComment,
                          icon: const Icon(Icons.add_comment_outlined),
                          label: const Text('Save comment'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: notes.isEmpty
                ? const Center(child: Text('No comments saved yet.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return _NoteCard(
                        note: note,
                        onDelete: () => onDeleteNote(note),
                        onJumpToPage: () => onJumpToPage(note.pageNumber),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.onDelete,
    required this.onJumpToPage,
  });

  final DocumentNote note;
  final VoidCallback onDelete;
  final VoidCallback onJumpToPage;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Page ${note.pageNumber}')),
                IconButton(
                  tooltip: 'Go to page',
                  onPressed: onJumpToPage,
                  icon: const Icon(Icons.open_in_new),
                ),
                IconButton(
                  tooltip: 'Delete comment',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            Text(
              note.selectedText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(note.comment),
          ],
        ),
      ),
    );
  }
}

class _UnsupportedDocument extends StatelessWidget {
  const _UnsupportedDocument({required this.document});

  final ReadingDocument document;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    document.type == ReadingDocumentType.epub
                        ? Icons.menu_book_outlined
                        : Icons.insert_drive_file_outlined,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    document.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    document.type == ReadingDocumentType.pdf
                        ? 'This PDF was imported before file bytes were stored. Re-import it to open the interactive viewer.'
                        : 'EPUB files are tracked in the library and ready for a dedicated EPUB renderer integration.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
