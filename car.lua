-- Car profile

-- Define sql_conn and redis_conn
require "profile-config"

api_version = 4

Set = require('lib/set')
Sequence = require('lib/sequence')
Handlers = require("lib/way_handlers")
Relations = require("lib/relations")
TrafficSignal = require("lib/traffic_signal")
find_access_tag = require("lib/access").find_access_tag
limit = require("lib/maxspeed").limit
Utils = require("lib/utils")
Measure = require("lib/measure")

Urban_density = require('lib/urban_density')
Ferries_withlist = require('lib/ferries_withlist')
Mapotempo = require('lib/mapotempo')
Startpoint_secure = require('lib/startpoint_secure')

function setup()
  Urban_density.assert_urban_database()
  return {
    properties = {
      max_speed_for_map_matching      = 80/3.6, -- 80kmph -> m/s
      -- For routing based on duration, but weighted for preferring certain roads
      weight_name                     = 'routability',
      -- For shortest duration without penalties for accessibility
      -- weight_name                     = 'duration',
      -- For shortest distance without penalties for accessibility
      -- weight_name                     = 'distance',
      process_call_tagless_node      = false,
      u_turn_penalty                 = 10,
      continue_straight_at_waypoint  = false,
      use_turn_restrictions          = true,
      left_hand_driving              = false,
      traffic_light_penalty          = 1,
    },

    default_mode              = mode.driving,
    default_speed             = function(way) return Urban_density.default_speed(way) end, -- function
    oneway_handling           = true,
    side_road_multiplier      = 0.9,
    turn_penalty              = 4,
    speed_reduction           = 0.8, -- Not Used
    turn_bias                 = 1.075,
    cardinal_directions       = false,

    -- Size of the vehicle, to be limited by physical restriction of the way
    vehicle_height = 1.90, -- in meters, 2.0m is the height slightly above biggest SUVs
    vehicle_width = 1, -- in meters, ways with narrow tag are considered narrower than 2.2m

    -- Size of the vehicle, to be limited mostly by legal restriction of the way
    vehicle_length = 2.9, -- in meters, 2.9m is the length of a cargo scooter
    vehicle_weight = 600, -- in kilograms

    -- Large vehicule
    -- Size of the vehicle, to be limited by physical restriction of the way
    vehicle_large_height = 2.5, -- in meters, 2.5m is the height of van
    vehicle_large_width = 1.9, -- in meters, ways with narrow tag are considered narrower than 2.2m

    -- Size of the vehicle, to be limited mostly by legal restriction of the way
    vehicle_large_length = 4.8, -- in meters, 4.8m is the length of large or family car
    vehicle_large_weight = 3500, -- in kilograms

    -- a list of suffixes to suppress in name change instructions. The suffixes also include common substrings of each other
    suffix_list = {
      'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW', 'North', 'South', 'West', 'East', 'Nor', 'Sou', 'We', 'Ea'
    },

    barrier_whitelist = Set {
      'cattle_grid',
      'border_control',
      'toll_booth',
      'sally_port',
      'gate',
      'lift_gate',
      'no',
      'entrance',
      'height_restrictor',
      'arch'
    },

    access_tag_whitelist = Set {
      'yes',
      'moped',
      'motorcycle',
      'motor_vehicle',
      'vehicle',
      'permissive',
      'private',
      'designated',
      'hov'
    },

    access_tag_blacklist = Set {
      'no',
      'agricultural',
      'forestry',
      'emergency',
      'psv',
      'customers',
--      'private',
--      'delivery',
      'destination'
    },

    -- tags disallow access to in combination with highway=service
    service_access_tag_blacklist = Set {
        'private'
    },

    restricted_access_tag_list = Set {
      'private',
      'delivery',
      'destination',
      'customers',
    },

    access_tags_hierarchy = Sequence {
      'moped',
      'motorcycle',
      'motor_vehicle',
      'vehicle',
      'access'
    },

    service_tag_forbidden = Set {
      'emergency_access'
    },

    restrictions = Sequence {
      'moped',
      'motorcycle',
      'motor_vehicle',
      'vehicle'
    },

    -- change usage of some bits in classes, only to be able to return in API, could not be used internaly
    classes = Sequence {
        'toll',
        -- Higwhay encoding bits
        -- 'w1', 'w2', 'w3',
        -- Landuse encoding bits
        -- 'l1', 'l2',
        -- 'notForLargeVehicule',
        -- 'lowEmissionZone',
    },

    -- classes to support for exclude flags
    excludable = Sequence {
        Set {'toll'},
    },

    avoid = Set {
      'area',
      -- 'toll',    -- uncomment this to avoid tolls
      'reversible',
      'impassable',
      'hov_lanes',
      'steps',
      'construction',
      'proposed',
      -- not for scooter
      'motorway',
      'motorway_link',
      'trunk',
      'trunk_link',
    },

    speeds = function(way) return Urban_density.speeds(way) end, -- function

    maxspeeds = function(way, max_speed) return Urban_density.maxspeeds(way, max_speed) end, -- function

    service_penalties = {
      alley             = 0.9,
      parking           = 0.7,
      parking_aisle     = 0.5,
      driveway          = 0.9,
      ["drive-through"] = 0.7,
      ["drive-thru"] = 0.7
    },

    restricted_highway_whitelist = Set {
      'motorway',
      'motorway_link',
      'trunk',
      'trunk_link',
      'primary',
      'primary_link',
      'secondary',
      'secondary_link',
      'tertiary',
      'tertiary_link',
      'residential',
      'living_street',
      'unclassified',
      'service',
      'pedestrian',
      'track',
    },

    construction_whitelist = Set {
      'no',
      'widening',
      'minor',
    },

    route_speeds = {
      ferry = 5,
      shuttle_train = 10
    },

    bridge_speeds = {
      movable = 5
    },

    -- surface/trackype/smoothness
    -- values were estimated from looking at the photos at the relevant wiki pages

    -- max speed for surfaces
    surface_speeds = {
      asphalt = nil,    -- nil mean no limit. removing the line has the same effect
      concrete = nil,
      ["concrete:plates"] = nil,
      ["concrete:lanes"] = nil,
      paved = nil,

      cement = 45,
      compacted = 30,
      fine_gravel = 20,

      paving_stones = 30,
      metal = 20,
      bricks = 20,

      grass = 20,
      wood = 20,
      sett = 20,
      grass_paver = 20,
      gravel = 20,
      unpaved = 20,
      ground = 20,
      dirt = 20,
      pebblestone = 20,
      tartan = 20,

      cobblestone = 20,
      clay = 20,

      earth = 20,
      stone = 20,
      rocky = 20,
      sand = 20,

      mud = 10
    },

    -- max speed for tracktypes
    tracktype_speeds = {
      grade1 =  40,
      grade2 =  30,
      grade3 =  20,
      grade4 =  15,
      grade5 =  10
    },

    -- max speed for smoothnesses
    smoothness_speeds = {
      intermediate    =  30,
      bad             =  25,
      very_bad        =  20,
      horrible        =  10,
      very_horrible   =  5,
      impassable      =  0
    },

    -- http://wiki.openstreetmap.org/wiki/Speed_limits
    maxspeed_table_default = {
      urban = 40,
      rural = 45,
      trunk = 45,
      motorway = 45
    },

    -- List only exceptions
    maxspeed_table = {
      ["at:rural"] = 50,
      ["at:trunk"] = 50,
      ["be:motorway"] = 50,
      ["be-bru:rural"] = 50,
      ["be-bru:urban"] = 30,
      ["be-vlg:rural"] = 50,
      ["by:urban"] = 50,
      ["by:motorway"] = 50,
      ["ch:rural"] = 50,
      ["ch:trunk"] = 50,
      ["ch:motorway"] = 50,
      ["cz:trunk"] = 50,
      ["cz:motorway"] = 50,
      ["de:living_street"] = 7,
      ["de:rural"] = 50,
      ["de:motorway"] = 50,
      ["dk:rural"] = 50,
      ["fr:rural"] = 50,
      ["gb:nsl_single"] = (50*1609)/1000,
      ["gb:nsl_dual"] = (50*1609)/1000,
      ["gb:motorway"] = (50*1609)/1000,
      ["nl:rural"] = 50,
      ["nl:trunk"] = 50,
      ['no:rural'] = 50,
      ['no:motorway'] = 50,
      ['pl:rural'] = 50,
      ['pl:trunk'] = 50,
      ['pl:motorway'] = 50,
      ["ro:trunk"] = 50,
      ["ru:living_street"] = 20,
      ["ru:urban"] = 50,
      ["ru:motorway"] = 50,
      ["uk:nsl_single"] = (50*1609)/1000,
      ["uk:nsl_dual"] = (50*1609)/1000,
      ["uk:motorway"] = (50*1609)/1000,
      ['za:urban'] = 50,
      ['za:rural'] = 50,
      ["none"] = 50
    },

    relation_types = Sequence {
      "route"
    },

    -- classify highway tags when necessary for turn weights
    highway_turn_classification = {
    },

    -- classify access tags when necessary for turn weights
    access_turn_classification = {
    }
  }
