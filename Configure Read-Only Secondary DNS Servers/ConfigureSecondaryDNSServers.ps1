## This script will fully create and configure multiple, if needed, Read Only Secondary DNS servers. 
## Once the DNS Roles are installed on the new Secondary Servers this script can be run and it will load all of the DNS Zones, Configure Zone Transfer and Notify settings, and add all new Read-Only Secondary Servers as Name Servers for all Zones.


$MasterServers = '','','','' #### All Primary DNS Servers ####
$DNSPrimary = "" #### PDC FQDN ###
$NewDNS = '','' #### New Secondary DNS Server(s) FQDN ####
$SecondaryServers = '','' #### All Secondary DNS Servers IPs, including new servers ####
$NS = '','','','' #### All DNS Servers that need to be set as Name Servers across all Zones, including new Secondary Servers. ####
$AllPrimaryServers = '','','','' #### FQDN of all Primary DNS Servers, needed to update Zone Transfer and Notify lists across all zones on all Primary DNS Servers. ####

#### Create all DNS zones on any new DNS Server. This will pull all zones currently on the primary DNS Server to setup on the new server and set the Master DNS Servers to the existing Primary DNS Servers. ####
foreach ($newsrv in $NewDNS){

    Get-DnsServerZone -ComputerName $DNSPrimary | where {("Primary" -eq $_.ZoneType) -and ($False -eq $_.IsAutoCreated) -and ("TrustAnchors" -ne $_.ZoneName)} | %{ $_ | Add-DnsServerSecondaryZone -ComputerName $newsrv -MasterServers $MasterServers -ZoneFile "$($_.ZoneName).dns"} 
}

#### Add all Secondary DNS Servers to the Zone Transfers tab and Notify list for each zone on each Primary DNS Server. ####
foreach ($primary in $AllPrimaryServers){

    Get-DnsServerZone -ComputerName $DNSPrimary | where {("Primary" -eq $_.ZoneType) -and ($False -eq $_.IsAutoCreated) -and ("TrustAnchors" -ne $_.ZoneName)} | ForEach-Object {try {Set-DnsServerPrimaryZone -ComputerName $primary -Name $_.ZoneName -SecureSecondaries TransferToSecureServers -SecondaryServers $SecondaryServers -Notify NotifyServers -NotifyServers $SecondaryServers -ea:Continue} catch {"$_"}}
}

#### Update/add Name Servers for all zones on the primary DNS Server. This will go through all Zones and attempt to add all servers, including existing, in case some are missing. ####
foreach ($name in $NS){
    
    Get-DnsServerZone -ComputerName $DNSPrimary | where {("Primary" -eq $_.ZoneType) -and ($False -eq $_.IsAutoCreated) -and ("TrustAnchors" -ne $_.ZoneName)} | ForEach-Object {try {Add-DnsServerResourceRecord -ns -ComputerName $name -NameServer $name -ZoneName $_.ZoneName -name $_.ZoneName -ea:Continue} catch {"$_"}}
}

