import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class VoiceSearchScreen extends StatefulWidget {
  const VoiceSearchScreen({super.key});

  @override
  State<VoiceSearchScreen> createState() => _VoiceSearchScreenState();
}

class _VoiceSearchScreenState extends State<VoiceSearchScreen> with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _text = 'Try saying "Milk" or "Vegetables"';
  double _soundLevel = 0.0;
  
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
       vsync: this,
       duration: const Duration(milliseconds: 1000),
       lowerBound: 0.5,
       upperBound: 1.0,
    )..repeat(reverse: true);
    
    _initSpeech();
  }

  @override
  void dispose() {
    _speech.stop();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    // Check permission first
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
         setState(() => _text = 'Microphone permission is required');
      }
      return;
    }

    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Mic Status: $status');
          if (status == 'notListening') {
             if (mounted) {
                // Determine if we should close or just show retry
                // Only auto-close if we have valid text
                if (_text != 'Try saying "Milk" or "Vegetables"' && 
                    _text != 'Listening...' && 
                    _text.isNotEmpty) {
                    // Do nothing here, let the onResult finalResult handle the pop 
                    // or the user can tap to confirm if we add a button. 
                    // But for now, we rely on _stopListening or finalResult.
                } else {
                   setState(() {
                     _isListening = false;
                     _text = 'Tap the microphone to try again';
                     _animationController.stop();
                   });
                }
             }
          }
        },
        onError: (errorNotification) {
          debugPrint('Mic Error: $errorNotification');
          if (mounted) {
             setState(() {
               _isListening = false;
               _text = "Didn't catch that. Tap to try again.";
               _animationController.stop();
             });
          }
        },
      );

      if (available) {
        _listen();
      } else {
        if (mounted) setState(() => _text = 'Speech recognition unavailable');
      }
    } catch (e) {
      debugPrint('Speech Init Error: $e');
       if (mounted) setState(() => _text = 'Error initializing speech');
    }
  }

  void _listen() {
    if (!_isListening) {
      setState(() {
        _isListening = true;
        _text = 'Listening...';
        _animationController.repeat(reverse: true);
      });
      
      _speech.listen(
        onResult: (val) {
          setState(() {
            _text = val.recognizedWords;
            if (val.hasConfidenceRating && val.confidence > 0) {
               _soundLevel = val.confidence; 
            }
          });
          
          // Wait for final result to ensure we captured the full phrase
          if (val.finalResult) {
             Future.delayed(const Duration(milliseconds: 800), () {
               if (mounted && _text.isNotEmpty) {
                 Navigator.pop(context, _text);
               }
             });
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3), // Increased to 3s to allow pauses
        partialResults: true,
        cancelOnError: false, 
        listenMode: stt.ListenMode.search,
      );
    }
  }
  
  void _stopListening() {
     _speech.stop();
     setState(() {
       _isListening = false;
       _animationController.stop();
     });
     
     // Only close if we have actual text
     if (_text != 'Try saying "Milk" or "Vegetables"' && 
         _text.isNotEmpty && 
         _text != 'Listening...') {
        Navigator.pop(context, _text);
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
           children: [
             // Close Button
             Align(
               alignment: Alignment.topLeft,
               child: IconButton(
                 icon: const Icon(Icons.close, size: 28),
                 onPressed: () => Navigator.pop(context),
               ),
             ),
             
             Expanded(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   // Recognized Text
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 32),
                     child: Text(
                       _text,
                       textAlign: TextAlign.center,
                       style: TextStyle(
                         fontSize: 24,
                         fontWeight: _isListening ? FontWeight.w500 : FontWeight.bold,
                         color: _isListening ? Colors.black87 : Colors.grey[600],
                       ),
                     ),
                   ),
                   
                   const SizedBox(height: 80),
                   
                   // Microphone Button with Ripple Animation
                   GestureDetector(
                     onTap: () {
                        if (_isListening) {
                          _stopListening();
                        } else {
                          _listen();
                        }
                     },
                     child: AnimatedBuilder(
                       animation: _animationController,
                       builder: (context, child) {
                         return Container(
                           width: 80 * (_isListening ? _animationController.value : 1.0),
                           height: 80 * (_isListening ? _animationController.value : 1.0),
                           decoration: BoxDecoration(
                             color: const Color(0xFFD9E7E0), // Light green circle
                             shape: BoxShape.circle,
                             boxShadow: _isListening ? [
                               BoxShadow(
                                 color: const Color(0xFF0D9759).withOpacity(0.3),
                                 blurRadius: 20 * _animationController.value,
                                 spreadRadius: 10 * _animationController.value,
                               )
                             ] : [],
                           ),
                           child: Center(
                             child: Container(
                               width: 64,
                               height: 64,
                               decoration: const BoxDecoration(
                                 color: Color(0xFF0D9759), // Solid Brand Green
                                 shape: BoxShape.circle,
                               ),
                               child: Icon(
                                 _isListening ? Icons.mic : Icons.mic_none,
                                 color: Colors.white,
                                 size: 32,
                               ),
                             ),
                           ),
                         );
                       },
                     ),
                   ),
                   
                   const SizedBox(height: 40),

                   // Manual Submit Button
                   if (_text != 'Try saying "Milk" or "Vegetables"' && 
                       _text != 'Listening...' && 
                       _text.isNotEmpty)
                     Padding(
                       padding: const EdgeInsets.only(bottom: 20),
                       child: ElevatedButton.icon(
                         onPressed: () => Navigator.pop(context, _text),
                         icon: const Icon(Icons.search),
                         label: const Text('Search'),
                         style: ElevatedButton.styleFrom(
                           backgroundColor: const Color(0xFF0D9759),
                           foregroundColor: Colors.white,
                           padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                         ),
                       ),
                     ),
                   
                   if (_isListening)
                    const Text(
                      'Tap to stop',
                      style: TextStyle(color: Colors.grey),
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
