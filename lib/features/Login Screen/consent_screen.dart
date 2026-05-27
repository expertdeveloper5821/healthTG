import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});
  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}
class _ConsentScreenState extends State<ConsentScreen> {
  final List<bool> _checked = List.generate(5, (_) => false);
  bool get _allChecked => _checked.every((v) => v);
  final List<_ConsentItem> _items = [
    _ConsentItem(
      text:
          'Legal consent for Health TG to use personal, clinical, and social data, but not limited to it',
    ),
    _ConsentItem(
      text:
          'I consent to acquire all medical records, history, and any relevant data needed for care coordination',
    ),
    _ConsentItem(
      text: 'I agree and accept',
      linkText:
          'terms to abide by Health TG care coordination services',
    ),
    _ConsentItem(
      text:
          'I agree and accept the usage of medical devices and provide accurate data in lieu of connectivity',
    ),
    _ConsentItem(
      text:
          'I agree that Health TG is not accountable for the overall health outcome',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Scrollbar(
                thickness: 4,
                radius: const Radius.circular(10),
                child: ListView.separated(
                  padding:
                      const EdgeInsets.fromLTRB(20, 40, 20, 20), 
                  itemCount: _items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 20),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return _ConsentTile(
                      item: item,
                      checked: _checked[index],
                      onChanged: (val) {
                        setState(() =>
                            _checked[index] = val ?? false);
                      },
                    );
                  },
                ),
              ),
            ),
           Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_allChecked)
                    Padding(
                      padding:
                          const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'You can only move forward if you agree to everything above',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                          height: 1.5,
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _allChecked ? () {} : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF5CD1AE),
                        disabledBackgroundColor:
                            const Color(0xFFD0D1D1), 
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(40),
                        ),
                        elevation: _allChecked ? 6 : 0,
                      ),
                      child: Text(
                        'Get Started',
                        style: const TextStyle(
                          fontFamily: 'Mulish',
                          fontWeight: FontWeight.w500,
                          fontSize: 18,
                          height: 1.5,
                          letterSpacing: 0,
                          color: Color(0xFF1E2021),
                        ),
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
class _ConsentItem {
  final String text;
  final String? linkText;

  const _ConsentItem({
    required this.text,
    this.linkText,
  });
}
class _ConsentTile extends StatelessWidget {
  final _ConsentItem item;
  final bool checked;
  final ValueChanged<bool?> onChanged;

  const _ConsentTile({
    required this.item,
    required this.checked,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => onChanged(!checked),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: checked
                  ? const Color(0xFF5CD1AE)
                  : Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: checked
                    ? const Color(0xFF5CD1AE)
                    : const Color(0xFFB0BEC5),
                width: 2,
              ),
            ),
            child: checked
                ? const Icon(Icons.check,
                    size: 14, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: item.linkText != null
              ? RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2D3748),
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(text: '${item.text} '),
                      TextSpan(
                        text: item.linkText,
                        style: const TextStyle(
                          color: Color(0xFF5CD1AE),
                          decoration:
                              TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {},
                      ),
                    ],
                  ),
                )
              : Text(
                  item.text,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF2D3748),
                    height: 1.5,
                  ),
                ),
        ),
      ],
    );
  }
}