/// Creates entity IDs on the device, so records can be created offline
/// without asking the server.
abstract interface class IdGenerator {
  String newId();
}
