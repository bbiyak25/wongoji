import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CharacterLimitDialog extends StatefulWidget {
  final int initialLimit;
  final bool initialEnabled;

  const CharacterLimitDialog({
    Key? key,
    this.initialLimit = 900,
    this.initialEnabled = true,
  }) : super(key: key);

  @override
  State<CharacterLimitDialog> createState() => _CharacterLimitDialogState();
}

class _CharacterLimitDialogState extends State<CharacterLimitDialog> {
  late bool _isEnabled;
  late double _currentLimit;

  // Wongoji Theme Colors extracted from your canvas
  final Color wongojiRed = const Color(0xFFE57373); // Soft coral/red grid color
  final Color wongojiDarkRed = const Color(0xFFD32F2F); // Deeper red for active text
  final Color wongojiBg = const Color(0xFFFDF6E3); // Warm cream paper background
  final Color wongojiText = const Color(0xFF4A4A4A); // Soft black/grey for readability

  @override
  void initState() {
    super.initState();
    _isEnabled = widget.initialEnabled;
    _currentLimit = widget.initialLimit.toDouble();
  }

  void _addLimit(int amount) {
    setState(() {
      _currentLimit += amount;
      if (_currentLimit > 10000) _currentLimit = 10000; // Upper limit cap
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: wongojiBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4.0), // Sharper corners like paper
        side: BorderSide(color: wongojiRed.withOpacity(0.5), width: 1), // Subtle red outline
      ),
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title and Switch
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "글자수 제한 켜기",
                  style: GoogleFonts.nanumMyeongjo(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: wongojiText,
                  ),
                ),
                Switch(
                  value: _isEnabled,
                  onChanged: (val) => setState(() => _isEnabled = val),
                  activeColor: wongojiRed,
                  activeTrackColor: wongojiRed.withOpacity(0.3),
                  inactiveThumbColor: Colors.grey.shade400,
                  inactiveTrackColor: Colors.grey.shade300,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Main Display Box (Mimics a Wongoji writing cell)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: _isEnabled ? Colors.white.withOpacity(0.7) : Colors.transparent,
                border: BorderSide(
                  color: _isEnabled ? wongojiRed : Colors.grey.shade400, 
                  width: 1.5
                ),
              ),
              child: Center(
                child: Text(
                  "글자수 제한: ${_currentLimit.toInt()} 자",
                  style: GoogleFonts.nanumMyeongjo(
                    fontSize: 24,
                    color: _isEnabled ? wongojiDarkRed : Colors.grey.shade500,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Slider
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: wongojiRed,
                inactiveTrackColor: wongojiRed.withOpacity(0.2),
                thumbColor: wongojiRed,
                overlayColor: wongojiRed.withOpacity(0.1),
                trackHeight: 2.0, // Thinner, more elegant track
              ),
              child: Slider(
                value: _currentLimit,
                min: 100,
                max: 5000, 
                divisions: 49,
                onChanged: _isEnabled
                    ? (val) => setState(() => _currentLimit = val)
                    : null,
              ),
            ),
            const SizedBox(height: 24),

            // The "+ Add" Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAddButton(500),
                _buildAddButton(1000),
                _buildAddButton(3000),
              ],
            ),
            const SizedBox(height: 32),

            // Disclaimer Text
            Text(
              "많은 글쓰기의 글자수제한은 +- 10% 정도의 마진을 둡니다.",
              textAlign: TextAlign.center,
              style: GoogleFonts.nanumMyeongjo(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 32),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "취소",
                    style: GoogleFonts.nanumMyeongjo(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () {
                    // Returns the data to whatever screen opened the dialog
                    Navigator.pop(context, {
                      'enabled': _isEnabled,
                      'limit': _currentLimit.toInt(),
                    });
                  },
                  child: Text(
                    "확인",
                    style: GoogleFonts.nanumMyeongjo(
                      color: wongojiDarkRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to build the square grid-like buttons
  Widget _buildAddButton(int amount) {
    return OutlinedButton(
      onPressed: _isEnabled ? () => _addLimit(amount) : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: wongojiDarkRed,
        backgroundColor: _isEnabled ? Colors.white.withOpacity(0.5) : Colors.transparent,
        side: BorderSide(
          color: _isEnabled ? wongojiRed.withOpacity(0.6) : Colors.grey.shade300,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)), // Square grid look
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      child: Text(
        "+ $amount",
        style: GoogleFonts.nanumMyeongjo(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }
}