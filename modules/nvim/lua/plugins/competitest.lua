-- Setup Competitest with Lazy
require("competitest").setup({
	picker_ui = {	
		width = 0.5,  -- Ancho del selector
		height = 0.6,  -- Altura del selector
		mappings = {
			focus_next = { "j", "<down>", "<Tab>" },
			focus_prev = { "k", "<up>", "<S-Tab>" },
			close = { "<esc>", "<C-c>", "q", "Q" },
			submit = { "<cr>" },
			},
		},
		editor_ui = {
			popup_width = 0.6,	
			popup_height = 0.8,
			show_nu = true,
			show_rnu = true, 		
			normal_mode_mappings = {
				switch_window = { "<C-h>", "<C-l>", "<C-i>" },
				save_and_close = "<C-s>",
				cancel = { "q", "Q" },
			},
		},
		runner_ui = {
			interface = "popup",
			width = 0.6,
			height = 0.6,
			mappings = {
				run_again = "R",
					run_all_again = "<C-r>",
					kill = "K",
					kill_all = "<C-k>",
					view_input = { "i", "I" },
					view_output = { "a", "A" },
					view_stdout = { "o", "O" },
					view_stderr = { "e", "E" },
					toggle_diff = { "d", "D" },
					close = { "q", "Q" },
				},
			},
			floating_border_highlight = 'FloatBorder',
			template_file = {
			 	cpp = '~/.config/nvim/templates/template.cpp',
			-- 	py = '~/.config/nvim/templates/template.py',
			},
			received_files_extension = "cpp",
			evaluate_template_modifiers = true,
			date_format = '%Y-%m-%d',
			compile_command = {
				cpp       = { exec = 'g++',           args = { '-std=c++17','-g','$(FNAME)', '-o', '$(FNOEXT)'} },
				some_lang = { exec = 'some_compiler', args = {'$(FNAME)'} },
			},
				run_command = {
				cpp       = { exec = './$(FNOEXT)' },
				some_lang = { exec = 'some_interpreter', args = {'$(FNAME)'} },
			},

})
