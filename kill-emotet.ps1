#Disable Admin Shares to prevent emotet's spread, uncomment to enable
#REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /V "AutoShareWks" /T "REG_DWORD" /D "0" /F | Out-Null #No Admin Shares
#restart-service Lanmanserver -Force
#Detect numeric services used in recent emotet compaigns
$emotetservices = Get-Service "[0-9][0-9]*"
#Detect services created within Appdata and other suspicious locations, feel free to turn on, on your own risk, this is risky
#$otherservices = Get-WmiObject win32_service | Where {$_.PathName -match "ProgramData|AppData|windirect|syswow64" -and $_.PathName -notmatch"Defender|sysmon|SilkService|perfhost|" }
# Put emotet process paths in here, you can also add descriptions etc
$emotetprocesses = get-process | Where {$_.Path -match "Appdata\windirect" -and $_.Path -notmatch"Defender|sysmon|SilkService" -and $_.Company -notmatch "Microsoft|Lenovo|Dell|Vmware" }
#Add Known Registry Names Here
$regmatches = @(
    'bcdboot' #emotet
)
#Add Malware MD5's Here
$md5matches = @(
    '005037d2093d135af59375ef0cbaeeb1', #emotet
	'35cf29fe15988d8e0796f8a5e5600f58', #emotet
	'2C176E4A178AFE66FDD68EE91FE621E3' #processhacker test
)
#Add Known Malware process names here
$processmatches = @(
    'emotet', #emotet
	'trickbot' #emotet
)
# Autoruns AutoKiller by ionstorm
if(!(Test-Path -Path "$env:Temp\autorunsc64.exe" )){
   Invoke-WebRequest -Uri "https://live.sysinternals.com/autorunsc64.exe" -OutFile $autorunspath
}
.$env:Temp\autorunsc64.exe -accepteula -vt -h -a l -nobanner -c > $env:Temp\autoruns.csv
$autoruns = Import-CSV $env:Temp\autoruns.csv
$badruns = $autoruns |Where {$_."Image Path" -in $processmatches -or $_.MD5 -in $md5matches}
foreach ($autorun in $badruns){
	$reg = $autorun."Entry Location"
	$entry = $autorun."Entry"
	$path = $autorun."Image Path"
	Write-Host "[+] Removing Registry Persistence Key: " $entry "within" $reg
	get-process |Where {$_.Path -eq "$path"} | Stop-Process -Force -Verbose -ErrorAction SilentlyContinue
	Remove-ItemProperty "registry::$reg" -Name "$entry" -Verbose -Force -Confirm:$false -ErrorAction SilentlyContinue
	#uncomment if you'd like to remove the file.
	#Remove-Item "$path" -Force -Confirm:$false -Verbose -ErrorAction SilentlyContinue
}
# Auto-Runs Auto Virustotal Killer
# Detection Threshold is set a 5 vt detections, be careful with this.
$vt = $autoruns | Where-object {$_."VT Detection" -notmatch '0\|' -and $_."VT Detection" -ne '' -and $_."VT Detection" -ne "Unknown" -and $_."VT Detection" -gt 5 }
foreach ($autorun in $vt){
	$reg = $autorun."Entry Location"
	$entry = $autorun."Entry"
	$path = $autorun."Image Path"
	Write-Host "[+] Removing Registry Persistence Key: " $entry "within" $reg
	get-process |Where {$_.Path -eq "$path"} | Stop-Process -Force -Verbose -ErrorAction SilentlyContinue
	Remove-ItemProperty "registry::$reg" -Name "$entry" -Verbose -Force -Confirm:$false -ErrorAction SilentlyContinue
	#uncomment if you'd like to remove the file.
	#Remove-Item "$path" -Force -Confirm:$false -Verbose -ErrorAction SilentlyContinue

}
# Autorun Service VT check and Cleanup
# Detection Threshold is set a 7 vt detections, be careful with this.
.$env:Temp\autorunsc64.exe -accepteula -vt -h -a s -nobanner -c > $env:Temp\autoruns_services.csv
$autoruns = Import-CSV $env:Temp\autoruns_services.csv
$vt = $autoruns | Where-object {$_."VT Detection" -notmatch '0\|' -and $_."VT Detection" -ne '' -and $_."VT Detection" -ne "Unknown" -and $_."VT Detection" -gt 7 }
foreach ($autorun in $vt){
	$entry = $autorun."Entry"
	$path = $autorun."Image Path"
	Write-Host "[+] Removing Services: " $entry "within" $reg
	get-process |Where {$_.Path -eq "$path"} | Stop-Process -Force -Verbose -ErrorAction SilentlyContinue
	Write-Host "[+] Stopping Malware Service:" $entry
	sc.exe stop $entry
	Write-Host "[+] Disabling Malware Service:" $entry
	#sc.exe delete $entry
	sc.exe disable $entry
	#Remove-Item "$path" -Force -Confirm:$false -Verbose -ErrorAction SilentlyContinue
}

