Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- CONFIG & PATH SETUP ---
$configFolder = "$env:APPDATA\MouseRemapperMini"
if (-not (Test-Path $configFolder)) { New-Item -ItemType Directory -Path $configFolder | Out-Null }
$configFile = "$configFolder\config.json"

# --- HEADLESS BACKGROUND SERVICE WORKER ---
if ($args -contains "-Background") {
    $hookCode = @'
    using System;
    using System.Runtime.InteropServices;
    using System.Windows.Forms;
    using System.Collections.Generic;
    using System.IO;
    using System.Text.RegularExpressions;

    public class BackgroundHookManager {
        private static IntPtr _hookID = IntPtr.Zero;
        private static LowLevelMouseProc _mouseProc = MouseHookCallback;
        private static LowLevelKeyboardProc _keyboardProc = KeyboardHookCallback;
        private static IntPtr _kbdHookID = IntPtr.Zero;

        public static void StartHook() {
            if (_hookID == IntPtr.Zero) {
                _hookID = SetMouseHook(_mouseProc);
            }
        }

        private delegate IntPtr LowLevelMouseProc(int nCode, IntPtr wParam, IntPtr lParam);
        private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

        private static IntPtr SetMouseHook(LowLevelMouseProc proc) {
            using (System.Diagnostics.Process curProcess = System.Diagnostics.Process.GetCurrentProcess())
            using (System.Diagnostics.ProcessModule curModule = curProcess.MainModule) {
                return SetWindowsHookEx(14, proc, GetModuleHandle(curModule.ModuleName), 0);
            }
        }

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr SetWindowsHookEx(int idHook, Delegate lpfn, IntPtr hMod, uint dwThreadId);

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool UnhookWindowsHookEx(IntPtr hhk);

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr GetModuleHandle(string lpModuleName);

        [DllImport("user32.dll")]
        private static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, int dwExtraInfo);

        private const int WM_XBUTTONDOWN = 0x020B;
        private const int WM_MBUTTONDOWN = 0x0207;
        private const int WM_MOUSEWHEEL = 0x020A;
        private const int WM_MOUSEHWHEEL = 0x020E;

        private static IntPtr MouseHookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
            if (nCode >= 0) {
                int msg = wParam.ToInt32();
                int buttonKey = 0;

                if (msg == WM_XBUTTONDOWN) {
                    int mouseData = Marshal.ReadInt32(lParam, 8);
                    int xButton = (mouseData >> 16) & 0xFFFF;
                    buttonKey = (xButton == 1) ? 1 : 2; // Side Button 1 or 2
                }
                else if (msg == WM_MBUTTONDOWN) { buttonKey = 3; }
                else if (msg == WM_MOUSEHWHEEL) {
                    int mouseData = Marshal.ReadInt32(lParam, 8);
                    int delta = (short)((mouseData >> 16) & 0xFFFF);
                    buttonKey = (delta > 0) ? 4 : 5; // Tilt Left / Right
                }

                if (buttonKey > 0) {
                    Dictionary<int, string> currentMappings = LoadConfigLive();
                    if (currentMappings.ContainsKey(buttonKey)) {
                        ExecuteAction(currentMappings[buttonKey]);
                        return (IntPtr)1; // Suppress default action
                    }
                }
            }
            return CallNextHookEx(_hookID, nCode, wParam, lParam);
        }

        private static IntPtr KeyboardHookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
            return CallNextHookEx(_kbdHookID, nCode, wParam, lParam);
        }

        private static Dictionary<int, string> LoadConfigLive() {
            Dictionary<int, string> map = new Dictionary<int, string>();
            string path = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "MouseRemapperMini", "config.json");
            try {
                if (File.Exists(path)) {
                    string json = File.ReadAllText(path);
                    MatchCollection matches = Regex.Matches(json, "\"([1-9])\"\\s*:\\s*\"([^\"]+)\"");
                    foreach (Match m in matches) {
                        if (m.Success) {
                            int btnId = int.Parse(m.Groups[1].Value);
                            string action = m.Groups[2].Value;
                            map[btnId] = action;
                        }
                    }
                }
            } catch {}

            if (map.Count == 0) {
                map[1] = "Ctrl + W (Close Tab)";
                map[2] = "Ctrl + T (New Tab)";
            }
            return map;
        }

        private static void ExecuteAction(string action) {
            byte modKey = 0x11;
            byte targetKey = 0x57;

            if (action.Contains("Ctrl + W")) { modKey = 0x11; targetKey = 0x57; }
            else if (action.Contains("Ctrl + T")) { modKey = 0x11; targetKey = 0x54; }
            else if (action.Contains("Ctrl + Shift + T")) { SendComplex(0x11, 0x10, 0x54); return; }
            else if (action.Contains("Ctrl + Shift + W")) { SendComplex(0x11, 0x10, 0x57); return; }
            else if (action.Contains("Alt + F4")) { modKey = 0x12; targetKey = 0x73; }
            else if (action.Contains("Ctrl + C")) { modKey = 0x11; targetKey = 0x43; }
            else if (action.Contains("Ctrl + V")) { modKey = 0x11; targetKey = 0x56; }
            else if (action.Contains("Ctrl + X")) { modKey = 0x11; targetKey = 0x58; }
            else if (action.Contains("Ctrl + Z")) { modKey = 0x11; targetKey = 0x5A; }
            else if (action.Contains("Ctrl + Y")) { modKey = 0x11; targetKey = 0x59; }
            else if (action.Contains("Ctrl + A")) { modKey = 0x11; targetKey = 0x41; }
            else if (action.Contains("Ctrl + F")) { modKey = 0x11; targetKey = 0x46; }
            else if (action.Contains("Ctrl + R")) { modKey = 0x11; targetKey = 0x52; }
            else if (action.Contains("Ctrl + Tab")) { modKey = 0x11; targetKey = 0x09; }
            else if (action.Contains("Alt + Tab")) { modKey = 0x12; targetKey = 0x09; }
            else if (action.Contains("Windows + D")) { modKey = 0x5B; targetKey = 0x44; }
            else if (action.Contains("Volume Up")) { keybd_event(0xAF, 0, 0, 0); keybd_event(0xAF, 0, 0x0002, 0); return; }
            else if (action.Contains("Volume Down")) { keybd_event(0xAE, 0, 0, 0); keybd_event(0xAE, 0, 0x0002, 0); return; }
            else if (action.Contains("Play / Pause")) { keybd_event(0xB3, 0, 0, 0); keybd_event(0xB3, 0, 0x0002, 0); return; }

            keybd_event(modKey, 0, 0, 0);
            keybd_event(targetKey, 0, 0, 0);
            System.Threading.Thread.Sleep(15);
            keybd_event(targetKey, 0, 0x0002, 0);
            keybd_event(modKey, 0, 0x0002, 0);
        }

        private static void SendComplex(byte mod1, byte mod2, byte target) {
            keybd_event(mod1, 0, 0, 0);
            keybd_event(mod2, 0, 0, 0);
            keybd_event(target, 0, 0, 0);
            System.Threading.Thread.Sleep(15);
            keybd_event(target, 0, 0x0002, 0);
            keybd_event(mod2, 0, 0x0002, 0);
            keybd_event(mod1, 0, 0x0002, 0);
        }
    }
