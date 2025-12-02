import 'package:flutter/material.dart';
import '../models/text_track_model.dart';
import 'video_editor_page_updated.dart';

class TextStyleEditor extends StatefulWidget {
  final TextTrackModel textTrack;
  final Function(TextTrackModel) onStyleUpdated;
  final Size? previewSize;
  final int initialTab;

  const TextStyleEditor({
    super.key,
    required this.textTrack,
    required this.onStyleUpdated,
    this.previewSize,
    this.initialTab = 0,
  });

  @override
  TextStyleEditorState createState() => TextStyleEditorState();
}

class TextStyleEditorState extends State<TextStyleEditor>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _textEditingController;
  late Color _selectedColor;
  late double _fontSize;
  late String _fontFamily;
  late double _rotation;

  final List<String> _fontFamilies = [
    'Arial',
    'Helvetica',
    'Times New Roman',
    'Courier New',
    'Verdana',
    'Georgia',
    'Comic Sans MS',
    'Impact',
  ];

  // Color options: Black, White + all Flutter primary colors
  final List<Color> _colorOptions = [
    Colors.black,
    Colors.white,
    ...Colors.primaries,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _textEditingController = TextEditingController(text: widget.textTrack.text);
    _selectedColor = widget.textTrack.textColor;
    _fontSize = widget.textTrack.fontSize;
    _fontFamily = widget.textTrack.fontFamily;
    _rotation = _normalizeRotation(widget.textTrack.rotation);

    // Listen to text changes for real-time updates
    _textEditingController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textEditingController.removeListener(_onTextChanged);
    _textEditingController.dispose();
    super.dispose();
  }

  /// Normalize rotation values to 0-360 degree range
  double _normalizeRotation(double rotation) {
    while (rotation < 0) {
      rotation += 360;
    }
    rotation = rotation % 360;
    if (rotation == 0 && rotation.isNegative) {
      rotation = 0;
    }
    return rotation;
  }

  /// Real-time text content update
  void _onTextChanged() {
    _updateTrack(text: _textEditingController.text);
  }

  /// Update track with new properties - called immediately on each change
  void _updateTrack({
    Color? textColor,
    double? fontSize,
    String? fontFamily,
    double? rotation,
    String? text,
  }) {
    // Update local state
    if (textColor != null) _selectedColor = textColor;
    if (fontSize != null) _fontSize = fontSize;
    if (fontFamily != null) _fontFamily = fontFamily;
    if (rotation != null) _rotation = _normalizeRotation(rotation);

    // Create updated track and notify immediately
    final updatedTrack = widget.textTrack.copyWith(
      text: text ?? _textEditingController.text,
      textColor: _selectedColor,
      fontSize: _fontSize,
      fontFamily: _fontFamily,
      rotation: _rotation,
    );

    widget.onStyleUpdated(updatedTrack);
  }

  @override
  Widget build(BuildContext context) {
    // Get bottom padding for devices with navigation bars
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return BottomSheetWrapper(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: BoxDecoration(
          color: Color(0xFF2C2C2E),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Text input field at top
            _buildTextInputHeader(),

            // Tab bar with icons
            _buildTabBar(),

            // Tab content area
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildKeyboardTab(bottomPadding),
                  _buildRotationTab(bottomPadding),
                  _buildFontTab(bottomPadding),
                  _buildSizeTab(bottomPadding),
                  _buildColorTab(bottomPadding),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextInputHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _textEditingController,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Enter text...',
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          IconButton(
            icon: Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Color(0xFF1C1C1E),
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[600],
        tabs: [
          Tab(icon: Icon(Icons.keyboard, size: 24)),
          Tab(icon: Icon(Icons.rotate_right, size: 24)),
          Tab(icon: Icon(Icons.font_download, size: 24)),
          Tab(icon: Icon(Icons.format_size, size: 24)),
          Tab(icon: Icon(Icons.color_lens, size: 24)),
        ],
      ),
    );
  }

  Widget _buildKeyboardTab(double bottomPadding) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + bottomPadding,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.keyboard, size: 48, color: Colors.grey[600]),
            SizedBox(height: 16),
            Text(
              'Tap the text field above to edit',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRotationTab(double bottomPadding) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + bottomPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Text Rotation',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 32),
          Center(
            child: Text(
              '${_rotation.round()}°',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 24),
          Slider(
            value: _rotation,
            min: 0,
            max: 360,
            divisions: 72,
            activeColor: Colors.white,
            inactiveColor: Colors.grey[700],
            onChanged: (value) {
              setState(() {
                _updateTrack(rotation: value);
              });
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0°', style: TextStyle(color: Colors.grey[400])),
              Text('90°', style: TextStyle(color: Colors.grey[400])),
              Text('270°', style: TextStyle(color: Colors.grey[400])),
              Text('360°', style: TextStyle(color: Colors.grey[400])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFontTab(double bottomPadding) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Edit Font Style',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 16 + bottomPadding,
            ),
            itemCount: _fontFamilies.length,
            itemBuilder: (context, index) {
              final font = _fontFamilies[index];
              final isSelected = _fontFamily == font;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _updateTrack(fontFamily: font);
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? Color(0xFF3A3A3C) : Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        font,
                        style: TextStyle(
                          fontFamily: font,
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSizeTab(double bottomPadding) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + bottomPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Font Size',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 32),
          Center(
            child: Text(
              '${_fontSize.round()}px',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 24),
          Slider(
            value: _fontSize,
            min: 12,
            max: 72,
            divisions: 60,
            activeColor: Colors.white,
            inactiveColor: Colors.grey[700],
            onChanged: (value) {
              setState(() {
                _updateTrack(fontSize: value);
              });
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('12px', style: TextStyle(color: Colors.grey[400])),
              Text('32px', style: TextStyle(color: Colors.grey[400])),
              Text('52px', style: TextStyle(color: Colors.grey[400])),
              Text('72px', style: TextStyle(color: Colors.grey[400])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorTab(double bottomPadding) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + bottomPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Keep title left-aligned
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Text Color',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 24),
          // Wrap layout centered with even spacing on both sides
          Wrap(
            spacing: 12, // Horizontal gap between items
            runSpacing: 12, // Vertical gap between rows
            children:
                _colorOptions.map((color) => _buildColorSwatch(color)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildColorSwatch(Color color) {
    final isSelected = _selectedColor == color;
    final isWhite = color == Colors.white;

    return GestureDetector(
      onTap: () {
        setState(() {
          _updateTrack(textColor: color);
        });
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? (isWhite ? Colors.black : Colors.white)
                : isWhite
                    ? Colors.grey[700]!
                    : Colors.transparent,
            width: isSelected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}
