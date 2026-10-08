/// Why quick input couldn't listen, read or set up the assistant.
enum QuickInputError {
  /// No microphone permission, or no speech recognizer on this phone.
  micUnavailable,

  /// The recognizer stopped with an error.
  speechFailed,

  /// Listening ended without any words.
  nothingHeard,

  /// The assistant model isn't downloaded.
  modelNotInstalled,

  /// The model download failed or was stopped.
  downloadFailed,

  /// The model failed or took too long to answer.
  llmFailed,

  /// The model's answer didn't match the expected JSON, or named things
  /// that weren't said.
  llmInvalid,
}
