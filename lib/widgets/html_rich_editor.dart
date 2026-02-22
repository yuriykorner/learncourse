import 'package:flutter/material.dart';
import 'package:html_editor_enhanced/html_editor.dart';

class HtmlRichEditor extends StatefulWidget {
  final String? initialContent;
  final Function(String) onContentChanged;

  const HtmlRichEditor({
    super.key,
    this.initialContent,
    required this.onContentChanged,
  });

  @override
  State<HtmlRichEditor> createState() => _HtmlRichEditorState();
}

class _HtmlRichEditorState extends State<HtmlRichEditor> {
  final HtmlEditorController _controller = HtmlEditorController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: HtmlEditor(
            controller: _controller,
            htmlEditorOptions: HtmlEditorOptions(
              hint: 'Введите текст урока...',
              initialText: widget.initialContent ?? '',
              darkMode: false,
            ),
            htmlToolbarOptions: HtmlToolbarOptions(
              // ✅ СТАНДАРТНАЯ НАСТРОЙКА TOOLBAR
              defaultToolbarButtons: const [
                StyleButtons(), // ✅ ВКЛЮЧАЕТ HEADER (H1, H2, H3, Normal)
                FontButtons(clearAll: false),
                ColorButtons(),
                ListButtons(listStyles: false),
                ParagraphButtons(
                  textDirection: false,
                  lineHeight: false,
                  caseConverter: false,
                ),
                InsertButtons(
                  video: true,
                  audio: false,
                  table: false,
                  hr: true,
                  otherFile: false,
                ),
              ],
              toolbarPosition: ToolbarPosition.aboveEditor,
            ),
            otherOptions: OtherOptions(
              height: MediaQuery.of(context).size.height * 0.5,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            callbacks: Callbacks(
              onChangeContent: (html) {
                widget.onContentChanged(html ?? '');
              },
            ),
          ),
        ),
      ],
    );
  }
}
