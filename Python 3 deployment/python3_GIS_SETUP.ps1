
[CmdletBinding()]
param (
	[Parameter(Mandatory = $true, ParameterSetName = 'UsingName', Position = 0)]
	[switch]$Name,
	[Parameter(Mandatory = $true, ParameterSetName = 'UsingPath', Position = 0)]
	[ValidateScript({ Test-Path -IsValid $_ })]
	[string]$newCondaEnvPath,
	[Parameter(Mandatory = $true, ParameterSetName = 'UsingName', Position = 1)]
	[string]$newCondaEnvName,
	[Parameter(Mandatory = $true, ParameterSetName = 'UsingName', Position = 2)]
	[Parameter(Mandatory = $true, ParameterSetName = 'UsingPath', Position = 1)]
	[ValidateScript({ Test-Path -IsValid $_ })]
	[string]$cusLibPath,
	[string]$logFile = $null
)
class AbortException: System.Exception {
	$abortMessage
	AbortException([string]$msg) { $this.abortMessage = $msg }
}

If ($logFile -eq '') {
	if ($psISE) {
		#Need to have this for debugging
		$logFile = Split-Path -Path $psISE.CurrentFile.FullPath
	}
	elseif ($PSScriptRoot) {
		$logFile = $PSScriptRoot
	}
	$logFile += "\python3setup.log"
}
# output everything to the specified log file  - create file if it doesn't exist - wrap script in scriptblock to send stream to a teed pipeline
if (!(Test-Path $logFile)) {
	New-Item -Path $(Split-Path $logFile) -Name $(Split-Path -Leaf $logFile) -Type File
}
$logFile = $(Resolve-Path $logFile).Path

