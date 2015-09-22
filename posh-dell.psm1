<#  

    Helpful resources
    
    Documentation of Dell dcim libraries: http://en.community.dell.com/techcenter/systems-management/w/wiki/1906.dcim-library-profile
    http://en.community.dell.com/techcenter/systems-management/w/wiki/4374.how-to-build-and-execute-wsman-method-commands.aspx
    http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2.41.0/
    http://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=1&cad=rja&uact=8&ved=0CDQQFjAA&url=http%3A%2F%2Fen.community.dell.com%2Fcfs-file.ashx%2F__key%2Ftelligent-evolution-components-attachments%2F13-4491-00-00-20-40-00-06%2FDell_5F00_ChassisSystemInfoProfile_2D00_1.0.pdf&ei=_kKzU-uVGpKHyAS9hIG4DA&usg=AFQjCNH4LgCBpleQcD3O3vBm6k26DHg9nw&sig2=q99c4YDrWEMnHk9eREI6aw&bvm=bv.70138588,d.aWw
    Search "Fibre Channel Host Bus Adapters for Dell PowerEdge Servers"
#>

Add-Type -TypeDefinition @"
    public enum ExportMode
    {
        Normal,
        Clone,
        Replace
    }
"@

Add-Type -TypeDefinition @"
    public enum ShutdownType
    {
        Graceful,
        Forced
    }
"@

Add-Type -TypeDefinition @"
    public enum EndHostPowerState
    {
        PoweredOff,
        PoweredOn
    }
"@


Function CreateCimSessionOption
{
    Return New-CimSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck -Encoding Utf8 -UseSsl
}

Function New-iDracSession
{
    Param(
        [Parameter(Mandatory=$TRUE)][string]$ipAddress,
        [Parameter(Mandatory=$TRUE)][PSCredential]$credential
    )
    $DebugPreference='Continue'
    $ErrorActionPreference = 'Stop'   
    Try
    {
        $Cimop = CreateCimSessionOption
        Return New-CimSession -Authentication Basic -Credential $credential -ComputerName $ipAddress -Port 443 -SessionOption $Cimop
    }
    Catch
    {
        Throw
    }

}

Function GetView
{
    Param(
        [Parameter(Mandatory=$TRUE)][string]$ipAddress,
        [Parameter(Mandatory=$TRUE)][PSCredential]$credential,
        [Parameter(Mandatory=$TRUE)][string]$uri
    )
    $DebugPreference='Continue'
    $ErrorActionPreference = 'Stop'
    Try
    {
        $session = New-iDracSession -ipAddress $ipAddress -credential $credential
        return Get-CimInstance -CimSession $session -ResourceUri $uri
    }
    Catch
    {
        Throw
    }
}

