<#
.SYNOPSIS
    blah

.DESCRIPTION
    blah


.PARAMETER NumbersArray
    blah

.EXAMPLE
    blah

#>
function Get-Sum
{
    param(
      [Parameter(Mandatory = $true)]
      [array]$Numbers
    )

    # Use Write-Host to fail PSScriptAnalyzer
    Write-Output "Hello, Appveyor!"

    $S = 0
    $Numbers | ForEach-Object {$S += $_}

    $S
}

Add-Numbers -Numbers 1..3