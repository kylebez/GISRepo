sal cadmin check-admin
sal radmin runas-admin
sal ruser runas-other-user
sal suser shellrunas
sal notepadp "C:\Program Files\Notepad++\notepad++.exe"

$adminAccount = "NNG\s_101270"
$sysInternalsDir = "C:\SysInternals"

If ([Environment]::Is64BitProcess) {
	$programFilesPath = $Env:ProgramFiles
	$programFilesVar = '$Env:ProgramFiles'
}
ELSE {
	$programFilesPath = $Env:ProgramW6432
	$programFilesVar = '$Env:ProgramW6432' 
}

Function Get-IP {
	(Invoke-WebRequest http://ifconfig.me/ip ).Content
}

Function Get-Zulu {
	Get-Date -Format u
}

Function Get-Pass {
	-join(48..57+65..90+97..122|ForEach-Object{[char]$_}|Get-Random -C 20)
}

function uptime {
	Get-WmiObject win32_operatingsystem | select csname, @{LABEL='LastBootUpTime';
	EXPRESSION={$_.ConverttoDateTime($_.lastbootuptime)}}
}

function reload-profile {
	.$profile.AllUsersAllHosts
}

function find-file($name) {
	ls -recurse -filter "*${name}*" -ErrorAction SilentlyContinue | foreach {
			$place_path = $_.directory
			echo "${place_path}\${_}"
	}
}

function unzip ($file) {
	$dirname = (Get-Item $file).Basename
	echo("Extracting", $file, "to", $dirname)
	New-Item -Force -ItemType directory -Path $dirname
	expand-archive $file -OutputPath $dirname -ShowProgress
}

function grep($regex, $dir) {
	if ( $dir ) {
			ls $dir | select-string $regex
			return
	}
	$input | select-string $regex
}

function touch($file) {
	"" | Out-File $file -Encoding ASCII
}

function sed($file, $find, $replace){
	(Get-Content $file).replace("$find", $replace) | Set-Content $file
}

function which($name) {
	Get-Command $name | Select-Object -ExpandProperty Definition
}

function export($name, $value) {
	set-item -force -path "env:$name" -value $value;
}

function pkill($name) {
    ps $name -ErrorAction SilentlyContinue | kill
}

function pgrep($name) {
    ps $name
}

function check-admin {
    return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
}

function runas-admin {
	$a = check-admin
	IF (!$a){
		Start-Process powershell.exe "-File",('"{0}"' -f $MyInvocation.MyCommand.Path) -Verb RunAs
		exit
	}
}

function runas-other-user {
	$a = check-admin
	IF (!$a){
		Start-Process powershell.exe "-File",('"{0}"' -f $MyInvocation.MyCommand.Path) -Credential (get-credential $adminAccount)
		exit
	}
}

#sometimes must include file extension for .msc
function shellrunas{
	param([string] $file,[switch] $Uninstall)
	pushd $sysInternalsDir
	$file = $file -replace " ", '` '
	switch ($([System.IO.Path]::GetExtension($file))){
		".msi" {. $runmsiexec "/i" $file $Uninstall; Break;} 
		".msp" {. $runmsiexec "/p" $file $Uninstall; Break;}
		Default {
			if ($Uninstall -eq $true){
				. ./shellrunas powershell -Command "Invoke-Command -ArgumentList `"$file`" -ScriptBlock {$removeCim}"
			} else {
				if (!(Test-Path -Path $file -IsValid)){
					$fn = $([System.IO.Path]::GetFileName($file))
					foreach ($p in $Env:Path.Split(';')){
						if(!(Test-Path -Path $p)){continue;}
						if ($(check-if-file-in-path $p $fn)) {
							echo $p\$fn
							. ./shellrunas $p\$fn
							break;
						}
					}
				}
				else{. ./shellrunas $file}
			}
		}
	}
	popd
}

$runmsiexec = {
		param ([string]$handle,[string]$file,[bool]$uninstall)
		if ($uninstall -eq $true){$handle = '/x'}
		. ./shellrunas powershell -WindowStyle "Hidden" -Command "msiexec $handle $file"; Break;
	}

function get-file-list($path) {
	return $(ls -af -Path $path -Name | out-string).split()
}

function check-if-file-in-path($path, $filename) {
	return $($(get-file-list $path | Select-String -SimpleMatch -Pattern "$filename." | Out-String).indexOf($filename) -gt -1) 
}

$removeCim = {
	param ([string]$name)
	echo $('Searching for appliations with the name {0}' -f $name)
	$cims = Get-CimInstance -ClassName Win32_Product -Filter ('Name like ''%{0}%''' -f $name)
	if ($cims.count -eq 0){echo $('No application found with name {0}' -f $name)}
	foreach ($cim in $cims){
		choice /c ync /n /m ('Uninstall {0}? [Y]es/[N]o/[C]ancel' -f $($cim).Name)
		switch ($LASTEXITCODE){
			2 {continue;}
			1 {Remove-CimInstance -Confirm -InputObject $cim; break;}
			3 {echo "Aborting..."; return;}
		}
	}
}

function remove-all-built-ins {
	Get-AppxPackage *3dbuilder* | Remove-AppxPackage
	Get-AppxPackage *windowsalarms* | Remove-AppxPackage
	Get-AppxPackage *windowscommunicationsapps* | Remove-AppxPackage
	Get-AppxPackage *windowscamera* | Remove-AppxPackage
	Get-AppxPackage *officehub* | Remove-AppxPackage
	Get-AppxPackage *skypeapp* | Remove-AppxPackage
	Get-AppxPackage *getstarted* | Remove-AppxPackage
	Get-AppxPackage *windowsmaps* | Remove-AppxPackage
	Get-AppxPackage *zunemusic* | Remove-AppxPackage
	Get-AppxPackage *bingfinance* | Remove-AppxPackage
	Get-AppxPackage *zunevideo* | Remove-AppxPackage
	Get-AppxPackage *bingnews* | Remove-AppxPackage
	Get-AppxPackage *windowsphone* | Remove-AppxPackage
	Get-AppxPackage *bingsports* | Remove-AppxPackage
	Get-AppxPackage *bingweather* | Remove-AppxPackage
	Get-AppxPackage *xboxapp* | Remove-AppxPackage
	Get-AppxPackage *soundrecorder* | Remove-AppxPackage
	Get-AppxPackage Microsoft.YourPhone | Remove-AppxPackage
}

function restore-all-built-ins {
	Get-AppxPackage -AllUsers| Foreach {Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml"}
}

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