end

-- Load white list of ferries
Ferries_withlist.load("ferries-withlist.csv")

function process_node(profile, node, result, relations)
  -- parse access and barrier tags
  local access = find_access_tag(node, profile.access_tags_hierarchy)
  if access then
    if profile.access_tag_blacklist[access] and not profile.restricted_access_tag_list[access] then
      result.barrier = true
    end
  else
    local barrier = node:get_value_by_key("barrier")
    if barrier then
      --  check height restriction barriers
      local restricted_by_height = false
      if barrier == 'height_restrictor' then
         local maxheight = Measure.get_max_height(node:get_value_by_key("maxheight"), node)
         restricted_by_height = maxheight and maxheight < profile.vehicle_height
      end

      --  make an exception for rising bollard barriers
      local bollard = node:get_value_by_key("bollard")
      local rising_bollard = bollard and "rising" == bollard

      -- make an exception for lowered/flat barrier=kerb
      -- and incorrect tagging of highway crossing kerb as highway barrier
      local kerb = node:get_value_by_key("kerb")
      local highway = node:get_value_by_key("highway")
      local flat_kerb = kerb and ("lowered" == kerb or "flush" == kerb)
      local highway_crossing_kerb = barrier == "kerb" and highway and highway == "crossing"

      if not profile.barrier_whitelist[barrier]
                and not rising_bollard
                and not flat_kerb
                and not highway_crossing_kerb
                or restricted_by_height then
        result.barrier = true
      end
    end
  end

  -- check if node is a traffic light
  result.traffic_lights = TrafficSignal.get_value(node)
