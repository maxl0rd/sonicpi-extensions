## Conductor

Conductor is a lib that can be used to formalize the way that multiple threads are synced together,
and to make them respect a timeline of regular measures. It also understands traditional time signatures,
which may make it useful for working alongside traditionally notated material.

### Example

Here is a full example:

```
run_file "/path/to/the/conductor.rb"

use_bpm 120
use_conductor

Conductor.set_time_sig(:time_4_4)

live_loop :conductor_beat_ticker do
  sleep 0.5
  Conductor.tick(0.5)
end

Conductor.thread_measures(4) do
  # First part, in another thread
  play :c4
  ___
  play :c5
end

Conductor.thread_measures(4) do
  # Second part, in another thread
  sleep 1
  play :e4
  ___
  sleep 1
  play :f5
end

Conductor.run

Conductor.repeat_measures(4) do
  # This runs on the main thread, and keeps the timeline going.
  # This will do nothing, but the whole statement will sync the thread for 4 measures.
end

Conductor.stop
```

### Getting Started

To start using Conductor:

*  Copy the `conductor.rb` file to your project and run it
*  Set your bpm
*  Set up a ticker
*  Start some threads

Conductor doesn't have its own time reference, so your code needs to provide a ticker of some sort. This enables Conductor to be synced to either Sonic Pi's internal beat clock, or an external reference (midi or osc events?). The simplest, most reliable time reference is to just set up a live loop that calls the tick method. 

The tick call can advance Conductor by any number of beats or fractional beats. If you use 4/4 time `:time_4_4`, then you can tick every beat like `tick(1)` and it'll work fine. However, time signatures like 5/4 `:time_5_4` are implemented as fractional beats (eg 4.5) and so you'll want to tick at least every half a beat if you are using those time sigs.

```
live_loop :conductor_beat_ticker do
  sleep 0.5
  Conductor.tick(0.5)
end
```

The Conductor must be started and stopped, otherwise none of the syncs required to run your threads will ever fire.

```
Conductor.run
  # ... do stuff ...
Conductor.stop
```

Conductor provides two useful methods for organizing musical parts:

*  The `repeat_measures` method creates a block that will repeat for the given number of measures. It will block, restarting itself only on measure boundaries. You should probably make sure that the musical content of each block fits into, or divides evenly into the given number of total measures.
*  The `thread_measures` method is the same as `repeat_measures` except that the block given will run in a new thread. So declaring these does not block the current thread. This is very similar to `in_thread` except that each repeat syncs against the bar line.

Conductor can also sync to the bar line any time inside a block using the method `Conductor.sync_to_measure`. However, it also defines a sugar for this, three underscores `___`. Think of it like a visual representation of a measure line. In many cases, you won't need to represent all the sleeps and filler rests if you just use the `___` to separate measures.

```
Conductor.repeat_measures(4) do
  # Implicit ___ on each repeat
  # This whole block will sound twice, taking up 4 measures of time
  sleep 1
  play :e4
  ___ # sugar for Conductor.sync_to_measure
  sleep 1
  play :f5
end
```

### Changing the Time Signature

Some modern compositions change time signature almost every bar. While this confuses humans, Conductor is totally cool with this. There are a few ways to change it.

*  You can explicitly set it to any of the supported symbols, like `Conductor.set_time_sig(:time_4_4)`.
*  You can set the time for the next measure when syncing, like `Conductor.sync_to_measure(:time_7_4)`.
*  Use the short form, `___ :time_3_4`

Remember that there is _only one time sig_ shared among all threads. So the smart move is to make one thread responsible for managing time and let everybody else follow along.

These are the supported times, and the number of beats in each:

```
TIME_SIG_MAP = {
  time_2_4: 2,
  time_5_8: 2.5,
  time_3_4: 3,
  time_6_8: 3,
  time_7_8: 3.5,
  time_4_4: 4,
  time_9_8: 4.5,
  time_5_4: 5,
  time_11_8: 5.5,
  time_6_4: 6,
  time_7_4: 7,
  time_8_4: 8,
  time_9_4: 9,
  time_10_4: 10,
  time_11_4: 11,
  time_12_4: 12
}  
```

