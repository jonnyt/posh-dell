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

Export-ModuleMember -Function Get-CPUView
Export-ModuleMember -Function Get-iDRACView
Export-ModuleMember -Function Get-MemoryView
Export-ModuleMember -Function Get-NICView
Export-ModuleMember -Function Get-SystemView

