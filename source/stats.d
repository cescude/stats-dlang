module stats;

import std.stdio;
import std.algorithm.comparison;
import std.array;
import std.bigint;
import core.checkedint;

import printer;

struct StatLine {
  char[] line;			// line with all numbers removed
  ulong count;			// number of times this StatLine has been seen
  size_t metric_idx;
  size_t metric_count;
}

struct NativeMetric {
  size_t offset;		// how far into ^^line^^ this metric should be printed
  ulong value;			// last read value, updated with each read
  ulong min;			// minimum value found
  ulong max;			// ...
  ulong sum;			// used to compute average (sum/count)

  // If any of the above ulongs overflow (most likely `sum`,
  // though...), we switch over and store the data in the following
  // `overflow` structure.
  
  BigIntMetric* overflow;	// non-null in the case of overflow
}

struct BigIntMetric {
  BigInt value;
  BigInt min;
  BigInt max;
  BigInt sum;
} 

auto native_metrics = appender!(NativeMetric[]);
auto bigint_metrics = appender!(BigIntMetric[]);

StatLine createStatLine(char[] line) {
  size_t m0 = native_metrics[].length;
  auto trimmed_line = appender!(char[]);

  for (size_t i=0; i<line.length; i++ ) {
    if (line[i] < '0' || line[i] > '9') {
      trimmed_line.put(line[i]);
      continue;
    }

    bool overflow = false; 
    ulong value;
    BigInt bigint_value;

    // Attempts to scan a ulong into `value`; detect overflow & use a bigint on
    // failure.
    i = scanNumber(line, i, value, bigint_value, overflow);

    // No matter what we have a NativeMetric, even if `value` is nonsense due
    // to overflow.
    native_metrics.put(NativeMetric(
      trimmed_line[].length, value, value, value, value, null
    ));

    if (overflow) {
      NativeMetric* m = &native_metrics[][$-1];
      extendMetric(m, BigInt(0), bigint_value, bigint_value);
      updateBigIntMetric(m, bigint_value);
    }

    trimmed_line.put(line[i]);
  }

  return StatLine(trimmed_line[], 1, m0, native_metrics[].length - m0);
}

unittest {
  import std.format;

  native_metrics.clear();
  bigint_metrics.clear();

  StatLine st0 = createStatLine(cast(char[])"one 123 two 234\n");
  assert(st0.line == cast(char[])"one  two \n");
  assert(st0.metric_idx == 0);
  assert(st0.metric_count == 2);
  assert(native_metrics[][0].offset == 4);
  assert(native_metrics[][0].value == 123);
  assert(native_metrics[][0].overflow is null);
  assert(native_metrics[][1].offset == 9);
  assert(native_metrics[][1].value == 234);
  assert(native_metrics[][1].overflow is null);

  StatLine st1 = createStatLine(cast(char[])"no numbers\n");
  assert(st1.line == cast(char[])"no numbers\n");
  assert(st1.metric_count == 0);

  // If the number is too large to fit in a ulong, it should be extended into a bigint
  StatLine st2 = createStatLine(cast(char[])format("something 1%d\n", ulong.max));
  assert(st2.line == cast(char[])"something \n");
  assert(st2.metric_count == 1);
  NativeMetric* m = &native_metrics[][st2.metric_idx];
  assert(m.offset == 10);

  // Numeric data is stored in the "overflow" structure
  assert(m.overflow !is null);
  assert(m.overflow.value == BigInt(format("1%d", ulong.max)));
}

// Folds the data from `line` into the metrics associated w/ `st`
void updateStatLine(ref StatLine st, char[] line) {

  st.count++;

  NativeMetric* m = &native_metrics[][st.metric_idx];

  for (size_t i=0; i<line.length; i++) {
    if (line[i] < '0' || line[i] > '9') continue;

    bool overflow = m.overflow !is null;
    ulong value;
    BigInt bigint_value;

    i = scanNumber(line, i, value, bigint_value, overflow);

    if ( overflow ) {
      extendMetric(m, BigInt(m.sum), BigInt(m.min), BigInt(m.max)); 
      updateBigIntMetric(m, bigint_value);
    }
    else {
      updateNativeMetric(m, value);
    }

    m++;

    // Right now `i` is pointing to a non-number; since we don't care about
    // these values (witness the "continue" on the first line of this loop),
    // it's ok that we'll immediately loop around and increment `i` once more.
  }
}

unittest {
  import std.format;

  NativeMetric m;

  native_metrics.clear();
  bigint_metrics.clear();

  StatLine st = createStatLine(cast(char[])format("one %d two %d\n", ulong.max, 2));

  m = native_metrics[][st.metric_idx];
  assert(m.offset == 4);
  assert(m.value == ulong.max);
  assert(m.overflow is null);

  m = native_metrics[][st.metric_idx+1];
  assert(m.offset == 9);
  assert(m.value == 2);
  assert(m.overflow is null);
  
  // The first metric will overflow and be extended, the second one will stay
  // as a ulong.
  updateStatLine(st, cast(char[])format("one %d two %d\n", 100, 10));

  m = native_metrics[][st.metric_idx];
  assert(m.overflow !is null);
  assert(m.overflow.value == BigInt(100));
  assert(m.overflow.sum == (BigInt(format("%d", ulong.max)) + 100));
  assert(m.overflow.min == BigInt(100));
  assert(m.overflow.max == BigInt(format("%d", ulong.max)));

  m = native_metrics[][st.metric_idx+1];
  assert(m.overflow is null);
  assert(m.value == 10);
  assert(m.sum == 12);
  assert(m.min == 2);
  assert(m.max == 10);
}

