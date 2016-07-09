<#
.SYNOPSIS
    Installs the DoubleTake agent.

.DESCRIPTION
    The Install-DTAgent cmdlet installs the DoubleTake agent on all servers specified in a CSV file in the Path parameter.

The cmdlet will first ping each server to see if it is responding. Then, if the server does not have the DoubleTake agent installed, it will proceed to install it.
    After that, it checks if the DoubleTake agent has been activated. If not, it activated the agent.


.PARAMETER Path
    Specifies the CSV file to get server information from.

.PARAMETER ActivationCode
    Specifies the DoubleTake activation code to use.

.PARAMETER Delimiter
    Specifies the delimiter used by the CSV file. By default it uses ';'.

.PARAMETER MaxPingRetries
    Specifies how many pings will be tried, before the server is considered not responding.

.EXAMPLE
    Install-DTAgent -Path C:\Migration\VMs.csv -ActivationCode 12341234

#>
function Install-DTAgent
{
    param(
      [Parameter(Mandatory = $true)]
      [string]$Path,
      [Parameter(Mandatory = $true)]
      [string]$ActivationCode,
      [string]$Delimiter = ";",
      [int]$MaxPingRetries = 5
    )

    [array]$VMsToReplicate = Import-Csv -Path $Path -Delimiter $Delimiter -ErrorAction stop

    Clear-DnsClientCache

    foreach($VM in $VMsToReplicate)
    {
        # check if machine is up
        $PingRetries = 0;
        $VMOnline = $true
        # 127.0.53.53 is a name collision
        while(-not (Test-Connection -ComputerName $VM.SourceIP -ErrorAction SilentlyContinue | ? {$_.IPV4Address -and $_.IPV4Address -ne '127.0.53.53'}))
        {
            Write-Host -ForegroundColor Red "Machine $($VM.SourceSrv) is not responding. Waiting a while..."
            Start-Sleep -Seconds 1
            $PingRetries += 1
            if($PingRetries -ge $MaxPingRetries)
            {
                Write-Host -ForegroundColor Red "Machine $($VM.SourceSrv) did not respond in time. Skipping"
                $VMOnline = $false
                break;
            }
        }

        if($VMOnline)
        {
            Write-Host -ForegroundColor Green "Machine $($VM.SourceSrv) is online"

            $VMSource = $VM.SourceSrv
            $IPSource = $VM.SourceIP
            $UserName = $VM.AdminUser
            $Password = $VM.AdminUserPwd

            $DtSource = $null
            if(-not (Test-DTAgentInstalled -VMSource $IPSource -UserName $UserName -Password $Password -DtSource ([ref]$DtSource)))
            {
                Write-Host "Initiating DT agent install on $VMSource..."
                # no formatting seems to be needed
                $Now = (Get-Date).AddSeconds(10) #.ToString("MM/dd/yyyy HH:mm:ss") #Get-date -Format d
                # installing without activation code. activating in next step
                Install-DoubleTake -RemoteServer $DtSource -Schedule $Now -NoReboot -AsJob -ActivationCode None | Out-Null
            }
            else
            {
                Write-Host -ForegroundColor Green "$VMSource already has DT agent installed"
            }
        } # end if VM online
    } # end foreach VM

    # just wait for a second or two here!
    New-Sleep -Seconds 10 -Message "Waiting for DT Agent to install"

    # now we wait for machines to install the DT agent
    $MaxLoops = 10
    $SleepTimeInSeconds = 10
    $LoopCounter = 0
    # loop takes at most $MaxLoops * $SleepTimeInSeconds seconds to complete
    while($true)
    {
        foreach($VM in ($VMsToReplicate | ? {-not $_.IsActivated}))
        {
            $VMSource = $VM.SourceSrv
            $IPSource = $VM.SourceIP
            $UserName = $VM.AdminUser
            $Password = $VM.AdminUserPwd
            $DtInfo = $null
            $DtSource = $null

            if(-not (Test-DTAgentInstalled -VMSource $IPSource -UserName $UserName -Password $Password -DtInfo ([ref]$DtInfo) -DtSource ([ref]$DtSource)))
            {
                $AllMachinesInstalled = $false
                Write-Verbose "$VMSource Not ready for activation yet..."
            }
            else
            {
                # machine is ready for activating license
                $ActivationStatus = Get-DtActivationStatus -ServiceHost $DtSource
                if (-not $ActivationStatus.IsValid) {
                    
                    Write-Host "$VMSource has DT agent installed. Activating license..."

                    Set-DtActivationCode -ServiceHost $DtSource -Code $ActivationCode | Out-Null
                    $dtonlineactivationRequest = Get-DtOnlineActivationRequest -ServiceHost $DtSource

                    try
                    {
                        $dtonlineActivation = Request-DtOnlineActivation -Code $dtonlineactivationRequest.Code `
                            -ServerName $dtonlineactivationRequest.ServerName `
                            -ServerInformation $dtonlineactivationRequest.ServerInformation

                        $dtactivation = Set-DtActivationCode -Code $dtonlineActivation.Code -ActivationKey $dtonlineActivation.ActivationKey -ServiceHost $DtSource -ErrorAction Stop
                    }
                    catch [System.Exception]
                    {
                        Write-Host -ForegroundColor Red "Failed to request an online activation"
                        if(-not ($dtonlineactivationRequest.ServerInformation))
                        {
                            Write-Host -ForegroundColor Red "ServerInformation missing from activation request. Is this a trial-license?"
                        }
                        $ActivationStatus = Get-DtActivationStatus -ServiceHost $DtSource
                        if($ActivationStatus.IsValid)
                        {
                            Write-Host -ForegroundColor Green "Server $VMSource is activated nonetheless..."
                        }
                        else
                        {
                            Write-Host -ForegroundColor Red "Please activate $VMSource manually using the DT console or try again later"
                        }
                    }

                    Write-Host -ForegroundColor Green "Activated DT agent on $VMSource"

                    # exclude from foreach loop      
                    $VM | Add-Member -Name "IsActivated" -Value $true -MemberType NoteProperty
                }
                else
                {
                    Write-Host -ForegroundColor Green "DT agent on $VMSource is already activated"
                    # exclude from foreach loop      
                    $VM | Add-Member -Name "IsActivated" -Value $true -MemberType NoteProperty
                }
            } # end else
        } # end foreach

        $MachinesActivated = ([array]($VMsToReplicate | ? {$_.IsActivated})).Count

        Write-Host -ForegroundColor Green "$MachinesActivated machines activated out of $($VMsToReplicate.Count)"

        # break if all machines are activated
        if(($VMsToReplicate | ? {-not $_.IsActivated}).Count -eq 0) { break; }

        # wait for DT agent installation to complete
        if($LoopCounter -lt $MaxLoops)
        {
            New-Sleep -Seconds 10 -Message "Waiting for DT Agent to install"
        }
        else
        {
            Write-Host -ForegroundColor Red "Unable to activate all machines within timelimit"
            break;
        }

        $LoopCounter += 1;

    } # end infinite loop

    if($MachinesActivated -ne $VMsToReplicate.Count)
    {
        Write-Host -ForegroundColor Red "The following machines did not activate/install DT agent"
        ($VMsToReplicate | ? {-not $_.IsActivated}) | select -ExpandProperty SourceSrv
    }
}
