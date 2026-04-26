local M = {}

M.PHASE = {
  IDLE = "idle",
  WORK = "work",
  SHORT_BREAK = "short_break",
  LONG_BREAK = "long_break",
  PAUSED = "paused",
}

local function fresh()
  return {
    phase = M.PHASE.IDLE,
    started_at = nil, -- ms (vim.uv.now)
    ends_at = nil, -- ms
    remaining_ms = nil, -- only set while paused
    cycle_index = 0, -- completed work blocks since last long break
    completed_today = 0, -- completed work blocks this nvim session
    paused_from = nil, -- phase before pause
  }
end

M.current = fresh()

function M.reset()
  M.current = fresh()
end

function M.is_active()
  local p = M.current.phase
  return p ~= M.PHASE.IDLE
end

function M.is_running()
  local p = M.current.phase
  return p == M.PHASE.WORK or p == M.PHASE.SHORT_BREAK or p == M.PHASE.LONG_BREAK
end

function M.is_break()
  local p = M.current.phase
  return p == M.PHASE.SHORT_BREAK or p == M.PHASE.LONG_BREAK
end

function M.remaining_ms(now_ms)
  local c = M.current
  if c.phase == M.PHASE.PAUSED then
    return c.remaining_ms or 0
  end
  if not c.ends_at then
    return 0
  end
  now_ms = now_ms or vim.uv.now()
  local r = c.ends_at - now_ms
  if r < 0 then
    r = 0
  end
  return r
end

function M.set_phase(phase, duration_ms, now_ms)
  now_ms = now_ms or vim.uv.now()
  M.current.phase = phase
  if phase == M.PHASE.IDLE or phase == M.PHASE.PAUSED then
    M.current.started_at = nil
    M.current.ends_at = nil
  else
    M.current.started_at = now_ms
    M.current.ends_at = now_ms + duration_ms
    M.current.remaining_ms = nil
    M.current.paused_from = nil
  end
end

function M.pause(now_ms)
  if not M.is_running() then
    return false
  end
  now_ms = now_ms or vim.uv.now()
  local remaining = M.remaining_ms(now_ms)
  M.current.paused_from = M.current.phase
  M.current.phase = M.PHASE.PAUSED
  M.current.remaining_ms = remaining
  M.current.started_at = nil
  M.current.ends_at = nil
  return true
end

function M.resume(now_ms)
  if M.current.phase ~= M.PHASE.PAUSED then
    return false, nil, nil
  end
  now_ms = now_ms or vim.uv.now()
  local prev = M.current.paused_from
  local remaining = M.current.remaining_ms or 0
  M.current.phase = prev
  M.current.started_at = now_ms
  M.current.ends_at = now_ms + remaining
  M.current.remaining_ms = nil
  M.current.paused_from = nil
  return true, prev, remaining
end

return M
