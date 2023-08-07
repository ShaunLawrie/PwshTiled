# Trying buffer cell hacks for speed
$script:OriginalBufferSize = $Host.UI.RawUI.BufferSize

Add-Type -Language CSharp -TypeDefinition @"

using System;
using System.Runtime.InteropServices;

namespace Win32
{
  // StartupInfo
  // ------------------------------------------------------------
  // Contains information about the context in which the process
  // was started.
  //
  // https://msdn.microsoft.com/en-us/library/ms686331.aspx
  // http://www.pinvoke.net/default.aspx/Structures/STARTUPINFO.html
  //
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
  public struct StartupInfo
  {
    public uint   cb;
    public string lpReserved;
    public string lpDesktop;
    public string lpTitle;
    public uint   dwX;
    public uint   dwY;
    public uint   dwXSize;
    public uint   dwYSize;
    public uint   dwXCountChars;
    public uint   dwYCountChars;
    public uint   dwFillAttribute;
    public uint   dwFlags;
    public ushort wShowWindow;
    public ushort cbReserved2;
    public IntPtr lpReserved2;
    public IntPtr hStdInput;
    public IntPtr hStdOutput;
    public IntPtr hStdError;
  }
  
  [Flags]
  public enum StartFlags
  {
    TitleIsLinkName = 0x00000800
    // Unused values omitted for brevity
  }
  
  public enum StandardHandle
  {
    StandardOutput = -11
    // Unused values omitted for brevity
  }
  
  [StructLayout(LayoutKind.Explicit, Size = 4)]
  public struct ColorRef {
  
    public ColorRef(byte r, byte g, byte b) {
      this.Value = 0;
      this.R = r;
      this.G = g;
      this.B = b;
    }

    public ColorRef(uint value) {
      this.R = 0;
      this.G = 0;
      this.B = 0;
      this.Value = value & 0x00FFFFFF;
    }

    [FieldOffset(0)]
    public byte R;
    
    [FieldOffset(1)]
    public byte G;
    
    [FieldOffset(2)]
    public byte B;

    [FieldOffset(0)]
    public uint Value;
  }
  
  [StructLayout(LayoutKind.Sequential)]
  public struct Coord
  {
    public short X;
    public short Y;
  }
  
  [StructLayout(LayoutKind.Sequential)]
  public struct SmallRect
  {
    public short Left;
    public short Top;
    public short Right;
    public short Bottom;
  }

  [StructLayout(LayoutKind.Sequential)]
  public struct ConsoleScreenBufferInfoEx
  {
    public uint      cbSize;
    public Coord     dwSize;
    public Coord     dwCursorPosition;
    public short     wAttributes;
    public SmallRect srWindow;
    public Coord     dwMaximumWindowSize;

    public ushort    wPopupAttributes;
    public bool      bFullscreenSupported;

    [MarshalAs(
      UnmanagedType.ByValArray,
      ArraySubType = UnmanagedType.Struct,
      SizeConst = 16)]
    public ColorRef[] ColorTable;
    
    public static ConsoleScreenBufferInfoEx Create()
    {
      return new ConsoleScreenBufferInfoEx { cbSize = 96 };
    }
        
    //public ColorRef black;
    //public ColorRef darkBlue;
    //public ColorRef darkGreen;
    //public ColorRef darkCyan;
    //public ColorRef darkRed;
    //public ColorRef darkMagenta;
    //public ColorRef darkYellow;
    //public ColorRef gray;
    //public ColorRef darkGray;
    //public ColorRef blue;
    //public ColorRef green;
    //public ColorRef cyan;
    //public ColorRef red;
    //public ColorRef magenta;
    //public ColorRef yellow;
    //public ColorRef white;
  }

  public class Kernel
  {
  