end

function process_way(profile, way, result, relations)
  -- the intial filtering of ways based on presence of tags
  -- affects processing times significantly, because all ways
  -- have to be checked.
  -- to increase performance, prefetching and intial tag check
  -- is done in directly instead of via a handler.

  -- in general we should  try to abort as soon as
  -- possible if the way is not routable, to avoid doing
  -- unnecessary work. this implies we should check things that
  -- commonly forbids access early, and handle edge cases later.

  -- data table for storing intermediate values during processing
  local data = {
    -- prefetch tags
    highway = way:get_value_by_key('highway'),
    bridge = way:get_value_by_key('bridge'),
    route = way:get_value_by_key('route')
  }

  -- perform an quick initial check and abort if the way is
  -- obviously not routable.
  -- highway or route tags must be in data table, bridge is optional
  if (not data.highway or data.highway == '') and
  (not data.route or data.route == '')
  then
    return
  end

  handlers = Sequence {
    -- set the default mode for this profile. if can be changed later
    -- in case it turns we're e.g. on a ferry
    WayHandlers.default_mode,

    -- check various tags that could indicate that the way is not
    -- routable. this includes things like status=impassable,
    -- toll=yes and oneway=reversible
    WayHandlers.blocked_ways,
    WayHandlers.avoid_ways,
    WayHandlers.handle_height,
    WayHandlers.handle_width,
    WayHandlers.handle_length,
    WayHandlers.handle_weight,

    -- determine access status by checking our hierarchy of
    -- access tags, e.g: motorcar, motor_vehicle, vehicle
    WayHandlers.access,

    -- check whether forward/backward directions are routable
    WayHandlers.oneway,

    -- check a road's destination
    WayHandlers.destinations,

    -- check whether we're using a special transport mode
    Ferries_withlist.ferries_withlist,
    WayHandlers.movables,

    -- handle service road restrictions
    WayHandlers.service,

    -- handle hov
    WayHandlers.hov,

    -- compute speed taking into account way type, maxspeed tags, etc.
    WayHandlers.speed,
    WayHandlers.maxspeed,
    WayHandlers.surface,

    -- compute class labels
    WayHandlers.classes,
    Mapotempo.classes,

    -- set penalties after setting classes with urban density
    Mapotempo.penalties,
    WayHandlers.penalties,

    -- handle turn lanes and road classification, used for guidance
    WayHandlers.turn_lanes,
    WayHandlers.classification,

    -- handle various other flags
    WayHandlers.roundabouts,
    Startpoint_secure.startpoint_secure,
    WayHandlers.driving_side,

    -- set name, ref and pronunciation
    WayHandlers.names,

    -- set weight properties of the way
    WayHandlers.weights,

    -- set classification of ways relevant for turns
    WayHandlers.way_classification_for_turn
  }

  WayHandlers.run(profile, way, result, data, handlers, relations)

  if profile.cardinal_directions then
      Relations.process_way_refs(way, relations, result)
  end
end

function process_turn(profile, turn)
  -- Use a sigmoid function to return a penalty that maxes out at turn_penalty
  -- over the space of 0-180 degrees.  Values here were chosen by fitting
  -- the function to some turn penalty samples from real driving.
  local turn_penalty = profile.turn_penalty
  local turn_bias = turn.is_left_hand_driving and 1. / profile.turn_bias or profile.turn_bias

  if turn.has_traffic_light then
      turn.duration = profile.properties.traffic_light_penalty
  end

  if turn.number_of_roads > 2 or turn.source_mode ~= turn.target_mode or turn.is_u_turn then
    if turn.angle >= 0 then
      turn.duration = turn.duration + turn_penalty / (1 + math.exp( -((13 / turn_bias) *  turn.angle/180 - 6.5*turn_bias)))
    else
      turn.duration = turn.duration + turn_penalty / (1 + math.exp( -((13 * turn_bias) * -turn.angle/180 - 6.5/turn_bias)))
    end

    if turn.is_u_turn then
      turn.duration = turn.duration + profile.properties.u_turn_penalty
    end
  end

  -- for distance based routing we don't want to have penalties based on turn angle
  if profile.properties.weight_name == 'distance' then
     turn.weight = 0
  else
     turn.weight = turn.duration
  end

  if profile.properties.weight_name == 'routability' then
      -- penalize turns from non-local access only segments onto local access only tags
      if not turn.source_restricted and turn.target_restricted then
          turn.weight = constants.max_turn_weight
      end
  end
end

return {
  setup = setup,
  process_way = process_way,
  process_node = process_node,
  process_turn = process_turn
}
