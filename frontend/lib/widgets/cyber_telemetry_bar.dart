import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/atlas_theme.dart';

/// Bottom ticker bar displaying live cyber telemetry logs & system stats
class CyberTelemetryBar extends StatefulWidget {
  final bool isConnected;
  final bool isListening;
  final bool isSpeaking;
  final String modelName;

  const CyberTelemetryBar({
    super.key,
    required this.isConnected,
    required this.isListening,
    required this.isSpeaking,
    required this.modelName,
  });

  @override
  State<CyberTelemetryBar> createState() => _CyberTelemetryBarState();
}

class _CyberTelemetryBarState extends State<CyberTelemetryBar> {
  Timer? _timer;
  int _ticks = 0;

  final List<String> _baseLogs = [
    'SYSTEM: READY',
    'WS: PORT 8000',
    'VAD: ONLINE',
    'WAKE_WORD: "HEY ATLAS"',
    'NEURAL_CORE: ACTIVE',
    'MEMORY: 482MB / 16GB',
    'STT: GOOGLE_ENGINE',
    'TTS: LOCAL_SYNTH',
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _ticks++;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = widget.isConnected ? AtlasColors.neonGreen : const Color(0xFFFF5F57);
    final statusText = widget.isConnected ? 'ONLINE' : 'DISCONNECTED';
    final stateLabel = widget.isListening
        ? 'LISTENING...'
        : widget.isSpeaking
            ? 'SPEAKING...'
            : 'IDLE';

    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF080914).withOpacity(0.95),
        border: Border(
          top: BorderSide(
            color: AtlasColors.neonPurple.withOpacity(0.18),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Live status dot
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.8),
                  blurRadius: 6,
                )
              ],
            ),
          ),
          const SizedBox(width: 8),

          Text(
            'ATLAS v1.0.0 [$statusText]',
            style: TextStyle(
              color: statusColor,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(width: 12),
          _verDivider(),
          const SizedBox(width: 12),

          Icon(Icons.developer_board_rounded, size: 12, color: AtlasColors.neonCyan),
          const SizedBox(width: 4),
          Text(
            'MODEL: ${widget.modelName}',
            style: const TextStyle(
              color: AtlasColors.neonCyan,
              fontSize: 10.5,
              fontFamily: 'monospace',
            ),
          ),

          const SizedBox(width: 12),
          _verDivider(),
          const SizedBox(width: 12),

          Text(
            'STATE: $stateLabel',
            style: TextStyle(
              color: widget.isListening
                  ? AtlasColors.neonGreen
                  : widget.isSpeaking
                      ? AtlasColors.neonPink
                      : AtlasColors.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),

          const Spacer(),

          // Telemetry ticker items
          Text(
            _baseLogs[_ticks % _baseLogs.length],
            style: TextStyle(
              color: AtlasColors.neonPurple.withOpacity(0.85),
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 12),
          _verDivider(),
          const SizedBox(width: 12),

          Text(
            'WAKE WORD: "Hey Atlas"',
            style: TextStyle(
              color: AtlasColors.neonGreen.withOpacity(0.8),
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _verDivider() => Container(
        width: 1,
        height: 10,
        color: AtlasColors.border.withOpacity(0.6),
      );
}
