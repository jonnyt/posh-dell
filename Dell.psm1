# http://techcenter.wikifoundry.com/page/DCIM.Library.MOF4
# http://en.community.dell.com/techcenter/systems-management/w/wiki/4374.how-to-build-and-execute-wsman-method-commands.aspx
# http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2.41.0/
###  http://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=1&cad=rja&uact=8&ved=0CDQQFjAA&url=http%3A%2F%2Fen.community.dell.com%2Fcfs-file.ashx%2F__key%2Ftelligent-evolution-components-attachments%2F13-4491-00-00-20-40-00-06%2FDell_5F00_ChassisSystemInfoProfile_2D00_1.0.pdf&ei=_kKzU-uVGpKHyAS9hIG4DA&usg=AFQjCNH4LgCBpleQcD3O3vBm6k26DHg9nw&sig2=q99c4YDrWEMnHk9eREI6aw&bvm=bv.70138588,d.aWw

Function CreateCimSessionOption
{
    Return New-CimSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck -Encoding Utf8 -UseSsl
}

Function CreateCimSession
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
        $session = CreateCimSession -ipAddress $ipAddress -credential $credential
        return Get-CimInstance -CimSession $session -ResourceUri $uri
    }
    Catch
    {
        Throw
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

Export-ModuleMember -Function Get-CPUView
Export-ModuleMember -Function Get-DellWarranty
Export-ModuleMember -Function Get-iDRACView
Export-ModuleMember -Function Get-MemoryView
Export-ModuleMember -Function Get-NICView
Export-ModuleMember -Function Get-SystemView
Export-ModuleMember -Function Get-BladeView
Export-ModuleMember -Function Get-ChassisView
