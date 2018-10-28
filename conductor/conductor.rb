# Conductor
# A pretty simple system for managing musical time across multiple threads.

# If you want to modify these classes, you must set `override` true.

defonce :use_conductor, :override => true do
  
  class Conductor    
    @@runtime = nil # Holds a reference to the Sonic Pi runtime
    @@measure = 1   # The current measure number, 1-indexed
    @@beat = 1      # The current beat number, 1-indexed
    
    # A map of all the supported time signatures to the number of beats in each.
    # We don't change the beat size or bpm based on the lower part.
    
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
    
    def self.set_runtime(rt)
      @@runtime = rt
    end
    
    def self.runtime
      @@runtime
    end
    
    # Explicitly change time signature.
    # Calling mid measure could have unpredictable results.
    
    def self.set_time_sig(new_time_sig)
      if TIME_SIG_MAP[@@time_sig]
        @@time_sig = new_time_sig 
      else
        raise "Invalid time sig #{new_time_sig}"
      end
    end
    
    # Synchronize conductor against an external time source
    # Pass in the number of beats that have elapsed since the last tick.
    
    def self.tick(num_beats=1)
      @@time_sig ||= :time_4_4
      if @@clock_state == :run
        @@beat += num_beats
        if @@beat.to_f >= TIME_SIG_MAP[@@time_sig] + 1.0
          @@beat = 1
          @@measure += 1
          runtime.set :conductor_measure, @@measure
          runtime.cue :conductor_new_measure
          runtime.puts "Measure #{@@measure}"
        else
          runtime.set :conductor_beat, @@beat
        end
      end
    end
  
    # Sync/block the thread until the next new measure
  
    def self.sync_to_measure(new_time_sig=nil)      
      runtime.sync :conductor_new_measure
      if new_time_sig
        @@time_sig = new_time_sig 
        runtime.set :conductor_time_sig, new_time_sig
      end
      self
    end
    
    # Repeat the block for the total number of given measures
    # Yields immediately, but syncs starts of repeats to measure lines
    
    def self.repeat_measures(num_measures)
      end_measure = @@measure + num_measures
      yield
      (num_measures-1).times do
        sync_to_measure
        yield if @@measure < end_measure
      end
    end
    
    # Repeat the block for the total number of given measures
    # Yields immediately, but syncs starts of repeats to measure lines
    
    def self.thread_measures(num_measures, &block)
      runtime.in_thread do
        repeat_measures(num_measures, &block)
      end
    end
    
    # Rewind the conductor
    
    def self.reset
      runtime.set :conductor_measure, 1           
      runtime.set :conductor_beat, 1              
      runtime.puts "Measure #{@@measure}"
    end
    
    # Start counting beats and sending cues
    
    def self.run
      @@clock_state = :run
      runtime.cue :conductor_new_measure             
      runtime.set :conductor_clock_state, :run   
    end
    
    # Stop counting beats and sending cues
    
    def self.stop
      @@clock_state = :stop
      runtime.set :conductor_clock_state, :stop
    end
  end
  
  Conductor.set_runtime(self)
  Conductor.reset
  
  ### Three underscores `___` denotes a bar line in the score.
  ### A new time sig can be given like `___ :time_6_4`

  define '___'.to_sym do |new_time_sig=nil|
    Conductor.sync_to_measure(new_time_sig)
  end
end



