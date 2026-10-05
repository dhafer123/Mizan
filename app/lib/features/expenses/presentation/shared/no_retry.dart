/// Retry policy for providers that read the local database: a failure there
/// won't fix itself, so show it at once and let the user retry.
Duration? noRetry(int retryCount, Object error) => null;
