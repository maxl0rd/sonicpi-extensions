
defonce :use_playable, :override => true do
  
  class Playables
    @@runtime = nil
    
    def self.synth(synth_sym=:sine, default_options={})
      PlayableSynthFactory.new(synth_sym, default_options)
    end
    
    def self.midi(port, default_options={})
      PlayableMidiFactory.new(port, default_options)
    end
    
    def self.set_runtime(rt)
      @@runtime = rt
    end
    
    def self.runtime
      @@runtime
    end
    
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
    
    VELOCITY_MAP = {
      off: -> (i) { 0 },
      ppp: -> (i) { Playables.runtime.rrand_i(23, 36) },
      pp:  -> (i) { Playables.runtime.rrand_i(36, 49) },
      p:   -> (i) { Playables.runtime.rrand_i(49, 62) },
      mp:  -> (i) { Playables.runtime.rrand_i(62, 75) },
      mf:  -> (i) { Playables.runtime.rrand_i(75, 88) },
      f:   -> (i) { Playables.runtime.rrand_i(88, 101) },
      ff:  -> (i) { Playables.runtime.rrand_i(101, 114) },
      fff: -> (i) { Playables.runtime.rrand_i(114, 127) }
    }
  end
  
  module FactoryMethods
    def rest(duration)
      Rest.new(duration)
    end
    
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
          options[key.to_sym] = Playables::VELOCITY_MAP[opt_val].call(index)
        end
        if opt_val.is_a?(Symbol) && key == :amp
          options[:amp] = Playables::VELOCITY_MAP[opt_val].call(index).to_f / 127.0
        end
      end
      options
    end
  end
  
  module NoteMethods
    def set_note(n)
      @note = n.to_f
    end
    
    def get_note
      @note ||= 0.0
    end
    
    def tune(&block)
      clone().tune!(&block)
    end
    
    def tune!(&block)
      set_note block.call(@note)
      self
    end
    
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
  
  module DurationMethods
    
    def set_duration(d)
      @duration = d.to_f
    end
    
    def get_duration
      @duration ||= 0.0
    end
    
    def stretch(&block)
      clone.stretch!(&block)
    end
    
    def stretch!(&block)
      set_duration block.call(@duration)
      self
    end
    
    protected
    
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
  
  module DelayAccumulator
    include DurationMethods
    
    def delay_accum
      @delay_accum ||= 0.0
    end
    
    def rest(duration)
      @delay_accum += resolve_duration(duration)
    end
  end
  
  class PlayableSynthFactory
    include DelayAccumulator
    include FactoryMethods
    
    def initialize(synth_sym, default_options={})
      @synth = synth_sym || :sine
      @default_options = default_options
    end
    
    def note(note_num, duration=:n4, options={})
      PlayableSynthNote.new(@synth, note_num, duration, delay_accum,
                            resolve_options(@default_options).merge(options))
    end
    
    def chord(notes, duration=:n4, options={})
      playables = []
      notes.each_with_index do |n, i|
        playables << PlayableSynthNote.new(@synth, n, duration, delay_accum,
                                           resolve_options(@default_options, i).merge(options))
      end
      playables
    end
    
    def arp(notes, duration=:n4, arp_delay=0.125, options={})
      playables = []
      notes.each_with_index do |n, i|
        playables << PlayableSynthNote.new(@synth, n, duration,
                                           delay_accum + arp_delay * i,
                                           resolve_options(@default_options, i).merge(options))
      end
      playables
    end
    
    def seq(notes=[], duration=:n4, options={})
      runables = []
      notes.each_with_index do |n, i|
        runables << PlayableSynthNote.new(@synth, n, duration, delay_accum,
                                          resolve_options(@default_options, i).merge(options))
        runables << Rest.new(duration)
      end
      runables
    end
  end
  
  class PlayableMidiFactory
    include DelayAccumulator
    include FactoryMethods
    
    def initialize(port, default_options={})
      @port = port || raise("Midi port is required")
      @default_options = default_options
    end
    
    def note(note_num, duration=:n4, options={})
      PlayableMidiNote.new(@port, note_num, duration, delay_accum,
                           resolve_options(@default_options).merge(options))
    end
    
    def chord(notes=[], duration=:n4, options={})
      playables = []
      notes.each_with_index do |n, i|
        playables << PlayableMidiNote.new(@port, n, duration, delay_accum,
                                          resolve_options(@default_options, i).merge(options))
      end
      playables
    end
    
    def arp(notes=[], duration=:n4, arp_delay=0.125, options={})
      playables = []
      notes.each_with_index do |n, i|
        playables << PlayableMidiNote.new(@port, n, duration,
                                          delay_accum + arp_delay * i,
                                          resolve_options(@default_options, i).merge(options))
      end
      playables
    end
    
    def seq(notes=[], duration=:n4, options={})
      playables = []
      notes.each_with_index do |n, i|
        playables << PlayableSynthNote.new(port, n, duration, delay_accum,
                                           resolve_options(@default_options, i).merge(options))
      end
      playables
    end
  end
  
  module RunnablePlayable
    def run
      play
    end
  end
  
  class PlayableSynthNote
    include NoteMethods
    include DurationMethods
    include RunnablePlayable
    
    def initialize(synth_sym, note_sym, duration, delay=0.0, options={})
      @synth = synth_sym || :sine
      @note = resolve_note(note_sym)
      @duration = resolve_duration(duration)
      @delay = delay
      @options = options
    end
    
    def play
      Playables.runtime.time_warp @delay do
        Playables.runtime.with_synth @synth do
          Playables.runtime.play @note, @options.merge(:sustain => @duration)
        end
      end
      self
    end
  end
  
  class PlayableMidiNote
    include NoteMethods
    include DurationMethods
    include RunnablePlayable
    
    def initialize(port, note_sym, duration, delay=0.0, options={})
      @port = port || raise("Midi port is required")
      @note = resolve_note(note_sym)
      @duration = resolve_duration(duration)
      @delay = delay
      @options = options.merge(:port => @port)
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
  end
  
  class Rest
    include DurationMethods
    include NoteMethods
    
    def initialize(duration)
      @note = 0
      @duration = resolve_duration(duration)
    end
    
    def run
      Playables.runtime.sleep @duration
    end
    
    def play
    end
    
    def set_note(n)
      @note = 0 # rests are always 0
    end
  end
  
  module ArrayMethods
    def deep_clone()
      map { |it| it.respond_to?(:deep_clone) ? it.deep_clone : it.clone }
    end
    
    def play
      each do |playable|
        if playable.respond_to?(:play)
          playable.play
        end
      end
    end
    
    def run 
      each do |runnable|
        if runnable.respond_to?(:run)
          runnable.run
        end
      end
    end
    
    def tune(&block)
      deep_clone.tune!(&block)
    end
    
    def tune!(&block)
      each do |tunable|
        if tunable.respond_to?(:tune!)
          tunable.tune!(&block)
        end
      end
      
      return self
    end
    
    def stretch(&block)
      deep_clone.stretch!(&block)
    end
    
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


