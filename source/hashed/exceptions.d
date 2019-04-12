module hashed.exceptions;

class HashedException : Exception {
  this(string message, string file = __FILE__, size_t line = __LINE__) {
    super(message, file, line);
  }
}