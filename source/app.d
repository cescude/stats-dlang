import std.stdio;
import std.array;
import std.bigint;
import core.checkedint;

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

void parseNative(char[] line, ref ulong value, ref size_t idx, ref bool overflow) {
  value = 0;
  for (; idx < line.length && line[idx] >= '0' && line[idx] <= '9'; idx++) {
    value *= 10;
    value += line[idx] - '0';
  }
}

StatLine newStatLine(char[] line) {
  auto trimmed = appender!(char[]);
  size_t metric_idx = native_metrics[].length;
  size_t metric_count = 0;

  for (size_t i=0; i<line.length; i++) {
    if (line[i] < '0' || line[i] > '9') {
      trimmed.put(line[i]);
      continue;
    }

    NativeMetric m = NativeMetric();
    m.offset = trimmed[].length;

    parseNative(line, m.value, i, m.overflow);

    i--; // Cancel out the for loop's i++ statmment

    m.min = m.value;
    m.max = m.value;
    m.sum = m.value;
    
    native_metrics.put(m);
    metric_count++;
  }

  return StatLine(trimmed[], 1, metric_idx, metric_count);
}

void updateStatLine(ref StatLine st, char[] line) {
  import std.algorithm.comparison;

  st.count++;

  size_t mt_idx = st.metric_idx;
  for (size_t i=0; i<line.length; i++) {
    if (line[i] < '0' || line[i] > '9') {
      continue;
    }

    ulong value = 0;
    bool overflow = false;

    parseNative(line, value, i, overflow);

    i--; // Cancel out the for loop's i++ statmment

    native_metrics[][mt_idx].overflow = overflow;
    native_metrics[][mt_idx].value = value;
    native_metrics[][mt_idx].sum += value;
    native_metrics[][mt_idx].min = min(native_metrics[][mt_idx].min, value);
    native_metrics[][mt_idx].max = max(native_metrics[][mt_idx].max, value);

    mt_idx++;
  }
}

size_t find(StatLine[] stats, char[] line) {
  size_t idx = 0;
  //write("SEARCHING ", line);
  foreach (StatLine st; stats) {
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
bool match(StatLine st, char[] line) {
  size_t st_idx = 0;
  size_t mt_idx = 0;
  bool parsing_number = false;

  for (size_t i=0; i<line.length; i++) {
    //writeln(line[i], "<>", st.line[st_idx]);
    
    if (line[i] < '0' || line[i] > '9') {
      if (st.line[st_idx] != line[i]) {
        return false;
      }
      
      st_idx++;
      continue;
    }

    if (mt_idx >= st.metric_count || native_metrics[][st.metric_idx+mt_idx].offset != st_idx) {
      return false;
    }

    mt_idx++;

    // skip past the number in `line`
    while (i<line.length && line[i] >= '0' && line[i] <= '9') {
      i++;
    }

    i--; // Cancel out the for loop's i++ statmment

    //st_idx++;
  }

  return true;
}

void writeStatLine(StatLine st) {
  size_t last_offset = 0;

  //write("n=", st.count, " ");
  foreach (NativeMetric m; native_metrics[][st.metric_idx..(st.metric_idx+st.metric_count)]) {
    write(st.line[last_offset..m.offset]);
    write(m.value, "[", m.min, "…", m.max, " μ=", m.sum / st.count, "]");
    last_offset = m.offset;
  }
  write(st.line[last_offset..$]);
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
      stats.put(newStatLine(line));
    }
    else {
      updateStatLine(stats[][idx], line);
    }

    //write("idx=", idx, " ");
    writeStatLine(stats[][idx]);
  }

  //foreach (size_t h, Appender!(StatLine[]) stats; stats_table) {
  //  writeln("hash=", h, " len=", stats[].length);
  //}
}

