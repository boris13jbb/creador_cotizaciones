import 'package:flutter/material.dart';

class SimpleColorDialog extends StatefulWidget {
  final String initialColor;

  const SimpleColorDialog(this.initialColor, {super.key});

  @override
  State<SimpleColorDialog> createState() => _SimpleColorDialogState();
}

class _SimpleColorDialogState extends State<SimpleColorDialog> {
  late TextEditingController _colorController;
  Color _currentColor = Colors.blue;

  @override
  void initState() {
    super.initState();
    _colorController = TextEditingController(text: widget.initialColor);
    if (widget.initialColor.isNotEmpty) {
      try {
        _currentColor = Color(
          int.parse(widget.initialColor.replaceAll('#', '0xFF')),
        );
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _colorController.dispose();
    super.dispose();
  }

  List<Color> getCommonColors() {
    return [
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.lightBlue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.yellow,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
      Colors.brown,
      Colors.grey,
      Colors.blueGrey,
      const Color(0xFF1A1A2E), // primary
      const Color(0xFF2D6A4F), // secondary
      const Color(0xFF40916C), // accent
      const Color(0xFFD8F3DC), // success
      const Color(0xFFFFE5E5), // error
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seleccionar Color'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 50,
            decoration: BoxDecoration(
              color: _currentColor,
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _colorController,
            decoration: const InputDecoration(
              labelText: 'Código Hexadecimal',
              hintText: '#RRGGBB',
              prefixText: '#',
            ),
            onChanged: (value) {
              if (value.length == 6) {
                try {
                  final int hexValue = int.parse('0xFF$value');
                  setState(() {
                    _currentColor = Color(hexValue);
                  });
                } catch (_) {}
              }
            },
            onSubmitted: (value) {
              if (value.length == 6) {
                try {
                  Navigator.pop(context, '#$value');
                } catch (_) {}
              }
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: getCommonColors().map((color) {
              final String hexString =
                  '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context, hexString);
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    border: Border.all(color: Colors.grey[400]!, width: 1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            final value = _colorController.text.trim();
            if (value.isNotEmpty && value.length == 6) {
              Navigator.pop(context, '#$value');
            }
          },
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}
