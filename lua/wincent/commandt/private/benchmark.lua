-- SPDX-FileCopyrightText: Copyright 2014-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local path = require('wincent.commandt.private.path').caller()
local data_directory = (path + '../../../../../data')

data_directory:prepend_to_package_path()

local time = require('wincent.commandt.private.time')
local lib = require('wincent.commandt.private.lib')

lib.epoch() -- Force eager loading of C library.

local reduce = function(list, initial, cb)
  local acc = initial
  for i, value in ipairs(list) do
    acc = cb(acc, value, i)
  end
  return acc
end

local round = function(number)
  return math.floor(number + 0.5)
end

local align = function(stringish, width)
  if type(stringish) == 'string' then
    return string.format('%' .. width .. 's', stringish)
  elseif stringish.align == 'center' then
    local padding = round((width - #stringish.text) / 2)
    return string.format('%' .. padding .. 's%s%' .. padding .. 's', '', stringish.text, ''):sub(1, width)
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

-- Remove trailing zeros.
local trim = function(number)
  return tostring(number):gsub('0+$', '')
end

local print_table = function(rows)
  for _, row in ipairs(rows) do
    local output = ''
    for i, cell in ipairs(row) do
      local width = reduce(rows, 0, function(acc, value)
        local length = type(value[i]) == 'string' and #value[i] or #value[i].text
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

local dump

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
        output = output .. indent .. '  ' .. '[' .. dump(key) .. '] = ' .. dump(item, indent .. '  ') .. ',\n'
      end
      return output .. indent .. '}'
    end
  else
    error('dump(): unsupported type ' .. type(value))
  end
end

local avg = function(values)
  local sum = 0
  for _, value in ipairs(values) do
    sum = sum + value
  end
  return sum / #values
end

local variance = function(values)
  local mean = avg(values)
  local result = 0
  for _, value in ipairs(values) do
    result = result + (mean - value) ^ 2
  end
  return result
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
      table.insert(zipped, { difference, absolute_difference, signedness })
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
      row[SIGNEDNESS] * rank,
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
      { { 15, 0.05 } },
      { { 17, 0.05 }, { 21, 0.025 } },
      { { 22, 0.05 }, { 25, 0.025 }, { 28, 0.01 } },
      { { 26, 0.05 }, { 30, 0.025 }, { 34, 0.01 }, { 36, 0.005 } },
      { { 29, 0.05 }, { 35, 0.025 }, { 39, 0.01 }, { 43, 0.005 } },
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

local benchmark = function(options)
  assert(type(options) == 'table')
  assert(type(options.config) == 'string')
  assert(type(options.log) == 'string')
  assert(type(options.run) == 'function')
  assert(options.setup == nil or type(options.setup) == 'function')
  assert(options.skip == nil or type(options.skip) == 'function')
  assert(options.teardown == nil or type(options.teardown) == 'function')

  -- We use Lua modules for benchmark config and logs so that we don't need to
  -- pull in a JSON or YAML dependency.
  local config = require(options.config)
  local ok, log = pcall(require, options.log)
  log = ok and log or {}

  local results = {
    when = os.date(),
    timings = {},
  }

  local times = tonumber(os.getenv('TIMES') or 20)
  for i = 1, times do
    for _, rehearsal in ipairs({ true, false }) do
      local mode = rehearsal and 'Rehearsal' or 'Final'
      local progress = ' ' .. i .. ' of ' .. times .. ' '
      local gap = (' '):rep(30 - #mode - #progress)
      local header = mode .. progress .. gap .. 'cpu         wall'
      print('\n' .. header)
      print(('-'):rep(#header))

      local cumulative_cpu_delta = 0
      local cumulative_wall_delta = 0
      for _, variant in ipairs(config.variants) do
        if variant.skip and variant.skip(variant) then
          print('Skipping: ' .. variant.name)
        else
          local setup = options.setup and options.setup(variant)
          local wall_delta
          local cpu_delta = time.cpu(function()
            wall_delta = time.wall(function()
              for j = 1, variant.times do
                options.run(variant, setup)
              end
            end)
          end)
          if options.teardown then
            options.teardown(variant)
          end

          cumulative_cpu_delta = cumulative_cpu_delta + cpu_delta
          cumulative_wall_delta = cumulative_wall_delta + wall_delta

          print(string.format('%-22s  %9s    %s', variant.name, float(cpu_delta), parens(float(wall_delta))))

          if not rehearsal then
            results.timings[variant.name] = results.timings[variant.name]
              or {
                cpu = {},
                wall = {},
              }
            table.insert(results.timings[variant.name].cpu, cpu_delta)
            table.insert(results.timings[variant.name].wall, wall_delta)
          end
        end
      end

      print(
        string.format('%-22s  %9s    %s', 'total', float(cumulative_cpu_delta), parens(float(cumulative_wall_delta)))
      )

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

  table.insert(log, results)

  -- Turn 'wincent.commandt.benchmark.logs.name' into
  -- 'wincent/commandt/benchmark/logs/name.lua', then into absolute path.
  local log_file = (data_directory + (options.log:gsub('%.', '/') .. '.lua')):normalize()

  local file, err = io.open(log_file, 'w+')
  if file == nil then
    error(err)
  end
  file:write('-- @generated\nreturn ' .. dump(log) .. '\n')
  file:close()

  print('\n\nSummary of cpu time and (wall time):\n')

  local summary = {
    {
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
    },
  }

  for label, timings in pairs(results.timings) do
    local position = reduce(config.variants, nil, function(acc, variant, i)
      if acc == nil then
        if variant.name == label then
          return i + 1
        end
      end
      return acc
    end)
    if position == nil then
      -- Entries for "total" timing go at the end.
      position = #config.variants + 2
    end
    summary[position] = {
      label,
      float(timings['cpu (best)']),
      float(timings['cpu (avg)']),
      float(timings['cpu (sd)']),
      string.format('[%+0.1f%%]', timings['cpu (+/-)']),
      timings['cpu (significance)'] > 0 and trim(timings['cpu (significance)']) or '',
      parens(float(timings['wall (best)'])),
      parens(float(timings['wall (avg)'])),
      parens(float(timings['wall (sd)'])),
      string.format('[%+0.1f%%]', timings['wall (+/-)']),
      timings['wall (significance)'] > 0 and trim(timings['wall (significance)']) or '',
    }
  end

  print_table(summary)
end

return benchmark
