# Gather and verify Admin Credentials. Give user 3 tries before exiting.
# Use this to populate the $Credentials variable for future use in a script.
# Continue your script below the While statement. 

$Stoploop = $false
[int]$Retrycount = "1"
 
do {
    try {
        try {$credentials = Get-Credential}
        catch {exit}
        $Username = $credentials.GetNetworkCredential().UserName
        If (Get-ADUser -F {SamAccountName -eq $Username} -Credential $credentials){
        Write-Host "Credentials Validated" -ForegroundColor Green
        }
        $Stoploop = $true
    }
    catch {
        if ($Retrycount -eq 3){
            Write-Host "Logon Failed. Attempt $Retrycount of 3." -ForegroundColor Red
            $Shell = New-Object -ComObject "WScript.Shell"
            $Button = $Shell.Popup("Logon failed 3 times, click OK to exit.", 0, "Error", 48)
            $Stoploop = $true
            exit
        }
        else {
            Write-Host "Logon Failed, please try again. Attempt $Retrycount of 3." -ForegroundColor Red
            $Retrycount = $Retrycount + 1
        }
    }
}

While ($Stoploop -eq $false)
