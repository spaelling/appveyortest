<#
.SYNOPSIS
    blah

.DESCRIPTION
    blah


.PARAMETER Parameter1
    blah

.EXAMPLE
    blah

#>
function New-Function
{
    param(
      [Parameter(Mandatory = $true)]
      [string]$Parameter1
    )

    Write-Host
}
