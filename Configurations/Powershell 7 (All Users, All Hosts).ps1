sal mklink make-link

function make-link{
	Param(
    [Parameter(Mandatory)]
	[string]$newpath,
	[Parameter(Mandatory)]
	[string]$targetpath,
	[switch]$Hard
    )
	If((Get-Item $targetpath) -is [System.IO.DirectoryInfo]){
		$type = "Junction"
	}
	elseif ($Hard -eq $true){$type = "HardLink"}
	else{$type = "SymbolicLink"}
	New-Item -ItemType $type -Path $newpath -Target $targetpath
}