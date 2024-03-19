## User Account Creation Script Version 1.1

## Will create On-Prem AD User accounts and O365 mailboxes for users specified in the AddUsers.csv file. 
## Will add user accounts to AD groups specified in that file. Separate groups by a ';' with no spaces. 
## Groups need to be specified using the Group Name(pre-Windows 2000) name, not the display name. 
## Will also place user accounts in the correct OU if specified in the CSV file.

## Just a heads up that the 'Description' column in the CSV file sets the 'Name' attribute in AD as well as the Description.
## This is what you see as the 'Name' when viewing users in AD.  

## If you do not have the CSV file you can make a new one by pasting the below line into Row 1 and saving it as 'AddUsers.csv'
## You will need to make sure the $ADUsers variable is pointing to the location of your AddUsers.csv file. 

## FirstName	LastName	Username	DisplayName	Description	Department	Password	Manager	JobTitle	Company	OU	Groups


## Written by Brad Hand 12/15/2022
## Updated by Brad Hand 09/28/2023 - Changed from adding On-Prem Exch Mailbox to enabling O365 remote mailbox.
## Updated by Brad Hand 01/04/2024 - Changed location of the AddUsers.csv file to point directly to the file on OSLA09
## Updated by Brad Hand 03/11/2024 - Renamed file from ADBulkAdd.ps1 to CreateNewUser.ps1
## Updated by Brad Hand 03/19/2024 - Added ability to gather and verify admin credentials so script can be run without launching an administrative powershell session. 


## $Session, $UPN, -HomeDirectory, -UserPrincipalName and Enable-RemoteMailbox commands will need edited to support your environment. Also you may want to change the location of the $ADUsers file.



# Import AD Module
Import-Module ActiveDirectory

# Gather and verify Admin Credentials. Give user 3 tries before exiting script.
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


#Create connection with Exchange Server and import only the Enable-Mailbox command
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "YOUR_EXCHANGE_SERVER_ADDRESS" -Authentication Kerberos

Import-PSSession $Session -CommandName *Mailbox

# Store the data from NewUsersFinal.csv in the $ADUsers variable
$ADUsers = Import-csv "C:\TEMP\AddUsers.csv" -delimiter ','

# Define UPN
$UPN = "DOMAIN.COM"

# Loop through each row containing user details in the CSV file
foreach ($User in $ADUsers) {

    #Read user data from each field in each row and assign the data to a variable as below
    $Username = $User.username
    $Password = $User.password
    $FirstName = $User.firstname
    $lastname = $User.lastname
    $initials = $User.initials
    $OU = $User.ou #This field refers to the OU the user account is to be created in
    $company = $User.company
    $department = $User.department
    $fullname = $User.displayname
    $displayname = $User.displayname
    $Groups = $User.groups
    $Manager = $User.manager
    $Description = $User.Description
    $JobTitle = $User.JobTitle

    # Check to see if the user already exists in AD
    if (Get-ADUser -F { SamAccountName -eq $username }) {
        
        # If user does exist, give a warning
        Write-Warning "A user account with username $username already exists in Active Directory."
    }
    else {

        # User does not exist then proceed to create the new user account
        # Account will be created in the OU provided by the $OU variable read from the CSV file
        New-ADUser `
            -SamAccountName $username `
            -UserPrincipalName "$username@DOMAIN.COM" `
            -Name $fullname `
            -Description $Description `
            -GivenName $firstname `
            -Surname $lastname `
            -Initials $initials `
            -Enabled $True `
            -DisplayName $displayname `
            -Path $OU `
            -Company $company `
            -Department $department `
            -HomeDrive "H:" `
            -HomeDirectory "\\Path_To_FileShare\$username" `
            -Manager $Manager `
            -Title $JobTitle `
            -AccountPassword (ConvertTo-secureString $password -AsPlainText -Force) -ChangePasswordAtLogon $True

        #Create Exchange Mailbox
        #Enable-Mailbox -Identity $username

        # If user is created, show message.
        Write-Host "The user account $username is created." -ForegroundColor Cyan

        #Add user to AD Groups specified in CSV file
        foreach ($Group in $Groups.Split(';')) {
            Add-ADGroupMember -Identity $Group -Members $username
            Write-Host "$username has been added to $Group"
        }

    }

}

#Wait for 10 seconds to ensure accounts are created before creating mail accounts.
Write-Host "Waiting for 10 seconds to finish creating accounts before creating mail accounts."
Start-Sleep -Seconds 10

#Create Mail Accounts for users in CSV file.
foreach ($User in $ADUsers) {

    $Username = $User.username

    #Check for existing Mailbox matching Username and create if it doesn't exist.
    $Mailbox = Get-Mailbox -Identity $Username -ErrorAction SilentlyContinue
    If (-not $Mailbox) {
        
       #Create Exchange Mailbox
       Enable-RemoteMailbox -Identity $username -RemoteRoutingAddress "$username@DOMAIN.mail.onmicrosoft.com" | Out-Null
       Write-Host "Mailbox Created for $username" -ForegroundColor Cyan
    }

    else {

       Write-Warning "Email account already exists for $username"
    }
}
