local rq_get_hex = require('cokeline/utils').get_hex
local rq_palette = require('colorscheme').palette
-- local rq_sliders = require('cokeline/sliders')

local comments_fg = rq_get_hex('Comment', 'fg')
local errors_fg = rq_get_hex('DiagnosticError', 'fg')
local warnings_fg = rq_get_hex('DiagnosticWarn', 'fg')

local components = {
  space = {
    text = ' ',
    truncation = { priority = 1 }
  },

  two_spaces = {
    text = '  ',
    truncation = { priority = 1 },
  },

  separator = {
    text = function(buffer)
      return buffer.index ~= 1 and '▏' or ''
    end,
  },

  devicon = {
    text = function(buffer)
      return buffer.devicon.icon
    end,
    hl = {
      fg = function(buffer)
        return buffer.devicon.color
      end,
    },
  },

  index = {
    text = function(buffer)
      return buffer.index .. ': '
    end,
    hl = {
      fg = function(buffer)
        return
          (buffer.diagnostics.errors ~= 0 and errors_fg)
          or (buffer.diagnostics.warnings ~= 0 and warnings_fg)
          or nil
      end,
    },
  },

  unique_prefix = {
    text = function(buffer)
      return buffer.unique_prefix
    end,
    hl = {
      fg = comments_fg,
      style = 'italic',
    },
    truncation = {
      priority = 7,
      direction = 'left',
    },
  },

  filename = {
    text = function(buffer)
      return buffer.filename
    end,
    hl = {
      fg = function(buffer)
        return
          (buffer.diagnostics.errors ~= 0 and errors_fg)
          or (buffer.diagnostics.warnings ~= 0 and warnings_fg)
          or nil
      end,
      style = function(buffer)
        return
          ((buffer.is_focused and buffer.diagnostics.errors ~= 0)
            and 'bold,underline')
          or (buffer.is_focused and 'bold')
          or (buffer.diagnostics.errors ~= 0 and 'underline')
          or nil
      end
    },
    truncation = { direction = 'left' },
  },

  diagnostics = {
    text = function(buffer)
      return
        (buffer.diagnostics.errors ~= 0 and '  ' .. buffer.diagnostics.errors)
        or (buffer.diagnostics.warnings ~= 0 and '  ' .. buffer.diagnostics.warnings)
        or ''
    end,
    hl = {
      fg = function(buffer)
        return
          (buffer.diagnostics.errors ~= 0 and errors_fg)
          or (buffer.diagnostics.warnings ~= 0 and warnings_fg)
          or nil
      end,
    },
    truncation = { priority = 2 },
  },

  close_or_unsaved = {
    text = function(buffer)
      return buffer.is_modified and '●' or ''
    end,
    hl = {
      fg = function(buffer)
        return buffer.is_modified and rq_palette.normal.green or nil
      end
    },
    delete_buffer_on_left_click = true,
    truncation = { priority = 5 },
  },
}

require('cokeline').setup({
  show_if_buffers_are_at_least = 2,

  buffers = {
    filter_valid = function(buffer) return buffer.type ~= 'terminal' end,
    new_buffers_position = 'next',
  },

  rendering = {
    max_buffer_width = 30,
    -- slider = rq_sliders.slide_if_needed,
  },

  default_hl = {
    focused = {
      fg = rq_get_hex('Normal', 'fg'),
      bg = rq_get_hex('ColorColumn', 'bg'),
    },
    unfocused = {
      fg = rq_get_hex('Comment', 'fg'),
      bg = rq_get_hex('ColorColumn', 'bg'),
    },
  },

  components = {
    components.space,
    components.separator,
    components.space,
    components.devicon,
    components.space,
    components.index,
    components.unique_prefix,
    components.filename,
    components.diagnostics,
    components.two_spaces,
    components.close_or_unsaved,
    components.space,
  },
})