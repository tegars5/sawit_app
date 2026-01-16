import 'package:flutter/material.dart';

class SwipeCompleteButton extends StatefulWidget {
  final Future<void> Function() onComplete;
  final String text;
  final Color backgroundColor;
  final Color thumbColor;

  const SwipeCompleteButton({
    super.key,
    required this.onComplete,
    this.text = 'Geser untuk Sampai',
    this.backgroundColor = const Color(0xFF00C853),
    this.thumbColor = Colors.white,
  });

  @override
  State<SwipeCompleteButton> createState() => _SwipeCompleteButtonState();
}

class _SwipeCompleteButtonState extends State<SwipeCompleteButton> {
  double _dragPosition = 0.0;
  bool _isCompleting = false;

  void _onDragUpdate(DragUpdateDetails details, double maxWidth) {
    if (_isCompleting) return;

    setState(() {
      _dragPosition += details.delta.dx;
      _dragPosition = _dragPosition.clamp(0.0, maxWidth - 60);
    });

    // Auto complete if dragged more than 80%
    if (_dragPosition > (maxWidth - 60) * 0.8) {
      _complete();
    }
  }

  void _onDragEnd() {
    if (_isCompleting) return;

    // Reset if not completed
    setState(() {
      _dragPosition = 0.0;
    });
  }

  Future<void> _complete() async {
    if (_isCompleting) return;

    setState(() {
      _isCompleting = true;
    });

    try {
      await widget.onComplete();
    } catch (e) {
      // Reset on error
      if (mounted) {
        setState(() {
          _dragPosition = 0.0;
          _isCompleting = false;
        });
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;

        return Container(
          height: 60,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Stack(
            children: [
              // Background text
              Center(
                child: Text(
                  _isCompleting ? 'Memproses...' : widget.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Draggable thumb
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                left: _dragPosition,
                top: 5,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) =>
                      _onDragUpdate(details, maxWidth),
                  onHorizontalDragEnd: (_) => _onDragEnd(),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: widget.thumbColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _isCompleting
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF00C853)),
                            ),
                          )
                        : const Icon(
                            Icons.arrow_forward,
                            color: Color(0xFF00C853),
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
