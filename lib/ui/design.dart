import 'dart:math';
import 'package:flutter/material.dart';

abstract final class KopiColors {
  static const background = Color(0xFFFCFAF8);
  static const ink = Color(0xFF4D4747);
  static const muted = Color(0xFF9C8C95);
  static const accent = Color(0xFFE9C2D2);
  static const soft = Color(0xFFF0DEE7);
  static const line = Color(0xFFE9DFE3);
  static const berry = Color(0xFF936D83);
  static const sage = Color(0xFFD8E0C4);
  static const lavender = Color(0xFFD8CAE6);
  static const sand = Color(0xFFF0DAB1);
  static const error = Color(0xFFAC4E64);
}

ThemeData kopiTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: KopiColors.background,
  fontFamily: 'Inter',
  colorScheme:
      ColorScheme.fromSeed(
        seedColor: KopiColors.accent,
        brightness: Brightness.light,
      ).copyWith(
        primary: KopiColors.berry,
        surface: KopiColors.background,
        onSurface: KopiColors.ink,
        error: KopiColors.error,
      ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 14, color: KopiColors.ink),
    bodySmall: TextStyle(fontSize: 12, color: KopiColors.muted),
  ),
  dividerTheme: const DividerThemeData(
    color: KopiColors.line,
    thickness: 0.7,
    space: 1,
  ),
  textSelectionTheme: const TextSelectionThemeData(
    cursorColor: KopiColors.berry,
    selectionColor: KopiColors.soft,
    selectionHandleColor: KopiColors.berry,
  ),
);

class Heading extends StatelessWidget {
  final String text;
  final double size;
  final TextAlign? align;
  const Heading(this.text, {super.key, this.size = 27, this.align});
  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: align,
    style: TextStyle(
      fontFamily: 'PTSerif',
      fontSize: size,
      height: 1.17,
      color: KopiColors.ink,
    ),
  );
}

class Flower extends StatelessWidget {
  final double size;
  const Flower({super.key, this.size = 72});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: _FlowerPainter()),
  );
}

class _FlowerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..color = const Color(0xFFE0B9CC);
    for (var i = 0; i < 5; i++) {
      final a = -pi / 2 + i * 2 * pi / 5;
      canvas.drawCircle(
        center + Offset(cos(a), sin(a)) * size.width * .29,
        size.width * .185,
        paint,
      );
    }
    canvas.drawCircle(
      center,
      size.width * .16,
      Paint()..color = KopiColors.background,
    );
  }

  @override
  bool shouldRepaint(_FlowerPainter oldDelegate) => false;
}

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Копи',
    child: const ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'копи',
            style: TextStyle(
              fontFamily: 'PTSerif',
              fontStyle: FontStyle.italic,
              fontSize: 29,
              height: 1,
            ),
          ),
          Flower(size: 23),
        ],
      ),
    ),
  );
}

enum Glyph {
  back,
  next,
  leaf,
  flag,
  calendar,
  home,
  plus,
  overview,
  person,
  coffee,
  bag,
  bus,
  movie,
}

class LineIcon extends StatelessWidget {
  final Glyph glyph;
  final double size;
  final Color color;
  const LineIcon(
    this.glyph, {
    super.key,
    this.size = 24,
    this.color = KopiColors.berry,
  });
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _IconPainter(glyph, color),
    ),
  );
}