Function Export-SystemConfigurationProfile
{
    Param(
        [Parameter(Mandatory=$True)][string]$ComputerName,
        [Parameter(Mandatory=$True)][PSCredential]$DracCredential,
        [Parameter(Mandatory=$True)][PSCredential]$ShareCredential,
        [Parameter(Mandatory=$True)][string]$ShareName,
        [Parameter(Mandatory=$True)][string]$ShareIP,
        [Parameter(Mandatory=$True)][string]$FileName,
        [Parameter(Mandatory=$False)][string]$Target='All',
        [Parameter(Mandatory=$True)][ExportMode]$ExportMode=[ExportMode]::Normal,
        [Parameter(Mandatory=$False)][Switch]$Passthrough=[Switch]$False
    )

    #$uri = 'http://schemas.dmtf.org/wbem/wscim/1/cimschema/2/root/dcim/DCIM_LCService?SystemCreationClassName=DCIM_ComputerSystem+CreationClassName=DCIM_LCService+SystemName=DCIM:ComputerSystem+Name=DCIM:LCService'

    $session = New-iDracSession -ipAddress $ComputerName -credential $DracCredential

    $properties= @{SystemCreationClassName="DCIM_ComputerSystem";SystemName="DCIM:ComputerSystem";CreationClassName="DCIM_LCService";Name="DCIM:LCService";}
    $instance = New-CimInstance -ClassName DCIM_LCService -Namespace root/dcim -ClientOnly -Key @($properties.keys) -Property $properties
    
    $parameters = @{}
    $parameters.Add('Username',$ShareCredential.UserName)
    $parameters.Add('Password',$ShareCredential.GetNetworkCredential().Password)
    $parameters.Add('IPAddress',$ShareIP)
    $parameters.Add('ShareName',$ShareName)
    $parameters.Add('ShareType',2)
    $parameters.Add('FileName',$FileName)
    $parameters.Add('Target',$Target)
    
    if($ExportMode -ne [ExportMode]::Normal)
    {
        Switch ($ExportMode)
        {
            'Clone' {$parameters.Add('ExportUse',1)}
            'Replace' {$parameters.Add('ExportUse',2)}
        }
    }

    $job = Invoke-CimMethod -MethodName ExportSystemConfiguration -InputObject $instance -CimSession $session -Arguments $parameters
    if($job.ReturnValue -eq 4096)
    {
        if($Passthrough)
        {
            $job
        }
        else
        {
            $job = Wait-SystemConfigurationJob -Session $session -JobID $job.Job.EndpointReference.InstanceID -Activity "Exporting System Configuration for $($session.ComputerName)"
        }
    }
    else
    {
        Throw "Job creation failed with error: $($job.Message)"
    }
    $job

}

Function Import-SystemConfigurationProfile
{
 Param(
        [Parameter(Mandatory=$True)][string[]]$ComputerName,
        [Parameter(Mandatory=$True)][PSCredential]$DracCredential,
        [Parameter(Mandatory=$True)][PSCredential]$ShareCredential,
        [Parameter(Mandatory=$True)][string]$ShareName,
        [Parameter(Mandatory=$True)][string]$ShareIP,
        [Parameter(Mandatory=$True)][string]$FileName,
        [Parameter(Mandatory=$False)][Switch]$Passthrough=[Switch]$False,
        [Parameter(Mandatory=$False)][Switch]$Confirm=[Switch]$True,
        [Parameter(Mandatory=$False)][Switch]$WhatIf=[Switch]$False,
        [Parameter(Mandatory=$False)][EndHostPowerState]$EndPowerState,
        [Parameter(Mandatory=$False)][ShutdownType]$ShutdownType

    )

    #$uri = 'http://schemas.dmtf.org/wbem/wscim/1/cimschema/2/root/dcim/DCIM_LCService?SystemCreationClassName=DCIM_ComputerSystem+CreationClassName=DCIM_LCService+SystemName=DCIM:ComputerSystem+Name=DCIM:LCService'

    Begin
    {
        $properties= @{SystemCreationClassName="DCIM_ComputerSystem";SystemName="DCIM:ComputerSystem";CreationClassName="DCIM_LCService";Name="DCIM:LCService";}
        $instance = New-CimInstance -ClassName DCIM_LCService -Namespace root/dcim -ClientOnly -Key @($properties.keys) -Property $properties
    
        $parameters = @{}
        $parameters.Add('Username',$ShareCredential.UserName)
        $parameters.Add('Password',$ShareCredential.GetNetworkCredential().Password)
        $parameters.Add('IPAddress',$ShareIP)
        $parameters.Add('ShareName',$ShareName)
        $parameters.Add('ShareType',2)
        $parameters.Add('FileName',$FileName)
    
        if(!$WhatIf)
        {
            Switch($EndPowerState)
            {
                'PoweredOff' {$parameters.Add('EndHostPowerState',0)}
                'PoweredOn' {$parameters.Add('EndHostPowerState',1)}
            }

            Switch($ShutdownType)
            {
                'Graceful' {$parameters.Add('ShutdownType',0)}
                'Forced' {$parameters.Add('ShutdownType',1)}
            }
        }

    }
    
    Process
    {
        foreach($computer in $ComputerName)
        {
            $session = New-iDracSession -ipAddress $computer -credential $DracCredential

            if($WhatIf)
            {
                $job = Invoke-CimMethod -MethodName ImportSystemConfigurationPreview -InputObject $instance -CimSession $session -Arguments $parameters
            }
            else
            {
                if(!$Confirm)
                {
                    $job = Invoke-CimMethod -MethodName ImportSystemConfiguration -InputObject $instance -CimSession $session -Arguments $parameters
                }
            }
            
            if($job.ReturnValue -eq 4096)
            {
                if($Passthrough)
                {
                    $job
                }
                else
                {
                    $job = Wait-SystemConfigurationJob -Session $session -JobID $job.Job.EndpointReference.InstanceID -Activity "Exporting System Configuration for $($session.ComputerName)"
                }
            }
            else
            {
                Throw "Job creation failed with error: $($job.Message)"
            }
            $job
        }
    }
}