    // GetStartupInfo
    // ----------------------------------------------------------
    // Retrieves information about the context in which the
    // calling process was started.
    //
    // https://msdn.microsoft.com/en-us/library/ms683230.aspx
    // http://www.pinvoke.net/default.aspx/kernel32/GetStartupInfo.html
    //
    [DllImport("Kernel32.dll",
      SetLastError = true,
      CharSet = CharSet.Ansi,
      EntryPoint = "GetStartupInfoA")]
    public static extern void GetStartupInfo(
      out StartupInfo lpStartupInfo);
    
    
    [DllImport("Kernel32.dll", 
      SetLastError=true)]
    public static extern IntPtr GetStdHandle(
      int handle);
    
    [DllImport("Kernel32.dll", 
      SetLastError=true)]
    public static extern bool GetConsoleMode(
      IntPtr handle,
      out int mode);
    
    [DllImport("Kernel32.dll",
      SetLastError=true)]
    public static extern bool SetConsoleMode(
      IntPtr hConsoleHandle,
      int mode);

    [DllImport("Kernel32.dll",
      SetLastError = true)]
    public static extern bool SetConsoleWindowInfo(
      IntPtr hConsoleOutput,
      bool bAbsolute,
      [In] ref SmallRect lpConsoleWindow );
      
    [DllImport("Kernel32.dll",
      SetLastError = true)]
    public static extern bool GetConsoleScreenBufferInfoEx(
      IntPtr hConsoleOutput,
      ref ConsoleScreenBufferInfoEx ConsoleScreenBufferInfoEx );
      
    [DllImport("Kernel32.dll",
      SetLastError = true)]
    public static extern bool SetConsoleScreenBufferInfoEx(
      IntPtr hConsoleOutput,
      ref ConsoleScreenBufferInfoEx ConsoleScreenBufferInfoEx );   
  }
  
  [Flags]
  public enum WindowsMessage
  {
    SettingsUpdated = 0x001A
    // Unused values omitted for brevity
  }
  
  public enum MessageTarget
  {
    Broadcast = 0xFFFF
    // Unused values omitted for brevity
  }
  
  public class User
  {  
    [DllImport("User32.dll",
      SetLastError = true,
      CharSet = CharSet.Auto)]
    public static extern bool SendNotifyMessage(
      IntPtr  hWnd,
      uint    Msg, 
      UIntPtr wParam,
      string  lParam);
  }
}

"@

function Set-BufferSize {
    param (
        [int] $Width,
        [int] $Height
    )
    $script:OriginalBufferSize = $Host.UI.RawUI.BufferSize
    $Host.UI.RawUI.BufferSize = [System.Management.Automation.Host.Size]::new($Width, $Height)
}

function Set-Buffer {
    param (
        [System.Management.Automation.Host.BufferCell[,]] $BufferCells
    )

    [Console]::CursorVisible = $false

    #$height = $BufferCells.Value.GetLength(0)
    #$width = $BufferCells.Value.GetLength(1)

    #Set-BufferSize -Width $width -Height $height
    $Host.UI.RawUI.SetBufferContents([System.Management.Automation.Host.Coordinates]::new(0, 0), $BufferCells)
}

function Move-Buffer {
    param (
        [int] $Left = 5,
        [int] $Top = 0
    )
    $rect = [Win32.SmallRect]@{
        Left = $Left
        Top = $Top
        Right = $Left
        Bottom = $Top
    }
    $hConsole = [Win32.Kernel]::GetStdHandle( [Win32.StandardHandle]::StandardOutput )
    $success  = [Win32.Kernel]::SetConsoleWindowInfo( $hConsole, $false, [ref]$rect )
    if($success -eq 0) {
        $e = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw "Status was not zero: $e"
    }
}

function Restore-BufferSize {
    $Host.UI.RawUI.BufferSize = $script:OriginalBufferSize
}

function Open-AlternateScreenBuffer {
    Write-Host "`e[?1049h" 
}

function Restore-OriginalScreenBuffer {
    Restore-BufferSize
    Write-Host "`e[?1049l"
}