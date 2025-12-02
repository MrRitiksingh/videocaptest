import 'package:flutter/material.dart';

class DurationSelector extends StatefulWidget {
  const DurationSelector({
    super.key,
    required this.initialDuration,
    required this.onSelect,
  });

  final int initialDuration;
  final void Function(int) onSelect;

  @override
  State<DurationSelector> createState() => _DurationSelectorState();
}

class _DurationSelectorState extends State<DurationSelector> {
  late final ValueNotifier<int> _selectedSeconds;

  @override
  void initState() {
    super.initState();
    _selectedSeconds = ValueNotifier(widget.initialDuration);
  }

  @override
  void dispose() {
    _selectedSeconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await _pickSeconds(context);
        if (result != null) {
          _selectedSeconds.value = result;
          widget.onSelect(result);
        }
      },
      child: CircleAvatar(
        radius: 15,
        backgroundColor: Colors.white,
        child: ValueListenableBuilder<int>(
          valueListenable: _selectedSeconds,
          builder: (context, selectedSeconds, _) {
            return Text(selectedSeconds.toString());
          },
        ),
      ),
    );
  }

  Future<int?> _pickSeconds(BuildContext context) async {
    final tempSelectedSeconds = ValueNotifier<int>(_selectedSeconds.value);

    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Seconds',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(
                height: 200,
                child: ValueListenableBuilder<int>(
                  valueListenable: tempSelectedSeconds,
                  builder: (context, selectedSeconds, _) {
                    return ListWheelScrollView.useDelegate(
                      itemExtent: 50,
                      physics: FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (value) {
                        tempSelectedSeconds.value = value + 1;
                      },
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: 10,
                        builder: (context, index) {
                          final isSelected = (index + 1) == selectedSeconds;
                          return Center(
                            child: Text(
                              (index + 1).toString(),
                              style: TextStyle(
                                fontSize: isSelected ? 28 : 24,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(tempSelectedSeconds.value);
                },
                child: Text('Confirm'),
              ),
            ],
          ),
        );
      },
    );

    tempSelectedSeconds.dispose();
    return result;
  }
}