Function Wait-SystemConfigurationJob
{
    Param (
        [Parameter(Mandatory,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,ValueFromRemainingArguments=$false)]$Session,
        [Parameter (Mandatory)]$JobID,
        [Parameter()][String]$Activity = 'Performing iDRAC job'
    )
    
    $jobstatus = Get-CimInstance -CimSession $Session -ResourceUri "http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/DCIM_LifecycleJob" -Namespace "root/dcim" -Query "SELECT InstanceID,JobStatus,Message,PercentComplete FROM DCIM_LifecycleJob Where InstanceID='$JobID'"
        
    if ($jobstatus.PercentComplete -eq 'NA') 
    {
        $PercentComplete = 0
    }
    else
    {
        $PercentComplete = $JobStatus.PercentComplete
    }
    
    while (($jobstatus.JobStatus -like 'Running' -or $jobstatus.JobStatus -like '*Progress*' -or $jobstatus.JobStatus -like '*ready*' -or $jobstatus.JobStatus -like '*pending*'))
    {
        $jobstatus = Get-CimInstance -CimSession $Session -ResourceUri "http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/DCIM_LifecycleJob" -Namespace "root/dcim" -Query "SELECT InstanceID,JobStatus,Message,PercentComplete FROM DCIM_LifecycleJob Where InstanceID='$JobID'"
        if ($jobstatus.JobStatus -notlike '*Failed*')
        {
            if ($jobstatus.PercentComplete -eq 'NA')
            {
                $PercentComplete = 0
            }
            else
            {
                $PercentComplete = $JobStatus.PercentComplete
            }
        } 
        else
        {
            Throw "Job creation failed with an error: $($jobstatus.Message). Use 'Get-PEConfigurationResult -JobID $($jobstatus.Job.EndpointReference.InstanceID)' to receive detailed configuration result"
        }
        
        Write-Progress -activity "Job Status: $($JobStatus.Message)" -status "$PercentComplete % Complete:" -percentcomplete $PercentComplete
        Start-Sleep 1
    }
    $jobstatus
}

Function Get-SystemConfigurationJob
{
    Param (
        [Parameter(Mandatory,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,ValueFromRemainingArguments=$false)]$Session,
        [Parameter (Mandatory)]$JobID
    )

    $job = Get-CimInstance -CimSession $Session -ResourceUri "http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/DCIM_LifecycleJob" -Namespace "root/dcim" -Query "SELECT * FROM DCIM_LifecycleJob Where InstanceID='$JobID'"
    $job
}