'@

    Add-Type -TypeDefinition $hookCode -ReferencedAssemblies System.Windows.Forms
    [BackgroundHookManager]::StartHook()
    [System.Windows.Forms.Application]::Run()
    exit
}

# --- GUI APP MODE ---
[System.Windows.Forms.Application]::EnableVisualStyles()

$global:mappings = [System.Collections.Generic.Dictionary[int, string]]::new()
if (Test-Path $configFile) {
    try {
        $savedJson = Get-Content $configFile -Raw | ConvertFrom-Json
        foreach ($p in $savedJson.psobject.properties) {
            $global:mappings[[int]$p.Name] = [string]$p.Value
        }
    }
    catch {
        $global:mappings[1] = "Ctrl + W (Close Tab)"
        $global:mappings[2] = "Ctrl + T (New Tab)"
    }
}
else {
    $global:mappings[1] = "Ctrl + W (Close Tab)"
    $global:mappings[2] = "Ctrl + T (New Tab)"
}

# Theme Colors
$colBg = [System.Drawing.Color]::FromArgb(20, 20, 24)
$colCard = [System.Drawing.Color]::FromArgb(32, 32, 38)
$colText = [System.Drawing.Color]::FromArgb(245, 245, 247)
$colMuted = [System.Drawing.Color]::FromArgb(150, 150, 165)
$colAccent = [System.Drawing.Color]::FromArgb(99, 102, 241)
$colSuccess = [System.Drawing.Color]::FromArgb(52, 211, 153)

