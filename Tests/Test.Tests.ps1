$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

Describe "When calling it should return the sum of the numbers" {
    It "should return an integer" {
        Add-Numbers -Numbers 1..3 | Should Be 6
    }
}