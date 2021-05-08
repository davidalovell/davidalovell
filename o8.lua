--- Object Sequencer

lydian      = {0,2,4,6,7,9,11}
divisions   = {1,2,3,4,6,8,12,16}
odd         = {1,3,5,7,9}
even        = {2,4,6,8,10}

global = {
    scale = lydian
  , bpm = 120
  , division = 1
  , reset = false
  , negharm = false
}

txi = {
    param = {}
  , input = {}
}

Voice = {
    new = function(self)
      o = {}
      setmetatable(o, self)
      self.__index = self
      return o
    end

  , synth = function(note, level)
      ii.jf.play_note(note, level)
    end

  , play = function(self)
      play_note(self)
    end

  , ext_degree = true
  , ext_octave = true

  , scale = global.scale
  , negharm = false

  , on = true
  , level = 1
  , degree = 1
  , octave = 0
  , transpose = 0

  , input_on = true
  , input_level = 3
  , input_degree = 1
  , input_octave = 0
  , input_transpose = 0
}

Settings = {
    new = function(self)
      o = {}
      setmetatable(o, self)
      self.__index = self
      return o
    end

  , reset = false
  , sequence = {1,2,3,4,5,6,7}
  , behaviour = "next"

  , division = 1
  , step = 1

  , input_division = 1
  , input_step = 1
}

