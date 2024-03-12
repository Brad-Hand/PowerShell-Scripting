## This script wil pull all machines running Windows Server OS from Active Directory and will gather a slew of data on each machine while also checking for offline/stale DNS records throughout the process. 
## It will output an Excel document with the following info: Machine Name, OS Version, if it's a DC, assigned IPs, Model, Memory in GBs, Number of Disks and their size/free space, and a column for manually entering Location and Purpose/description. 

#Get a list of servers from AD
$servers = Get-ADComputer -Filter { OperatingSystem -Like '*Windows*Server*' } -Properties OperatingSystem | Select -ExpandProperty Name
$infoColl = @()
$Count = 0
write-host "(Found: $servers)'n"
#Proccess script for each server found
Foreach ($s in $servers)
{
    write-host "($s is Proccessing)"
    #Test if servers found in AD are online. Will only collect data for online servers
    If(Test-Connection $s -Count 1 -Quiet)
    {
    #This should test for stale entries in AD/DNS. If a server name replies to ping but doesn't reply to WMI, DNS/AD entry is probably incorrect.
    If(Get-WmiObject Win32_OperatingSystem -ComputerName $s -ErrorAction SilentlyContinue) 
    {
    #Get Operating System
    $OSInfo = Get-WmiObject Win32_OperatingSystem -ComputerName $s
    #Get Memory Information. The data will be shown in a table as MB, rounded to the nearest second decimal.
    $PhysicalMemory = Get-WmiObject CIM_PhysicalMemory -ComputerName $s | Measure-Object -Property capacity -Sum | % { [Math]::Round(($_.sum / 1GB), 2) }
    #Get all IPv4 Addresses, exclude ipV6
    $IPINFO = Get-WmiObject -ComputerName $s Win32_NetworkAdapterConfiguration | Where-Object { $_.IPAddress -ne $null } | Select-Object -Expand IPAddress | Where-Object { ([Net.IPAddress]$_).AddressFamily -eq "InterNetwork" }
    [string]$IPADDR = $IPINFO
    #Get Hard Disk Information
    $Disks = Get-wmiobject  Win32_LogicalDisk -computername $s -ErrorAction SilentlyContinue -filter "DriveType= 3" #-Credential $cred
    #Get Model of server to check if Virtualized or not
    $Model = get-wmiobject win32_computersystem | select model
    #Check if server is a Domain Controller
    $DC = Get-WmiObject -ComputerName $s -Class Win32_ComputerSystem | Select-Object -ExpandProperty DomainRole

        $infoObject = [PSCustomObject]@{Hostname=$s}

            #Add the following data to $infoObject
            Add-Member -inputObject $infoObject NoteProperty -name "OS" -value $OSInfo.Caption
            if( $DC -Match '4|5' ) {Add-Member -InputObject $infoObject NoteProperty -name "DC" -Value "Yes"}
            else {Add-Member -InputObject $infoObject NoteProperty -name "DC" -Value "No"}
            Add-Member -InputObject $infoObject NoteProperty -name "IPs" -value $IPADDR
            Add-Member -InputObject $infoObject NoteProperty -name "Model" -value $Model.Model
            Add-Member -inputObject $infoObject NoteProperty -name "RAM (GB)" -value $PhysicalMemory
            Add-Member -InputObject $infoObject NoteProperty -name "Location" -Value ""
            Add-Member -InputObject $infoObject NoteProperty -name "Purpose" -Value ""
            #Pull Hard Disk information
            foreach($Disk in $Disks) {
                $total=“{0:N0}” -f ($Disk.Size/1GB) 
                $free=([Math]::Round($Disk.FreeSpace /1GB))
                Add-Member -inputObject $infoObject NoteProperty -Name ("Drive (" + $Disk.DeviceID + ")") -Value $total 
                Add-Member -inputObject $infoObject NoteProperty -Name (“Free Space GB (" + $Disk.DeviceID + ")") -Value $free 
                }
    
    $infoColl += $infoObject

    #Search through the output to verify all data fields are present before writting to CSV.
    $Verify=$infoColl | ForEach{$_.PSObject.Properties} | Select -Expand Name -Unique
    $Verify|Where{$_ -notin $infoColl[0].psobject.properties.name}|ForEach{Add-Member -InputObject $infoColl[0] Noteproperty -Name $_ -Value ""}

    }


    Else {
        $infoObject = [PSCustomObject]@{Hostname=$s}
        Add-Member -inputObject $infoObject NoteProperty -name "OS" -value "**Possible Stale DNS Record**"
        $infoColl += $infoObject
        }
    }

    Else {
        $infoObject = [PSCustomObject]@{Hostname=$s}
        Add-Member -inputObject $infoObject NoteProperty -name "OS" -value "**OFFLINE**"
        $infoColl += $infoObject
        }

}

#Export results to CSV
$infoColl | Export-Csv -path .\Server_Inventory_$((Get-Date).ToString('MM-dd-yyyy')).csv -NoTypeInformation
