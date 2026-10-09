/// Where a category suggestion came from, strongest first.
enum CategorySource {
  /// The user's own earlier choice for the same note.
  memory,

  /// The keyword list.
  rules,

  /// The on-device LLM.
  llm,
}