Function Get-SystemConfigurationResult 
{
    [CmdletBinding()]
    [OutputType([PSObject])]
    Param (
        [Parameter(Mandatory,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,ValueFromRemainingArguments=$false)]$Session,
        [Parameter(Mandatory)]$JobID
    )

    Begin 
    {
        $properties=@{InstanceID="DCIM:LifeCycleLog";}
        $instance = New-CimInstance -ClassName DCIM_LCRecordLog -Namespace root/dcim -ClientOnly -Key @($properties.keys) -Property $properties
        $Parameters = @{JobID = $JobID}
    }

    Process
    {
        $Result = Invoke-CimMethod -InputObject $instance -MethodName GetConfigResults -CimSession $Session -Arguments $Parameters
        if ($Result.ReturnValue -eq 0) 
        {
            $Xml = $Result.COnfigResults
            $XmlDoc = New-Object System.Xml.XmlDocument
            $ConfigResults = $XmlDoc.CreateElement('Configuration')
            $ConfigResults.InnerXml = $Xml
            Foreach ($ConfigResult in $ConfigResults.ConfigResults) 
            {
                $ResultHash = [Ordered]@{
                    JobName = $ConfigResult.JobName
                    JobID = $ConfigResult.JobID
                    JobDisplayName = $ConfigResult.JobDisplayName
                    FQDD = $ConfigResult.FQDD
                }
                $OperationArray = @()
                Foreach ($Operation in $ConfigResult.Operation)
{
                    $OperationHash = [Ordered]@{
                        Name = $Operation.Name -join ' - '
                        DisplayValue = $Operation.DisplayValue
                        Detail = $Operation.Detail.NewValue
                        MessageID = $Operation.MessageID
                        Message = $Operation.Message
                        Status = $Operation.Status
                        ErrorCode = $Operation.ErrorCode
                    }
                    $OperationArray += $OperationHash      
                }
                $ResultHash.Add('Operation',$OperationArray)
                New-Object -TypeName PSObject -Property $ResultHash
            }
        } 
        else
        {
            Write-Error $Result.Message
        }
    }
}

Function Get-SystemView
{
    Param(
        [Parameter(Mandatory=$TRUE)][string]$ipAddress,
        [Parameter(Mandatory=$TRUE)][PSCredential]$credential
    )
    Return GetView -ipAddress $ipAddress -credential $credential -uri 'http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_SystemView'
}

Function Get-BladeView
{
    Param(
        [Parameter(Mandatory=$TRUE)][string]$ipAddress,
        [Parameter(Mandatory=$TRUE)][PSCredential]$credential
    )
    Return GetView -ipAddress $ipAddress -credential $credential -uri 'http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_BladeServerView'
}

Function Get-FCStatistics
{
    Param(
        [Parameter(Mandatory=$TRUE)][string]$ipAddress,
        [Parameter(Mandatory=$TRUE)][PSCredential]$credential
    )
    Return GetView -ipAddress $ipAddress -credential $credential -uri 'http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_FCStatistics'
}

Function Get-FCCapabilities
{
    Param(
        [Parameter(Mandatory=$TRUE)][string]$ipAddress,
        [Parameter(Mandatory=$TRUE)][PSCredential]$credential
    )
    Return GetView -ipAddress $ipAddress -credential $credential -uri 'http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_FCCababilities'
}

Function Get-FCView
{
    Param(
        [Parameter(Mandatory=$TRUE)][string]$ipAddress,
        [Parameter(Mandatory=$TRUE)][PSCredential]$credential
    )
    Return GetView -ipAddress $ipAddress -credential $credential -uri 'http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_FCView'
}

Function Get-FCEnumeration
{
    Param(
        [Parameter(Mandatory=$TRUE)][string]$ipAddress,
        [Parameter(Mandatory=$TRUE)][PSCredential]$credential
    )
    Return GetView -ipAddress $ipAddress -credential $credential -uri 'http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_FCEnumeration'
}

Function Get-ChassisView
{
    Param(
        [Parameter(Mandatory=$TRUE)][string]$ipAddress,
        [Parameter(Mandatory=$TRUE)][PSCredential]$credential
    )
    Return GetView -ipAddress $ipAddress -credential $credential -uri 'http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_ModularChassisView'
}

Function Get-CPUView
{
    Param(
        [Parameter(Mandatory=$TRUE)][string]$ipAddress,
        [Parameter(Mandatory=$TRUE)][PSCredential]$credential
    )
    Return GetView -ipAddress $ipAddress -credential $credential -uri 'http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_CPUView'
}