function Get-CustomFont($size, $isBold = $false) {
    $f = New-Object System.Drawing.Font("Segoe UI", [float]$size)
    if ($isBold) { return [System.Drawing.Font]::new($f, [System.Drawing.FontStyle]::Bold) }
    return $f
}

function Get-AppIcon {
    $bmp = [System.Drawing.Bitmap]::new(32, 32)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    $brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(99, 102, 241))
    $g.FillEllipse($brush, 2, 2, 28, 28)
    $pen = [System.Drawing.Pen]::new([System.Drawing.Color]::White, 2.5)
    $g.DrawLine($pen, 16, 8, 16, 24)
    $g.DrawLine($pen, 10, 14, 16, 8)
    $g.DrawLine($pen, 22, 14, 16, 8)
    $hIcon = $bmp.GetHicon()
    return [System.Drawing.Icon]::FromHandle($hIcon)
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Mouse Button Remapper Pro"
$form.Size = New-Object System.Drawing.Size(460, 560)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$form.MaximizeBox = $false
$form.BackColor = $colBg
$form.ForeColor = $colText
$form.Icon = Get-AppIcon
$form.Font = Get-CustomFont 9.5

# System Tray Integration
$trayMenu = New-Object System.Windows.Forms.ContextMenuStrip
$trayMenu.BackColor = $colCard
$trayMenu.ForeColor = $colText

$menuOpen = $trayMenu.Items.Add("Open Control Panel")
$menuOpen.Font = Get-CustomFont 9 $true
$menuOpen.Add_Click({
        $form.Show()
        $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
        $form.ShowInTaskbar = $true
    })

$menuExit = $trayMenu.Items.Add("Exit Remapper App")
$menuExit.Add_Click({
        [MouseHookManager]::StopHook()
        $trayIcon.Visible = $false
        [System.Windows.Forms.Application]::Exit()
    })

$trayIcon = New-Object System.Windows.Forms.NotifyIcon
$trayIcon.Icon = Get-AppIcon
$trayIcon.Text = "Mouse Button Remapper Pro (Active)"
$trayIcon.ContextMenuStrip = $trayMenu
$trayIcon.Visible = $true

$trayIcon.Add_DoubleClick({
        $form.Show()
        $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
        $form.ShowInTaskbar = $true
    })

$form.Add_FormClosing({
        param($sender, $e)
        if ($e.CloseReason -eq [System.Windows.Forms.CloseReason]::UserClosing) {
            $e.Cancel = $true
            $form.Hide()
            $form.ShowInTaskbar = $false
        }
    })

# GUI Elements
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "Mouse Button Control Pro"
$lblTitle.Location = New-Object System.Drawing.Point(24, 20)
$lblTitle.Size = New-Object System.Drawing.Size(400, 26)
$lblTitle.Font = Get-CustomFont 13 $true
$form.Controls.Add($lblTitle)

