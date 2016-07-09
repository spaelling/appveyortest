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
function Get-Function
{
    param(
      [Parameter(Mandatory = $true)]
      [string]$Parameter1
    )

    Write-Out "Hello, Appveyor!"
}