void updateNativeMetric(NativeMetric* m, ulong value) {

  // We know value fits into a ulong, but the metric sum may overflow. As such,
  // we need to handle extending into a BigIntMetric...

  bool overflow = false;

  m.value = value;
  ulong sum = addu(m.sum, value, overflow);

  if ( overflow ) {
    extendMetric(m, BigInt(m.sum), BigInt(m.min), BigInt(m.max));
    updateBigIntMetric(m, BigInt(value));
  }
  else {
    m.sum = sum;
    m.min = min(m.min, value);
    m.max = max(m.max, value);
  }
}

void updateBigIntMetric(NativeMetric* m, BigInt value) {
  m.overflow.value = value;
  m.overflow.sum = m.overflow.sum + value;
  m.overflow.min = min(m.overflow.min, value);
  m.overflow.max = max(m.overflow.max, value);
}

void extendMetric(NativeMetric* m, BigInt sum, BigInt min, BigInt max) {
  if ( m.overflow !is null ) return;
  bigint_metrics.put(BigIntMetric());
  m.overflow = &bigint_metrics[][$-1];
  m.overflow.sum = sum;
  m.overflow.min = min;
  m.overflow.max = max;
}

// Reads a number from the `line` starting at `line_idx`. Returns the
// index just beyond the scanned digits.
//
// When `use_bigint` is true, `v` is ignored and the scanned number is
// stored in `b`.
//
// When `use_bigint` is false AND the scanned number fits in `v`, `b`
// is ignored.
//
// WHen `use_bigint` is false AND the scanned number doesn't fit in
// `v`, `use_bigint` is set to true and `b` holds the value.
size_t scanNumber(const char[] line, size_t line_idx, ref ulong v, ref BigInt b, ref bool use_bigint) {
  size_t i = line_idx;

  if ( !use_bigint ) {

    v = 0;
    for (; line[i] >= '0' && line[i] <= '9'; i++) {
      v = mulu(v, 10, use_bigint);
      v = addu(v, line[i] - '0', use_bigint);
    }

    if ( use_bigint ) {
      return scanNumber(line, line_idx, v, b, use_bigint);
    }

    return i;
  }

  b = 0;
  for (; line[i] >= '0' && line[i] <= '9'; i++) {
      b = b * 10 + BigInt(line[i] - '0');
  }

  return i;
}

unittest {
  import std.format;

  char[] line;
  ulong value;
  BigInt bigint_value;
  bool use_bigint;
  size_t idx;

  line = cast(char[])format("one %d\n", ubyte.max);
  use_bigint = false;
  idx = scanNumber(line, 4, value, bigint_value, use_bigint);
  assert(line[idx] == '\n');
  assert(value == ubyte.max);
  assert(use_bigint == false);

  line = cast(char[])format("one %d\n", ulong.max);
  use_bigint = false;
  idx = scanNumber(line, 4, value, bigint_value, use_bigint);
  assert(line[idx] == '\n');
  assert(value == ulong.max);
  assert(use_bigint == false);

  line = cast(char[])format("one %d0\n", ulong.max);
  use_bigint = false;
  idx = scanNumber(line, 4, value, bigint_value, use_bigint);
  assert(line[idx] == '\n');
  assert(bigint_value == BigInt(format("%d0", ulong.max)));
  assert(use_bigint == true);

  string num = format("%d%d%d", ulong.max, ulong.max, ulong.max);
  line = cast(char[])format("one %s\n", num);
  use_bigint = false;
  idx = scanNumber(line, 4, value, bigint_value, use_bigint);
  assert(line[idx] == '\n');
  assert(bigint_value == BigInt(num));
  assert(use_bigint == true);
}

// Search stats for a StatLine matching `line`. If found, returns the index. If
// not found, returns the length of the stats slice.
size_t find(const StatLine[] stats, char[] line) {
  foreach (size_t idx, const StatLine st; stats) {
    if (st.match(line)) {
      //writeln("MATCHED!");
      return idx;
    }
    //writeln("MISSED!");
  }
  return stats.length;
}

// Make sure `line` is \n terminated! Returns true if `line` matches `st`.
bool match(const StatLine st, char[] line) {
  size_t st_idx = 0;
  size_t mt_idx = 0;

  for (size_t i=0; i<line.length; i++) {

    if (line[i] < '0' || line[i] > '9') {
      //writeln(line[i], "<>", st.line[st_idx]);
      if (line[i] != st.line[st_idx++]) {
        return false;
      }
      continue;
    }

    if (mt_idx >= st.metric_count) {
      //writeln(mt_idx, ">=", st.metric_count);
      return false;
    }

    NativeMetric* m = &native_metrics[][st.metric_idx + mt_idx++];

    if (m.offset != st_idx) {
      //writeln("offset ", m.offset, "!=", st_idx);
      return false;
    }

    while (line[i] >= '0' && line[i] <= '9') {
      //writeln(line[i], ">= '0' && ", line[i], " <= '9'");
      i++;
    }

    //writeln(line[i], "<>", st.line[st_idx]);
    if (line[i] != st.line[st_idx++]) {
      //writeln(line[i], "!=", st.line[st_idx-1]);
      return false;
    }
  }

  return true;
}

unittest {
  StatLine st = createStatLine(cast(char[])"one 123 two 234\n");
  assert(match(st, cast(char[])"one 2 two 3333333333\n"));
  assert(!match(st, cast(char[])"one 2!two 33333333333\n"));
}