Function Get-MemoryView
{
    Param(
        [Parameter(Mandatory=$TRUE)][string]$ipAddress,
        [Parameter(Mandatory=$TRUE)][PSCredential]$credential
    )
    Return GetView -ipAddress $ipAddress -credential $credential -uri 'http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_MemoryView'
}

Function Get-NICView
{
    Param(
        [Parameter(Mandatory=$TRUE)][string]$ipAddress,
        [Parameter(Mandatory=$TRUE)][PSCredential]$credential
    )
    Return GetView -ipAddress $ipAddress -credential $credential -uri 'http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_NICView'
}

Function Get-iDRACView
{
    Param(
        [Parameter(Mandatory=$TRUE)][string]$ipAddress,
        [Parameter(Mandatory=$TRUE)][PSCredential]$credential
    )
    Return GetView -ipAddress $ipAddress -credential $credential -uri 'http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_iDRACCARDView'
}

<# 
.Synopsis 
   Get Warranty Info for Dell Computer 
.DESCRIPTION 
   This takes a Computer Name, returns the ST of the computer, 
   connects to Dell's SOAP Service and returns warranty info and 
   related information. If computer is offline, no action performed. 
   ST is pulled via WMI. 
.EXAMPLE 
   get-dellwarranty -Name bob, client1, client2 | ft -AutoSize 
    WARNING: bob is offline 
 
    ComputerName ServiceLevel  EndDate   StartDate DaysLeft ServiceTag Type                       Model ShipDate  
    ------------ ------------  -------   --------- -------- ---------- ----                       ----- --------  
    client1      C, NBD ONSITE 2/22/2017 2/23/2014     1095 7GH6SX1    Dell Precision WorkStation T1650 2/22/2013 
    client2      C, NBD ONSITE 7/16/2014 7/16/2011      334 74N5LV1    Dell Precision WorkStation T3500 7/15/2010 
.EXAMPLE 
    Get-ADComputer -Filter * -SearchBase "OU=Exchange 2010,OU=Member Servers,DC=Contoso,DC=com" | get-dellwarranty | ft -AutoSize 
 
    ComputerName ServiceLevel            EndDate   StartDate DaysLeft ServiceTag Type      Model ShipDate  
    ------------ ------------            -------   --------- -------- ---------- ----      ----- --------  
    MAIL02       P, Gold or ProMCritical 4/26/2016 4/25/2011      984 CGWRNQ1    PowerEdge M905  4/25/2011 
    MAIL01       P, Gold or ProMCritical 4/26/2016 4/25/2011      984 DGWRNQ1    PowerEdge M905  4/25/2011 
    DAG          P, Gold or ProMCritical 4/26/2016 4/25/2011      984 CGWRNQ1    PowerEdge M905  4/25/2011 
    MAIL         P, Gold or ProMCritical 4/26/2016 4/25/2011      984 CGWRNQ1    PowerEdge M905  4/25/2011 
.EXAMPLE 
    get-dellwarranty -ServiceTag CGABCQ1,DGEFGQ1 | ft  -AutoSize 
 
    ServiceLevel            EndDate   StartDate DaysLeft ServiceTag Type      Model ShipDate  
    ------------            -------   --------- -------- ---------- ----      ----- --------  
    P, Gold or ProMCritical 4/26/2016 4/25/2011      984 CGABCQ1    PowerEdge M905  4/25/2011 
    P, Gold or ProMCritical 4/26/2016 4/25/2011      984 DGEFGQ1    PowerEdge M905  4/25/201 
.INPUTS 
   Name(ComputerName), ServiceTag 
.OUTPUTS 
   System.Object 
.NOTES 
   General notes 
