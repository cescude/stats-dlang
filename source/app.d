import std.stdio;
import std.algorithm.comparison;
import std.array;
import std.bigint;
import core.checkedint;

import stats;
import printer;

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
      stats.put(createStatLine(line));
    }
    else {
      stats[][idx].updateStatLine(line);
    }

    //write("idx=", idx, " ");
    printStatLine(stats[][idx]);
  }

  //foreach (size_t h, Appender!(StatLine[]) stats; stats_table) {
  //  writeln("hash=", h, " len=", stats[].length);
  //}
}

