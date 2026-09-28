-- SPDX-FileCopyrightText: Copyright 2026-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

-- A simple reference scorer for short test inputs. Unlike the real scorer,
-- tries every legal alignment of the query, scores each one, and returns the
-- largest total (no dynamic programming, memoization, greedy choice, threshold
-- pruning, or work-cap fallback).
return function(candidate, query, options)
  options = options or {}
  local ignore_case = options.ignore_case or false
  local always_show_dot_files = options.always_show_dot_files or false
  local never_show_dot_files = options.never_show_dot_files or false

  local function hidden_dot(position)
    return candidate:sub(position, position) == '.'
      and (position == 1 or candidate:sub(position - 1, position - 1) == '/')
  end

  local has_hidden_component = false
  for position = 1, #candidate do
    if hidden_dot(position) then
      has_hidden_component = true
      break
    end
  end

  if query == '' then
    if has_hidden_component and (never_show_dot_files or not always_show_dot_files) then
      return -1
    end
    return 1
  end
  if candidate == '' or #query > #candidate then
    return 0
  end
  if never_show_dot_files and has_hidden_component then
    return 0
  end

  local compared_candidate = candidate
  if ignore_case then
    compared_candidate = candidate:gsub('[A-Z]', string.lower)
    query = query:gsub('[A-Z]', string.lower)
  end
  local base = (1 / #candidate + 1 / #query) / 2
  local best = 0

  local function contribution(position, previous)
    if previous and position == previous + 1 then
      return base * 1.3
    end

    -- The historical first-character rule uses candidate index zero as the
    -- previous position (index one here), so either of the first two positions
    -- earns the full base score.
    local distance = position - (previous or 1)
    if distance <= 1 then
      return base
    end
    local before = candidate:sub(position - 1, position - 1)
    local character = candidate:sub(position, position)
    if before:match('[a-z]') and character:match('[A-Z]') then
      return base * 0.8
    elseif before == '/' then
      return base * 0.9
    elseif before == '-' or before == '_' or before == ' ' or before:match('[0-9]') then
      return base * 0.8
    elseif before == '.' then
      return base * 0.7
    end
    return base * 0.75 / distance
  end

  local function visit(query_index, previous, total)
    if query_index > #query then
      best = math.max(best, total)
      return
    end

    local character = query:sub(query_index, query_index)
    -- Leave enough characters for the rest of the query. This only excludes
    -- positions from which completing an alignment is impossible.
    local last_position = #candidate - (#query - query_index)
    for position = (previous or 0) + 1, last_position do
      -- A query dot can search past several hidden components before choosing
      -- one. A non-dot cannot cross a hidden dot that has not been consumed.
      if not always_show_dot_files and hidden_dot(position) and character ~= '.' then
        break
      end
      if compared_candidate:sub(position, position) == character then
        visit(query_index + 1, position, total + contribution(position, previous))
      end
    end
  end

  visit(1, nil, 0)
  return best
end
