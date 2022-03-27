module printer;

import std.stdio;
import std.array;
import std.exception;
import std.bigint;

import stats;

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

void printBigIntRatio(BigInt n, BigInt d) {
  printBigInt(n/d);
  print(".");
  printBigInt(10 * (n%d) / d);
}

void printRatio(S)(S n, S d) {
  printNumber(n/d);
  print(".");
  printNumber(10*(n%d)/d);
}

void printBigInt(BigInt b) {
  print(b.toDecimalString());
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

void printStatLine(StatLine st) {
  size_t last_offset = 0;

  //print("n="); printNumber(st.count); print(" ");
  foreach (NativeMetric m; native_metrics[][st.metric_idx..st.metric_idx+st.metric_count]) {
    print(st.line[last_offset..m.offset]);

    if (m.overflow is null) {
      printNumber(m.value);
      if (m.min != m.max) {
        print("[");
        printNumber(m.min);
        print("…");
        printNumber(m.max);
        print(" μ=");
        printRatio(m.sum, st.count);
        print("]");
      }
    }
    else {
      BigIntMetric* b = m.overflow;
      printBigInt(b.value);
      if (b.min != b.max) {
        print("[");
        printBigInt(b.min);
        print("…");
        printBigInt(b.max);
        print(" μ=");
        printBigIntRatio(b.sum, BigInt(st.count));
        print("]");
      }
    }
    last_offset = m.offset;
  }
  //write(st.line[last_offset..$]);
  print(st.line[last_offset..$]);
  flush();
}

