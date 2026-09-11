import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_super_app/core/services/api_service.dart';
import 'package:pdf_super_app/features/home/screens/pdf_preview_screen.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class FillFormsScreen extends StatefulWidget {
  final PlatformFile selectedFile;

  const FillFormsScreen({super.key, required this.selectedFile});

  @override
  State<FillFormsScreen> createState() => _FillFormsScreenState();
}

class _FillFormsScreenState extends State<FillFormsScreen> {
  PdfDocument? _document;

  bool _isLoading = true;
  bool _isSaving = false;

  final List<_FormFieldItem> _fields = <_FormFieldItem>[];

  int _totalPdfFields = 0;

  @override
  void initState() {
    super.initState();
    _loadForm();
  }

  @override
  void dispose() {
    for (final _FormFieldItem field in _fields) {
      field.controller?.dispose();
    }

    _document?.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD PDF FORM
  // ============================================================

  Future<void> _loadForm() async {
    final String? path = widget.selectedFile.path;

    if (path == null || path.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      _showMessage('Unable to access the selected PDF file.');
      return;
    }

    try {
      final File file = File(path);

      if (!await file.exists()) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }

        _showMessage('Selected PDF file was not found.');
        return;
      }

      final List<int> bytes = await file.readAsBytes();

      final PdfDocument document = PdfDocument(inputBytes: bytes);

      final PdfForm form = document.form;

      form.setDefaultAppearance(false);

      final int fieldCount = form.fields.count;

      debugPrint('================================================');
      debugPrint('FILL FORMS - PDF FORM ANALYSIS');
      debugPrint('File: ${widget.selectedFile.name}');
      debugPrint('Total PDF form fields: $fieldCount');

      final String pdfText = String.fromCharCodes(bytes.take(200000));

      final bool containsAcroForm = pdfText.contains('/AcroForm');

      final bool containsXfa = pdfText.contains('/XFA');

      final bool containsWidget = pdfText.contains('/Widget');

      debugPrint('Contains /AcroForm: $containsAcroForm');
      debugPrint('Contains /XFA: $containsXfa');
      debugPrint('Contains /Widget: $containsWidget');

      final List<_FormFieldItem> loadedFields = <_FormFieldItem>[];

      for (int index = 0; index < fieldCount; index++) {
        final PdfField field = form.fields[index];

        debugPrint(
          'Field ${index + 1}: '
          'type=${field.runtimeType}, '
          'name=${field.name}',
        );

        final _FormFieldItem? item = _createFormFieldItem(field, index);

        if (item != null) {
          loadedFields.add(item);
        }
      }

      debugPrint(
        'Supported fields loaded: '
        '${loadedFields.length}',
      );

      debugPrint('================================================');

      if (!mounted) {
        for (final _FormFieldItem field in loadedFields) {
          field.controller?.dispose();
        }

        document.dispose();
        return;
      }

      setState(() {
        _document = document;
        _fields
          ..clear()
          ..addAll(loadedFields);
        _totalPdfFields = fieldCount;
        _isLoading = false;
      });

      if (fieldCount == 0) {
        if (containsXfa) {
          _showMessage(
            'This PDF appears to use an XFA form. '
            'Editable AcroForm fields were not found.',
          );
        } else if (containsAcroForm || containsWidget) {
          _showMessage(
            'PDF contains form-related data, '
            'but no supported editable fields were found.',
          );
        } else {
          _showMessage('No editable form fields were found in this PDF.');
        }

        return;
      }

      if (loadedFields.isEmpty) {
        _showMessage(
          'PDF form fields were detected, '
          'but their field types are not supported yet.',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Fill Forms load error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      _showMessage('Unable to read PDF form fields.');
    }
  }

  // ============================================================
  // CREATE FORM FIELD ITEM
  // ============================================================

  _FormFieldItem? _createFormFieldItem(PdfField field, int index) {
    final String? rawName = field.name;

    final String fieldName = rawName != null && rawName.trim().isNotEmpty
        ? rawName.trim()
        : 'Field ${index + 1}';

    // ----------------------------------------------------------
    // TEXT BOX
    // ----------------------------------------------------------

    if (field is PdfTextBoxField) {
      final TextEditingController controller = TextEditingController(
        text: field.text,
      );

      return _FormFieldItem(
        field: field,
        name: fieldName,
        type: _FormFieldType.text,
        controller: controller,
      );
    }

    // ----------------------------------------------------------
    // CHECKBOX
    // ----------------------------------------------------------

    if (field is PdfCheckBoxField) {
      return _FormFieldItem(
        field: field,
        name: fieldName,
        type: _FormFieldType.checkbox,
        boolValue: field.isChecked,
      );
    }

    // ----------------------------------------------------------
    // RADIO BUTTON
    // ----------------------------------------------------------

    if (field is PdfRadioButtonListField) {
      final List<_RadioOption> radioOptions = _getRadioOptions(field);

      String? selectedValue;

      try {
        if (field.selectedIndex >= 0 &&
            field.selectedIndex < radioOptions.length) {
          selectedValue = radioOptions[field.selectedIndex].value;
        } else if (field.selectedItem != null) {
          selectedValue = field.selectedItem!.value;
        }
      } catch (e) {
        debugPrint('Radio selected value read safely skipped: $e');
      }

      return _FormFieldItem(
        field: field,
        name: fieldName,
        type: _FormFieldType.radio,
        value: selectedValue,
        items: radioOptions.map((_RadioOption option) => option.label).toList(),
        radioOptions: radioOptions,
      );
    }

    // ----------------------------------------------------------
    // COMBO BOX
    // ----------------------------------------------------------

    if (field is PdfComboBoxField) {
      final List<String> items = _getFieldItemTexts(field.items);

      String? selectedValue;

      try {
        if (field.selectedIndex >= 0 && field.selectedIndex < items.length) {
          selectedValue = items[field.selectedIndex];
        }
      } catch (e) {
        debugPrint('Combo selected value read error: $e');
      }

      return _FormFieldItem(
        field: field,
        name: fieldName,
        type: _FormFieldType.comboBox,
        value: selectedValue,
        items: items,
      );
    }

    // ----------------------------------------------------------
    // LIST BOX
    // ----------------------------------------------------------

    if (field is PdfListBoxField) {
      final List<String> items = _getFieldItemTexts(field.items);

      final List<String> selectedValues = List<String>.from(
        field.selectedValues,
      );

      return _FormFieldItem(
        field: field,
        name: fieldName,
        type: _FormFieldType.listBox,
        value: selectedValues.isNotEmpty ? selectedValues.first : null,
        selectedValues: selectedValues,
        items: items,
      );
    }

    // ----------------------------------------------------------
    // UNSUPPORTED
    // ----------------------------------------------------------

    debugPrint(
      'Unsupported PDF form field: '
      '${field.runtimeType} '
      'name=$fieldName',
    );

    return null;
  }

  // ============================================================
  // RADIO OPTIONS
  // ============================================================

  List<_RadioOption> _getRadioOptions(PdfRadioButtonListField field) {
    final List<_RadioOption> options = <_RadioOption>[];

    try {
      final int count = field.items.count;

      for (int index = 0; index < count; index++) {
        try {
          final PdfRadioButtonListItem item = field.items[index];

          final String value = item.value;

          final String label = value.trim().isNotEmpty
              ? value
              : 'Option ${index + 1}';

          options.add(_RadioOption(label: label, value: value));
        } catch (e) {
          debugPrint('Radio option $index read error: $e');
        }
      }
    } catch (e) {
      debugPrint('Radio item collection read error: $e');
    }

    debugPrint('Radio options found: ${options.length}');

    return options;
  }

  // ============================================================
  // GET FIELD ITEM TEXTS
  // ============================================================

  List<String> _getFieldItemTexts(PdfListFieldItemCollection items) {
    return List<String>.generate(items.count, (int index) => items[index].text);
  }

  // ============================================================
  // SAVE FORM
  // ============================================================

  Future<void> _saveForm() async {
    if (_document == null) {
      _showMessage('PDF is not ready yet.');
      return;
    }

    if (_fields.isEmpty) {
      _showMessage('There are no editable fields to save.');
      return;
    }

    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      for (final _FormFieldItem item in _fields) {
        final PdfField field = item.field;

        // ------------------------------------------------------
        // TEXT
        // ------------------------------------------------------

        if (field is PdfTextBoxField) {
          field.text = item.controller?.text ?? '';
        }
        // ------------------------------------------------------
        // CHECKBOX
        // ------------------------------------------------------
        else if (field is PdfCheckBoxField) {
          field.isChecked = item.boolValue ?? false;
        }
        // ------------------------------------------------------
        // RADIO
        // ------------------------------------------------------
        else if (field is PdfRadioButtonListField) {
          final String? value = item.value?.toString();

          if (value != null && value.trim().isNotEmpty) {
            try {
              final int optionIndex = field.items.count == 0
                  ? -1
                  : _findRadioIndex(field, value);

              if (optionIndex >= 0 && optionIndex < field.items.count) {
                field.selectedIndex = optionIndex;
              } else {
                field.selectedValue = value;
              }
            } catch (e) {
              debugPrint('Radio save fallback: $e');

              try {
                field.selectedValue = value;
              } catch (e2) {
                debugPrint('Radio selectedValue save failed: $e2');
              }
            }
          }
        }
        // ------------------------------------------------------
        // COMBO BOX
        // ------------------------------------------------------
        else if (field is PdfComboBoxField) {
          final String? value = item.value?.toString();

          if (value != null && value.trim().isNotEmpty) {
            try {
              final int optionIndex = _findComboIndex(field, value);

              if (optionIndex >= 0) {
                field.selectedIndex = optionIndex;
              } else {
                field.selectedValue = value;
              }
            } catch (e) {
              debugPrint('Combo save fallback: $e');

              field.selectedValue = value;
            }
          }
        }
        // ------------------------------------------------------
        // LIST BOX
        // ------------------------------------------------------
        else if (field is PdfListBoxField) {
          field.selectedValues = List<String>.from(item.selectedValues);
        }
      }

      // Generate field appearance.
      _document!.form.setDefaultAppearance(false);

      final List<int> outputBytes = await _document!.save();

      if (outputBytes.isEmpty) {
        throw Exception('Filled PDF is empty.');
      }

      final Directory directory = await getApplicationDocumentsDirectory();

      final String fileName =
          'Filled_Form_'
          '${DateTime.now().millisecondsSinceEpoch}.pdf';

      final String outputPath = '${directory.path}/$fileName';

      final File outputFile = File(outputPath);

      await outputFile.writeAsBytes(outputBytes, flush: true);

      final int outputSize = await outputFile.length();

      if (outputSize <= 0) {
        throw Exception('Filled PDF file is empty.');
      }

      debugPrint('✅ Filled PDF written to disk');
      debugPrint('📦 Output size: $outputSize bytes');

      // ========================================================
      // SAVE HISTORY METADATA
      // ========================================================

      try {
        final response = await ApiService.instance.createHistory(
          toolName: 'Fill Forms',
          fileName: widget.selectedFile.name,
          outputFileName: fileName,
          status: 'completed',
          fileSize: outputSize,
          notes:
              'Filled ${_fields.length} '
              'supported PDF form '
              '${_fields.length == 1 ? 'field' : 'fields'}.',
        );

        debugPrint(
          '✅ Fill Forms history API response: '
          '${response.data}',
        );
      } catch (historyError) {
        debugPrint(
          '⚠️ Fill Forms completed, but history '
          'could not be saved: $historyError',
        );
      }

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showMessage('Form saved successfully.');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PdfPreviewScreen(fileName: fileName, filePath: outputPath),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Fill Forms save error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showMessage('Unable to save the filled PDF form.');
    }
  }

