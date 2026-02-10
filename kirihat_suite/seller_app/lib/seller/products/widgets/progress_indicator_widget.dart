import 'package:flutter/material.dart';

/// Multi-step progress indicator widget for product listing form
class ProgressIndicatorWidget extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> stepLabels;

  const ProgressIndicatorWidget({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.stepLabels,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Use horizontal scrollable on mobile or smaller screens
          if (constraints.maxWidth < 1100) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildStepRow(),
            );
          }
          return Center(child: _buildStepRow());
        },
      ),
    );
  }

  Widget _buildStepRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalSteps, (index) {
        bool isLast = index == totalSteps - 1;
        return Row(
          children: [
            _StepNode(
              stepNumber: index + 1,
              stepLabel: stepLabels[index],
              status: _getStepStatus(index),
            ),
            if (!isLast) _StepConnector(isCompleted: index < currentStep),
          ],
        );
      }),
    );
  }

  StepStatus _getStepStatus(int index) {
    if (index < currentStep) return StepStatus.completed;
    if (index == currentStep) return StepStatus.current;
    return StepStatus.pending;
  }
}

enum StepStatus { completed, current, pending }

class _StepNode extends StatefulWidget {
  final int stepNumber;
  final String stepLabel;
  final StepStatus status;

  const _StepNode({
    required this.stepNumber,
    required this.stepLabel,
    required this.status,
  });

  @override
  State<_StepNode> createState() => _StepNodeState();
}

class _StepNodeState extends State<_StepNode> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    if (widget.status == StepStatus.current) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_StepNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == StepStatus.current && oldWidget.status != StepStatus.current) {
      _animationController.repeat(reverse: true);
    } else if (widget.status != StepStatus.current) {
      _animationController.stop();
      _animationController.reset();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: widget.status == StepStatus.current ? _scaleAnimation.value : 1.0,
              child: child,
            );
          },
          child: Container(
            width: widget.status == StepStatus.current ? 48 : 40,
            height: widget.status == StepStatus.current ? 48 : 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getCircleColor(),
              border: widget.status == StepStatus.pending
                  ? Border.all(color: Colors.grey.shade400, width: 2)
                  : null,
            ),
            child: Center(
              child: widget.status == StepStatus.completed
                  ? const Icon(Icons.check, color: Colors.white, size: 24)
                  : Text(
                      '${widget.stepNumber}',
                      style: TextStyle(
                        color: widget.status == StepStatus.pending
                            ? Colors.grey.shade600
                            : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 100,
          child: Text(
            widget.stepLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: widget.status == StepStatus.current
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: _getTextColor(),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getCircleColor() {
    switch (widget.status) {
      case StepStatus.completed:
        return const Color(0xFF34A853); // Green
      case StepStatus.current:
        return const Color(0xFF34A853); // Green
      case StepStatus.pending:
        return Colors.transparent; // Outlined only
    }
  }

  Color _getTextColor() {
    switch (widget.status) {
      case StepStatus.completed:
        return const Color(0xFF34A853);
      case StepStatus.current:
        return const Color(0xFF34A853);
      case StepStatus.pending:
        return Colors.grey.shade600;
    }
  }
}

class _StepConnector extends StatelessWidget {
  final bool isCompleted;

  const _StepConnector({required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30, // Reduced from 60 to prevent overflow
      height: 2,
      margin: const EdgeInsets.only(bottom: 40),
      color: isCompleted ? const Color(0xFF34A853) : Colors.grey.shade300,
    );
  }
}
