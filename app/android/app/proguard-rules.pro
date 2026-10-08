# The on-device assistant (flutter_gemma 0.12.6, MediaPipe LLM inference).
# Rules from the plugin's README; R8 strips these otherwise.
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**
-keep class com.google.ai.edge.localagents.** { *; }
-dontwarn com.google.ai.edge.localagents.**
