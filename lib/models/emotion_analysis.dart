class EmotionAnalysis {
  final Map<String, double> emotionScores;
  final String primaryEmotion;
  final String intensity;

  EmotionAnalysis({
    required this.emotionScores,
    required this.primaryEmotion,
    required this.intensity,
  });

  factory EmotionAnalysis.fromMap(Map<String, double> scores) {
    // Find the primary emotion (highest score)
    var maxEmotion = scores.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );

    // Calculate intensity
    String intensity;
    if (maxEmotion.value >= 0.7) {
      intensity = 'high';
    } else if (maxEmotion.value >= 0.4) {
      intensity = 'medium';
    } else {
      intensity = 'low';
    }

    return EmotionAnalysis(
      emotionScores: Map.from(scores),
      primaryEmotion: maxEmotion.key,
      intensity: intensity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'emotionScores': emotionScores,
      'primaryEmotion': primaryEmotion,
      'intensity': intensity,
    };
  }

  factory EmotionAnalysis.fromJson(Map<String, dynamic> json) {
    return EmotionAnalysis(
      emotionScores: Map<String, double>.from(json['emotionScores']),
      primaryEmotion: json['primaryEmotion'],
      intensity: json['intensity'],
    );
  }
}