$thisScript = { try {
		IF (!$Name) { $newCondaEnvName = Split-Path -Leaf $newCondaEnvPath }
		# Different Env vars for C:\Program Files if 32 or 64 bit, need to declare it AND the variable string itself (for passing into process later)
		If ([Environment]::Is64BitProcess) {
			$programFilesPath = $Env:ProgramFiles
			$programFilesVar = '$Env:ProgramFiles'
		}
		ELSE {
			$programFilesPath = $Env:ProgramW6432
			$programFilesVar = '$Env:ProgramW6432' 
		}
		$pythonExecDir = "$programFilesPath\ArcGIS\Pro\bin\Python\"
		#Sometimes need to reparse the string to account for space in Program Files path
		function Handle-Program-Files-Space ([string]$p) {
			return $p.Replace($programFilesPath, "$programFilesVar")
		}

		# Extra info for log file, to seperate runs
		Write-Information "`n$(Get-Date)`nBegin Python 3 Setup...`n"

		# Determine whether run on a GIS server or not, and find the correct Python script path
		If (!(Test-Path $pythonExecDir)) {
			$pythonExecDir = "$programFilesPath\ArcGIS\Server\framework\runtime\ArcGIS\bin\Python\"
		}
		
		# Variable declarations once the python exec path is established
		$sitePackages = "\Lib\site-packages"
		$condaDir = $pythonExecDir + "Scripts"
		$GISDefEnvName = "arcgispro-py3"
		$GISEnvPath = $pythonExecDir + "envs\"
		$GISNewEnv = "`"$GISEnvPath$newCondaEnvName`""
		$GISDefEnv = "`"$GISEnvPath$GISDefEnvName`""
		IF ($Name) { $newCondaEnvPath = $GISNewEnv }

		#function to check admin
		function Check-Admin{
			return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
		}
		
		# function to call an operation and allow user to cotinue, abort, or retry depending on op success
		function script:Invoke-And-Set-Checkpoint ([string]$operation, [string]$StatusMessage, [switch]$NoCheck) {
			$P = $operation -split " "
			$callOp = $P[0] 
			$paramA = $P[1..($P.Length - 1)]

			$isAcceptable = $false
			:callFunction do {
				#call scripts in current directory and export all output into current stream
				if ( -not [string]::IsNullOrEmpty( $StatusMessage ) ) {$StatusMessage|Out-Host}
				. ./$callOp @paramA *>&1
				#create a checkpoint where the user can check the status of the process
				if(!$NoCheck){
					$UserCheckpointInput = 0
					:userInput while ($UserCheckpointInput -notin "c", "r", "a" ) {
						$UserCheckpointInput = $(Read-Host "Check output for errors. Continue, retry, or abort? [c/r/a]").ToLower()
						switch ($UserCheckpointInput) {
							"c" { "Continuing..." | Out-Host; $isAcceptable = $true; break userInput }
							"r" { "Retrying..." | Out-Host; break userInput }
							"a" { throw [AbortException] "Operation aborted by user" }
							default { "Try again" | Out-Host; break }
						}
					}
				}
				else{$isAcceptable = $true}
			} while ($isAcceptable -eq $false)
		}
		#set cd to the correct location to call conda
		Set-Location $condaDir
		#Check if conda environment already exists, if it does, prompt to remove and reinstall
		If (Test-Path ($GISNewEnv.Trim('"'))) {
			Write-Host "$newCondaEnvName already exists."
			IF ($(Read-Host "Do you want to delete and reinstall? [y/n]").ToLower() -ne 'y') {
				#Exit if no
				Write-Information "Reinstallation rejected in prompt"
				Write-Host "Exiting..."
				Return
			}
			Else {
					#Delete environment if yes
					#Check to see if conda sees this as an environment (i.e. if it is properly installed)
					$envs = (. ./conda info -e --json | ConvertFrom-Json).envs | where {$newCondaEnvName -eq $(Split-Path $_ -Leaf)}
					Write-Host "Deleting environment, this can take a while"
					#Sometimes a junction to the environment will mess up the removal, so remove it first - might need admin
					$envs | where { $_ -eq $($GISNewEnv).Trim('"') } | % {$e = Get-Item $_; If ($e -ne $null -and $e.LinkType -eq 'Junction'){Remove-Item $e -Force}}
					$env = $envs|where{$_ -eq $newCondaEnvPath}
					#If properly installed, try to remove the environment the proper way
					If($env -ne $null){
						 Invoke-And-Set-Checkpoint "deactivate $newCondaEnvName" -StatusMessage "Environment deactivating..." -NoCheck
						 Invoke-And-Set-Checkpoint "conda remove -p $newCondaEnvPath --all --yes"
					}
					#Force delete any remaining environment folder
					If ((Test-Path $newCondaEnvPath)){
						$r = "Remove-Item $newCondaEnvPath -Recurse -Force"
						If (Check-Admin -eq $true){
							Invoke-Expression $r
						}
						Else{
							Start-Process powershell -Verb runas -ArgumentList "-Command `"$r`""
						}
					}
					Write-Host "Deletion complete"
				}
		}
		Write-Host "`nCleaning conda cache..."
		Invoke-And-Set-Checkpoint "conda clean --all --yes --quiet" -NoCheck
		Write-Host "`nCreating conda environment..."
		Invoke-And-Set-Checkpoint "conda create -p `"$newCondaEnvPath`" --clone $GISDefEnvName --pinned --yes"
		Write-Host "`nCompleted env creation script"

		Write-Host "Setting conda configurations..."
		#REFACTOR conda config getter and setter
		#without this, there may be HTTP 000 errors on the network
		. ./conda config --set ssl_verify no #NOTE: turning off ssl, not sure the TRC is 100% onboard with this
		$condaChannels = $(. ./conda config --get channels).Split("`n").ForEach({ $_.Split("'")[1] })
		#make sure esri is the top priority channel
		If($condaChannels -notcontains "esri"){
			. ./conda config --prepend channels esri
		}

		#Add additional dependency channels
		#TODO Config list of channels?
		If("conda-forge" -notin $condaChannels){
			. ./conda config --append channels conda-forge
		}

		Invoke-And-Set-Checkpoint "deactivate $newCondaEnvName" -StatusMessage "Environment deactivating..." -NoCheck

		Write-Host "Installing dependencies..."
		# TODO: Write dependency install code from config file

		# TODO: Revise below
		# Creating script to link to custom library folder in new environment and to new environment in ArcGIS Pro env folder
		$newCusLibPath = $cusLibPath
		$mkLinks = "If (!(Test-Path $newCusLibPath)){New-Item -Path $newCusLibPath -ItemType Junction -Value $cusLibPath};If (!(Test-Path $GISNewEnv)) {New-Item -Path $GISNewEnv -ItemType Junction -Value $newCondaEnvPath}"

		# Creating script to write custom library to default python environment lookup
		$mkLinksDesc = "linking to custom library folder in new environment and to new environment in ArcGIS Pro env folder"

		#Handle passing in a path with Program Files (containing a space) into the seperate powershell functions
		$mkLinks = Handle-Program-Files-Space $mkLinks
		$appendToPth = Handle-Program-Files-Space $appendToPth

		# run in a seperate elevated process
		# Write informational explanation and then run the created commands
		$process = "Write-Output ``n'$mkLinksDesc'; $mkLinks;"
		$process = $process.replace('"""', '"')
		If (Check-Admin -eq $true){
			Invoke-Expression $process
		}
		#Handle elevation if needed
		Else{
			$sb = {Param($command); cd $HOME; Invoke-Expression $command}
			Start-Process powershell -Verb runas -ArgumentList "-NoExit","-Command &{$sb} $process" >$null
		}
		#Test that the previous job was successful
		#REFACTOR
		If (!(Test-Path $cusLibPath)){Write-Warning "Error creating custom library link, please try it manually. Custom libraries will not work without it."}
		If (!(Test-Path ($GISNewEnv.Trim('"')))) { Write-Warning "Error creating new environment link, please try it manually. Cannot reference this new environment by name without it."}
		If (!$(Select-String -Quiet -Path $arcGISProPthFile -SimpleMatch $($appendToPthStmt.Replace('`"""', '"')))) { Write-Error "Error writing to pth file, try it manually" }

		Write-Host "setting new environment as default `n"
		#need to run as a background job or the shell will 'hang' at the new environment input prompt
		Start-Job -Name proswap -InitializationScript ([scriptblock]::Create("cd "+(Handle-Program-Files-Space $condaDir))) -ScriptBlock { ./proswap $input } -InputObject $newCondaEnvPath > $null
		Receive-Job proswap -Wait 
		Write-Host "`nScript complete"
	}
	catch [AbortException] { 
		Write-Output $_.Exception.abortMessage; return
	} 
	catch { return $_ } }

. $thisScript *>&1 | Tee-Object -FilePath $logFile -Append
