import std.stdio;
import std.array;
import std.bigint;

struct StatLine {
  char[] line; // line with all numbers removed
  ulong count;
  Metric[] metrics;
}

struct Metric {
  size_t offset; // where in the line is this placed?
  ulong min;
  ulong max;
  ulong sum; // for computing the average
}

StatLine newStatLine(char[] line) {
  auto trimmed = appender!(char[]);
  auto metrics = appender!(Metric[]);

  for (size_t i=0; i<line.length; i++) {
    if (line[i] < '0' || line[i] > '9') {
      trimmed.put(line[i]);
      continue;
    }

    Metric m = Metric();
    m.offset = trimmed[].length;

    // parse the number
    while (i < line.length && line[i] >= '0' && line[i] <= '9') {
      m.sum *= 10;
      m.sum += line[i] - '0';
      i++;
    }

    // We've moved beyond
    trimmed.put(line[i]);

    m.min = m.sum;
    m.max = m.sum;
    
    metrics.put(m);
  }

  return StatLine(trimmed[], 1, metrics[]);
}

void updateStatLine(ref StatLine st, char[] line) {
  import std.algorithm.comparison;

  st.count++;

  size_t mt_idx = 0;
  for (size_t i=0; i<line.length; i++) {
    if (line[i] < '0' || line[i] > '9') {
      continue;
    }

    ulong value = 0;
    while (i < line.length && line[i] >= '0' && line[i] <= '9') {
      value *= 10;
      value += line[i] - '0';
      i++;
    }

    st.metrics[mt_idx].sum += value;
    st.metrics[mt_idx].min = min(st.metrics[mt_idx].min, value);
    st.metrics[mt_idx].max = max(st.metrics[mt_idx].max, value);

    mt_idx++;
  }
}

size_t find(StatLine[] stats, char[] line) {
  size_t idx = 0;
  foreach (StatLine st; stats) {
    if (st.match(line)) {
      return idx;
    }
    idx++;
  }
  return idx;
}

void writeStatLine(ref StatLine st) {
  size_t last_offset = 0;

  write("c=", st.count, " ");
  foreach (Metric m; st.metrics) {
    write(st.line[last_offset..m.offset]);
    write("[", m.min, "...", m.max, ", avg=", cast(double)m.sum / cast(double)st.count, "]");
    last_offset = m.offset;
  }
  write(st.line[last_offset..$]);
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

    if (mt_idx == st.metrics.length || st.metrics[mt_idx].offset != st_idx) {
      return false;
    }

    mt_idx++;

    // skip past the number in `line`
    while (i<line.length && line[i] >= '0' && line[i] <= '9') {
      i++;
    }

    st_idx++;
  }

  return true;
}

void main(string[] args)
{
  auto stats = appender!(StatLine[]);

  foreach (char[] line; stdin.lines) {
    size_t idx = find(stats[], line);
    if (idx == stats[].length) {
      stats.put(newStatLine(line));
    }
    else {
      updateStatLine(stats[][idx], line);
    }

    writeStatLine(stats[][idx]);
  }
}

