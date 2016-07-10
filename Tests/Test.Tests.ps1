
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\..\code\$sut"

Describe "When calling it should return the sum of the numbers" {
    It "should return the sum of the list of integers" {
        Get-Sum -Numbers (1..3) | Should Be 6
    }
}