foreach($svc in $emotetservices) {
	Write-Host "[+] Stopping Emotet Service:" $svc.Name
	sc.exe stop $svc.Name
	Write-Host "[+] Deleting Emotet Service:" $svc.Name
	sc.exe delete $svc.Name
	Write-Host "[+] Deleting Service Executable:" $svc.PathName
	Remove-Item $svc.PathName -Force -Confirm:$false -Verbose -ErrorAction SilentlyContinue
}
	
#foreach($svc in $otherservices) {
#	Write-Host "[+] Stopping Other Service:" $svc.Name
#	sc.exe stop $svc.Name
#	Write-Host "[+] Deleting Other Service:" $svc.Name
#	sc.exe delete $svc.Name
#	Write-Host "[+] Deleting Other Service Executable:" $svc.PathName
#	Remove-Item $svc.PathName -Force -Confirm:$false -Verbose -ErrorAction SilentlyContinue
#}

foreach($proc in $emotetprocesses) {
	Write-Host "[+] Killing Process:" $proc.Name
	Stop-Process -Name $proc.Name -Force -Verbose -ErrorAction SilentlyContinue
	Write-Host "[+] Deleting Emotet Executable:" $svc.PathName
	Remove-Item $proc.Path -Force -Confirm:$false -Verbose -ErrorAction SilentlyContinue
}

$PatternSID = 'S-1-5-21-\d+-\d+\-\d+\-\d+$'
$ProfileList = gp 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*' | Where-Object {$_.PSChildName -match $PatternSID} | 
    Select  @{name="SID";expression={$_.PSChildName}}, 
            @{name="UserHive";expression={"$($_.ProfileImagePath)\ntuser.dat"}}, 
            @{name="Username";expression={$_.ProfileImagePath -replace '^(.*[\\\/])', ''}}
 
$LoadedHives = gci Registry::HKEY_USERS | ? {$_.PSChildname -match $PatternSID} | Select @{name="SID";expression={$_.PSChildName}}
$UnloadedHives = Compare-Object $ProfileList.SID $LoadedHives.SID | Select @{name="SID";expression={$_.InputObject}}, UserHive, Username

Foreach ($item in $ProfileList) {
    IF ($item.SID -in $UnloadedHives.SID) {
        reg load HKU\$($Item.SID) $($Item.UserHive) | Out-Null
    }
    "{0}" -f $($item.Username) | Write-Output
	foreach ($v in $regmatches) {
		$value = (Get-item registry::HKEY_USERS\$($Item.SID)\software\microsoft\windows\currentversion\run).getvalue | ? { $_ -match $v }
		if ($value -ne $null) {
			Write-Output "[+] Found Emotet registry value: $value"
			Write-Output "[+] Removing Emotet registry value: $value"
			Remove-ItemProperty registry::HKEY_USERS\$($Item.SID)\Software\Microsoft\Windows\CurrentVersion\Run -Name $value -Verbose -Force -Confirm:$false
			Remove-ItemProperty registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Run -Name $value -Verbose -Force -Confirm:$false
			}
		}
	}
    IF ($item.SID -in $UnloadedHives.SID) {
        [gc]::Collect()
        reg unload HKU\$($Item.SID) | Out-Null
    }