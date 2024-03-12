## This script will create a Genesys Cloud user account based on variable set below. You will need to fill in the RoleIDs based on the roles you wish to assign users in your envrionment.

# Gather all variables needed for account creation. These could be pulled from a CSV or manually entered in the script. Create foreach loop for running through multiple users via a CSV. 
$PhoneNumber = ""
$Number = "+1$PhoneNumber"
$extension = ""
$email = ""
$DisplayName = ""
$Title = ""
$Department = ""
$DivisionID = ""
$Password = ""
$LocationID = ""

# Create the user account with a 10 digit DID and Extension. This uses the US country code. Will need to adjust if in another country. 
$NewGCUser = @{
    addresses = @{
        address = $Number
        countryCode = "US"
        mediaType = "PHONE"
        type = "WORK"
        },
        @{
        countryCode = "US"
        extension = $extension
        mediaType = "PHONE"
        type = "WORK2"
        }
    department = $Department
    divisionID = $DivisionID
    email = $email
    name = $DisplayName
    title = $JobTitle
    state = "active"
    password = $Password
}

#Convert above array into JSON for importing into Genesys Cloud
$NewGCUser | ConvertTo-Json | Out-File C:\Temp\GCNewUser.txt -Force

gc.exe users create -f "C:\Temp\GCNewUser.txt"


#Give above time to process before adding roles to the account
Start-Sleep -Seconds 5

#Pull the new user's data from Genesys Cloud
$GCUser = gc.exe users list --autopaginate --filtercondition="email==$email" | ConvertFrom-Json

#Specify what roles to add to users by default. Add as many or as few as needed, just specify the Role's ID inside the quotes.
$Roles = (
        "RoleID#1",
        "RoleID#2",
        "RoleID#3" 
    )

#Convert above variable string into JSON for importing into Genesys Cloud.
$Roles | ConvertTo-Json | Out-File C:\temp\GCRoles.txt -force

gc.exe users roles update $GCuser.id -f C:\temp\GCRoles.txt


#Set the user's location. This is useful if you use locations for E911 routing. 
$Location = @{
    locations = 
        @(
        @{id = @LocationID}
        ) 
     version = $GCUser.version
}

$Location | ConvertTo-Json | Out-File C:\Temp\GCLocation.txt -force 

gc.exe users update $GCUser.id -f C:\Temp\GCLocation.txt

