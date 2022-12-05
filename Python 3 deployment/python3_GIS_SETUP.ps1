
[CmdletBinding()]
param (
	[Parameter(Mandatory = $true, Position = 0)]
	[string]$newCondaEnv,
	[Parameter(Mandatory = $true, Position = 1)]
	[ValidateScript({ Test-Path -IsValid $_ })]
	[string]$arcnngPath,
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

if ((Test-Path $newCondaEnv -PathType 'Container') -or (!(Test-Path $newCondaEnv) -and ($newCondaEnv -replace '\\', '/') -match '[A-Z]:/\w+/.+')) {
	$newCondaEnvPath = $newCondaEnv
	$newCondaEnvName = Split-Path -Leaf $newCondaEnvPath
}
else { $newCondaEnvName = $newCondaEnv}

$thisScript = { try {
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

		# Extra info for log file, to separate runs
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

		#function to check admin
		function Check-Admin{
			return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
		}

		function Elevate-Task($command, $message){
			#check if elevated, if so, run the string command
			Write-Output `n$message
			If (Check-Admin -eq $true){
				Invoke-Expression $command
			}
			Else{
				#Handle elevation if needed - NOTE NEED SHELLRUNAS from https://docs.microsoft.com/en-us/sysinternals/downloads/shellrunas
				$p = Read-Host -Prompt "Need elevation - what is the path to shellrunas (or 'N' if not installed)"
				If ($p.ToUpper() -eq 'N' -or !(Test-Path $p.Trim('"'))) {
					Write-Warning "Can't do this task automatically without the shellrunas utility. `nYou can download it from https://docs.microsoft.com/en-us/sysinternals/downloads/shellrunas `n ...Exiting..."
					Exit 1
				}
				Else {
					Write-Output "Running the task in a separate process...`n"
					Start-Process -FilePath $p -ArgumentList "powershell ", " -NoExit -Command `"Write-Output '$message'; $command; Start-Sleep -s 3;`""
					Pause
				}
			}
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
						$UserCheckpointInput = $(Read-Host "Check output for non-DEBUG errors. Inconsistent environment is OK. Continue, retry, or abort? [c/r/a]").ToLower()
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
		$GISEnvPath = $GISNewEnv.Trim('"')
		If ((Test-Path $GISEnvPath) -or (Test-Path $newCondaEnvPath)) {
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
					If (!$newCondaEnvPath) {
						(. ./conda env list) | % { $condaEnvList += ";$_" }
						$condaEnvList = ($condaEnvList -split ';').Where({ $_ -match '^(?:base)' }, "SkipUntil")
						$selectedCondaEnvName = $condaEnvList | Select-String "^$([regex]::escape($newCondaEnvName))\b" | Select-Object -ExpandProperty "Matches" -First 1 | Select-Object -ExpandProperty "Value"
						$selectedCondaEnvPath = $condaEnvList | Select-String "(?<=$([regex]::escape($newCondaEnvName))\s+)\w.+" | Select-Object -ExpandProperty "Matches" -First 1 | Select-Object -ExpandProperty "Value"
						If ($selectedCondaEnvName -ne $newCondaEnvName -or !$(Test-Path "$selectedCondaEnvPath")) { Write-Error 'Error resolving conda environment!! Try using environment path instead!'; Exit 1 }
						$condaEnvTarget = (Get-Item $selectedCondaEnvPath).Target
						If($condaEnvTarget){
							$newCondaEnvPath = $selectedCondaEnvName
						} Else {$newCondaEnvPath = $condaEnvTarget}
					}
					$env = $envs|where{$_ -eq $newCondaEnvPath}
					#If properly installed, try to remove the environment the proper way
					If($env -eq $null -and $newCondaEnvPath -ne $null){
						$env = $newCondaEnvPath
					}
					Elseif ($env -eq $null) { Write-Host "Error getting conda environment"; Exit 1}
					If($env -ne $null){
                        Write-Host "proswap to default environment..."
		                #need to run as a background job or the shell will 'hang'
		                Start-Job -Name proswap -InitializationScript ([scriptblock]::Create("cd "+(Handle-Program-Files-Space $condaDir))) -ScriptBlock { ./proswap $input } -InputObject $GISDefEnvName > $null
		                Receive-Job proswap -Wait

					    #Sometimes a junction to the environment will mess up the removal, so remove it first
					    $envs | where { $_ -eq $GISEnvPath } | % { $e = Get-Item $_; If ($e -ne $null -and $e.LinkType -eq 'Junction') { Elevate-Task "Remove-Item '$e' -Force -Recurse" "Remove junction to new environment" }}
						 Invoke-And-Set-Checkpoint "conda remove -p $newCondaEnvPath --all --yes"
					}
					Else { Write-Host "Can't use conda command to delete, will force delete"}
					#Force delete any remaining environment folder
					If ((Test-Path $newCondaEnvPath)){
						$remEnvCommand = "Remove-Item $newCondaEnvPath -Recurse -Force"
						Elevate-Task $remEnvCommand "Attempting to delete environment folder"
					}
					#Delete the symlink to the enivronment
					If ((Test-Path $GISEnvPath)){
						$remSymLinkCommand = "cmd /c rmdir `"$($GISEnvPath.Replace(' ','` '))`""
						Elevate-Task $remSymLinkCommand "Attempting to delete symlink"
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
		$condaChannels = $(. ./conda config --get channels)
		If($condaChannels -eq $null){
			. ./conda config --prepend channels defaults
		}
		$condaChannels = $condaChannels.Split("`n").ForEach({ $_.Split("'")[1] })
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
		Write-Host "Installing svglib"
		Invoke-And-Set-Checkpoint "conda install -p `"$newCondaEnvPath`" svglib --no-update-deps --yes --quiet"
		Write-Host "Installing reportlab"
		Invoke-And-Set-Checkpoint "conda install -p `"$newCondaEnvPath`" reportlab --no-update-deps --yes --quiet"

		# Creating script to link to arcnng folder in new environment
		$arcnngLnkPath = $newCondaEnvPath + $sitePackages
		$newArcnngPath = $arcnngLnkPath + "\arcnng3"
		$mkLinks = "If (!(Test-Path $newArcnngPath)){New-Item -Path $newArcnngPath -ItemType Junction -Value $arcnngPath};If (!(Test-Path $GISNewEnv)) {New-Item -Path $GISNewEnv -ItemType Junction -Value $newCondaEnvPath}"

		$mkLinksDesc = "linking to arcnng folder in new environment and to new environment in ArcGIS Pro env folder"

		#Handle passing in a path with Program Files (containing a space) into the separate powershell functions
		$mkLinks = Handle-Program-Files-Space $mkLinks

		# run in a separate elevated process (will always need to reenter password since they turned off UAC)
		# Write informational explanation and then run the created commands
		$process = "Write-Output ``n'$mkLinksDesc'; $mkLinks"
		$process = "cd $HOME; $process"
		Elevate-Task $process "Creating symlinks"

		#Test that the previous job was successful
		#REFACTOR
		If (!(Test-Path $newArcnngPath)){Write-Warning "Error creating arcnng link, please do this manually"}
		If (!(Test-Path ($GISNewEnv.Trim('"')))) { Write-Warning "Error creating new environment link, please do this manually"}

		Write-Host "setting new environment as default `n"
		#need to run as a background job or the shell will 'hang' at the new environment input prompt
		Start-Job -Name proswapjob -InitializationScript ([scriptblock]::Create("cd "+(Handle-Program-Files-Space $condaDir))) -ScriptBlock { ./proswap $input } -InputObject $newCondaEnvPath > $null
		Receive-Job proswapjob -Wait
		Write-Host "`nScript complete"
	}
	catch [AbortException] {
		Write-Output $_.Exception.abortMessage; return
	}
	catch { return $_ } }

. $thisScript *>&1 | Tee-Object -FilePath $logFile -Append