$lblSub = New-Object System.Windows.Forms.Label
$lblSub.Text = "Remap any mouse button to advanced keyboard shortcuts."
$lblSub.Location = New-Object System.Drawing.Point(24, 48)
$lblSub.Size = New-Object System.Drawing.Size(400, 20)
$lblSub.ForeColor = $colMuted
$form.Controls.Add($lblSub)

$panelConfig = New-Object System.Windows.Forms.Panel
$panelConfig.Location = New-Object System.Drawing.Point(24, 82)
$panelConfig.Size = New-Object System.Drawing.Size(396, 155)
$panelConfig.BackColor = $colCard
$form.Controls.Add($panelConfig)

$lblButton = New-Object System.Windows.Forms.Label
$lblButton.Text = "Target Button"
$lblButton.Location = New-Object System.Drawing.Point(16, 18)
$lblButton.Size = New-Object System.Drawing.Size(120, 20)
$lblButton.ForeColor = $colMuted
$panelConfig.Controls.Add($lblButton)

$cmbButton = New-Object System.Windows.Forms.ComboBox
$cmbButton.Location = New-Object System.Drawing.Point(140, 15)
$cmbButton.Size = New-Object System.Drawing.Size(238, 25)
$cmbButton.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cmbButton.BackColor = $colBg
$cmbButton.ForeColor = $colText
# Highlight actual active side buttons at the top
$cmbButton.Items.Add("[X] Side Button 1 (XButton1) [Active]") | Out-Null
$cmbButton.Items.Add("[X] Side Button 2 (XButton2) [Active]") | Out-Null
$cmbButton.Items.Add("Middle Click / Wheel Click") | Out-Null
$cmbButton.Items.Add("Wheel Tilt Left") | Out-Null
$cmbButton.Items.Add("Wheel Tilt Right") | Out-Null
$cmbButton.Items.Add("Extra Mouse Button 4") | Out-Null
$cmbButton.Items.Add("Extra Mouse Button 5") | Out-Null
$cmbButton.SelectedIndex = 0
$panelConfig.Controls.Add($cmbButton)

$lblAction = New-Object System.Windows.Forms.Label
$lblAction.Text = "Trigger Shortcut"
$lblAction.Location = New-Object System.Drawing.Point(16, 60)
$lblAction.Size = New-Object System.Drawing.Size(120, 20)
$lblAction.ForeColor = $colMuted
$panelConfig.Controls.Add($lblAction)

$cmbAction = New-Object System.Windows.Forms.ComboBox
$cmbAction.Location = New-Object System.Drawing.Point(140, 57)
$cmbAction.Size = New-Object System.Drawing.Size(238, 25)
$cmbAction.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cmbAction.BackColor = $colBg
$cmbAction.ForeColor = $colText
# Highlight current shortcuts at the top
$cmbAction.Items.Add("[X] Ctrl + W (Close Tab) [Current]") | Out-Null
$cmbAction.Items.Add("[X] Ctrl + T (New Tab) [Current]") | Out-Null
$cmbAction.Items.Add("Ctrl + Shift + T (Reopen Closed Tab)") | Out-Null
$cmbAction.Items.Add("Ctrl + Shift + W (Close Window)") | Out-Null
$cmbAction.Items.Add("Alt + F4 (Close App)") | Out-Null
$cmbAction.Items.Add("Ctrl + C (Copy)") | Out-Null
$cmbAction.Items.Add("Ctrl + V (Paste)") | Out-Null
$cmbAction.Items.Add("Ctrl + X (Cut)") | Out-Null
$cmbAction.Items.Add("Ctrl + Z (Undo)") | Out-Null
$cmbAction.Items.Add("Ctrl + Y (Redo)") | Out-Null
$cmbAction.Items.Add("Ctrl + A (Select All)") | Out-Null
$cmbAction.Items.Add("Ctrl + F (Find / Search)") | Out-Null
$cmbAction.Items.Add("Ctrl + R (Refresh Page)") | Out-Null
$cmbAction.Items.Add("Ctrl + Tab (Next Tab)") | Out-Null
$cmbAction.Items.Add("Alt + Tab (Switch Window)") | Out-Null
$cmbAction.Items.Add("Windows + D (Show Desktop)") | Out-Null
$cmbAction.Items.Add("Volume Up") | Out-Null
$cmbAction.Items.Add("Volume Down") | Out-Null
$cmbAction.Items.Add("Play / Pause Media") | Out-Null
$cmbAction.SelectedIndex = 0
$panelConfig.Controls.Add($cmbAction)

