import 'package:flutter/material.dart';
import 'floating_cart_button.dart';

class DraggableCartWrapper extends StatefulWidget {
  final Widget child;

  const DraggableCartWrapper({super.key, required this.child});

  @override
  State<DraggableCartWrapper> createState() => _DraggableCartWrapperState();
}

class _DraggableCartWrapperState extends State<DraggableCartWrapper> {
  // If offset is null, we use the default position (bottom-right)
  Offset? _offset;
  final GlobalKey _buttonKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // The main screen content
            widget.child,

            // The Draggable Button
            if (_offset == null)
              Positioned(
                bottom: 20,
                right: 16,
                child: _buildDraggableContent(constraints),
              )
            else
              Positioned(
                left: _offset!.dx,
                top: _offset!.dy,
                child: _buildDraggableContent(constraints),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDraggableContent(BoxConstraints constraints) {
    return GestureDetector(
      key: _buttonKey,
      onPanUpdate: (details) {
        // If we haven't started dragging yet (offset is null), 
        // calculate the starting absolute position based on 'bottom-right'
        if (_offset == null) {
          final RenderBox? renderBox = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
          if (renderBox != null) {
             final buttonSize = renderBox.size;
             // Start from bottom-right of the AVAILABLE space (constraints)
             // dx = maxWidth - buttonWidth - 16
             // dy = maxHeight - buttonHeight - 20
             _offset = Offset(
               constraints.maxWidth - buttonSize.width - 16, 
               constraints.maxHeight - buttonSize.height - 20
             );
          } else {
             _offset = details.localPosition; // Fallback
          }
        }

        if (_offset == null) return;

        setState(() {
          double newX = _offset!.dx + details.delta.dx;
          double newY = _offset!.dy + details.delta.dy;
          
          // Clamp to layout bounds (safe area)
          final RenderBox? renderBox = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
          final buttonSize = renderBox?.size ?? const Size(100, 56); 

          // Prevent going off area
          if (newX < 0) newX = 0;
          if (newX > constraints.maxWidth - buttonSize.width) newX = constraints.maxWidth - buttonSize.width;
          if (newY < 0) newY = 0;
          if (newY > constraints.maxHeight - buttonSize.height) newY = constraints.maxHeight - buttonSize.height;

          _offset = Offset(newX, newY);
        });
      },
      onPanEnd: (details) {
        if (_offset == null) return;
        
        // Snap to edge of the AVAILABLE space
        final parentWidth = constraints.maxWidth;
        final RenderBox? renderBox = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
        final buttonWidth = renderBox?.size.width ?? 100;

        final centerX = _offset!.dx + (buttonWidth / 2);
        
        double targetX;
        if (centerX < parentWidth / 2) {
          targetX = 16; // Left edge padding
        } else {
          targetX = parentWidth - buttonWidth - 16; // Right edge padding
        }

        setState(() {
          _offset = Offset(targetX, _offset!.dy);
        });
      },
      child: const FloatingCartButton(),
    );
  }
}