#> 
function Get-DellWarranty
{ 
    [CmdletBinding()] 
    [OutputType([System.Object])] 
    Param( 
        # Name should be a valid computer name or IP address. 
        [Parameter(Mandatory=$False,  
                   ValueFromPipeline=$true, 
                   ValueFromPipelineByPropertyName=$true,  
                   ValueFromRemainingArguments=$false)] 
         
        [Alias('HostName', 'Identity', 'DNSHostName', 'ComputerName')] 
        [string[]]$Name, 
         
         # ServiceTag should be a valid Dell Service tag. Enter one or more values. 
         [Parameter(Mandatory=$false,  
                    ValueFromPipeline=$false)] 
         [string[]]$ServiceTag 
         ) 
 
    Begin
    {
        $uri =  'http://xserv.dell.com/services/AssetService.asmx?WSDL'
        $service = New-WebServiceProxy -Uri $uri
    } 
    Process{ 
        if($ServiceTag -eq $Null){ 
            foreach($C in $Name){ 
                $test = Test-Connection -ComputerName $c -Count 1 -Quiet 
                    if($test -eq $true){ 
                       # $service = New-WebServiceProxy -Uri $uri 
                        if($args.count -ne 0){ 
                            $serial = $args[0] 
                            } 
                        else{ 
                        $system = Get-WmiObject -ComputerName $C win32_bios -ErrorAction SilentlyContinue 
                        $serial =  $system.serialnumber 
                        } 
                        $guid = [guid]::NewGuid() 
                        $info = $service.GetAssetInformation($guid,'check_warranty.ps1',$serial) 
                         
                        $Result=[ordered]@{ 
                        'ComputerName'=$c 
                        'ServiceLevel'=$info[0].Entitlements[0].ServiceLevelDescription.ToString() 
                        'EndDate'=$info[0].Entitlements[0].EndDate.ToShortDateString() 
                        'StartDate'=$info[0].Entitlements[0].StartDate.ToShortDateString() 
                        'DaysLeft'=$info[0].Entitlements[0].DaysLeft 
                        'ServiceTag'=$info[0].AssetHeaderData.ServiceTag 
                        'Type'=$info[0].AssetHeaderData.SystemType 
                        'Model'=$info[0].AssetHeaderData.SystemModel 
                        'ShipDate'=$info[0].AssetHeaderData.SystemShipDate.ToShortDateString() 
                        } 
                     
                        $obj = New-Object -TypeName psobject -Property $result 
                        $obj
                    }  
                    else{ 
                        Write-Warning "$c is offline" 
                        clv c 
                        }         
 
                } 
        } 
        elseif($ServiceTag -ne $Null)
        { 
            foreach($s in $ServiceTag)
            { 
                  # $service = New-WebServiceProxy -Uri $uri
                        if($args.count -ne 0){ 
                            $serial = $args[0] 
                            } 
                        $guid = [guid]::NewGuid() 
                        $info = $service.GetAssetInformation($guid,'check_warranty.ps1',$S) 
                         
                        if($info -like "*"){ 
                         
                            $Result=[ordered]@{ 
                            'ServiceLevel'=$info[0].Entitlements[0].ServiceLevelDescription.ToString() 
                            'EndDate'=$info[0].Entitlements[0].EndDate.ToShortDateString() 
                            'StartDate'=$info[0].Entitlements[0].StartDate.ToShortDateString() 
                            'DaysLeft'=$info[0].Entitlements[0].DaysLeft 
                            'ServiceTag'=$info[0].AssetHeaderData.ServiceTag 
                            'Type'=$info[0].AssetHeaderData.SystemType 
                            'Model'=$info[0].AssetHeaderData.SystemModel 
                            'ShipDate'=$info[0].AssetHeaderData.SystemShipDate.ToShortDateString() 
                            } 
                        } 
                        else
                        { 
                            Write-Warning "$S is not a valid Dell Service Tag." 
                            Return $Null
                        } 
                     
                        $obj = New-Object -TypeName psobject -Property $result 
                        $obj
                   } 
            } 
    } 
    End 
    { 
    } 
}

Set-Alias CreateCimSession New-iDracSession

Export-ModuleMember -Function *