$btnAdd = New-Object System.Windows.Forms.Button
$btnAdd.Text = "Save Mapping"
$btnAdd.Location = New-Object System.Drawing.Point(140, 100)
$btnAdd.Size = New-Object System.Drawing.Size(238, 36)
$btnAdd.BackColor = $colAccent
$btnAdd.ForeColor = [System.Drawing.Color]::White
$btnAdd.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnAdd.Font = Get-CustomFont 9.5 $true
$btnAdd.FlatAppearance.BorderSize = 0
$panelConfig.Controls.Add($btnAdd)

$lblList = New-Object System.Windows.Forms.Label
$lblList.Text = "Active Mappings Pipeline"
$lblList.Location = New-Object System.Drawing.Point(24, 252)
$lblList.Size = New-Object System.Drawing.Size(200, 20)
$lblList.ForeColor = $colMuted
$form.Controls.Add($lblList)

$listBox = New-Object System.Windows.Forms.ListBox
$listBox.Location = New-Object System.Drawing.Point(24, 278)
$listBox.Size = New-Object System.Drawing.Size(396, 95)
$listBox.BackColor = $colCard
$listBox.ForeColor = $colText
$listBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$listBox.Font = Get-CustomFont 9.5
$form.Controls.Add($listBox)

function Refresh-MappingList {
    $listBox.Items.Clear()
    foreach ($key in $global:mappings.Keys) {
        $name = switch ($key) {
            1 { "Side Button 1" }
            2 { "Side Button 2" }
            3 { "Middle Click" }
            4 { "Wheel Tilt Left" }
            5 { "Wheel Tilt Right" }
            6 { "Extra Button 4" }
            7 { "Extra Button 5" }
            default { "Button $key" }
        }
        $listBox.Items.Add("$name   --->   " + $global:mappings[$key]) | Out-Null
    }
}
Refresh-MappingList

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Status: Active - Remapping System-Wide"
$lblStatus.Location = New-Object System.Drawing.Point(24, 392)
$lblStatus.Size = New-Object System.Drawing.Size(396, 20)
$lblStatus.ForeColor = $colSuccess
$lblStatus.Font = Get-CustomFont 9 $true
$form.Controls.Add($lblStatus)

$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Text = "Install/Update Background Service"
$btnInstall.Location = New-Object System.Drawing.Point(24, 422)
$btnInstall.Size = New-Object System.Drawing.Size(396, 44)
$btnInstall.BackColor = $colCard
$btnInstall.ForeColor = $colSuccess
$btnInstall.FlatStyle = [System.Windows.Forms.FlatStyle]::Standard
$btnInstall.Font = Get-CustomFont 10 $true
$form.Controls.Add($btnInstall)

$btnAdd.Add_Click({
        $btnText = $cmbButton.SelectedItem.ToString()
        $actionText = $cmbAction.SelectedItem.ToString()

        # Map button selection index/text to ID
        $xBtnId = 1
        if ($btnText -match "Side Button 2") { $xBtnId = 2 }
        elseif ($btnText -match "Middle Click") { $xBtnId = 3 }
        elseif ($btnText -match "Tilt Left") { $xBtnId = 4 }
        elseif ($btnText -match "Tilt Right") { $xBtnId = 5 }
        elseif ($btnText -match "Button 4") { $xBtnId = 6 }
        elseif ($btnText -match "Button 5") { $xBtnId = 7 }

        $global:mappings[$xBtnId] = $actionText
        Refresh-MappingList

        $jsonObject = [ordered]@{}
        foreach ($key in $global:mappings.Keys) {
            $jsonObject[[string]$key] = $global:mappings[$key]
        }
        $jsonObject | ConvertTo-Json | Set-Content $configFile

        [System.Windows.Forms.MessageBox]::Show("Mapping saved and applied instantly!", "Success", 'OK', 'Information')
    })

