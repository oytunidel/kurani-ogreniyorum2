import 'package:flutter/material.dart';

class AppColors {
  static const Color green = Color(0xFF58CC02);
  static const Color greenDark = Color(0xFF46A302);
  static const Color greenBg = Color(0xFFD7FFB8);
  static const Color blue = Color(0xFF1CB0F6);
  static const Color blueDark = Color(0xFF1899D6);
  static const Color blueBg = Color(0xFFDDF4FF);
  static const Color orange = Color(0xFFFF9600);
  static const Color orangeDark = Color(0xFFD97D00);
  static const Color orangeBg = Color(0xFFFFEFD2);
  static const Color red = Color(0xFFFF4B4B);
  static const Color redDark = Color(0xFFD33131);
  static const Color redBg = Color(0xFFFFDFE0);
  static const Color gold = Color(0xFFFFC800);
  static const Color goldDark = Color(0xFFD9A800);
  static const Color purple = Color(0xFFCE82FF);
  static const Color gray = Color(0xFFE5E5E5);
  static const Color grayDark = Color(0xFFAFAFAF);
  static const Color text = Color(0xFF3C3C3C);
  static const Color textLight = Color(0xFF777777);
}

class Button3D extends StatefulWidget {
  const Button3D({
    super.key,
    required this.label,
    required this.onTap,
    this.color = AppColors.green,
    this.shadowColor = AppColors.greenDark,
    this.textColor = Colors.white,
    this.icon,
    this.expand = true,
    this.height = 54,
    this.fontSize = 17,
  });

  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Color shadowColor;
  final Color textColor;
  final IconData? icon;
  final bool expand;
  final double height;
  final double fontSize;

  @override
  State<Button3D> createState() => _Button3DState();
}

class _Button3DState extends State<Button3D> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null;
    final Color face = enabled ? widget.color : AppColors.gray;
    final Color edge = enabled ? widget.shadowColor : AppColors.grayDark;
    final Color fg = enabled ? widget.textColor : AppColors.grayDark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        margin: EdgeInsets.only(top: _down ? 4 : 0),
        padding: EdgeInsets.only(bottom: _down ? 0 : 4),
        decoration: BoxDecoration(
          color: edge,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          height: widget.height,
          width: widget.expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            color: face,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: fg, size: widget.fontSize + 5),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: widget.fontSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Card3D extends StatefulWidget {
  const Card3D({
    super.key,
    required this.child,
    required this.onTap,
    this.face = Colors.white,
    this.edge = AppColors.gray,
    this.width,
    this.height,
    this.radius = 18,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color face;
  final Color edge;
  final double? width;
  final double? height;
  final double radius;

  @override
  State<Card3D> createState() => _Card3DState();
}

class _Card3DState extends State<Card3D> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: widget.width,
        margin: EdgeInsets.only(top: _down ? 4 : 0),
        padding: EdgeInsets.only(bottom: _down ? 0 : 4),
        decoration: BoxDecoration(
          color: widget.edge,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
        child: Container(
          height: widget.height == null ? null : widget.height! - 4,
          decoration: BoxDecoration(
            color: widget.face,
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(color: widget.edge, width: 2),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(width: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
      ],
    );
  }
}
