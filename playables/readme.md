## Playable

Playable is a set of extensions to SonicPi that is useful for programmers working on larger compositions. Programmers familiar with Ruby might find it more capable than the built in data structures when manipulating large amounts of musical information.

### Overview

The immediacy of working in a Sonic Pi buffer is extraordinarily compelling and rewards rapid iteration and experimentation. However, the lack of higher level structures to organize and manipulate musical data makes larger-scale compositions somewhat challenging. The programmer is forced into a rather procedural mode, and to operate on only primitive data structures (lists, maps, rings, etc). This library may be useful to programmers who are more comfortable with a traditional object-oriented approach.

There are two main concepts:

*  A `Playable` is any object (generally a "note") that can be sounded by calling its `play` method. Both Sonic Pi’s internal supercollider synths as well as MIDI output are supported. The two main properties of a `Playable` are its note and duration. Powerful methods are provided for manipulating those two properties.
*  A `Runnable` is any object that can "do its thing" by calling its `run` method. It can "eat up time" in its thread by sleeping or syncing in the process. A `Playable` is also a `Runnable` and it will play when asked to run, but it won’t use up any time.

You can also manage arrays of both Playables and Runnables. They can be played or run in their entirety by calling `play` or `run` on the array. In this way, runnables can be composed into giant structures, and then complex phrases can be run with one method call.

Runables are entirely compatible with Sonic Pi threads, so that they may each be run simultaneously or even spawn their own threads.

### Getting Started

To use the library, you need to download and include the `playables.rb` file in your buffer. The entire library is defined in a Sonic Pi `defonce` method, which you have to call before you can use it.

```
run_file "/path/to/the/playables.rb"
use_playable
```

Now we can create an instrument:

```
piano = Playables.synth :piano
```

This creates what we call a Playable Factory. It’s an object that can stamp out Playables for the synth we configured, in this case the built in piano synth. Let’s make a note:

```
my_note = piano.note :c3
```

Now we have a Playable. We can hear this any time by calling `my_note.play`.  Playable also has a convenient convention for notating musical durations, which is accepted as the second argument to `note()`.

```
piano.note(:c3, :n1).play  # whole note
piano.note(:c4, :n4).play  # quarter note
piano.note(:c4, :n8d).play # dotted eighth note
piano.note(:c5, :n8t).play # eighth note triplet
```

We can also make Playables that are composites of multiple notes, such as with the `chord` method. These chords can even be modified and augmented with the `<<` operator. The method returns an array, and calling play on that array will sound all notes at once.

```
a_chord = piano.chord([:a3, :c3, :e3], :n2) # Am
a_chord << piano.note(:g3, :n2) # now it’s Am7
```

The factories take any options that the underlying Sonic Pi synth understands. Additionally, there is a convenient notation for musical dynamics that works with both the synth `amp` param and the midi `velocity` param. You can set default options on the factory and/or override each note.

```
piano = Playables.synth(:piano, {attack: 0.1})
soft_note = piano.note(:c3, :n2, amp: :pp)
loud_note = piano.note(:c3, :n2, amp: :ff)
```

### Runnable Sequences

Sequences, or reusable musical motifs, can be built in a few ways. The `seq` method creates an array of Runnables. Each note in the given array appends a Playable note and a rest of the same length so that the sequence plays as a melody.

```
pf = Playables.synth(:piano)
seq1 = pf.seq([:a3, :b3, :d3, :e3], :n16) 
seq1.run
```

You could also build sequences by hand, which is a bit more flexible. Since the Playable notes in the sequence do not "use any time", we must also insert rests into the array so that the pattern plays as a melody. Rests work by sleeping the thread just like calling `sleep()` does. However, they can be manipulated like notes and their durations can be modified.

This technique is very flexible, and makes it easy to build sequences that are a mix of polyphonic and melody lines.

```
pf = Playables.synth(:piano)
seq1 = pf.seq
seq1 << pf.note :a3
seq1 << pf.rest :n16
seq1 << pf.note :b3
seq1 << pf.rest :n16
seq1 << pf.note :d3
seq1 << pf.rest :n16
seq1 << pf.note :e3
seq1 << pf.rest :n16
seq1.run
```