# Background Service Installer
$btnInstall.Add_Click({
        try {
            $scriptPath = $MyInvocation.MyCommand.Path
            if (-not $scriptPath -or -not (Test-Path $scriptPath)) { $scriptPath = $PSCommandPath }
            if (-not $scriptPath -or -not (Test-Path $scriptPath)) { $scriptPath = "$PSScriptRoot\MouseRemapperMini.ps1" }

            if (-not (Test-Path $scriptPath)) {
                [System.Windows.Forms.MessageBox]::Show("Please ensure this script is saved on your disk before installing the background service.", "Notice", 'OK', 'Warning')
                return
            }

            $startupFolder = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
            if (-not (Test-Path $startupFolder)) { New-Item -ItemType Directory -Path $startupFolder | Out-Null }

            $vbsStartupPath = "$startupFolder\MouseRemapperMini.vbs"
            $vbsContent = 'CreateObject("Wscript.Shell").Run "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File """' + $scriptPath + '""" -Background", 0, False'
            Set-Content -Path $vbsStartupPath -Value $vbsContent

            Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -Background" -WindowStyle Hidden

            [System.Windows.Forms.MessageBox]::Show("Background service successfully installed! It is now running silently in the background and will persist permanently after closing the app or restarting your PC.", "Success", 'OK', 'Information')
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to install background service: $_", "Error", 'OK', 'Error')
        }
    })

# C# Hook Engine for GUI Mode
$hookCode = @'
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using System.Collections.Generic;

public class MouseHookManager {
    private static IntPtr _hookID = IntPtr.Zero;
    private static LowLevelMouseProc _proc = HookCallback;
    public static Dictionary<int, string> ActiveMappings = new Dictionary<int, string>();
    public static bool IsRunning = false;

    public static void StartHook(Dictionary<int, string> mappings) {
        ActiveMappings = mappings;
        if (_hookID == IntPtr.Zero) {
            _hookID = SetHook(_proc);
            IsRunning = true;
        }
    }

    public static void UpdateMappings(Dictionary<int, string> mappings) {
        ActiveMappings = mappings;
    }

    public static void StopHook() {
        if (_hookID != IntPtr.Zero) {
            UnhookWindowsHookEx(_hookID);
            _hookID = IntPtr.Zero;
            IsRunning = false;
        }
    }

    private delegate IntPtr LowLevelMouseProc(int nCode, IntPtr wParam, IntPtr lParam);

