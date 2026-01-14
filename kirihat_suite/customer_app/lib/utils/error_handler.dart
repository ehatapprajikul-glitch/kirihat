import 'package:flutter/material.dart';

/// Error boundary widget for handling widget failures gracefully
class ErrorBoundary extends StatelessWidget {
  final Widget child;
  final String fallbackMessage;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.fallbackMessage = 'Something went wrong',
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// Fallback widget displayed when errors occur
class ErrorFallbackWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  const ErrorFallbackWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9759),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Network error specific widget
class NetworkErrorWidget extends StatelessWidget {
  final VoidCallback? onRetry;

  const NetworkErrorWidget({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ErrorFallbackWidget(
      message: 'Network error. Please check your connection.',
      icon: Icons.wifi_off,
      onRetry: onRetry,
    );
  }
}

/// Generic error widget for failed data loading
class LoadingErrorWidget extends StatelessWidget {
  final String? customMessage;
  final VoidCallback? onRetry;

  const LoadingErrorWidget({
    super.key,
    this.customMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorFallbackWidget(
      message: customMessage ?? 'Failed to load data',
      onRetry: onRetry,
    );
  }
}
