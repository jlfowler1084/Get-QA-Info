function Get-QAInfo {
    Param(
    [CmdletBinding()]
    [Parameter(Mandatory=$true,
               ValuefromPipeline=$true,
               Position=1,
               HelpMessage='Enter name of the Server/VM here',
               ValuefromPipelineByPropertyName=$true)]                  
        [string[]]$ComputerName,
        
        [Parameter(Mandatory=$true,
               ValuefromPipeline=$true,
               Position=2,
               HelpMessage='Enter name of the vCenterServer',
               ValuefromPipelineByPropertyName=$false)]                  
        [string[]]$vCenterServer
           
            )

Connect-VIServer $vCenterServer

foreach($Computer in $ComputerName){

    $OS = Get-WmiObject win32_operatingSystem -ComputerName $Computer
    $VMSpecs = get-vm $Computer | Select-Object Name,memoryGB,VMHost,numcpu,corespersocket,folder
    $VMVlan =  get-vm $Computer | Get-NetworkAdapter
    $IP = Get-VM $Computer | Select-Object Name, @{N="IP Address";E={@($_.guest.IPAddress[0])}}
    $DNS = Get-WmiObject -ComputerName $Computer -Class Win32_Networkadapterconfiguration -Filter "IPEnabled = 'TRUE'" | select DNSServerSearchOrder
    $Gateway = Get-WmiObject -ComputerName $Computer -Class Win32_Networkadapterconfiguration -Filter "IPEnabled = 'TRUE'" | select DefaultIPGateway
    $Datastore = get-vm $Computer | Get-Datastore
    $Cluster = get-vm $Computer | Get-Cluster
    $VMHost = get-vm $Computer | Get-VMHost
    $HardDisks = get-vm $Computer | Get-HardDisk | Select-Object *
    $OU = Get-ADComputer $Computer -Properties CanonicalName,memberof
    $VMTools = Get-VM $Computer | % { get-view $_.id } | Select-Object name, `
                                                            @{Name=“ToolsVersion”; Expression={$_.config.tools.toolsversion}}, `
                                                            @{Name=“ToolStatus”; Expression={$_.Guest.ToolsVersionStatus}}
    $AdminGroup = Get-ADGroupMember "$Computer - Administrator"
    $SplunkForwarder = Invoke-Command {
        Get-Service -ComputerName $Computer -name SplunkForwarder
    }
    $CSFalconService = Invoke-Command {
        Get-Service -ComputerName $Computer -Name CSFalconService    
    }

$props = [ordered]@{'ComputerName'=$Computer;
           'Operating System'=$OS.name;
           'Memory(GB)'=$VMSpecs.MemoryGB;
           'CPUs'=$VMSpecs.NumCpu;
           'CoresPerSocket'=$VMSpecs.CoresPerSocket;
           'VMFolder'=$VMSpecs.Folder;
           'Vlan'=$VMVlan.NetworkName;
           'IP Address'=$IP.'IP Address';
           'DNS Servers'=$DNS.DNSServerSearchOrder;
           'Default Gateway'=$Gateway.DefaultIPGateway;          
           'DataStore'=$Datastore.Name;
           'Cluster'=$Cluster.Name;
           'VMHost'=$VMHost.Name;
           'HardDisks'=$HardDisks.name;
           'DiskSize'=$HardDisks.CapacityGB;
           'StorageFormat'=$HardDisks.storageFormat;
           'OU'=$OU.CanonicalName;
           'MemberOf'=$OU.MemberOf;
           'UsersInAdminAG'=$AdminGroup.samAccountName;
           'VMTools'=$VMTools.ToolStatus;
           'VMToolsVersion'=$VMTools.ToolsVersion;
            #'CrowdStrike Falcon'=$CSFalconService.status.tostring();
            #'Splunk Forwarder'=$SplunkForwarder.status.tostring();
               }
               
$obj = New-Object -TypeName PSObject -Property $Props
       Write-Output $obj 

    Invoke-command -computername $Computer {get-service csfalconservice}
    Invoke-command -computername $Computer {get-service splunkforwarder}

    }
}

