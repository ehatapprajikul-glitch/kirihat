import 'package:flutter/material.dart';

/// A collapsible description widget with "Read More/Less" functionality
class CollapsibleDescription extends StatefulWidget {
  final String description;
  final int previewLines;
  final bool defaultExpanded;
  final double fontSize;
  final Color? textColor;
  final Color linkColor;

  const CollapsibleDescription({
    super.key,
    required this.description,
    this.previewLines = 3,
    this.defaultExpanded = false,
    this.fontSize = 14.0,
    this.textColor,
    this.linkColor = const Color(0xFF0D9759),
  });

  @override
  State<CollapsibleDescription> createState() => _CollapsibleDescriptionState();
}

class _CollapsibleDescriptionState extends State<CollapsibleDescription> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.defaultExpanded;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.description.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedCrossFade(
          firstChild: _buildCollapsedText(),
          secondChild: _buildExpandedText(),
          crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Text(
            _isExpanded ? 'Read Less' : 'Read More',
            style: TextStyle(
              color: widget.linkColor,
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsedText() {
    return Text(
      widget.description,
      maxLines: widget.previewLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: widget.fontSize,
        color: widget.textColor ?? Colors.grey[700],
        height: 1.5,
      ),
    );
  }

  Widget _buildExpandedText() {
    // Split by newlines or bullet points for better formatting
    final lines = widget.description.split('\n');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        // Check if line starts with bullet or dash
        final trimmed = line.trim();
        if (trimmed.isEmpty) return const SizedBox(height: 8);
        
        final isBullet = trimmed.startsWith('•') || 
                        trimmed.startsWith('-') || 
                        trimmed.startsWith('*');
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isBullet) ...[
                Text(
                  '• ',
                  style: TextStyle(
                    fontSize: widget.fontSize,
                    color: widget.linkColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: Text(
                    trimmed.replaceFirst(RegExp(r'^[•\-*]\s*'), ''),
                    style: TextStyle(
                      fontSize: widget.fontSize,
                      color: widget.textColor ?? Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: Text(
                    line,
                    style: TextStyle(
                      fontSize: widget.fontSize,
                      color: widget.textColor ?? Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Optional Key Features box to display above description
class KeyFeaturesBox extends StatelessWidget {
  final List<String> features;
  final int maxFeatures;

  const KeyFeaturesBox({
    super.key,
    required this.features,
    this.maxFeatures = 4,
  });

  @override
  Widget build(BuildContext context) {
    if (features.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayFeatures = features.take(maxFeatures).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D9759).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF0D9759).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: displayFeatures.map((feature) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF0D9759),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    feature,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
