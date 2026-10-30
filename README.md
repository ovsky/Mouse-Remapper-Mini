# 🖱️ Mouse Button Remapper Mini

**Mouse Button Remapper Mini** is a self-contained, high-performance mouse and keyboard remapping utility for Windows. Built as a consolidated single-file architecture combining C# win32 hook mechanics and PowerShell Windows Forms, it provides instant, low-latency remapping of mouse side buttons, middle clicks, and wheel tilts to system macros—without requiring external dependency files or DLL split assemblies.

---

## ✨ Key Features & Architecture

*   **Single-File Unified Engine:** Houses the low-level C# Win32 hook worker (`WH_MOUSE_LL`) and the dark-themed WinForms GUI directly inside a single script for effortless distribution.
*   **Dual Operating Modes:**
    *   **GUI Mode:** Interactive control panel with real-time mapping selection, system tray integration, and quick service toggling.
    *   **Headless Background Worker (`-Background`):** Runs invisibly in user space without rendering UI elements or console windows.
*   **Input Interception & Suppression:** Catches hardware events (e.g., `WM_XBUTTONDOWN`, `WM_MBUTTONDOWN`, `WM_MOUSEHWHEEL`) and suppresses default OS navigation events to eliminate dual-firing.
*   **Startup Persistence Engine:** Built-in VBScript background launcher installer that registers the headless script/executable to run seamlessly on Windows boot (`shell:startup`).
*   **Zero-Dependency JSON Parser:** Uses an inline regular-expression key-value matcher compatible natively across .NET Framework 4.8 and PowerShell 5.1+.

---

## 🏗️ Supported Inputs & Actions

### Target Mouse Buttons
| Key Code | Target Event | Description |
| :--- | :--- | :--- |
| `1` | Side Button 1 (`XButton1`) | Primary thumb side button |
| `2` | Side Button 2 (`XButton2`) | Secondary thumb side button |
| `3` | Middle Click | Physical scroll wheel button |
| `4` | Wheel Tilt Left | Horizontal wheel tilt left |
| `5` | Wheel Tilt Right | Horizontal wheel tilt right |
| `6` | Extra Button 4 | Secondary side expansion button |
| `7` | Extra Button 5 | Tertiary side expansion button |

### Trigger Shortcuts
*   **Browser Navigation:** `Ctrl + W` (Close Tab), `Ctrl + T` (New Tab), `Ctrl + Shift + T` (Reopen Closed Tab), `Ctrl + Shift + W` (Close Window), `Ctrl + R` (Refresh), `Ctrl + Tab` (Next Tab)
*   **Editing Macros:** `Ctrl + C` (Copy), `Ctrl + V` (Paste), `Ctrl + X` (Cut), `Ctrl + Z` (Undo), `Ctrl + Y` (Redo), `Ctrl + A` (Select All), `Ctrl + F` (Find)
*   **System Controls:** `Alt + F4` (Close Application), `Alt + Tab` (Task Switcher), `Windows + D` (Show Desktop), `Volume Up`, `Volume Down`, `Play / Pause Media`

---

## 🛠️ Building to `.exe`

The repository includes a companion build script (`builder.ps1`) that automatically compiles `remapper.ps1` into a standalone, windowless executable (`MouseButtonRemapperMini.exe`) with an auto-generated high-DPI application icon.

### Quick Build Instructions

1. Ensure `remapper.ps1` and `builder.ps1` are placed in the same directory.
2. Open a PowerShell terminal and run:
   ```powershell
   .\builder.ps1
   ```
3. The build utility will check for `ps2exe`, generate the dynamic icon stream, compile with `-NoConsole`, and output `MouseButtonRemapperMini.exe`.

---

## 📁 Storage & Configuration

Runtime configuration is stored in the local application data directory:
```text
%APPDATA%\MouseRemapperMini\config.json
```

### Configuration Structure (`config.json`)
```json
{
  "1": "Ctrl + W (Close Tab)",
  "2": "Ctrl + T (New Tab)"
}
```

---

## 📜 License

Mouse Button Remapper Mini is licensed under the **MIT License**.