module printer;

import std.stdio;
import std.array;
import std.exception;

char[4096] writeBuffer;
size_t writeBufferLength = 0;

void flush() {
  stdout.rawWrite(writeBuffer[0..writeBufferLength]);
  writeBufferLength = 0;
}

void print(char c) {
  if (writeBufferLength == writeBuffer.length) {
    flush();
  }
  writeBuffer[writeBufferLength++] = c;
}

void print(char[] str) {
  foreach (char c; str) {
    print(c);
  }
}

void print(string str) {
  print(cast(char[])str);
}

void printNumber(S)(S n) {

  // Use format to figure out how large a size_t is (it's 20)
  import std.format;
  char[format!"%d"(n.max).length] buf;

  size_t numDigits = 0;
  if (n == 0) {
    print('0');
    return;
  }

  // No reason to deal with negatives

  while (n > 0) {
    buf[numDigits++] = '0' + (n%10);
    n /= 10;
  }
  for (size_t i=1; i<=numDigits; i++) {
    print(buf[numDigits-i]);
  }
}

