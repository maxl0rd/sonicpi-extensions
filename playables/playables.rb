# Playables
# Playables is an object-oriented way to model musical information in Sonic Pi.

# If you want to modify these classes, you must set `override` true.

defonce :use_playables, :override => false do
  
  class Playables
    @@runtime = nil # A reference to the Sonic Pi runtime
    
    # Creates a factory for a synth voice with the given default options
    
    def self.synth(synth_sym=:sine, default_options={})
      PlayableSynthFactory.new(synth_sym, default_options)
    end
    
    # Creates a factory for a midi voice with the given default options
    
    def self.midi(port, default_options={})
      PlayableMidiFactory.new(port, default_options)
    end
    
    def self.set_runtime(rt)
      @@runtime = rt
    end
    
    def self.runtime
      @@runtime
    end
    
    # Defines beat values for the supported symbolic durations
    
    DURATION_MAP = {
      :n1d => 6.0,
      :n1 => 4.0,
      :n2d => 2.0 * 1.5,
      :n2 => 2.0,
      :n4d => 1.0 * 1.5,
      :n4 => 1.0,
      :n4t => 2.0 / 3.0,
      :n8d => 0.5 * 1.5,
      :n8 => 0.5,
      :n8t => 0.5 * 2.0 / 3.0,
      :n16d => 0.25 * 1.5,
      :n16 => 0.25,
      :n16t => 0.25 * 2.0 / 3.0,
      :n32 => 0.125
    }
    
    # Defines lambdas for humanized velocity levels that map to the traditional dynamic levels
    
    VELOCITY_MAP = {
      off: -> (i=0) { 0 },
      ppp: -> (i=0) { Playables.runtime.rrand_i(23, 36) },
      pp:  -> (i=0) { Playables.runtime.rrand_i(36, 49) },
      p:   -> (i=0) { Playables.runtime.rrand_i(49, 62) },
      mp:  -> (i=0) { Playables.runtime.rrand_i(62, 75) },
      mf:  -> (i=0) { Playables.runtime.rrand_i(75, 88) },
      f:   -> (i=0) { Playables.runtime.rrand_i(88, 101) },
      ff:  -> (i=0) { Playables.runtime.rrand_i(101, 114) },
      fff: -> (i=0) { Playables.runtime.rrand_i(114, 127) }
    }
  end
  
  # Methods that are included in all of the voice factory classes
  # Requires that the class implements the `factory` method to create a playable
  
  module FactoryMethods
    
    # Generate a single playable note
    
    def note(note_num=0, duration=:n4, options={})
      factory(note_num, duration, delay_accum, 
              resolve_options(@default_options).merge(options))
    end
    
    # Generate an array of playables, one per note in the given array
    
    def chord(notes=[], duration=:n4, options={})
      playables = []
      notes.each_with_index do |n, i|
        playables << factory(n, duration, delay_accum,
                             resolve_options(@default_options, i).merge(options))
      end
      playables
    end
    
    # Generate an array of playables, one per note in the given array
    # Each will be delayed by a small amount, producing an arpeggio
    
    def arp(notes=[], duration=:n4, arp_delay=0.125, options={})
      playables = []
      notes.each_with_index do |n, i|
        playables << factory(n, duration,
                             delay_accum + arp_delay * i,
                             resolve_options(@default_options, i).merge(options))
      end
      playables
    end
    
    # Generate a runnable sequence of regular notes and rests
    
    def seq(notes=[], duration=:n4, options={})
      runables = []
      notes.each_with_index do |n, i|
        runables << factory(n, duration, delay_accum,
                            resolve_options(@default_options, i).merge(options))
        runables << rest(duration)
      end
      runables
    end
    
    # Create a rest
    
    def rest(duration)
      Rest.new(duration)
    end
    
    # Resolve the default options in a factory that will be passed to each Playable.
    # Supports lambda options as long as they accept the index parameter.
    # Also supports symbolic velocities and durations.
    
    def resolve_options(original_options, index=0)
      options = {}
      original_options.each_pair do |key, opt_val|
        if opt_val.is_a? Proc
          options[key.to_sym] = opt_val.call(index)
        else
          options[key.to_sym] = opt_val
        end
        if opt_val.is_a?(Symbol) && key == :duration
          options[:duration] = Playables::DURATION_MAP[opt_val]
        end
        if opt_val.is_a?(Symbol) && [:velocity, :vel].include?(key)
          options[key.to_sym] = Playables::VELOCITY_MAP[opt_val].call()
        end
        if opt_val.is_a?(Symbol) && key == :amp
          options[:amp] = Playables::VELOCITY_MAP[opt_val].call().to_f / 127.0
        end
      end
      options
    end
  end
  
  # Methods to manipulate note values that are included in all of the Playables.
  
  module NoteMethods
    def set_note(n)
      @note = n.to_f
    end
    
    def get_note
      @note ||= 0.0
    end
    
    # Passes the current note value to the block, and then sets it to whatever the block returns.
    # Produces a clone of the playable with the new note set, leaving the original unmodified.
    
    def tune(&block)
      clone().tune!(&block)
    end
    
    # Passes the current note value to the block, and then sets it to whatever the block returns.
    # Mutates the note in the Playable.
    
    def tune!(&block)
      set_note block.call(@note)
      self
    end
    
    # Resolve note values that might be procs or letter symbols.
    
    def resolve_note(note)
      if note.is_a?(Proc)
        note = note.call()
      end
      if note.is_a?(Symbol)
        note = Playables.runtime.note(note)
      end
      if note.nil?
        raise 'Bad Note'
      end
      note
    end
  end
  
  # Methods to manipulate duration values that are included in all of the Playables.
  
  module DurationMethods
    
    def set_duration(d)
      @duration = d.to_f
    end
    
    def get_duration
      @duration ||= 0.0
    end
    
    # Passes the current duration value to the block, and then sets it to whatever the block returns.
    # Produces a clone of the playable with the new duration set, leaving the original unmodified.
    
    def stretch(&block)
      clone.stretch!(&block)
    end
    
    # Passes the current duration value to the block, and then sets it to whatever the block returns.
    # Mutates the duration in the Playable.
    
    def stretch!(&block)
      set_duration block.call(@duration)
      self
    end
    
    protected
    
    # Resolves duration values that might be procs or symbolic durations.
    
    def resolve_duration(duration)
      if duration.is_a?(Proc)
        duration = duration.call()
      end
      if duration.is_a?(Symbol)
        duration = Playables::DURATION_MAP[duration]
      end
      if duration.nil?
        raise 'Bad Duration'
      end
      duration
    end
  end
  
  # Delay accumulator included in all factories.
  
  module DelayAccumulator
    include DurationMethods
    
    def delay_accum
      @delay_accum ||= 0.0
    end
    
    # Each call to rest will increase the delay applied 
    # to all subsequent playables generated by this factory.
    
    def rest(duration)
      @delay_accum += resolve_duration(duration)
    end
  end
  
  # A factory for synth playables
  
  class PlayableSynthFactory
    include DelayAccumulator
    include FactoryMethods
    
    def initialize(synth_sym, default_options={})
      @synth = synth_sym || :sine
      @default_options = default_options
    end
    
    def factory(*args)
      PlayableSynthNote.send :new, *[@synth].concat(args)
    end
  end
  
  # A factory for midi playables
  
  class PlayableMidiFactory
    include DelayAccumulator
    include FactoryMethods
    
    def initialize(port, default_options={})
      @port = port || raise("Midi port is required")
      @default_options = default_options
    end
    
    def factory(*args)
      PlayableMidiNote.send :new, *[@port].concat(args)
    end
  end
  
  module RunnablePlayable
    def run
      play
    end
  end
  
  # A playable for a synth note
  
  class PlayableSynthNote
    include NoteMethods
    include DurationMethods
    include RunnablePlayable
    
    def initialize(synth_sym, note_sym, duration, delay=0.0, options={})
      @synth = synth_sym || :sine
      @note = resolve_note(note_sym)
      @duration = resolve_duration(duration)
      @delay = delay
      @amp = resolve_amp(options[:amp] || 0.5)
      @options = options.merge(:sustain => @duration, :amp => @amp)
    end
    
    def play
      Playables.runtime.time_warp @delay do
        Playables.runtime.with_synth @synth do
          Playables.runtime.play @note, @options
        end
      end
      self
    end
    
    def resolve_amp(amp)
      if amp.is_a?(Symbol)
        Playables::VELOCITY_MAP[amp].call().to_f / 127.0
      else
        amp
      end
    end
  end
  
  # A playable for a midi note
  
  class PlayableMidiNote
    include NoteMethods
    include DurationMethods
    include RunnablePlayable
    
    def initialize(port, note_sym, duration, delay=0.0, options={})
      @port = port || raise("Midi port is required")
      @note = resolve_note(note_sym)
      @duration = resolve_duration(duration)
      @delay = delay
      @velocity = resolve_velocity(options[:vel] || options[:velocity] || 0.5)
      @options = options.merge(:port => @port, :velocity => @velocity, :vel => nil)
    end
    
    def play
      Playables.runtime.time_warp @delay do
        Playables.runtime.midi_note_on @note, @options
      end
      Playables.runtime.time_warp @delay + @duration do
        Playables.runtime.midi_note_off @note, @options
      end
      self
    end
    
    def resolve_velocity(velocity)
      if velocity.is_a?(Symbol)
        Playables::VELOCITY_MAP[velocity].call().to_f
      else
        velocity
      end
    end
  end
  
  # A rest
  
  class Rest
    include DurationMethods
    include NoteMethods
    
    def initialize(duration)
      @note = 0
      @duration = resolve_duration(duration)
    end
    
    # Sleeps when runs
    
    def run
      Playables.runtime.sleep @duration
    end
    
    # No-op
    
    def play
    end
    
    # Note is always 0
    
    def set_note(n)
      @note = 0
    end
  end
  
  # Methods to extend Array so that we can work with groups of Runnables and Playables
  
  module ArrayMethods
    def deep_clone()
      map { |it| it.respond_to?(:deep_clone) ? it.deep_clone : it.clone }
    end
    
    # Play all elements in the array, recursively
    
    def play
      each do |playable|
        if playable.respond_to?(:play)
          playable.play
        end
      end
    end
    
    # Run all elements in the array, recursively
    
    def run 
      each do |runnable|
        if runnable.respond_to?(:run)
          runnable.run
        end
      end
    end
    
    # Tune all elements, recursively, returning a deep clone
    
    def tune(&block)
      deep_clone.tune!(&block)
    end
    
    # Tune all elements, recursively
    
    def tune!(&block)
      each do |tunable|
        if tunable.respond_to?(:tune!)
          tunable.tune!(&block)
        end
      end
      
      return self
    end
    
    # Stretch all elements, recursively, returning a deep clone
    
    def stretch(&block)
      deep_clone.stretch!(&block)
    end
    
    # Stretch all elements, recursively
    
    def stretch!(&block)
      each do |stretchable|
        if stretchable.respond_to?(:stretch!)
          stretchable.stretch!(&block)
        end
      end
      
      return self
    end
  end
  
  # Monkey-patch Array to support recursive ArrayMethods in arrays.
  
  class ::Array
    include ArrayMethods
  end
  
  # Assign the Sonic Pi workspace/runtime  
  Playables.set_runtime(self)
end


