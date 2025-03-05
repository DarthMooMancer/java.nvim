local M = {}
M.close_key = nil
M.java_build = nil
M.java_run = nil
M.new_java_file = nil
M.new_java_project = nil

-- Default config
M.config = {
  project_root = "~/Projects",
  keybinds = {
    ["<Esc>"] = "CloseTerminal",
    ["<leader>jb"] = "JavaBuild",
    ["<leader>jr"] = "JavaRun",
    ["<leader>nf"] = "NewJavaFile",
    ["<leader>np"] = "NewJavaProject",
  },
  terminal = {
    right_padding = 10,
    bottom_padding = 10,
    left_padding = 10,
    top_padding = 10,
    border = true,
    number = true,
    relativenumber = true,
    scroll = true,
  }
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- Apply keybindings manually
  for key, command in pairs(M.config.keybinds) do
    if command == "CloseTerminal" then
      M.close_key = key
    end
    if command == "JavaBuild" then
      M.java_build = key
    end
    if command == "JavaRun" then
      M.java_run = key
    end
    if command == "NewJavaFile" then
      M.new_java_file = key
    end
    if command == "NewJavaProject" then
      M.new_java_project = key
    end
  end

  -- Register Keybinds
  vim.keymap.set("n", M.java_build, ":JavaBuild<CR>", { silent = true })
  vim.keymap.set("n", M.java_run, ":JavaRun<CR>", { silent = true })
  vim.keymap.set("n", M.new_java_file, ":NewJavaFile<CR>", { silent = true })
  vim.keymap.set("n", M.new_java_project, ":NewJavaProject<CR>", { silent = true })

  -- Register user commands
  vim.api.nvim_create_user_command("NewJavaProject", M.create_project, {})
  vim.api.nvim_create_user_command("NewJavaFile", M.create_new_file, {})
  vim.api.nvim_create_user_command("JavaBuild", M.build, {})
  vim.api.nvim_create_user_command("JavaRun", M.run, {})
end

-- Open floating terminal
local function open_float_terminal(cmd)
  local ui = vim.api.nvim_list_uis()[1]
  local width, height = math.floor(ui.width * 0.9), math.floor(ui.height * 0.9)
  local row, col = math.floor(ui.height * 0.05), math.floor(ui.width * 0.05)

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width - M.config.terminal.right_padding,
    height = height - M.config.terminal.bottom_padding,
    row = row - M.config.terminal.left_padding,
    col = col - M.config.terminal.top_padding,
    style = "minimal",
    border = M.config.terminal.border and "rounded" or "none",
  })

  -- Enable scrolling, relative line numbers, and prevent closing on click
  vim.api.nvim_win_set_option(win, "winblend", vim.o.pumblend)
  vim.api.nvim_win_set_option(win, "winhighlight", "Normal:Pmenu,FloatBorder:Pmenu")
  if(M.config.terminal.number == true) then
    vim.api.nvim_win_set_option(win, "number", true)
  end
  if(M.config.terminal.number == true and M.config.terminal.relativenumber == true) then
    vim.api.nvim_win_set_option(win, "relativenumber", true)
  end
  if(M.config.terminal.scroll == true) then
    vim.api.nvim_win_set_option(win, "scrolloff", 5)
  end
  vim.api.nvim_win_set_option(win, "cursorline", true)

  vim.fn.termopen(cmd)

  vim.api.nvim_buf_set_keymap(buf, "n", M.close_key, "i<C-\\><C-n>:q<CR>", { noremap = true, silent = true })
  return buf, win
end

-- Create a new Java project
function M.create_project()
  -- Use vim.ui.input for better handling of input
  vim.ui.input({ prompt = "Enter project name: " }, function(project_name)
    if not project_name or project_name == "" then
      print("Project creation canceled.")
      return
    end

    -- Paths for the project
    local project_root = vim.fn.expand(M.config.project_root) .. "/" .. project_name
    local src_dir = project_root .. "/src"
    local build_dir = project_root .. "/build"

    -- Create directories
    vim.fn.mkdir(src_dir, "p")
    vim.fn.mkdir(build_dir, "p")

    -- Write the Main.java file
    local main_java_path = src_dir .. "/Main.java"
    local main_java_content = [[
public class Main {
    public static void main(String[] args) {
        System.out.println("Hello, World!");
    }
}
]]

    -- Create the file and write content
    local file = io.open(main_java_path, "w")
    if file then
      file:write(main_java_content)
      file:close()
      vim.cmd("edit " .. main_java_path)
      print(" Project '" .. project_name .. "' created at " .. project_root)
    else
      print("Error creating Main.java")
    end
  end)
end

-- Create a new Java file
function M.create_new_file()
  vim.ui.input({ prompt = "Enter class name: " }, function(class_name)
    if not class_name or class_name == "" then
      print("Class creation canceled.")
      return
    end

    local current_dir = vim.fn.expand("%:p:h")
    local root_dir = current_dir:match("(.*)/root/src")
    if not root_dir then
      print("Error: src directory not found.")
      return
    end

    local java_file_path = root_dir .. "/src/" .. class_name .. ".java"
    local java_content = string.format([[
public class %s {
    // New File
}
]], class_name)

    local file = io.open(java_file_path, "w")
    if file then
      file:write(java_content)
      file:close()
      vim.cmd("edit " .. java_file_path)
      print( class_name .. ".java created successfully!")
    else
      print("Error creating " .. class_name .. ".java")
    end
  end)
end

-- Compile Java files
function M.build()
  local current_dir = vim.fn.expand("%:p:h")
  local project_root = current_dir:match("(.*)/src")
  if not project_root then
    print("Error: Must be inside the 'src' directory.")
    return
  end

  local src_dir = project_root .. "/src"
  local out_dir = project_root .. "/build"

  vim.fn.mkdir(out_dir, "p")
  local compile_command = string.format("javac -d %s %s/*.java", out_dir, src_dir)
  local compile_status = vim.fn.system(compile_command)

  if vim.v.shell_error ~= 0 then
    print("Error during compilation:\n" .. compile_status)
  else
    print("Compilation successful!")
  end
end

-- Run Java program in floating terminal
function M.run()
  local current_dir = vim.fn.expand("%:p:h")
  local project_root = current_dir:match("(.*)/src")
  if not project_root then
    print("Error: Must be inside the 'src' directory.")
    return
  end

  local out_dir = project_root .. "/build"
  open_float_terminal("java -cp " .. out_dir .. " Main")
end

return M
