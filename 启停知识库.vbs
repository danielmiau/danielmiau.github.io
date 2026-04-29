Set ws = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

Dim flagFile
flagFile = fso.GetParentFolderName(WScript.ScriptFullName) & "\docsify_running.tmp"

If fso.FileExists(flagFile) Then
    ws.Run "taskkill /f /im node.exe", 0, True
    fso.DeleteFile flagFile, True
    ws.Popup "Docsify stopped.", 1, "Success", 64
Else
    ws.Run "taskkill /f /im node.exe >nul 2>&1", 0, True
    ws.Run "cmd /c cd /d ""E:\github\danielmiau.github.io\docs"" && docsify serve", 0
    fso.CreateTextFile flagFile, True
    WScript.Sleep 1000
    ws.Run "http://localhost:3000"
End If