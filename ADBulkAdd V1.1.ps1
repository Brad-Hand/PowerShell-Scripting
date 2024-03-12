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


## $Session, $UPN, -HomeDirectory, -UserPrincipalName and Enable-RemoteMailbox commands will need edited to support your environment. Also you may want to change the location of the $ADUsers file.



# Import AD Module
Import-Module ActiveDirectory

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