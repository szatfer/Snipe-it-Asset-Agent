#This is a Script for Snipe-it to create new Asset&Model or Update yout Asset specs in Snipe-it.

# -rtd_location_id = Default location id 
# -custom_fieldset_id - use your custom fildsets
# -eol - warranty months
# -status_id = default status id
# Lenovo does not store the conventional designations like T490, X270, etc. in the system, so I created this list in the section for determining Lenovo types. This will later provide the Asset name.
# Category - set up yout category id
# Custom fields, modify your data
# -customfields @{ = list your custom fields (Wifi, Ethernet, CPU, RAM.. etc)
#                  Snipe-it Custom Fieldname       Variables
#-customfields @{ "_snipeit_cpu_2"               = "$processor"
#                 "_snipeit_memoria_3"           = "$ram GB"
#                 "_snipeit_m2_ssd_5"            = "$ssd_write"
#                 "_snipeit_hdd_6"               = "$hdd_write"
#                 "_snipeit_lan_mac_address_1"   = "$ethernet"
#                 "_snipeit_wifi_mac_address_13" = "$wifi"
#    }
	
# Check the SnipePS module is install or not
$moduleName = "SnipeitPS"
if (Get-Module -ListAvailable | Where-Object { $_.Name -eq $moduleName }) { Import-Module $moduleName }
else {
  Install-Module $moduleName -Force
  Import-Module $moduleName
}
# Log script
Start-Transcript -Path C:\temp\log_snipeit_agent.txt -Verbose -Append

#Connect the Snipe-it server
Connect-SnipeitPS -url '[serverurl]' -apiKey '[apikey]'

# "Check SSD and HDD and convert to GB"
	$ssd_calc = Get-PhysicalDisk | Where-Object { $_.MediaType -eq "SSD" }
	$nvmeDisksCapacity = $ssd_calc | Measure-Object -Property Size -Sum | Select-Object -ExpandProperty Sum
		$ssd = $nvmeDisksCapacity | ForEach-Object { [math]::Ceiling($_ / 1GB) }
		if ($null -eq $ssd -or $ssd -eq '') {}
	else { $ssd_write = "$ssd GB" }
	$hdd_calc = Get-PhysicalDisk | Where-Object { $_.MediaType -eq "HDD" }
	$DisksCapacity = $hdd_calc | Measure-Object -Property Size -Sum | Select-Object -ExpandProperty Sum
		$hdd = $DisksCapacity | ForEach-Object { [math]::Ceiling($_ / 1GB) }
		if ($null -eq $hdd -or $hdd -eq '') {}
	else { $hdd_write = "$hdd GB" }

