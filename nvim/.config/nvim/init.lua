-- ══════════════════════════════════════════════════════════════════════════════
-- Bootstrap lazy.nvim
-- ══════════════════════════════════════════════════════════════════════════════
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    'git', 'clone', '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- ══════════════════════════════════════════════════════════════════════════════
-- Leader (must be set before lazy)
-- ══════════════════════════════════════════════════════════════════════════════
vim.g.mapleader      = ' '
vim.g.maplocalleader = ' '

-- ══════════════════════════════════════════════════════════════════════════════
-- Early globals (plugin vars that must exist before plugins load)
-- ══════════════════════════════════════════════════════════════════════════════
-- netrw is active: handles :e /dir and nvim /dir directory browsing
-- nvim-tree coexists as a side-panel toggle only (hijack_netrw = false)


-- ══════════════════════════════════════════════════════════════════════════════
-- Plugins
-- ══════════════════════════════════════════════════════════════════════════════
require('lazy').setup({

  -- ── Colorschemes ─────────────────────────────────────────────────────────
  -- Switch live with <leader>cs (Telescope picker).
  -- To change default: update the colorscheme name in the ACTIVE block below.
  { 'rebelot/kanagawa.nvim', event = 'VeryLazy' },
  {
    'bluz71/vim-nightfly-colors',    -- ACTIVE
    name     = 'nightfly',
    lazy     = false,
    priority = 1000,
    config   = function()
      vim.cmd.colorscheme('nightfly')
    end,
  },
  -- Installed (available via <leader>cs — all load at VeryLazy):
  -- ── dark/warm ───────────────────────────────────────────────────────────
  { 'jacoborus/tender.vim',           event = 'VeryLazy' },                                    -- warm amber, vimscript classic
  { 'ellisonleao/gruvbox.nvim',       event = 'VeryLazy' },                                    -- earthy retro
  { 'sainnhe/gruvbox-material',       event = 'VeryLazy' },                                    -- softer gruvbox variant
  { 'sainnhe/everforest',             event = 'VeryLazy' },                                    -- muted greens
  { 'ribru17/bamboo.nvim',            event = 'VeryLazy' },                                    -- green-tinted, easy on eyes
  -- ── dark/cool ───────────────────────────────────────────────────────────
  { 'catppuccin/nvim',                name = 'catppuccin', event = 'VeryLazy',
    opts = { flavour = 'mocha' } },                                                            -- mocha/macchiato/frappe
  { 'rose-pine/neovim',               name = 'rose-pine',   event = 'VeryLazy' },             -- rose-pine/moon
  { 'folke/tokyonight.nvim',          event = 'VeryLazy',   opts = { style = 'night' } },     -- night/storm/moon
  { 'EdenEast/nightfox.nvim',         event = 'VeryLazy' },                                    -- nightfox/duskfox/nordfox/terafox
  { 'rmehri01/onenord.nvim',          event = 'VeryLazy' },                                    -- Nord palette, warmer
  { 'shatur/neovim-ayu',              event = 'VeryLazy' },                                    -- ayu-dark/mirage
  { 'oxfist/night-owl.nvim',          event = 'VeryLazy' },                                    -- Sarah Drasner's night owl
  -- ── OneDark family ──────────────────────────────────────────────────────
  { 'navarasu/onedark.nvim',          event = 'VeryLazy' },                                    -- dark/darker/cool/deep/warm/warmer
  { 'olimorris/onedarkpro.nvim',      event = 'VeryLazy' },                                    -- onedark_pro/vivid/dark
  -- ── high contrast / vivid ───────────────────────────────────────────────
  { 'sainnhe/sonokai',                event = 'VeryLazy' },                                    -- default/atlantis/andromeda/shusia/maia/espresso
  { 'Mofiqul/dracula.nvim',           event = 'VeryLazy' },                                    -- classic dracula
  { 'scottmckendry/cyberdream.nvim',  event = 'VeryLazy' },                                    -- neon cyberpunk
  { 'bluz71/vim-moonfly-colors',      name = 'moonfly',     event = 'VeryLazy' },              -- cool dark moonlit
  -- ── IDE-familiar ────────────────────────────────────────────────────────
  { 'projekt0n/github-nvim-theme',    event = 'VeryLazy' },                                    -- github_dark/dark_dimmed/dark_colorblind/dark_high_contrast
  { 'Mofiqul/vscode.nvim',            event = 'VeryLazy' },                                    -- VSCode dark+
  { 'marko-cerovac/material.nvim',    event = 'VeryLazy',
    opts = { style = 'palenight' } },                                                          -- darker/dark/palenight/oceanic

  -- ── LSP ──────────────────────────────────────────────────────────────────
  -- blink.cmp (loaded when nvim ≥ 0.10) is listed as a dependency so lazy.nvim
  -- ensures it loads first on capable versions; on nvim 0.9 it is disabled
  -- (cond below) and the lspconfig config falls back to default capabilities.
  {
    'neovim/nvim-lspconfig',
    lazy = false,
    dependencies = {
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',
      'saghen/blink.cmp',
    },
    config = function()
      require('mason').setup()

      -- blink.cmp requires nvim ≥ 0.10; fall back to plain capabilities on older.
      local capabilities = vim.fn.has('nvim-0.10') == 1
        and require('blink.cmp').get_lsp_capabilities()
        or vim.lsp.protocol.make_client_capabilities()

      -- Single LspAttach autocmd covers all servers — no per-server on_attach needed.
      vim.api.nvim_create_autocmd('LspAttach', {
        group    = vim.api.nvim_create_augroup('UserLspAttach', { clear = true }),
        callback = function(event)
          local bufnr  = event.buf
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          local opts   = { buffer = bufnr, silent = true }
          local map    = function(key, fn, desc)
            vim.keymap.set('n', key, fn, vim.tbl_extend('force', opts, { desc = desc }))
          end
          map('gd', vim.lsp.buf.definition,      'Go to definition')
          map('gD', vim.lsp.buf.declaration,     'Go to declaration')
          map('gr', vim.lsp.buf.references,      'References')
          map('gi', vim.lsp.buf.implementation,  'Go to implementation')
          map('K',  vim.lsp.buf.hover,           'Hover docs')
          map('<leader>rn', vim.lsp.buf.rename,      'Rename symbol')
          map('<leader>ca', vim.lsp.buf.code_action, 'Code action')
          map('<leader>d',  vim.diagnostic.open_float, 'Show diagnostics')
          -- vim.diagnostic.jump() was added in nvim 0.10
          if vim.fn.has('nvim-0.10') == 1 then
            map('[d', function() vim.diagnostic.jump({ count = -1 }) end, 'Prev diagnostic')
            map(']d', function() vim.diagnostic.jump({ count = 1 }) end,  'Next diagnostic')
          else
            map('[d', vim.diagnostic.goto_prev, 'Prev diagnostic')
            map(']d', vim.diagnostic.goto_next, 'Next diagnostic')
          end

          -- LSP word highlight — replaces vim-illuminate (semantic, not regex)
          -- Use a buffer-keyed augroup so multiple servers attaching to the same
          -- buffer don't stack duplicate CursorHold autocmds (clear = true replaces).
          if client and client.supports_method('textDocument/documentHighlight') then
            local hl_group = vim.api.nvim_create_augroup('UserDocHighlight_' .. bufnr, { clear = true })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer   = bufnr,
              group    = hl_group,
              callback = vim.lsp.buf.document_highlight,
            })
            vim.api.nvim_create_autocmd('CursorMoved', {
              buffer   = bufnr,
              group    = hl_group,
              callback = vim.lsp.buf.clear_references,
            })
          end
        end,
      })

      -- Server configs defined once; registration method differs by nvim version.
      -- nvim 0.11+: vim.lsp.config/enable (new built-in API, no lspconfig on_attach)
      -- nvim 0.9–0.10: lspconfig.server.setup() (classic API)
      local servers = {
        pyright = {
          capabilities = capabilities,
          settings = { python = { analysis = { useLibraryCodeForTypes = true } } },
        },
        clangd = { capabilities = capabilities },
        bashls = { capabilities = capabilities },
        lua_ls = {
          capabilities = capabilities,
          settings = {
            Lua = {
              runtime     = { version = 'LuaJIT' },
              workspace   = { library = { vim.env.VIMRUNTIME }, checkThirdParty = false },
              diagnostics = { globals = { 'vim' } },
            },
          },
        },
      }

      if vim.fn.has('nvim-0.11') == 1 then
        require('mason-lspconfig').setup({
          ensure_installed = vim.tbl_keys(servers),
          automatic_enable = false, -- we call vim.lsp.enable() below
        })
        for name, cfg in pairs(servers) do vim.lsp.config(name, cfg) end
        vim.lsp.enable(vim.tbl_keys(servers))
      else
        require('mason-lspconfig').setup({ ensure_installed = vim.tbl_keys(servers) })
        local lspconfig = require('lspconfig')
        for name, cfg in pairs(servers) do lspconfig[name].setup(cfg) end
      end

      vim.diagnostic.config({
        severity_sort = true,
        float         = { border = 'rounded', source = true },
      })
    end,
  },

  -- ── Completion ───────────────────────────────────────────────────────────
  {
    'saghen/blink.cmp',
    cond         = vim.fn.has('nvim-0.10') == 1, -- uses vim.snippet built-in (nvim 0.10+)
    version      = '*', -- use release tags (pre-built Rust binary)
    dependencies = { 'rafamadriz/friendly-snippets' },
    config       = function()
      require('blink.cmp').setup({
        keymap = {
          preset      = 'default',
          ['<Tab>']   = { 'select_next', 'snippet_forward', 'fallback' },
          ['<S-Tab>'] = { 'select_prev', 'snippet_backward', 'fallback' },
          ['<CR>']    = { 'accept', 'fallback' },
        },
        sources = {
          default = { 'lsp', 'path', 'snippets', 'buffer' },
        },
        snippets = { preset = 'default' },                       -- uses vim.snippet (nvim 0.10+ built-in)
        completion = {
          list          = { selection = { preselect = false } }, -- require explicit Tab before CR accepts
          accept        = { auto_brackets = { enabled = true } },
          documentation = { auto_show = true, auto_show_delay_ms = 200 },
          menu          = {
            min_width = 30,
            draw = {
              components = {
                label             = { width = { fill = true, max = 80 } },
                label_description = { width = { max = 50 } },
              },
            },
          },
        },
      })
    end,
  },

  -- ── Treesitter ───────────────────────────────────────────────────────────
  {
    'nvim-treesitter/nvim-treesitter',
    lazy         = false,
    build        = ':TSUpdate',
    dependencies = {
      'nvim-treesitter/nvim-treesitter-textobjects',
      {
        'nvim-treesitter/nvim-treesitter-context',
        config = function()
          require('treesitter-context').setup({ max_lines = 3 })
        end,
      },
    },
    config       = function()
      -- Highlighting: built-in vim.treesitter, enabled per filetype
      vim.api.nvim_create_autocmd('FileType', {
        group    = vim.api.nvim_create_augroup('UserTreesitter', { clear = true }),
        pattern  = {
          'python', 'cpp', 'c', 'bash', 'lua', 'vim',
          'json', 'javascript', 'typescript', 'yaml', 'toml',
          'markdown', 'rust', 'go', 'html', 'css',
        },
        callback = function() pcall(vim.treesitter.start) end,
      })

      -- Textobjects: select
      local sel = require('nvim-treesitter-textobjects.select')
      for lhs, query in pairs({
        af = '@function.outer', ['if'] = '@function.inner',
        ac = '@class.outer', ic = '@class.inner',
        aa = '@parameter.outer', ia = '@parameter.inner',
      }) do
        vim.keymap.set({ 'x', 'o' }, lhs,
          function() sel.select_textobject(query, 'textobjects') end,
          { desc = query })
      end

      -- Textobjects: move
      local mv = require('nvim-treesitter-textobjects.move')
      vim.keymap.set('n', ']f', function() mv.goto_next_start('@function.outer', 'textobjects') end, { desc = 'Next function' })
      vim.keymap.set('n', '[f', function() mv.goto_previous_start('@function.outer', 'textobjects') end, { desc = 'Prev function' })
      vim.keymap.set('n', ']C', function() mv.goto_next_start('@class.outer', 'textobjects') end, { desc = 'Next class' })
      vim.keymap.set('n', '[C', function() mv.goto_previous_start('@class.outer', 'textobjects') end, { desc = 'Prev class' })
    end,
  },

  -- ── Telescope ────────────────────────────────────────────────────────────
  {
    'nvim-telescope/telescope.nvim',
    cmd          = 'Telescope',
    keys         = {
      { '<C-p>',      '<cmd>Telescope find_files<CR>',                      desc = 'Find files' },
      { '<F3>',       '<cmd>Telescope buffers<CR>',                         desc = 'Buffers' },
      { '<leader>f',  '<cmd>Telescope git_files<CR>',                       desc = 'Git files' },
      { '<leader>F',  '<cmd>Telescope find_files<CR>',                      desc = 'Find files' },
      { '<leader>g',  '<cmd>Telescope live_grep<CR>',                       desc = 'Live grep' },
      { '<leader>G',  '<cmd>Telescope grep_string<CR>',                     desc = 'Grep string' },
      { '<leader>b',  '<cmd>Telescope buffers<CR>',                         desc = 'Buffers' },
      { '<leader>s',  '<cmd>Telescope lsp_document_symbols<CR>',            desc = 'Doc symbols' },
      { '<leader>S',  '<cmd>Telescope lsp_workspace_symbols<CR>',           desc = 'WS symbols' },
      { '<leader>lr', '<cmd>Telescope lsp_references<CR>',                  desc = 'LSP references' },
      { '<leader>cs', '<cmd>Telescope colorscheme enable_preview=true<CR>', desc = 'Colorscheme picker' },
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
      { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
    },
    config       = function()
      local telescope = require('telescope')
      local actions   = require('telescope.actions')
      telescope.setup({
        defaults = {
          mappings = {
            i = {
              ['<C-j>'] = actions.move_selection_next,
              ['<C-k>'] = actions.move_selection_previous,
              ['<Esc>'] = actions.close,
            },
          },
          file_ignore_patterns = { '%.git/', 'node_modules/', '__pycache__/', '%.o', '%.a' },
          vimgrep_arguments = {
            'rg', '--color=never', '--no-heading', '--with-filename',
            '--line-number', '--column', '--smart-case', '--hidden',
          },
        },
        pickers = {
          find_files = { hidden = true },
          live_grep  = { additional_args = function() return { '--hidden' } end },
        },
      })
      telescope.load_extension('fzf')
    end,
  },

  -- ── UI ───────────────────────────────────────────────────────────────────
  {
    'nvim-lualine/lualine.nvim',
    lazy = false,
    config = function()
      require('lualine').setup({
        options = {
          theme                = 'auto',
          icons_enabled        = true,
          component_separators = { left = '', right = '' },
          section_separators   = { left = '', right = '' },
        },
        sections = {
          lualine_a = { 'mode' },
          lualine_b = { 'branch', 'diff', 'diagnostics' },
          lualine_c = { { 'filename', path = 1 } },
          lualine_x = { 'encoding', 'fileformat', 'filetype' },
          lualine_y = { 'progress' },
          lualine_z = { 'location' },
        },
      })
    end,
  },
  {
    'folke/which-key.nvim',
    event  = 'VeryLazy',
    config = function()
      local wk = require('which-key')
      wk.setup()
      wk.add({
        { '<leader>h', group = 'git hunks' },
        { '<leader>l', group = 'LSP' },
        { '<leader>x', group = 'diagnostics' },
        { '<leader>c', group = 'colorscheme' },
      })
    end,
  },
  {
    'nvimdev/dashboard-nvim',
    lazy         = false,
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config       = function()
      require('dashboard').setup({
        theme = 'hyper',
        config = {
          week_header = { enable = true },
          shortcut = {
            { desc = ' Files',  group = 'Label', action = 'Telescope find_files', key = 'f' },
            { desc = ' Grep',   group = 'Label', action = 'Telescope live_grep',  key = 'g' },
            { desc = ' Config', group = 'Label', action = 'e $MYVIMRC',           key = 'v' },
            { desc = ' Quit',   group = 'Label', action = 'qa',                   key = 'q' },
          },
        },
      })
    end,
  },

  -- ── File tree ────────────────────────────────────────────────────────────
  {
    'nvim-tree/nvim-tree.lua',
    lazy         = true,
    keys         = { { '<F6>', '<cmd>NvimTreeToggle<CR>', desc = 'File tree' } },
    config       = function()
      require('nvim-tree').setup({
        hijack_netrw       = false,              -- let netrw handle :e /dir
        hijack_directories = { enable = false }, -- no directory interception
      })
    end,
  },

  -- ── Git ──────────────────────────────────────────────────────────────────
  {
    'lewis6991/gitsigns.nvim',
    event  = 'BufReadPost',
    config = function()
      require('gitsigns').setup({
        signs = {
          add          = { text = '▎' },
          change       = { text = '▎' },
          delete       = { text = '▁' },
          topdelete    = { text = '▔' },
          changedelete = { text = '▎' },
        },
        on_attach = function(bufnr)
          local gs   = package.loaded.gitsigns
          local opts = { buffer = bufnr, silent = true }
          local map  = function(key, fn, desc)
            vim.keymap.set('n', key, fn, vim.tbl_extend('force', opts, { desc = desc }))
          end
          map(']h', gs.next_hunk, 'Next hunk')
          map('[h', gs.prev_hunk, 'Prev hunk')
          map('<leader>hs', gs.stage_hunk, 'Stage hunk')
          map('<leader>hu', gs.undo_stage_hunk, 'Undo stage hunk')
          map('<leader>hp', gs.preview_hunk, 'Preview hunk')
          map('<leader>hb', function() gs.blame_line({ full = true }) end, 'Blame line')
          map('<leader>hB', gs.toggle_current_line_blame, 'Toggle inline blame')
          map('<leader>hd', gs.diffthis, 'Diff this')
        end,
      })
    end,
  },
  {
    'tpope/vim-fugitive',
    cmd = { 'Git', 'Gdiffsplit', 'Gvdiffsplit', 'Gclog', 'GMove', 'GDelete' },
  },

  -- ── Diagnostics & formatting ─────────────────────────────────────────────
  {
    'folke/trouble.nvim',
    cmd    = 'Trouble',
    keys   = {
      { '<leader>xx', '<cmd>Trouble diagnostics toggle<CR>',              desc = 'Trouble' },
      { '<leader>xb', '<cmd>Trouble diagnostics toggle filter.buf=0<CR>', desc = 'Trouble buf' },
    },
    config = function() require('trouble').setup() end,
  },
  {
    'stevearc/conform.nvim',
    event  = 'BufWritePre',
    config = function()
      require('conform').setup({
        notify_no_formatters = false, -- silence when formatter not installed
        formatters_by_ft = {
          lua        = { 'stylua' },          -- :MasonInstall stylua
          python     = { 'ruff_fix', 'ruff_format' }, -- ruff replaces black+isort; respects pyproject.toml/ruff.toml per project
          cpp        = { 'clang_format' },
          c          = { 'clang_format' },
          sh         = { 'shfmt' },
          bash       = { 'shfmt' },
          javascript = { 'prettier' },
          json       = { 'prettier' },
        },
        format_on_save = function()
          if vim.env.NOFORMAT then return end
          return { timeout_ms = 500, lsp_format = 'fallback' }
        end,
      })
    end,
  },

  -- ── Editing helpers ──────────────────────────────────────────────────────
  { 'kylechui/nvim-surround',  event = 'VeryLazy', config = function() require('nvim-surround').setup() end },
  { 'tpope/vim-repeat',        event = 'VeryLazy' },
  { 'andymass/vim-matchup',    event = 'BufReadPost' },
  {
    'echasnovski/mini.ai',
    event  = 'VeryLazy',
    config = function()
      require('mini.ai').setup({
        n_lines = 500,
        custom_textobjects = {
          f = false, -- don't override treesitter's af/if (function textobjects)
          -- indent textobject: ii = inner indent block, ai = block + header line above
          i = function(ai_type)
            local cur    = vim.fn.line('.')
            local indent = vim.fn.indent(cur)
            if indent == 0 then indent = vim.fn.indent(vim.fn.nextnonblank(cur)) end
            local start_l, end_l = cur, cur
            for l = cur - 1, 1, -1 do
              local blank = vim.fn.getline(l):match('^%s*$')
              if not blank and vim.fn.indent(l) < indent then break end
              if not blank then start_l = l end
            end
            for l = cur + 1, vim.fn.line('$') do
              local blank = vim.fn.getline(l):match('^%s*$')
              if not blank and vim.fn.indent(l) < indent then break end
              if not blank then end_l = l end
            end
            local from_l = ai_type == 'a' and math.max(1, start_l - 1) or start_l
            local from_c = ai_type == 'a' and 1 or (vim.fn.indent(start_l) + 1)
            return { from = { line = from_l, col = from_c }, to = { line = end_l, col = #vim.fn.getline(end_l) } }
          end,
        },
      })
    end,
  },
  {
    'echasnovski/mini.bracketed',
    event  = 'VeryLazy',
    config = function()
      require('mini.bracketed').setup({
        diagnostic = { suffix = '' }, -- disabled: using vim.diagnostic.jump ([d/]d)
        file       = { suffix = '' }, -- disabled: using treesitter-textobjects (]f/[f)
      })
    end,
  },

  -- ── Syntax ───────────────────────────────────────────────────────────────
  {
    'catgoose/nvim-colorizer.lua',
    event  = 'BufReadPost',
    config = function()
      require('colorizer').setup({
        filetypes            = { '*' },
        user_default_options = { names = false },
      })
    end,
  },

  -- ── Tools ────────────────────────────────────────────────────────────────
  {
    'lukas-reineke/indent-blankline.nvim',
    main   = 'ibl',
    event  = 'BufReadPost',
    config = function()
      require('ibl').setup({
        indent  = { char = { '|', '¦', '┆', '┊' } },
        exclude = {
          filetypes = { 'json', 'markdown', 'csv', 'help', 'dashboard' },
        },
      })
    end,
  },
  { 'mbbill/undotree',         cmd = 'UndotreeToggle',
    keys = { { '<leader>u', '<cmd>UndotreeToggle<CR>', desc = 'Undo tree' } } },
  { 'tpope/vim-eunuch',        cmd = { 'Move', 'Rename', 'Delete', 'SudoWrite', 'Chmod' } },
  { 'rickhowe/diffchar.vim',   cmd = { 'DiffCharOn', 'DiffCharOff', 'DiffCharToggle' } },


  -- ── Writing ──────────────────────────────────────────────────────────────
  {
    'folke/zen-mode.nvim',
    cmd          = 'ZenMode',
    dependencies = { 'folke/twilight.nvim' },
    opts         = { plugins = { twilight = { enabled = true } } },
    keys         = { { '<leader>z', '<cmd>ZenMode<CR>', desc = 'Zen mode' } },
  },
  -- ── Motion ───────────────────────────────────────────────────────────────
  {
    'folke/flash.nvim',
    event = 'VeryLazy',
    opts  = {},
    keys  = {
      { 's',     function() require('flash').jump()              end, mode = { 'n', 'x', 'o' }, desc = 'Flash jump' },
      { 'S',     function() require('flash').treesitter()        end, mode = { 'n', 'x', 'o' }, desc = 'Flash treesitter' },
      { 'r',     function() require('flash').remote()            end, mode = 'o',               desc = 'Flash remote' },
      { 'R',     function() require('flash').treesitter_search() end, mode = { 'o', 'x' },      desc = 'Flash treesitter search' },
      { '<C-s>', function() require('flash').toggle()            end, mode = 'c',               desc = 'Flash toggle search' },
    },
  },

}, {
  ui = { border = 'rounded' },
  performance = {
    rtp = {
      disabled_plugins = {
        'gzip', 'matchit', 'matchparen',
        'tarPlugin', 'tohtml', 'tutor', 'zipPlugin',
      },
    },
  },
})

-- ══════════════════════════════════════════════════════════════════════════════
-- Options
-- ══════════════════════════════════════════════════════════════════════════════
local opt          = vim.opt

opt.cursorcolumn   = true
opt.cursorline     = true
opt.ignorecase     = true
opt.infercase      = true
opt.list           = true
opt.listchars      = { tab = '→ ', trail = '.', extends = '>', precedes = '<' }
opt.mouse          = 'a'
opt.swapfile       = false
opt.number         = true
opt.relativenumber = true
opt.scrolloff      = 5
opt.signcolumn     = 'yes'
opt.shiftround     = true
opt.smartcase      = true
opt.tabstop        = 2
opt.softtabstop    = -1 -- follow shiftwidth
opt.expandtab      = true
opt.shiftwidth     = 2
opt.title          = true
local undodir      = vim.fn.stdpath('state') .. '/undo'
vim.fn.mkdir(undodir, 'p')
opt.undofile      = true
opt.undodir       = undodir
opt.visualbell    = true
opt.wildmode      = 'list:longest'
opt.termguicolors = true

opt.matchpairs:append('<:>')

if vim.fn.executable('rg') == 1 then
  opt.grepprg    = 'rg --vimgrep'
  opt.grepformat = '%f:%l:%c:%m,%f:%l:%m'
end

opt.wildignore:append({
  '*/.git/*', '*/tmp/*', '*.swp', '*.so', '*.o', '*.a',
  '*.obj', '*.bak', '*.zip', '*.pyc', '*.pyo', '*.class', '.DS_Store',
})

-- ══════════════════════════════════════════════════════════════════════════════
-- Autocmds
-- ══════════════════════════════════════════════════════════════════════════════
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- Cursorline follows active window
local cursor_grp = augroup('UserCursorLine', { clear = true })
autocmd('WinLeave', {
  group    = cursor_grp,
  callback = function()
    vim.opt_local.cursorline   = false
    vim.opt_local.cursorcolumn = false
  end,
})
autocmd('WinEnter', {
  group    = cursor_grp,
  callback = function()
    vim.opt_local.cursorline   = true
    vim.opt_local.cursorcolumn = true
  end,
})


-- ══════════════════════════════════════════════════════════════════════════════
-- Keymaps
-- ══════════════════════════════════════════════════════════════════════════════
local map = vim.keymap.set

-- Window navigation — normal mode (Ctrl and Alt variants)
for _, d in ipairs({ 'k', 'j', 'h', 'l' }) do
  map('n', '<C-' .. d .. '>', '<cmd>wincmd ' .. d .. '<CR>', { silent = true })
  map('n', '<M-' .. d .. '>', '<cmd>wincmd ' .. d .. '<CR>', { silent = true })
end
map('n', '<M-Up>', '<cmd>wincmd k<CR>', { silent = true })
map('n', '<M-Down>', '<cmd>wincmd j<CR>', { silent = true })
map('n', '<M-Left>', '<cmd>wincmd h<CR>', { silent = true })
map('n', '<M-Right>', '<cmd>wincmd l<CR>', { silent = true })
map('n', '<C-Up>', '<cmd>wincmd k<CR>', { silent = true })
map('n', '<C-Down>', '<cmd>wincmd j<CR>', { silent = true })
map('n', '<C-Left>', '<cmd>wincmd h<CR>', { silent = true })
map('n', '<C-Right>', '<cmd>wincmd l<CR>', { silent = true })

-- Window navigation — insert mode
map('i', '<C-k>', '<ESC><C-w>k', { silent = true })
map('i', '<C-j>', '<ESC><C-w>j', { silent = true })
map('i', '<C-h>', '<ESC><C-w>h', { silent = true })
map('i', '<C-l>', '<ESC><C-w>l', { silent = true })
map('i', '<C-Up>', '<ESC><C-w>k', { silent = true })
map('i', '<C-Down>', '<ESC><C-w>j', { silent = true })
map('i', '<C-Left>', '<ESC><C-w>h', { silent = true })
map('i', '<C-Right>', '<ESC><C-w>l', { silent = true })
map('i', '<M-Up>', '<ESC><C-w>k', { silent = true })
map('i', '<M-Down>', '<ESC><C-w>j', { silent = true })
map('i', '<M-Left>', '<ESC><C-w>h', { silent = true })
map('i', '<M-Right>', '<ESC><C-w>l', { silent = true })

-- Window resize
map('n', '-', '<C-W>-', { desc = 'Decrease height' })
map('n', '+', '<C-W>+', { desc = 'Increase height' })

-- Delete buffer without closing window
map('n', '<leader>bd', function()
  if #vim.fn.getbufinfo({ buflisted = 1 }) > 1 then
    vim.cmd('bp|bd #')
  else
    vim.cmd('bd')
  end
end, { desc = 'Delete buffer' })

-- Clear search highlight
map('n', '<leader>/', '<cmd>nohlsearch<CR>', { silent = true, desc = 'Clear highlight' })

-- Visual star: search for visual selection (replaces vim-visualstar)
map('x', '*', [[y/\V<C-r>=escape(@",'/\')<CR><CR>]])
map('x', '#', [[y?\V<C-r>=escape(@",'?\')<CR><CR>]])

-- Open file under cursor in split
map('n', 'gs', ':above wincmd f<CR>', { desc = 'Open file above' })
map('n', '<leader>gv', ':vertical wincmd f<CR>', { desc = 'Open file vert' })

-- Config editing
map('n', '<leader>ev', '<cmd>e $MYVIMRC<CR>', { silent = true, desc = 'Edit config' })

-- Indent guides toggle
map('n', '<F4>', '<cmd>IBLToggle<CR>', { desc = 'Toggle indent guides' })

-- Jump list
map('n', '<leader>j', '<cmd>Telescope jumplist<CR>', { desc = 'Jump list' })

-- Plugin manager UI
map('n', '<leader>L', '<cmd>Lazy<CR>', { desc = 'Lazy UI' })

-- ══════════════════════════════════════════════════════════════════════════════
-- Commands
-- ══════════════════════════════════════════════════════════════════════════════
for lhs, rhs in pairs({ W = 'w', WQ = 'wq', Wq = 'wq', Q = 'q', Qa = 'qa', QA = 'qa' }) do
  vim.api.nvim_create_user_command(lhs, rhs, {})
end