    private static IntPtr SetHook(LowLevelMouseProc proc) {
        using (System.Diagnostics.Process curProcess = System.Diagnostics.Process.GetCurrentProcess())
        using (System.Diagnostics.ProcessModule curModule = curProcess.MainModule) {
            return SetWindowsHookEx(14, proc, GetModuleHandle(curModule.ModuleName), 0);
        }
    }

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelMouseProc lpfn, IntPtr hMod, uint dwThreadId);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr GetModuleHandle(string lpModuleName);

    [DllImport("user32.dll")]
    private static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, int dwExtraInfo);

    private const int WM_XBUTTONDOWN = 0x020B;
    private const int WM_MBUTTONDOWN = 0x0207;
    private const int WM_MOUSEHWHEEL = 0x020E;

    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0 && IsRunning) {
            int msg = wParam.ToInt32();
            int buttonKey = 0;

            if (msg == WM_XBUTTONDOWN) {
                int mouseData = Marshal.ReadInt32(lParam, 8);
                int xButton = (mouseData >> 16) & 0xFFFF;
                buttonKey = (xButton == 1) ? 1 : 2;
            }
            else if (msg == WM_MBUTTONDOWN) { buttonKey = 3; }
            else if (msg == WM_MOUSEHWHEEL) {
                int mouseData = Marshal.ReadInt32(lParam, 8);
                int delta = (short)((mouseData >> 16) & 0xFFFF);
                buttonKey = (delta > 0) ? 4 : 5;
            }

            if (buttonKey > 0 && ActiveMappings.ContainsKey(buttonKey)) {
                ExecuteAction(ActiveMappings[buttonKey]);
                return (IntPtr)1;
            }
        }
        return CallNextHookEx(_hookID, nCode, wParam, lParam);
    }

    private static void ExecuteAction(string action) {
        byte modKey = 0x11;
        byte targetKey = 0x57;

        if (action.Contains("Ctrl + W")) { modKey = 0x11; targetKey = 0x57; }
        else if (action.Contains("Ctrl + T")) { modKey = 0x11; targetKey = 0x54; }
        else if (action.Contains("Ctrl + Shift + T")) { SendComplex(0x11, 0x10, 0x54); return; }
        else if (action.Contains("Ctrl + Shift + W")) { SendComplex(0x11, 0x10, 0x57); return; }
        else if (action.Contains("Alt + F4")) { modKey = 0x12; targetKey = 0x73; }
        else if (action.Contains("Ctrl + C")) { modKey = 0x11; targetKey = 0x43; }
        else if (action.Contains("Ctrl + V")) { modKey = 0x11; targetKey = 0x56; }
        else if (action.Contains("Ctrl + X")) { modKey = 0x11; targetKey = 0x58; }
        else if (action.Contains("Ctrl + Z")) { modKey = 0x11; targetKey = 0x5A; }
        else if (action.Contains("Ctrl + Y")) { modKey = 0x11; targetKey = 0x59; }
        else if (action.Contains("Ctrl + A")) { modKey = 0x11; targetKey = 0x41; }
        else if (action.Contains("Ctrl + F")) { modKey = 0x11; targetKey = 0x46; }
        else if (action.Contains("Ctrl + R")) { modKey = 0x11; targetKey = 0x52; }
        else if (action.Contains("Ctrl + Tab")) { modKey = 0x11; targetKey = 0x09; }
        else if (action.Contains("Alt + Tab")) { modKey = 0x12; targetKey = 0x09; }
        else if (action.Contains("Windows + D")) { modKey = 0x5B; targetKey = 0x44; }
        else if (action.Contains("Volume Up")) { keybd_event(0xAF, 0, 0, 0); keybd_event(0xAF, 0, 0x0002, 0); return; }
        else if (action.Contains("Volume Down")) { keybd_event(0xAE, 0, 0, 0); keybd_event(0xAE, 0, 0x0002, 0); return; }
        else if (action.Contains("Play / Pause")) { keybd_event(0xB3, 0, 0, 0); keybd_event(0xB3, 0, 0x0002, 0); return; }

        keybd_event(modKey, 0, 0, 0);
        keybd_event(targetKey, 0, 0, 0);
        System.Threading.Thread.Sleep(15);
        keybd_event(targetKey, 0, 0x0002, 0);
        keybd_event(modKey, 0, 0x0002, 0);
    }

    private static void SendComplex(byte mod1, byte mod2, byte target) {
        keybd_event(mod1, 0, 0, 0);
        keybd_event(mod2, 0, 0, 0);
        keybd_event(target, 0, 0, 0);
        System.Threading.Thread.Sleep(15);
        keybd_event(target, 0, 0x0002, 0);
        keybd_event(mod2, 0, 0x0002, 0);
        keybd_event(mod1, 0, 0x0002, 0);
    }
}
'@

Add-Type -TypeDefinition $hookCode -ReferencedAssemblies System.Windows.Forms

$form.Add_Shown({
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 150
        [MouseHookManager]::StartHook($global:mappings)
    })

$form.Add_FormClosed({
        [MouseHookManager]::StopHook()
        try { $trayIcon.Dispose() } catch {}
    })

[void]$form.ShowDialog()