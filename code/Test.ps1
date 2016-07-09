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

    # Use Write-Host to fail PSScriptAnalyzer
    Write-Host "Hello, Appveyor!"
}