  // ============================================================
  // FIND RADIO INDEX
  // ============================================================

  int _findRadioIndex(PdfRadioButtonListField field, String value) {
    for (int index = 0; index < field.items.count; index++) {
      try {
        final PdfRadioButtonListItem item = field.items[index];

        if (item.value == value) {
          return index;
        }
      } catch (e) {
        debugPrint('Radio index lookup error at $index: $e');
      }
    }

    return -1;
  }

  // ============================================================
  // FIND COMBO INDEX
  // ============================================================

  int _findComboIndex(PdfComboBoxField field, String value) {
    for (int index = 0; index < field.items.count; index++) {
      try {
        if (field.items[index].text == value) {
          return index;
        }
      } catch (e) {
        debugPrint('Combo index lookup error at $index: $e');
      }
    }

    return -1;
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF1769FF),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        elevation: 8,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // ============================================================
  // FIELD LABEL
  // ============================================================

  String _typeLabel(_FormFieldType type) {
    switch (type) {
      case _FormFieldType.text:
        return 'Text Field';

      case _FormFieldType.checkbox:
        return 'Checkbox';

      case _FormFieldType.radio:
        return 'Radio Button';

      case _FormFieldType.comboBox:
        return 'Dropdown';

      case _FormFieldType.listBox:
        return 'List';
    }
  }

