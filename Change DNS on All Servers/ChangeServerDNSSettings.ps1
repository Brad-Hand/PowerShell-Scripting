## This script will change the DNS settings on every machine running a Server OS under the specified OU as well as remove any old WINS configurations. It will also create a .csv file of each server and what NIC was changed as a log file.

$DNSServers = “",”" # set dns servers here
$OU = "" # Set OU to search for Servers in

#Pull all Windows Servers from AD
$computers = Get-ADComputer -SearchBase $OU -Filter { OperatingSystem -Like '*Windows*Server*' } -Properties OperatingSystem | Select -ExpandProperty Name

Foreach($computer in $computers){

#Test if server found in AD is Online
If(Test-Connection $computer -Count 1 -Quiet) {

    #This will test for stale entries in AD/DNS. If a server name replies to ping but doesn't reply to WMI, DNS/AD entry is probably incorrect.
    If(Get-WmiObject Win32_OperatingSystem -ComputerName $computer -ErrorAction SilentlyContinue) {
    
        echo "Processing $computer ..."

        #Get all enabled NICs on each server from the stored .csv
        $NICs = Get-WMIObject Win32_NetworkAdapterConfiguration -computername $computer |where{$_.IPEnabled -eq “TRUE”} 

            #Change DNS and remove WINS servers
            Foreach($NIC in $NICs) {
                $NIC.SetDNSServerSearchOrder($DNSServers) | Out-Null
                $NIC.SetDynamicDNSRegistration(“TRUE”) | Out-Null
                $NIC.SetWINSServer("$Null","$Null") | Out-Null
                $NICdescription = $nic | Select-Object -ExpandProperty Description
                $Comp = $computer
                echo "Changed DNS and removed WINS on $comp NIC $NICdescription"

                #Exports all changes to .csv file
                [pscustomobject]@{ComputerName = $comp; NIC = $NICdescription} | Export-Csv -NoType "C:\temp\ServersChanged.csv" -Append
            }
        }
    }
}
