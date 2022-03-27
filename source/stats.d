module stats;

import std.algorithm.comparison;
import std.array;
import std.bigint;
import core.checkedint;

import printer;

//immutable ulong CUTOFF = 1000000;//ulong.max-1;

struct StatLine {
  char[] line; // line with all numbers removed
  ulong count;
  size_t metric_idx;
  size_t metric_count;
}

struct NativeMetric {
  size_t offset;
  ulong value;
  ulong min;
  ulong max;
  ulong sum;
  BigIntMetric* overflow; // If non-null, use this for the value/min/max/sum
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

void updateNativeMetric(NativeMetric* m, ulong value) {

  // We know value fits into a ulong, but the metric sum may overflow. As such,
  // we need to handle extending into a BigIntMetric...

  bool overflow = false;

  m.value = value;
  ulong sum = adds(m.sum, value, overflow);

  //if (sum > CUTOFF) overflow = true;

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
  if ( m.overflow !is null ) return; // TODO: should this be an assert?
  bigint_metrics.put(BigIntMetric());
  m.overflow = &bigint_metrics[][$-1];
  m.overflow.sum = sum;
  m.overflow.min = min;
  m.overflow.max = max;
}

// returns how far to push the index variable
size_t scanNumber(const char[] line, size_t line_idx, ref ulong v, ref BigInt b, ref bool use_bigint) {

  size_t i = line_idx;

  if ( !use_bigint ) {

    v = 0;
    for (; line[i] >= '0' && line[i] <= '9'; i++) {
      v = muls(v, 10, use_bigint);

      //if (v > CUTOFF) use_bigint = true;

      v = adds(v, line[i] - '0', use_bigint);

      //if (v > CUTOFF) use_bigint = true;

      if ( use_bigint ) {
        return scanNumber(line, line_idx, v, b, use_bigint);
      }
    }

    return i;
  }

  b = 0;
  for (; line[i] >= '0' && line[i] <= '9'; i++) {
      b = b * 10 + BigInt(line[i] - '0');
  }

  return i;
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