  // ============================================================
  // FIELD ICON
  // ============================================================

  IconData _fieldIcon(_FormFieldType type) {
    switch (type) {
      case _FormFieldType.text:
        return Icons.short_text_rounded;

      case _FormFieldType.checkbox:
        return Icons.check_box_outlined;

      case _FormFieldType.radio:
        return Icons.radio_button_checked_rounded;

      case _FormFieldType.comboBox:
        return Icons.arrow_drop_down_circle_outlined;

      case _FormFieldType.listBox:
        return Icons.format_list_bulleted_rounded;
    }
  }

  // ============================================================
  // FIELD EDITOR
  // ============================================================

  Widget _buildFieldEditor(_FormFieldItem item) {
    switch (item.type) {
      // --------------------------------------------------------
      // TEXT
      // --------------------------------------------------------

      case _FormFieldType.text:
        return TextField(
          controller: item.controller,
          maxLines: 3,
          minLines: 1,
          style: const TextStyle(color: Color(0xFF10255C), fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Enter value',
            hintStyle: const TextStyle(color: Color(0xFF9AA9BE), fontSize: 12),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.55),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.82),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.82),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(
                color: Color(0xFF12B886),
                width: 1.2,
              ),
            ),
          ),
        );

      // --------------------------------------------------------
      // CHECKBOX
      // --------------------------------------------------------

      case _FormFieldType.checkbox:
        return SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Checked',
            style: TextStyle(
              color: Color(0xFF17345F),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          value: item.boolValue ?? false,
          activeThumbColor: const Color(0xFF12B886),
          onChanged: (value) {
            setState(() {
              item.boolValue = value;
            });
          },
        );

      // --------------------------------------------------------
      // RADIO
      // --------------------------------------------------------

      case _FormFieldType.radio:
        final List<_RadioOption> radioOptions =
            item.radioOptions ?? <_RadioOption>[];

        if (radioOptions.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
            ),
            child: const Text(
              'No radio options found.',
              style: TextStyle(color: Color(0xFF74859F), fontSize: 12),
            ),
          );
        }

        return Column(
          children: List<Widget>.generate(radioOptions.length, (int index) {
            final _RadioOption option = radioOptions[index];

            final bool selected = item.value == option.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  setState(() {
                    item.value = option.value;
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFE8F8F2)
                        : Colors.white.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF12B886)
                          : Colors.white.withValues(alpha: 0.82),
                      width: selected ? 1.2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selected
                            ? const Color(0xFF12B886)
                            : const Color(0xFF8798AF),
                        size: 21,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          option.label,
                          style: TextStyle(
                            color: const Color(0xFF17345F),
                            fontSize: 12.5,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );

      // --------------------------------------------------------
      // COMBO BOX
      // --------------------------------------------------------

      case _FormFieldType.comboBox:
        final List<String> items = item.items ?? <String>[];

        return DropdownButtonFormField<String>(
          initialValue: items.contains(item.value?.toString())
              ? item.value?.toString()
              : null,
          isExpanded: true,
          items: items
              .map(
                (String value) => DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (String? value) {
            setState(() {
              item.value = value;
            });
          },
          decoration: _dropdownDecoration('Select option'),
        );

      // --------------------------------------------------------
      // LIST BOX
      // --------------------------------------------------------

      case _FormFieldType.listBox:
        final List<String> items = item.items ?? <String>[];

        return DropdownButtonFormField<String>(
          initialValue: items.contains(item.value?.toString())
              ? item.value?.toString()
              : null,
          isExpanded: true,
          items: items
              .map(
                (String value) => DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (String? value) {
            setState(() {
              item.value = value;

              item.selectedValues = value == null
                  ? <String>[]
                  : <String>[value];
            });
          },
          decoration: _dropdownDecoration('Select option'),
        );
    }
  }

  // ============================================================
  // DROPDOWN DECORATION
  // ============================================================

  InputDecoration _dropdownDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9AA9BE), fontSize: 12),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.55),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.82)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.82)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFF12B886), width: 1.2),
      ),
    );
  }

  // ============================================================
  // EMPTY FIELDS
  // ============================================================

  Widget _buildEmptyFields() {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.52),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.80)),
            ),
            child: const Icon(
              Icons.find_in_page_outlined,
              color: Color(0xFFE58A1F),
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Editable Fields',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF10255C),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _totalPdfFields > 0
                ? 'The PDF contains fields, '
                      'but the current form UI could not '
                      'map them to supported controls.'
                : 'This PDF does not contain '
                      'supported standard editable form fields.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF74859F),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SAVE BUTTON
  // ============================================================

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveForm,
          icon: _isSaving
              ? const SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_rounded),
          label: Text(
            _isSaving ? 'Saving Form...' : 'Save Filled PDF',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF12B886),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(
              0xFF12B886,
            ).withValues(alpha: 0.55),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      body: SafeArea(
        child: Stack(
          children: [
            const _FillFormsBackground(),

            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                if (_isLoading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1769FF),
                      ),
                    ),
                  )
                else ...[
                  SliverToBoxAdapter(child: _buildFileInfo()),
                  SliverToBoxAdapter(child: _buildStatusCard()),
                  if (_fields.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      sliver: _buildFieldsList(),
                    )
                  else
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyFields(),
                    ),
                  if (_fields.isNotEmpty)
                    SliverToBoxAdapter(child: _buildSaveButton()),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Row(
        children: [
          _GlassIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: _isSaving ? () {} : () => Navigator.pop(context),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fill Forms',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF10255C),
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _fields.isEmpty
                      ? 'Edit your PDF form fields'
                      : 'Fill ${_fields.length} form '
                            '${_fields.length == 1 ? 'field' : 'fields'}',
                  style: const TextStyle(
                    color: Color(0xFF7184A4),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILE INFO
  // ============================================================

  Widget _buildFileInfo() {
    final String fieldText = _totalPdfFields > 0
        ? '$_totalPdfFields '
              '${_totalPdfFields == 1 ? 'field' : 'fields'} detected'
        : 'No editable fields detected';

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF12B886).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.edit_note_rounded,
                    color: Color(0xFF12B886),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.selectedFile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF10255C),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        fieldText,
                        style: const TextStyle(
                          color: Color(0xFF7A8CA6),
                          fontSize: 11.5,
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

  // ============================================================
  // STATUS CARD
  // ============================================================

  Widget _buildStatusCard() {
    final bool hasFields = _fields.isNotEmpty;

    final bool hasPdfFields = _totalPdfFields > 0;

    final Color cardColor;
    final Color borderColor;
    final Color iconColor;
    final Color textColor;
    final IconData icon;
    final String message;

    if (hasFields) {
      cardColor = const Color(0xFFE8F8F2);
      borderColor = const Color(0xFFB9E5D4);
      iconColor = const Color(0xFF12B886);
      textColor = const Color(0xFF416C5A);
      icon = Icons.check_circle_outline_rounded;

      message =
          'Editable PDF form fields are ready. '
          'Update the values below and save the form.';
    } else if (hasPdfFields) {
      cardColor = const Color(0xFFFFF3E6);
      borderColor = const Color(0xFFF2D1A7);
      iconColor = const Color(0xFFE58A1F);
      textColor = const Color(0xFF745B40);
      icon = Icons.info_outline_rounded;

      message =
          'PDF form fields were detected, '
          'but no currently supported field types '
          'could be displayed.';
    } else {
      cardColor = const Color(0xFFFFF3E6);
      borderColor = const Color(0xFFF2D1A7);
      iconColor = const Color(0xFFE58A1F);
      textColor = const Color(0xFF745B40);
      icon = Icons.info_outline_rounded;

      message =
          'This PDF does not contain supported '
          'editable form fields. Try a fillable '
          'AcroForm PDF.';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontSize: 11.5,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FIELDS LIST
  // ============================================================

  SliverList _buildFieldsList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final _FormFieldItem item = _fields[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildFieldCard(item),
        );
      }, childCount: _fields.length),
    );
  }

  // ============================================================
  // FIELD CARD
  // ============================================================

  Widget _buildFieldCard(_FormFieldItem item) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(21),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.50),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF12B886).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _fieldIcon(item.type),
                      color: const Color(0xFF12B886),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF10255C),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _typeLabel(item.type),
                          style: const TextStyle(
                            color: Color(0xFF7A8CA6),
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              _buildFieldEditor(item),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// FORM FIELD MODEL
// ============================================================

enum _FormFieldType { text, checkbox, radio, comboBox, listBox }

class _FormFieldItem {
  final PdfField field;
  final String name;
  final _FormFieldType type;

  final TextEditingController? controller;

  bool? boolValue;
  String? value;

  List<String>? items;

  List<_RadioOption>? radioOptions;

  List<String> selectedValues;

  _FormFieldItem({
    required this.field,
    required this.name,
    required this.type,
    this.controller,
    this.boolValue,
    this.value,
    this.items,
    this.radioOptions,
    this.selectedValues = const <String>[],
  });
}

// ============================================================
// RADIO OPTION MODEL
// ============================================================

class _RadioOption {
  final String label;
  final String value;

  const _RadioOption({required this.label, required this.value});
}

// ============================================================
// GLASS ICON BUTTON
// ============================================================

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withValues(alpha: 0.38),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.80)),
              ),
              child: Icon(icon, size: 18, color: const Color(0xFF17345F)),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// BACKGROUND
// ============================================================

class _FillFormsBackground extends StatelessWidget {
  const _FillFormsBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: _BlurCircle(
              size: 300,
              color: const Color(0xFF7EB3FF).withValues(alpha: 0.26),
            ),
          ),
          Positioned(
            top: 330,
            left: -120,
            child: _BlurCircle(
              size: 250,
              color: const Color(0xFF4C8EFF).withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            bottom: -90,
            right: -80,
            child: _BlurCircle(
              size: 270,
              color: const Color(0xFF94C5FF).withValues(alpha: 0.18),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// BLUR CIRCLE
// ============================================================

class _BlurCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _BlurCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
