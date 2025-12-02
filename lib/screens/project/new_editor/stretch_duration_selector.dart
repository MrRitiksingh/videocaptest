import 'package:flutter/material.dart';

class StretchDurationSelector extends StatefulWidget {
  const StretchDurationSelector({
    super.key,
    required this.currentDuration,
    required this.onDurationSelected,
    this.minDuration = 1.0,
    this.maxDuration = 30.0,
    this.title = 'Stretch Duration',
    this.loadingText = 'Processing...',
  });

  final int currentDuration;
  final Function(double) onDurationSelected;
  final double minDuration;
  final double maxDuration;
  final String title;
  final String loadingText;

  @override
  State<StretchDurationSelector> createState() =>
      _StretchDurationSelectorState();
}

class _StretchDurationSelectorState extends State<StretchDurationSelector>
    with SingleTickerProviderStateMixin {
  late double _selectedDuration;
  bool _isProcessing = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _selectedDuration = widget.currentDuration.toDouble();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onDurationChanged(double value) {
    setState(() {
      _selectedDuration = value;
    });
  }

  Future<void> _applyStretch() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await widget.onDurationSelected(_selectedDuration);
      if (mounted) {
        Navigator.pop(context, _selectedDuration);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to stretch: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  String _formatDuration(double seconds) {
    if (seconds < 60) {
      return '${seconds.toInt()}s';
    }

    final duration = Duration(seconds: seconds.toInt());
    final minutes = duration.inMinutes;
    final remainingSeconds = duration.inSeconds % 60;

    if (remainingSeconds == 0) {
      return '${minutes}m';
    }

    return '${minutes}m ${remainingSeconds}s';
  }

  double get _stretchRatio => _selectedDuration / widget.currentDuration;

  Widget _buildLoadingOverlay() {
    if (!_isProcessing) return const SizedBox.shrink();

    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                widget.loadingText,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDurationDisplay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDurationColumn(
                'Current',
                _formatDuration(widget.currentDuration.toDouble()),
                Colors.white,
              ),
              const Icon(Icons.arrow_forward, color: Colors.white70),
              _buildDurationColumn(
                'New',
                _formatDuration(_selectedDuration),
                Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStretchRatioIndicator(),
        ],
      ),
    );
  }

  Widget _buildDurationColumn(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStretchRatioIndicator() {
    final ratio = _stretchRatio;
    final String ratioText;
    final Color ratioColor;

    if (ratio > 1.0) {
      ratioText = '${ratio.toStringAsFixed(1)}x slower';
      ratioColor = Colors.orange;
    } else if (ratio < 1.0) {
      ratioText = '${(1 / ratio).toStringAsFixed(1)}x faster';
      ratioColor = Colors.green;
    } else {
      ratioText = 'No change';
      ratioColor = Colors.white70;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: ratioColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ratioColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        ratioText,
        style: TextStyle(
          color: ratioColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSliderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Duration: ${_formatDuration(_selectedDuration)}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        const SizedBox(height: 10),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.blue,
            inactiveTrackColor: Colors.grey[600],
            thumbColor: Colors.blue,
            overlayColor: Colors.blue.withValues(alpha: 0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            trackHeight: 4,
            valueIndicatorColor: Colors.blue,
            valueIndicatorTextStyle: const TextStyle(color: Colors.white),
          ),
          child: Slider(
            value: _selectedDuration,
            min: widget.minDuration,
            max: widget.maxDuration,
            divisions: (widget.maxDuration - widget.minDuration).toInt(),
            label: _formatDuration(_selectedDuration),
            onChanged: _isProcessing ? null : _onDurationChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(widget.minDuration),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              _formatDuration(widget.maxDuration),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Stack(
        children: [
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
              minHeight: 300,
            ),
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed:
                            _isProcessing ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Duration Display
                  _buildDurationDisplay(),

                  const SizedBox(height: 20),

                  // Slider Section
                  _buildSliderSection(),

                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isProcessing
                              ? null
                              : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white70),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _applyStretch,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Apply',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _buildLoadingOverlay(),
        ],
      ),
    );
  }
}
