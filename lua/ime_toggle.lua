local M = {}

function M.setup()
    if vim.fn.has("win32") == 0 then
        return
    end

    local ffi = require "ffi"

    ffi.cdef [[
        typedef unsigned int UINT, HWND, WPARAM;
        typedef unsigned long LPARAM, LRESULT;
        LRESULT SendMessageA(HWND hWnd, UINT Msg, WPARAM wParam, LPARAM lParam);
        HWND ImmGetDefaultIMEWnd(HWND unnamedParam1);
        HWND GetForegroundWindow();
    ]]

    local user32 = ffi.load "user32.dll"
    local imm32 = ffi.load "imm32.dll"

    local ime_hwnd
    local ime_group = vim.api.nvim_create_augroup("ime_toggle", { clear = true })

    -- 在 InsertEnter 或 CmdlineEnter 时获取当前窗口的 IME 控件句柄
    vim.api.nvim_create_autocmd({ "InsertEnter", "CmdlineEnter" }, {
        group = ime_group,
        once = true,
        desc = "获取当前窗口的 IME 控件句柄",
        callback = function()
            ime_hwnd = imm32.ImmGetDefaultIMEWnd(user32.GetForegroundWindow())
            if ime_hwnd == 0 then
                vim.notify("未能获取到 IME 窗口句柄", vim.log.levels.ERROR)
            else
                vim.notify("成功获取到 IME 窗口句柄: " .. tostring(ime_hwnd), vim.log.levels.DEBUG)
            end
        end,
    })

    local WM_IME_CONTROL = 0x283
    local IMC_GETCONVERSIONMODE = 0x001
    local IMC_SETCONVERSIONMODE = 0x002
    local ime_mode_ch = 1025
    local ime_mode_en = 0

    local function set_ime_mode(mode)
        if not ime_hwnd or ime_hwnd == 0 then
            vim.notify("IME 窗口句柄无效，无法设置 IME 模式", vim.log.levels.WARN)
            return nil
        end
        local result = user32.SendMessageA(ime_hwnd, WM_IME_CONTROL, IMC_SETCONVERSIONMODE, mode)
        if result == 0 then
            vim.notify("设置 IME 模式失败", vim.log.levels.ERROR)
        else
            vim.notify("成功设置 IME 模式: " .. mode, vim.log.levels.DEBUG)
        end
    end

    local function get_ime_mode()
        if not ime_hwnd or ime_hwnd == 0 then
            vim.notify("IME 窗口句柄无效，无法获取 IME 模式", vim.log.levels.WARN)
            return nil
        end
        local mode = user32.SendMessageA(ime_hwnd, WM_IME_CONTROL, IMC_GETCONVERSIONMODE, 0)
        if mode == 0 then
            vim.notify("获取 IME 模式失败", vim.log.levels.ERROR)
        else
            vim.notify("当前 IME 模式: " .. mode, vim.log.levels.DEBUG)
        end
        return mode
    end

    -- 在退出插入或命令行模式时切换到英文模式
    vim.api.nvim_create_autocmd({ "InsertLeave", "CmdlineLeave" }, {
        group = ime_group,
        desc = "在退出插入或命令行模式时切换到英文模式",
        callback = function()
            local current_mode = get_ime_mode()
            if current_mode == ime_mode_ch then
                set_ime_mode(ime_mode_en)
                vim.notify("切换到英文输入法", vim.log.levels.INFO)
            else
                vim.notify("当前 IME 模式不是中文，无需切换", vim.log.levels.DEBUG)
            end
        end,
    })
end

return M
