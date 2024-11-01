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
        end,
    })

    local WM_IME_CONTROL = 0x283
    local IMC_GETCONVERSIONMODE = 0x001
    local IMC_SETCONVERSIONMODE = 0x002
    local ime_mode_ch = 1025
    local ime_mode_en = 0

    local function set_ime_mode(mode)
        if not ime_hwnd or ime_hwnd == 0 then
            return nil
        end
        return user32.SendMessageA(ime_hwnd, WM_IME_CONTROL, IMC_SETCONVERSIONMODE, mode)
    end

    local function get_ime_mode()
        if not ime_hwnd or ime_hwnd == 0 then
            return nil
        end
        return user32.SendMessageA(ime_hwnd, WM_IME_CONTROL, IMC_GETCONVERSIONMODE, 0)
    end

    vim.api.nvim_create_autocmd({ "InsertLeave", "CmdlineLeave" }, {
        group = ime_group,
        desc = "在退出插入或命令行模式时切换到英文模式",
        callback = function()
            if ime_mode_ch == get_ime_mode() then
                set_ime_mode(ime_mode_en)
            end
        end,
    })
end

return M