function new_sequencer()
  local i = 0
  return
    function(s)
			i = (s.reset or global.reset) and 0 or i

			local step = s.step * s.input_step

			if s.behaviour == "next" then
				i = ((i + step) - 1) % #s.sequence + 1
			elseif s.behaviour == "prev" then
				i = ((i - step) - 1) % #s.sequence + 1
			elseif s.behaviour == "drunk" then
				i = ((i + step * math.random(-1, 1)) - 1) % #s.sequence + 1
				i = clamper( i, 1, #s.sequence )
			elseif s.behaviour == "random" then
				i = math.random(1, #s.sequence)
			end

      return s.sequence[i], false
    end
end

function new_divider(fn)
	local i = 0
	return
		function(s)
      s = type(s) == "table" and s or {division = s, input_division = 1, reset = false}

			local reset = s.reset or global.reset
			local division = s.division * s.input_division

			i = reset and 1 or (i % division + 1)

			if i == 1 then
				return fn(), false
			end

		end
end

function init()
  input[1]{
      mode = 'scale'
    , notes = global.scale

  }

  input[2]{
      mode = 'change'
    , threshold = 4.0
    , hysteresis = 0.1
    , direction = 'rising'
  }

  metro[1].event = clock_event
  metro[1].time = 60/global.bpm
  metro[1]:start()

  txi_getter()
  on_init()
end

function txi_getter()
  for i = 1, 4 do
    ii.txi.get( 'param', i )
    ii.txi.get( 'in', i )
  end
end

ii.txi.event = function( e, val )
  if e.name == 'param' then
    txi.param[ e.arg ] = val
  elseif e.name == 'in' then
    txi.input[ e.arg ] = val
  end
end

input[1].scale = function(s)
  global = {
      cv_octave = s.octave
    , cv_degree = s.index
  }
end

input[2].change = function()
  on_trigger()
  global.reset = false
end

function clock_event()
  txi_getter()
  on_clock()
  global.reset = false
end

function play_note(v)
  if v.on and v.input_on then
    return v.synth( new_note(v), v.level * v.input_level )
  end
end

function new_note(v)
  local cv_degree = v.ext_degree and global.cv_degree or 1
	local cv_octave = v.ext_octave and global.cv_octave or 0

  local degree = ( v.degree - 1 ) + ( v.input_degree - 1 ) + ( cv_degree - 1 )
  local transpose = v.transpose + v.input_transpose
  local octave = v.octave + v.input_octave + cv_octave + math.floor( degree / #v.scale )
  local index = degree % #v.scale + 1

  local note = ( v.scale[ index ] + transpose )
  local negative = ( 7 - note ) % 12
	note = v.negharm and negative or note

  return note / 12 + octave
end

function linlin( range_min, range_max, output_min, output_max, input )
  return (input - range_min) * (output_max - output_min) / (range_max - range_min) + output_min
end

function clamper( input, min, max )
  return (input < min) and min or ( (input > max) and max or input )
end

function table_getter( range_min, range_max, input, table )
  return table[ clamper( math.floor( linlin( range_min, range_max, 1, #table, input ) ), 1, #table ) ]
end

function on_init()
  clock_divider = new_divider(function() output[1](pulse(0.05)); on_clock_division() end)
  clock_reset = new_divider(function() global.reset = true end)
  trigger_reset = new_divider(function() global.reset = true end)
  --
  ONOFF_divider = new_divider(
    function()
      v1.input_on = v1.s1.sequencer(v1.s1)
      v2.input_on = v2.s1.sequencer(v2.s1)
    end
  )
  --
  ii.jf.mode(1)
  ii.jf.run_mode(1)
  ii.jf.run(5)
  ii.wsyn.ar_mode(1)
  --
  v1 = Voice:new()
  v1.on = true
  v1.octave = -1
  v1.level = 2

  v1.s1 = Settings:new()
  v1.s1.sequencer = new_sequencer()
  v1.s1.sequence = {true,true,false}

  v1.s2 = Settings:new()
  v1.s2.sequencer = new_sequencer()
  v1.s2.sequence = {1,2,3,1,5,7}
  v1.s2.divider = new_divider(function() v1:play() end)

  v1.play = function(self)
    self.input_level = math.random(100,200)/100
    self.input_transpose = 0
    self.negharm = global.negharm
    self.s2.division = table_getter(0,10,txi.param[2],even)/4
    self.s2.input_division = self.s2.sequencer(self.s2)
    play_note(self)
  end

  v2 = Voice:new()
  v2.on = true
  v2.octave = -1
  v2.level = 2
  v2.transpose = 7

  v2.s1 = Settings:new()
  v2.s1.sequencer = new_sequencer()
  v2.s1.sequence = {true,false}
  v2.s1.division = 4

  v2.s2 = Settings:new()
  v2.s2.sequencer = new_sequencer()
  v2.s2.seqeunce = {1,5,1,3,12}
  v2.s2.divider = new_divider(function() v2:play() end)

  v2.play = function(self)
    self.input_level = math.random(100,200)/100
    self.negharm = global.negharm
    self.s2.division = table_getter(0,10,txi.param[2],odd)/5
    self.s2.input_division = self.s2.sequencer(self.s2)
    play_note(self)
  end

  bass = Voice:new()
  bass.on = true
  bass.ext_octave = false
  bass.octave = -2
  bass.level = 2.5

  bass.s1 = Settings:new()
  bass.s1.sequencer = new_sequencer()
  bass.s1.sequence = {2,6,7,1}
  bass.s1.divider = new_divider(function() bass:play() end)
  bass.s1.division = 2

  bass.s2 = Settings:new()
  bass.s2.sequencer = new_sequencer()
  bass.s2.sequence = {1,1,1,1}
  bass.synth = function(note, level)
    ii.jf.play_voice(1, note, level)
  end
  bass.play = function(self)
    self.input_level = math.random(100,200)/100
    self.input_degree = self.s2.sequencer(self.s2)
    self.negharm = global.negharm
    self.s1.division = table_getter(0,10,txi.param[4],divisions)
    self.s1.input_division = self.s1.sequencer(self.s1)
    self.s2.sequence[4] = math.random(4,5)
    play_note(self)
  end

  w1 = Voice:new()
  w1.on = true
  w1.octave = 3
  w1.level = 0.2
  w1.ext_degree = false
  w1.ext_octave = false
  w1.synth = function(note, level)
    ii.wsyn.play_note(note, level)
  end
  w1.play = function(self)
    self.input_degree = self.s1.sequencer(self.s1)
    self.input_level = math.random(100,200)/100
    ii.wsyn.lpg_time(math.random(-350,-100)/100)
    self.negharm = global.negharm
    self.s1.division = table_getter(0,10,txi.param[3],divisions)/2
    self.s1.input_division = math.random(1,4)
    self.s1.behaviour = "next"
    play_note(self)
  end

  w1.s1 = Settings:new()
  w1.s1.sequencer = new_sequencer()
  w1.s1.sequence = {2,3,4,6,7}--,9,10,11,13,14}
  w1.s1.step = 3
  w1.s1.divider = new_divider(function() w1:play() end)

end

function on_trigger()
  trigger_reset(128)
  --
  v1.note = v1.s2.divider(v1.s2)
  v2.note = v2.s2.divider(v2.s2)
  bass.note = bass.s1.divider(bass.s1)
end

function on_clock()
  clock_reset(128)
  --
  global.bpm = linlin(0, 5, 10, 1000, txi.input[1])
  metro[1].time = 60/global.bpm

  global.division = table_getter(0, 5, txi.input[2], divisions)
  clock_divider(global.division)

  global.negharm = table_getter(0, 4, txi.input[3], {false,true})

  global.ONOFF = table_getter(0, 10, txi.param[1], divisions)*4
  ONOFF_divider(global.ONOFF)
end

function on_clock_division()
  w1.note = w1.s1.divider(w1.s1)
end