This is the main technique that you will probably use to build phrases.

### Manipulating tuning and time

There are two flexible methods for manipulating playables and runnables:

* The `tune` method modifies the pitch of a Playable or an entire nested array structure.
* The `stretch` method modifies the duration of both Playables and Runnables.

The `tune` and `stretch` methods return new copies, while the `tune!` and `stretch!` methods mutate in place.

These methods both work by taking a block. The block is passed the current note or duration of the Playable. The block's return value is assigned to the note.

To transpose a chord:

```
pf = Playables.synth(:piano)
cm_3 = pf.chord([:c3, :e3, :g3], :n2)
cm_4 = cm_3.tune { |n| n + 12 }
[cm_3, pf.rest(:n2), cm_4].run
```

The `stretch` method changes the duration of all underlying playables and runnables. The duration of a playable determines how long the note is held. The duration of a runnable, like a rest, determines how long to pause. So typically both of these are changed when a sequence is stretched.

In this example, we make a little pattern in 16th time, then stretch it 4x to make it quarter time. These two patterns are composed into another pattern, in which we run them together.

```
pf = Playables.synth(:piano)
cm_16 = [
  pf.chord([:c3, :e3, :g3], :n16),
  pf.rest(:n16),
  pf.chord([:c3, :e3, :g3], :n16),
  pf.rest(:n16)
]
cm_4 = cm_16.stretch{ |d| d * 4 }
[cm_16, cm_16, cm_4].run
```

The `tune` and `stretch` methods make "deep clones" of arrays, so that entire nested structures may be modified. 

### Using blocks, procs and lambdas

To make the most of Playables, you will want to make use of Ruby blocks, procs and lambdas.

A little known fact is that Sonic Pi will already "resolve" any Proc given as a synth arg. For example, this works:

```
with_synth :piano do
  play :c3, { amp: Proc.new { [0.1, 0.3, 0.7].choose } }
end
```

This is a good way to start organizing the musical concepts you are using in a piece.
Using procs is the simplest way to get started.

```
fff    = Proc.new { rrand(0.9, 1.0) }
mf     = Proc.new { rrand(0.5, 0.7) }
random = Proc.new { rrand(0.0, 1.0) }

piano_mf = pf = Playables.synth(:piano, {amp: mf})
piano_mf.note(:c4).play
```

Using lambdas is a little more complex because Playables resolves procs and lambdas differently than Sonic Pi does natively. Lambdas must be called with the correct number of arguments, and Sonic Pi calls them with no args.

Playables resolves lambdas by calling them with a single integer argument, which represents the index of the note that is being generated. This currently applies to chords and sequences. This enables more customization of the properties of each. 

Here's an example of using lambdas to control the amplitude and panning of a sequence.

```
use_bpm 120
echoing = -> (i) { 0.5 / ((i+1)**2) } # decay exponentially

panning_right_sine = Playables.synth(:sine, {
  amp: echoing,
  pan: -> (i) { 1.0 / (i+1) }
})
panning_left_sine = Playables.synth(:sine, {
  amp: echoing,
  pan: -> (i) { -1.0 / (i+1) }
})

s1 = [:c3, :g3, :a4, :d4]
s2 = [:e3, :b3, :a4, :d4]

[
  panning_right_sine.seq(s1+s2, :n8),
  panning_left_sine.seq(s2, :n4),
  panning_right_sine.seq(s1+s2, :n8),
  panning_left_sine.seq(s1, :n4)
].run
```

Finally, the `tune` and `stretch` methods described above require _blocks_ not lambdas. Use the `&` ampersand operator to turn a lambda into a block.

```
pf = Playables.synth(:piano)
octave_up = -> (n) { n + 12 }
cm_3 = pf.chord([:c3, :e3, :g3], :n2)
[cm_3, pf.rest(:n2), cm_3.tune(&octave_up)].run
```






