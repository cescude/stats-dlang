import std.stdio;
import std.algorithm.comparison;
import std.array;
import std.bigint;
import core.checkedint;

import printer;

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
  bool overflow; // PLAN: if true, look in the bigint_metrics array?
}

struct BigIntMetric {
  size_t offset;
  BigInt value;
  BigInt min;
  BigInt max;
  BigInt sum;
} 

auto native_metrics = appender!(NativeMetric[]);
auto bigint_metrics = appender!(BigIntMetric[]);

StatLine parsy(char[] line) {
  size_t m0 = native_metrics[].length;
  auto trimmed_line = appender!(char[]);

  for (size_t i=0; i<line.length; i++ ) {
    if (line[i] < '0' || line[i] > '9') {
      trimmed_line.put(line[i]);
      continue;
    }

    ulong value = 0;
    while (line[i] >= '0' && line[i] <= '9') {
      value *= 10;
      value += line[i++] - '0';
    }
    native_metrics.put(NativeMetric(
      trimmed_line[].length, value, value, value, value, false
    ));

    trimmed_line.put(line[i]);
  }

  return StatLine(trimmed_line[], 1, m0, native_metrics[].length - m0);
}

void updateStatLine(ref StatLine st, char[] line) {

  st.count++;

  NativeMetric* m = &native_metrics[][st.metric_idx];

  for (size_t i=0; i<line.length; i++) {
    if (line[i] < '0' || line[i] > '9') continue;

    ulong value = 0;
    while (line[i] >= '0' && line[i] <= '9') {
      value *= 10;
      value += line[i++] - '0';
    }
    updateMetric(m++, value);

    // Don't need to backtrack here, we know it's not a number and that's
    // really all we care about here...
    //i -= 1;
  }
}

void updateMetric(NativeMetric* m, ulong value) {
  m.value = value;
  m.sum += value;
  m.min = min(m.min, value);
  m.max = max(m.max, value);
}

size_t find(const StatLine[] stats, char[] line) {
  size_t idx = 0;
  //write("SEARCHING ", line);
  foreach (const StatLine st; stats) {
    if (st.match(line)) {
      //writeln("MATCHED");
      return idx;
    }
    //write("MISSED ", st.line);
    idx++;
  }
  return idx;
}

// Make sure `line` is \n terminated!
bool match(const StatLine st, char[] line) {
  size_t st_idx = 0;
  size_t mt_count = st.metric_count;
  NativeMetric* m = &native_metrics[][st.metric_idx];

  for (size_t i=0; i<line.length; i++) {

    if (line[i] < '0' || line[i] > '9') {
      if (line[i] != st.line[st_idx++]) {
        return false;
      }
      continue;
    }

    if (mt_count-- == 0) {
      return false;
    }

    if (m++.offset != st_idx) {
      return false;
    }

    while (line[i] >= '0' && line[i] <= '9') {
      i++;
    }

    if (line[i] != st.line[st_idx++]) {
      return false;
    }
  }

  return true;
}

void writeStatLine(StatLine st) {
  size_t last_offset = 0;

  //print("n="); printNumber(st.count); print(" ");
  foreach (NativeMetric m; native_metrics[][st.metric_idx..(st.metric_idx+st.metric_count)]) {
    print(st.line[last_offset..m.offset]);

    if (m.min == m.max) {
      printNumber(m.value);
    } else {
      printNumber(m.value);
      print("[");
      printNumber(m.min);
      print("…");
      printNumber(m.max);
      print(" μ=");
      printNumber(m.sum / st.count);
      print("]");
    }
    last_offset = m.offset;
  }
  //write(st.line[last_offset..$]);
  print(st.line[last_offset..$]);
  flush();
}

size_t hash(char[] line, size_t mask) {
  // Simple hash lifted from dlang's API docs
  size_t result = 0;
  foreach (c; line) {
    if (c < '0' || c > '9') {
      result = (result * 9) + c;
      result &= mask;
    }
  }
  return result;
}

void main(string[] args)
{
  Appender!(StatLine[])[256] stats_table;
  foreach (ref Appender!(StatLine[]) stats; stats_table) {
    stats = appender!(StatLine[]);
  }

  foreach (char[] line; stdin.lines) {

    size_t h = hash(line, stats_table.length-1);
    auto stats = stats_table[h];

    size_t idx = find(stats[], line);
    if (idx == stats[].length) {
      stats.put(parsy(line));
    }
    else {
      stats[][idx].updateStatLine(line);
    }

    //write("idx=", idx, " ");
    writeStatLine(stats[][idx]);
  }

  //foreach (size_t h, Appender!(StatLine[]) stats; stats_table) {
  //  writeln("hash=", h, " len=", stats[].length);
  //}
}

