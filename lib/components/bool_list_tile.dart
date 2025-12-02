import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class BooleanListTile extends StatelessWidget {
  final bool enabled;
  final String title;
  final String? subtitle;
  final ValueChanged<bool> onChanged;
  final bool? listTileEnable;

  const BooleanListTile({
    super.key,
    required this.enabled,
    required this.title,
    required this.onChanged,
    this.subtitle,
    this.listTileEnable = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: listTileEnable == true,
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 14.0,
              ),
            )
          : null,
      trailing: CupertinoSwitch(
        thumbColor: enabled
            ? const Color.fromRGBO(12, 81, 203, 1)
            : const Color.fromRGBO(126, 126, 126, 1),
        activeTrackColor: const Color.fromRGBO(24, 28, 50, 1),
        value: enabled,
        onChanged: listTileEnable == false ? (val) {} : onChanged,
      ),
    );
  }
}

class BooleanController {
  bool value;

  BooleanController({required this.value});

  onChanged({
    required bool valueValue,
  }) {
    value = valueValue;
  }
}

class BooleanListTileWithController extends StatefulWidget {
  final BooleanController booleanController;
  final String title;
  final String? subtitle;
  final bool? listTileEnable;

  const BooleanListTileWithController({
    super.key,
    required this.booleanController,
    required this.title,
    this.subtitle,
    this.listTileEnable = true,
  });

  @override
  State<BooleanListTileWithController> createState() =>
      _BooleanListTileWithControllerState();
}

class _BooleanListTileWithControllerState
    extends State<BooleanListTileWithController> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: widget.listTileEnable == true,
      contentPadding: EdgeInsets.zero,
      title: Text(widget.title),
      subtitle: widget.subtitle != null
          ? Text(
              widget.subtitle!,
              style: const TextStyle(
                fontSize: 14.0,
              ),
            )
          : null,
      trailing: CupertinoSwitch(
        thumbColor: widget.booleanController.value
            ? const Color.fromRGBO(12, 81, 203, 1)
            : const Color.fromRGBO(126, 126, 126, 1),
        activeTrackColor: const Color.fromRGBO(24, 28, 50, 1),
        value: widget.booleanController.value,
        onChanged: widget.listTileEnable == false
            ? (val) {}
            : (val) {
                widget.booleanController.onChanged(valueValue: val);
                setState(() {});
              },
      ),
    );
  }
}