# Check CPU
	if((Get-CimInstance -Class Win32_Processor).Name.Split(' ') | Where-Object { $_.StartsWith('Intel')){
		$processorNameParts = (Get-CimInstance -Class Win32_Processor).Name.Split(' ')
		$processor = $processorNameParts | Where-Object { $_.StartsWith('i') }
	}
	Else((Get-CimInstance -Class Win32_Processor).Name.Split(' ') | Where-Object { $_.StartsWith('AMD')){
		$processorNameParts = (Get-CimInstance -ClassName Win32_Processor).name.split(' ')
		$processor = $processorNameParts | Select-Object -First 4 
	}

# Collect Datas
$manufacturer = (Get-WmiObject -Class win32_computersystem).manufacturer.Split(' ')[0]
$assettag = (Get-WmiObject Win32_SystemEnclosure).SMBiosAssetTag
$modelno = (Get-WmiObject -Class win32_baseboard).product
$model = (Get-WmiObject -Class:Win32_ComputerSystem).Model
#Category - my category: 3:Desktop, 4:Laptop, edit your category id
$category = if (Get-WmiObject -Class win32_battery -ComputerName localhost) { 3 } else { 4 } 
$serialnumber = (Get-WmiObject -Class win32_bios).serialnumber
$hostname = (Get-WmiObject Win32_OperatingSystem).CSName
$ram = (Get-WmiObject Win32_ComputerSystem).totalphysicalmemory | ForEach-Object { [math]::Ceiling($_ / 1GB) }
$ethernet = Get-NetAdapter -Physical -Name "ethernet" | ForEach-Object { $_.MacAddress } | ForEach-Object { $_.ToLower() -replace '-','' -replace "(.{4})(?!$)",'$1.' } | Select-Object -Unique
$wifi = Get-NetAdapter -Physical | Where-Object { $_.Name -like "*wi*" } | ForEach-Object { $_.MacAddress } | ForEach-Object { $_.ToLower() -replace '-','' -replace "(.{4})(?!$)",'$1.' } | Select-Object -Unique
$manufacturerid = (Get-SnipeitManufacturer -search "$manufacturer").id

# Lenovo types
$lenovo_type = @{
  "20GKS0CN00" = @("Thinkpad 13")
  "20KN0061HV" = @("ThinkPad E480")
  "21CD0056HV" = @("Thinkpad X1 Yoga")
  "20H1006MHV" = @("ThinkPad E470")
  "20W40091FR" = @("ThinkPad T15")
  "20F9003SHV" = @("ThinkPad T460s")
  "20HD002HHV" = @("ThinkPad T470")
  "20HF003NHV" = @("ThinkPad T470s")
  "20L50005HV" = @("ThinkPad T480")
  "20L7004MHV" = @("ThinkPad T480s")
  "20N20009HV" = @("ThinkPad T490")
  "20L90022HV" = @("ThinkPad T580")
  "20N4000FHV" = @("Thinkpad T590")
  "20HN002UHV" = @("ThinkPad X270")
  "20HN0014HV" = @("ThinkPad X270")
  "20HN0013HV" = @("ThinkPad X270")
  "21HD004YHV" = @("ThinkPad T14")
}

# Write-out the asset specs
Write-Host "Collected Data:"
Write-Host "-------------"
Write-Host "Manufacturer: $manufacturer"
Write-Host "Assettag: $assettag"
Write-Host "Model Number: $modelno"
Write-Host "Model: $model"
Write-Host "Snipe-it Category: $category"
Write-Host "Serial: $serialnumber"
Write-Host "Hostname: $hostname"
Write-Host "CPU: $processor"
Write-Host "RAM: $ram"
Write-Host "Ethernet: $ethernet"
Write-Host "Wifi: $wifi"
Write-Host "HDD: $hdd_write"
Write-Host "SSD: $ssd_write"

Write-Host "$lenovo_type[$modelno]"
$lenovo_type_true = $lenovo_type[$modelno]


# Model
# Model = Dell
if ((Get-WmiObject -Class Win32_ComputerSystem).manufacturer -like "*Dell*") {
  if (Get-SnipeitModel -search "$model") { 
  Write-Host "The Dell $model is exist"
  $modelid = (Get-SnipeitModel -search "$model").id
  Set-SnipeitModel -id "$modelid" -name "$model" -model_number "$modelno" -category_id "$category" -manufacturer_id "$manufacturerid" -custom_fieldset_id "5" -eol "36"
  }
  else { New-SnipeitModel -Name "$model" -category_id "$category" -manufacturer_id "$manufacturerid" -model_number "$modelno" -fieldset_id "5" -eol "36"
    $modelid = (Get-SnipeitModel -search "$model").id
  }
}
# Model = Lenovo
else { if (Get-SnipeitModel -search "$model") { 
        Write-Host "The Lenovo $lenovo_type_true - $model is exist"
        $modelid = (Get-SnipeitModel -search "$lenovo_type_true").id         
        Set-SnipeitModel -id "$modelid" -Name "$lenovo_type_true" -category_id "$category" -manufacturer_id "$manufacturerid" -model_number "$modelno" -fieldset_id "5" -eol "36"
        }
  else {
    Write-Host "New model upload:"
    New-SnipeitModel -Name "$lenovo_type_true" -category_id "$category" -manufacturer_id "$manufacturerid" -model_number "$modelno" -fieldset_id "5" -eol "36"
    $modelid = (Get-SnipeitModel -search "$model").id
  }
}

# If the Dell device exists, update the data.
if ((Get-WmiObject -Class win32_computersystem).manufacturer -like "*Dell*") {
  if (Get-SnipeitAsset -search "$serialnumber") {
    Write-Host "If the Dell device does not exist, enter the data:"
    $assetid = (Get-SnipeitAsset -asset_tag "$assettag").id
    $modelid = (Get-SnipeitModel -search "$model").id

    Set-SnipeitAsset -Name "$manufacturer $model" -model_id "$modelid" -Id "$assetid" -asset_tag "$assettag" -serial "$serialnumber" -notes "Adatfrissítés Snipe-it Agent-el"  -warranty_months "36" -customfields @{ "_snipeit_cpu_2" = "$processor"
      "_snipeit_memoria_3" = "$ram GB"
      "_snipeit_m2_ssd_5" = "$ssd_write"
      "_snipeit_hdd_6" = "$hdd_write"
      "_snipeit_lan_mac_address_1" = "$ethernet"
      "_snipeit_wifi_mac_address_13" = "$wifi"
    }
  }

# If the Dell device does not exist, enter the data.
  else {
    Write-Host "if the Dell device does not exist, enter the data"
    New-SnipeitAsset -Name "$manufacturer $model" -model_id "$modelid" -asset_tag "$assettag" -serial "$serialnumber" -status_id 7 -notes "Gép felvétele Snipe-it Agentel" -rtd_location_id "21" -warranty_months "36" -customfields @{ "_snipeit_cpu_2" = "$processor"
      "_snipeit_memoria_3" = "$ram GB"
      "_snipeit_m2_ssd_5" = "$ssd_"
      "_snipeit_hdd_6" = "$hdd_"
      "_snipeit_lan_mac_address_1" = "$ethernet"
      "_snipeit_wifi_mac_address_13" = "$wifi"
    }
  }
}

# If the Lenovo device exists, update the data.
if ((Get-WmiObject -Class win32_computersystem).manufacturer -like "*Lenovo*"){ 
	if (Get-SnipeitAsset -search "$modelno") {
		Write-Host "if Asset is exist, update data"
		$assetid = (Get-SnipeitAsset -asset_tag "$assettag").id
		$modelid = (Get-SnipeitModel -search "$lenovo_type_true").id

		Set-SnipeitAsset -Name "$manufacturer $lenovo_type_true" -model_id "$modelid" -Id "$assetid" -asset_tag "$assettag" -serial "$serialnumber" -notes "Adatfrissítés Snipe-it Agent-el"  -warranty_months "36" -customfields @{ "_snipeit_cpu_2" = "$processor"
		"_snipeit_memoria_3" = "$ram GB"
		"_snipeit_m2_ssd_5" = "$ssd_write"
		"_snipeit_hdd_6" = "$hdd_write"
		"_snipeit_lan_mac_address_1" = "$ethernet"
		"_snipeit_wifi_mac_address_13" = "$wifi"
		}
	}
# If the Lenovo device does not exist, enter the data
  else { 
	Write-Host "if the Lenovo device does not exist, enter the data"
    $modelid = (Get-SnipeitModel -search "$lenovo_type_true").id

    New-SnipeitAsset -Name "$manufacturer $lenovo_type_true" -model_id "$modelid" -asset_tag "$assettag" -serial "$serialnumber" -status_id 7 -notes "Gép felvétele Snipe-it Agentel" -rtd_location_id "21" -warranty_months "36" -customfields @{ "_snipeit_cpu_2" = "$processor"
      "_snipeit_memoria_3" = "$ram GB"
      "_snipeit_m2_ssd_5" = "$ssd_write"
      "_snipeit_hdd_6" = "$hdd_write"
      "_snipeit_lan_mac_address_1" = "$ethernet"
      "_snipeit_wifi_mac_address_13" = "$wifi"
    }

  }
}

Stop-Transcript
