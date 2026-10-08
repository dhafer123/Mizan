/// Which tier read a phrase.
enum ParseMethod {
  /// The rule parser alone.
  rules,

  /// The on-device LLM, after the rules weren't sure.
  llm,
}