class _IconPainter extends CustomPainter {
  final Glyph glyph;
  final Color color;
  _IconPainter(this.glyph, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void path(List<Offset> points) {
      final v = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        v.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(v, p);
    }

    void line(double x, double y, double x2, double y2) =>
        canvas.drawLine(Offset(x, y), Offset(x2, y2), p);
    switch (glyph) {
      case Glyph.back:
        path([const Offset(14, 5), const Offset(7, 12), const Offset(14, 19)]);
      case Glyph.next:
        path([const Offset(10, 5), const Offset(17, 12), const Offset(10, 19)]);
      case Glyph.plus:
        line(12, 5, 12, 19);
        line(5, 12, 19, 12);
      case Glyph.home:
        path([const Offset(2, 10), const Offset(12, 2), const Offset(22, 10)]);
        path([
          const Offset(5, 9),
          const Offset(5, 22),
          const Offset(19, 22),
          const Offset(19, 9),
        ]);
        path([
          const Offset(9, 22),
          const Offset(9, 13),
          const Offset(15, 13),
          const Offset(15, 22),
        ]);
      case Glyph.flag:
        line(5, 22, 5, 3);
        path([
          const Offset(5, 3),
          const Offset(19, 3),
          const Offset(15, 8),
          const Offset(19, 12),
          const Offset(5, 12),
        ]);
      case Glyph.calendar:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(5, 5, 14, 16),
            const Radius.circular(1),
          ),
          p,
        );
        line(8, 2, 8, 7);
        line(16, 2, 16, 7);
        line(5, 10, 19, 10);
        line(9, 14, 11, 14);
        line(14, 14, 15, 14);
        line(9, 17, 11, 17);
      case Glyph.overview:
        canvas.drawRect(const Rect.fromLTWH(4, 10, 3, 11), p);
        canvas.drawRect(const Rect.fromLTWH(11, 4, 3, 17), p);
        canvas.drawRect(const Rect.fromLTWH(18, 7, 3, 14), p);
      case Glyph.person:
        canvas.drawCircle(const Offset(12, 6), 4, p);
        canvas.drawArc(const Rect.fromLTWH(4, 10, 16, 20), pi, pi, false, p);
      case Glyph.leaf:
        canvas.drawPath(
          Path()
            ..moveTo(5, 18)
            ..cubicTo(0, 8, 10, 3, 20, 3)
            ..cubicTo(22, 15, 14, 21, 5, 18),
          p,
        );
        line(4, 22, 16, 8);
      case Glyph.coffee:
        path([
          const Offset(5, 8),
          const Offset(6, 18),
          const Offset(15, 18),
          const Offset(16, 8),
          const Offset(5, 8),
        ]);
        canvas.drawArc(const Rect.fromLTWH(13, 8, 8, 7), -pi / 2, pi, false, p);
        line(3, 21, 19, 21);
        line(8, 3, 8, 5);
        line(12, 2, 12, 4);
      case Glyph.bag:
        path([
          const Offset(6, 8),
          const Offset(18, 8),
          const Offset(20, 22),
          const Offset(4, 22),
          const Offset(6, 8),
        ]);
        canvas.drawArc(const Rect.fromLTWH(8, 2, 8, 12), pi, pi, false, p);
      case Glyph.bus:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(4, 4, 16, 15),
            const Radius.circular(3),
          ),
          p,
        );
        line(4, 11, 20, 11);
        line(7, 19, 7, 22);
        line(17, 19, 17, 22);
        line(7, 15, 8, 15);
        line(16, 15, 17, 15);
        line(8, 1, 16, 1);
      case Glyph.movie:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(4, 3, 16, 18),
            const Radius.circular(2),
          ),
          p,
        );
        path([
          const Offset(10, 8),
          const Offset(16, 12),
          const Offset(10, 16),
          const Offset(10, 8),
        ]);
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.glyph != glyph || old.color != color;
}

class KopiButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool secondary, busy;
  const KopiButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.secondary = false,
    this.busy = false,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: secondary ? KopiColors.soft : KopiColors.accent,
        foregroundColor: KopiColors.ink,
        disabledBackgroundColor: KopiColors.soft,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          height: 1.4,
        ),
        elevation: 0,
      ),
      child: busy
          ? const SizedBox.square(
              dimension: 19,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            )
          : Text(label, textAlign: TextAlign.center),
    ),
  );
}

class HelpButton extends StatelessWidget {
  final VoidCallback onPressed;
  const HelpButton({super.key, required this.onPressed});
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Помощь',
    onPressed: onPressed,
    icon: Container(
      width: 27,
      height: 27,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFDCC5D2), width: .8),
      ),
      child: const Text(
        '?',
        style: TextStyle(
          fontFamily: 'PTSerif',
          fontSize: 15,
          color: KopiColors.berry,
        ),
      ),
    ),
  );
}

class KopiField extends StatelessWidget {
  final String label, hint;
  final TextEditingController controller;
  final bool password, moneyInput;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction action;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  const KopiField({
    super.key,
    required this.label,
    required this.controller,
    this.hint = '',
    this.password = false,
    this.moneyInput = false,
    this.validator,
    this.keyboardType,
    this.action = TextInputAction.next,
    this.onSubmitted,
    this.autofillHints,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 23),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: KopiColors.muted),
        ),
        TextFormField(
          controller: controller,
          obscureText: password,
          autocorrect: !password && !moneyInput,
          enableSuggestions: !password && !moneyInput,
          autofillHints: autofillHints,
          keyboardType: moneyInput
              ? const TextInputType.numberWithOptions(decimal: true)
              : keyboardType,
          textInputAction: action,
          onFieldSubmitted: onSubmitted,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: const TextStyle(fontSize: 15, color: KopiColors.ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFD4CFD1), fontSize: 15),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: KopiColors.line),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: KopiColors.berry),
            ),
            errorMaxLines: 3,
            errorStyle: const TextStyle(fontSize: 11),
          ),
        ),
      ],
    ),
  );
}

Future<void> showKopiMessage(
  BuildContext context,
  String title,
  String message,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: KopiColors.background,
  builder: (sheetContext) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Heading(title),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              height: 1.7,
              color: KopiColors.muted,
            ),
          ),
          const SizedBox(height: 26),
          KopiButton('Понятно', onPressed: () => Navigator.pop(sheetContext)),
        ],
      ),
    ),
  ),
);
