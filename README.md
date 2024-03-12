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

