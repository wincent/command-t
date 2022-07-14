#!/usr/bin/env luajit

-- SPDX-FileCopyrightText: Copyright 2014-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require'ffi'

local pwd = os.getenv('PWD')
local benchmarks_directory  = debug.getinfo(1).source:match('@?(.*/)')
local data_directory = pwd .. '/' .. benchmarks_directory .. '../../data/'
local lua_directory = pwd .. '/' .. benchmarks_directory .. '../../lua/'

package.path = lua_directory .. '?.lua;' .. package.path
package.path = lua_directory .. '?/init.lua;' .. package.path
package.path = data_directory .. '?.lua;' .. package.path

local commandt = require'wincent.commandt'
local time = require'wincent.commandt.private.time'

-- We use Lua modules for benchmark data so that we don't need to pull in a JSON
-- or YAML dependency.
local data = require'wincent.benchmark'
local ok, log = pcall(require, 'wincent.benchmark.log')
log = ok and log or {}

local lib = require'wincent.commandt.private.lib'

commandt.epoch() -- Force eager loading of C library.

local round = function(number)
  return math.floor(number + 0.5)
end

local align = function(stringish, width)
  if type(stringish) == 'string' then
    return string.format('%' .. width .. 's', stringish)
  elseif stringish.align == 'center' then
    local padding = round((width - #(stringish.text)) / 2)
    return string.format(
      '%' .. padding .. 's%s%' .. padding .. 's',
      '',
      stringish.text,
      ''
    ):sub(1, width)
  elseif stringish.align == 'left' then
    return string.format('%-' .. width .. 's', stringish.text)
  else
    return string.format('%' .. width .. 's', stringish.text)
  end
end

local center = function(text)
  return {
    align = 'center',
    text = text,
  }
end

local left = function(text)
  return {
    align = 'left',
    text = text,
  }
end

local right = function(text)
  return {
    align = 'left',
    text = text,
  }
end

local float = function(number)
  return string.format('%.5f', number)
end

local parens = function(text)
  return '(' .. text .. ')'
end

local options = {
  recurse = os.getenv('RECURSE') == nil or os.getenv('RECURSE') == '1',
  threads = tonumber(os.getenv('THREADS')),
  -- TODO may want to put something in here (like a high limit) to make this an
  -- apples-to-apples comparison
  -- although in reality, no client will (or should) ever ask for more than,
  -- say, 100 matches...
  -- TODO figure out why RECURSE makes a big difference in Lua port but almost
  -- none in Ruby one
}

local results = {
  when = os.date(),
  timings = {},
}

-- TODO: if TIMES > 1 then there is probably no point in doing 20 rehearsals
local times = tonumber(os.getenv('TIMES') or 20)
for i = 1, times do
  for _, rehearsal in ipairs({true, false}) do
    local mode = rehearsal and 'Rehearsal' or 'Final'
    local progress = ' ' .. i .. ' of ' .. times .. ' '
    local gap = (' '):rep(30 - #mode - #progress)
    local header = mode .. progress .. gap .. 'cpu         wall'
    print('\n' .. header)
    print(('-'):rep(#header))

    local cumulative_cpu_delta = 0
    local cumulative_wall_delta = 0
    for _, config in ipairs(data.tests) do
      local scanner = lib.scanner_new_copy(config.paths)
      local matcher = lib.commandt_matcher_new(scanner, options)

      local wall_delta
      local cpu_delta = time.cpu(function()
        wall_delta = time.wall(function()
          for j = 1, config.times do
            for _, query in ipairs(config.queries) do
              local input = ''
              for letter in query:gmatch('.') do
                local matches = lib.commandt_matcher_run(matcher, input)
                for k = 0, matches.count - 1 do
                  local str = matches.matches[k]
                  ffi.string(str.contents, str.length)
                end
                input = input .. letter
              end
              local matches = lib.commandt_matcher_run(matcher, input)
              for k = 0, matches.count - 1 do
                local str = matches.matches[k]
                ffi.string(str.contents, str.length)
              end
            end
          end
        end)
      end)

      cumulative_cpu_delta = cumulative_cpu_delta + cpu_delta
      cumulative_wall_delta = cumulative_wall_delta + wall_delta

      print(string.format('%-22s  %9s    %s', config.name, float(cpu_delta), parens(float(wall_delta))))

      if not rehearsal then
        results.timings[config.name] = results.timings[config.name] or {
          cpu = {},
          wall = {},
        }
        table.insert(results.timings[config.name].cpu, cpu_delta)
        table.insert(results.timings[config.name].wall, wall_delta)
      end
    end


    print(string.format('%-22s  %9s    %s', 'total', float(cumulative_cpu_delta), parens(float(cumulative_wall_delta))))

    if not rehearsal then
      results.timings.total = results.timings.total or {
        cpu = {},
        wall = {},
      }
      table.insert(results.timings.total.cpu, cumulative_cpu_delta)
      table.insert(results.timings.total.wall, cumulative_wall_delta)
    end
  end
end

local dump

local avg = function(values)
  local sum = 0
  for _, value in ipairs(values) do
    sum = sum + value
  end
  return sum / #values
end

local DIFFERENCE = 1
local ABSOLUTE_DIFFERENCE = 2
local SIGNEDNESS = 3
local SIGNED_RANK = 4

-- Test for significance via Wilcoxon Signed Rank test.
--
-- See: http://vassarstats.net/textbook/ch12a.html
local significance = function(last, current)
  if #last ~= #current then
    return 0
  end

  local zipped = {}
  for i, l in ipairs(last) do
    local difference = l - current[i]
    if difference ~= 0 then
      local absolute_difference = math.abs(difference)
      local signedness = difference / absolute_difference -- 1 or -1.
      table.insert(zipped, {difference, absolute_difference, signedness})
    end
  end

  table.sort(zipped, function(a, b)
    return a[ABSOLUTE_DIFFERENCE] < b[ABSOLUTE_DIFFERENCE]
  end)

  local rank = 1
  local ranked = {}

  for i, row in ipairs(zipped) do
    local acc = 0
    local count = 0
    for j, inner_row in ipairs(zipped) do
      if inner_row[ABSOLUTE_DIFFERENCE] == row[ABSOLUTE_DIFFERENCE] then
        count = count + 1
        acc = acc + j
      end
    end
    rank = acc / count
    table.insert(ranked, {
      row[DIFFERENCE],
      row[ABSOLUTE_DIFFERENCE],
      row[SIGNEDNESS],
      row[SIGNEDNESS] * rank
    })
  end

  local n = #ranked
  local w = 0

  for _, row in ipairs(ranked) do
    w = w + row[SIGNED_RANK]
  end

  local p_value = 0
  if n < 10 then
    local thresholds = ({
      {},
      {},
      {},
      {},
      {},
      {{15, 0.05}},
      {{17, 0.05}, {21, 0.025}},
      {{22, 0.05}, {25, 0.025}, {28, 0.01}},
      {{26, 0.05}, {30, 0.025}, {34, 0.01}, {36, 0.005}},
      {{29, 0.05}, {35, 0.025}, {39, 0.01}, {43, 0.005}},
    })[n + 1]
    while true do
      local limit = table.remove(thresholds, #thresholds)
      if limit == nil then
        break
      end
      if math.abs(w) >= limit[1] then
        p_value = limit[2]
        break
      end
    end
  else
    local sd = math.sqrt(n * (n + 1) * (2 * n + 1) / 6)
    local z = math.abs((w - 0.5) / sd)
    if z >= 3.291 then
      p_value = 0.0005
    elseif z >= 2.576 then
      p_value = 0.005
    elseif z >= 2.326 then
      p_value = 0.01
    elseif z >= 1.960 then
      p_value = 0.025
    elseif z >= 1.645 then
      p_value = 0.05
    end
  end

  return p_value
end

local variance = function(values)
  local mean = avg(values)
  local result = 0
  for _, value in ipairs(values) do
    result = result + (mean - value) ^ 2
  end
  return result
end

local previous = log[#log]

for label, metrics in pairs(results.timings) do
  metrics['cpu (best)'] = math.min(unpack(metrics.cpu))
  metrics['wall (best)'] = math.min(unpack(metrics.wall))

  metrics['cpu (avg)'] = avg(metrics.cpu)
  metrics['wall (avg)'] = avg(metrics.wall)

  local cpu_avg = metrics['cpu (avg)']
  local wall_avg = metrics['wall (avg)']

  if previous then
    local previous_cpu_avg = previous.timings[label]['cpu (avg)']
    local previous_cpu = previous.timings[label].cpu
    local previous_wall_avg = previous.timings[label]['wall (avg)']
    local previous_wall = previous.timings[label].wall

    metrics['cpu (+/-)'] = (cpu_avg - previous_cpu_avg) / cpu_avg * 100
    metrics['wall (+/-)'] = (wall_avg - previous_wall_avg) / wall_avg * 100

    metrics['cpu (significance)'] = significance(previous_cpu, metrics.cpu)
    metrics['wall (significance)'] = significance(previous_wall, metrics.wall)

  else
    metrics['cpu (+/-)'] = 0
    metrics['wall (+/-)'] = 0

    metrics['cpu (significance)'] = 0
    metrics['wall (significance)'] = 0
  end

  metrics['cpu (variance)'] = variance(metrics.cpu)
  metrics['wall (variance)'] = variance(metrics.wall)

  metrics['cpu (sd)'] = math.sqrt(metrics['cpu (variance)'])
  metrics['wall (sd)'] = math.sqrt(metrics['wall (variance)'])
end

dump = function(value, indent)
  indent = indent or ''
  if type(value) == 'nil' then
    return 'nil'
  elseif type(value) == 'number' then
    return tostring(value)
  elseif type(value) == 'string' then
    if value:match("'") then
      error('dump(): cannot serialize string containing single quote')
    end
    return "'" .. value .. "'"
  elseif type(value) == 'table' then
    if value[1] ~= nil then -- Assume it's a list.
      local output = '{\n'
      for _, item in ipairs(value) do
        output = output .. indent .. '  ' .. dump(item, indent .. '  ') .. ',\n'
      end
      return output .. indent .. '}'
    else
      local output = '{\n'
      for key, item in pairs(value) do
        output = output .. indent .. '  ' ..
          '[' .. dump(key) .. '] = ' ..
          dump(item, indent .. '  ') .. ',\n'
      end
      return output .. indent .. '}'
    end
  else
    error('dump(): unsupported type ' .. type(value))
  end
end

table.insert(log, results)
local file, err = io.open(data_directory .. 'wincent/benchmark/log.lua', 'w+')
if file == nil then
  error(err)
end
file:write('-- @generated\nreturn ' .. dump(log) .. '\n')
file:close()

-- Remove trailing zeros.
local trim = function(number)
  return tostring(number):gsub('0+$', '')
end

print('\n\nSummary of cpu time and (wall time):\n')

local summary = {{
  '',
  center('best'),
  center('avg'),
  center('sd'),
  center('+/-'),
  center('p'),
  center('(best)'),
  center('(avg)'),
  center('(sd)'),
  center('+/-'),
  center('p'),
}}

local reduce = function(list, initial, cb)
  local acc = initial
  for i, value in ipairs(list) do
    acc = cb(acc, value, i)
  end
  return acc
end

for label, timings in pairs(results.timings) do
  local position = reduce(data.tests, nil, function(acc, config, i)
    if acc == nil then
      if config.name == label then
        return i + 1
      end
    end
    return acc
  end)
  if position == nil then
    -- Entries for "total" timing go at the end.
    position = #(data.tests) + 2
  end
  summary[position] = {
    label,
    float(timings['cpu (best)']),
    float(timings['cpu (avg)']),
    float(timings['cpu (sd)']),
    string.format('[%+0.1f%%]', timings['cpu (+/-)']),
    timings['cpu (significance)'] > 0 and trim(timings['cpu (significance)']) or '',
    float(timings['wall (best)']),
    float(timings['wall (avg)']),
    float(timings['wall (sd)']),
    string.format('[%+0.1f%%]', timings['wall (+/-)']),
    timings['wall (significance)'] > 0 and trim(timings['wall (significance)']) or '',
  }
end

local print_table = function(rows)
  for _, row in ipairs(rows) do
    local output = ''
    for i, cell in ipairs(row) do
      local width = reduce(rows, 0, function(acc, value)
        local length = type(value[i]) == 'string' and #(value[i]) or #(value[i].text)
        if length > acc then
          return length
        else
          return acc
        end
      end)
      if i == 1 then
        output = output .. align(cell, width)
      else
        output = output .. ' ' .. align(cell, width)
      end
    end
    print(output)
  end
end

print_table(summary)
