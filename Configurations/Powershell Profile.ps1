sal cadmin check-admin
sal radmin runas-admin
sal ruser runas-other-user
sal suser shellrunas
sal getsha Get-FileHash

$notepadp="$Env:ProgramFiles\Notepad++\notepad++.exe"

$adminAccount = "NNG\s_101270"
$sysInternalsDir = "C:\SysInternals"

if ($env:TERM_PROGRAM -eq "vscode") { . "$(code --locate-shell-integration-path pwsh)" }

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

sal relp reload-profile

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

function Elevate-Task($command, $message){
	#check if elevated, if so, run the string command
	Write-Output $message
	If (Check-Admin -eq $true){
		Invoke-Expression $command
	}
	Else{
		#Handle elevation if needed - NOTE NEED SHELLRUNAS from https://docs.microsoft.com/en-us/sysinternals/downloads/shellrunas
		$p = $sysInternalsDir+"/ShellRunas.exe"
		If(!(Test-Path $p)){
			$p = Read-Host -Prompt "Need elevation - what is the path to shellrunas (or 'N' if not installed)"
			If ($p.ToUpper() -eq 'N' -or !(Test-Path $p.Trim('"'))) {
				Write-Warning "Can't do this task automatically without the shellrunas utility`n
				You can download it from https://docs.microsoft.com/en-us/sysinternals/downloads/shellrunas`n`n
				Skipping... you have to do it manually `n"
				return
			}
		}
		Write-Output "Running the task in a seperate admin process...`n"
		Start-Process -FilePath $p -ArgumentList "powershell ", " -NoExit -Command `"$command; Start-Sleep -s 3; Exit;`""
		Pause
	}
}

function enable-debugger-mode(){
	Elevate-Task "reg add `"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock`" /t REG_DWORD /f /v `"AllowDevelopmentWithoutDevLicense`" /d `"1`"" "Turning on dev mode"
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
	param([string] $fileOrName, [switch] $Uninstall, [string][Parameter(ValueFromRemainingArguments)] $args)
	pushd $sysInternalsDir
	$fileOrNameModified = $fileOrName -replace " ", '` '
	switch ($([System.IO.Path]::GetExtension($fileOrName))){
		#run the msiexec cmd when the file extension is msi or msp
		".msi" {. $runmsiexec "/i" $fileOrName $Uninstall; Break;} 
		".msp" {. $runmsiexec "/p" $fileOrName $Uninstall; Break;}
		Default {
			if ($Uninstall -eq $true){
				#this uninstalls from the cim object server, pretty much the only way to uninstall standard apps from a terminal
				#NOTE: will expect an application name, not a path
				. ./shellrunas powershell -Command "Invoke-Command -ArgumentList `"$fileOrNameModified`" -ScriptBlock {$removeCim}"
			} else {
				#checks if a path was given or a name - if a path just run the path
				if (!(Test-Path -Path $fileOrName)){
					$fn = $([System.IO.Path]::GetFileName($fileOrName))
					#If a name is passed in, find the proper executable and full path - shellrunas needs the full path to work
					
					#Searches for a run command with the same name in the registry
					$appaths = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths" -Name
					foreach ($ap in $appaths){
						if($ap.ToUpper() -like "$($fileOrName.ToUpper())*"){
							#gets and executes the run path of the found run command
							$a = Get-ItemPropertyValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\$ap" -Name "(default)"
							$a = $a -replace " ", '` '
							echo Running:` $a
							. ./shellrunas powershell -Command "& `"$a $args`""
							return
						}
					}
					#Searches the PATH for an executable with the same name
					foreach ($p in $Env:Path.Split(';')){
						if(!(Test-Path -Path $p)){continue;}
						if ($(check-if-file-in-path $p $fn)) {
							echo Running:` $p\$fn
							. ./shellrunas $p\$fn $args
							break;
						}
					}
				}
				else{echo Running:` $fileOrName;. ./shellrunas $fileOrName $args}
			}
		}
	}
	popd
}

#MSI Runner
$runmsiexec = {
		param ([string]$handle,[string]$file,[bool]$uninstall)
		if ($uninstall -eq $true){$handle = '/x'}
		. ./shellrunas powershell -WindowStyle "Hidden" -Command "msiexec $handle $file"; Break;
	}

#Helper functions for traversing through path
function get-file-list($path) {
	return $(ls -af -Path $path -Name | out-string).split()
}
function check-if-file-in-path($path, $filename) {
	return $($(get-file-list $path | Select-String -Pattern "^$filename\." | Out-String).indexOf($filename) -gt -1) 
}

#CIM Uninstaller
$removeCim = {
	param ([string]$name)
	echo $('Searching for applications with the name {0}' -f $name)
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

function manage-files-admin {
	[CmdletBinding()]
	param(
	[Parameter(Mandatory)][ValidateSet("Rename","Remove","Move","Copy")] $operation,
	[Parameter(Mandatory)][string[]]$InputPaths, #If path has a space, must surround with "' '"
	[string[]] $outputPathsOrNames
	)
	$i = @($InputPaths)
	if ($operation -ne 'Remove'){
		$mappedOp = $true
		if($outputPathsOrNames -eq ''){throw "$operation operation requires addtional parameter"}
		$o = @($outputPathsOrNames)
		if($i.length -ne $o.length){throw "Parameter arrays don't match each others length"}
	}
	else{$mappedOp = $false}
	
	for($c=0;$c -le ($i.length-1);$c++){
		$a=$i[$c]
		$b=""
		if($mappedOp){
			$b = " "+$o[$c]
		}
		if ($operation -eq 'Copy'){
			$recurse = " -Recurse"
		}
		else{$recurse=""}
		Elevate-Task "Write-Host 'Performing $operation on $a...';$operation-Item $a$b$recurse" "Performing file operation"
	}	
}

sal mf manage-files-admin

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
	#TODO - doesn't handle paths with spaces, need to pass in literal quotations when appropriate
	Elevate-Task "New-Item -ItemType $type -Path $newpath -Target $targetpath" "Making sym links"
}

function change-permissions{
	#See https://docs.microsoft.com/en-us/dotnet/api/system.security.accesscontrol.filesystemrights for list of file permissions
	[CmdletBinding()]
	param(
	[Parameter(Mandatory)][string]$InputPath,
	[Parameter(Mandatory)][string]$id,
	[Parameter(Mandatory)][ValidateSet("AppendData","ChangePermissions", "CreateDirectories", "CreateFiles", "Delete", "DeleteSubdirectoriesAndFiles",
	"ExecuteFile","FullControl","ListDirectory","Modify","Read","ReadAndExecute","ReadAttributes","ReadData","ReadExtendedAttributes","ReadPermissions",
	"Synchronize","TakeOwnership","Traverse","Write","WriteAttributes","WriteData","WriteExtendedAttributes")][string]$permission,
	[Parameter(Mandatory)][ValidateSet("Allow","Deny")][string]$type
	)
	Elevate-Task "Write-Host 'Setting $type $permission on $InputPath...';`$NewAcl = Get-Acl -Path $InputPath; `$newFilePermList = '$id', '$permission', '$type';
	`$fileSystemAccessRule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList `$newFilePermList;
	`$NewAcl.SetAccessRule(`$fileSystemAccessRule); Set-Acl -Path $InputPath -AclObject `$NewAcl" "Changing permissions..."
}


