function Add-R53Record {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)]
		[string] $record,
		
		[Parameter(Mandatory=$true)]
		[string] $type,
		
		[Parameter(Mandatory=$true)]
		[string] $target,
		
		[Parameter(Mandatory=$true)]
		[string] $TTL,
		
		[Parameter(Mandatory=$true)]
		[string] $zone
	)
	process {
		$zoneEntry = @((Get-R53HostedZones) | ? {$_.Name -eq "$($zone)."})
		
		if ($zoneEntry.count -eq 1) {
			$zoneEntry = $zoneEntry[0]
			$hostedZone = $zoneEntry.Id
			$DNSName = "$($record).$($zone)"
			
			#
			# Check to see if the record already exists
			#
			
			# This command will return records starting at the input record name - this will return a record even if the specified recordname doesn't exist.
			
			$ExistingRecordSet = Get-R53ResourceRecordSet -HostedZoneId $hostedZone -StartRecordName "$($record).$($zone)" -MaxItems 1
			# Now that we have the record set - find out if it matches the record we are looking for.
			$ExistingRecords = @($ExistingRecordSet.ResourceRecordSets | ? { $_.Name -match $DNSName })
			if ( $ExistingRecords.Count -ne 0 ) {
				$ExistingValue = $ExistingRecordSet.ResourceRecordSets[0].ResourceRecords[0].Value
				Write-Warning "Record $DNSName already exists - $ExistingValue"
				return
			}
			
			# Create a Changes array - this is submitted to the AWS web service for proessing
			$Changes = (New-Object -TypeName System.Collections.ArrayList($null))
			
			$RecordType = $type
			$DNSTarget = $target
			
			
			# Create a Value - this is the IPAddress/Target for the record.  This is added as a property to the RecordSet
			$Value = (New-Object -TypeName Amazon.Route53.Model.ResourceRecord)
			$Value.Value = $DNSTarget
			
			# Create a RecordSet - this has the details of the DNS addition; the Name of the record, the Type (A, AAAA, CNAME, PTR, etc.), 
			# the TTL, and the Value to be pointed at.  This is added to the Change.
			$RecordSet = (New-Object -TypeName Amazon.Route53.Model.ResourceRecordSet)
			$RecordSet.Name = $DNSName
			$RecordSet.Type = $RecordType
			$RecordSet.TTL = $TTL
			$RecordSet.ResourceRecords.Add($Value)
			
			# Create a Change - this is an individual Change record to add to the Changes array.  The change has an Action, and a record set.  
			# Future revisions might accept multiple changes to this function, and the changes can all be wrapped into one RecordSet.
			$Change = (New-Object -TypeName Amazon.Route53.Model.Change)
			$Change.Action = "CREATE"					# Specifies that this is a CREATE
			$Change.ResourceRecordSet = $RecordSet
			
			[void]$Changes.Add($Change)
			
			Write-Verbose "`n`nAdding $DNSName - $DNSTarget"
			$Changes
			
			$ChangeResponse = Edit-R53ResourceRecordSet -ChangeBatch_Changes $Changes -HostedZoneId $hostedZone # -whatif
			$ChangeResponse
		}
		else {Write-Warning "Zone name '$zone' not found"}
	}
}

function Edit-R53Record {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)]
		[string] $record,
		
		[Parameter(Mandatory=$true)]
		[string] $type,
		
		[Parameter(Mandatory=$true)]
		[string] $target,
		
		[Parameter(Mandatory=$true)]
		[string] $TTL,
		
		[Parameter(Mandatory=$true)]
		[string] $zone
	)
	
	process {
		$zoneEntry = @((Get-R53HostedZones) | ? {$_.Name -eq "$($zone)."})
		
		if ($zoneEntry.count -eq 1) {
			$zoneEntry = $zoneEntry[0]
			$hostedZone = $zoneEntry.Id
			$DNSName = "$($record).$($zone)"
			
			#
			# Check to see if the record already exists
			#
			
			# This command will return records starting at the input record name - this will return a record even if the specified recordname doesn't exist.
			
			$ExistingRecordSet = Get-R53ResourceRecordSet -HostedZoneId $hostedZone -StartRecordName "$($record).$($zone)" -MaxItems 1
			# Now that we have the record set - find out if it matches the record we are looking for.
			$ExistingRecords = @($ExistingRecordSet.ResourceRecordSets | ? { $_.Name -match $DNSName })
			if ( $ExistingRecords.Count -ne 1 ) {
				Write-Warning "Record $DNSName count not exactly 1 ..."
				$ExistingValue = $ExistingRecordSet.ResourceRecordSets[0].ResourceRecords
				return
			}
			
			# Create a Changes array - this is submitted to the AWS web service for proessing
			$Changes = (New-Object -TypeName System.Collections.ArrayList($null))
			
			$RecordType = $type
			$DNSTarget = $target
			
			
			# Create a Value - this is the IPAddress/Target for the record.  This is added as a property to the RecordSet
			$Value = (New-Object -TypeName Amazon.Route53.Model.ResourceRecord)
			$Value.Value = $DNSTarget
			
			# Create a RecordSet - this has the details of the DNS addition; the Name of the record, the Type (A, AAAA, CNAME, PTR, etc.), 
			# the TTL, and the Value to be pointed at.  This is added to the Change.
			$RecordSet = (New-Object -TypeName Amazon.Route53.Model.ResourceRecordSet)
			$RecordSet.Name = $DNSName
			$RecordSet.Type = $RecordType
			$RecordSet.TTL = $TTL
			$RecordSet.ResourceRecords.Add($Value)
			
			# Create a Change - this is an individual Change record to add to the Changes array.  The change has an Action, and a record set.  
			# Future revisions might accept multiple changes to this function, and the changes can all be wrapped into one RecordSet.
			$Change = (New-Object -TypeName Amazon.Route53.Model.Change)
			$Change.Action = "UPSERT"					# Specifies that this is a UPSERT (Update / Insert)
			$Change.ResourceRecordSet = $RecordSet
			
			[void]$Changes.Add($Change)
			
			Write-Verbose "`n`nAdding $DNSName - $DNSTarget"
			$Changes
			
			$ChangeResponse = Edit-R53ResourceRecordSet -ChangeBatch_Changes $Changes -HostedZoneId $hostedZone # -whatif
			$ChangeResponse
		}
		else {Write-Warning "Zone name '$zone' not found"}
	}
}


function Get-R53Record {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)]
		[string] $record,
		
		[Parameter(Mandatory=$true)]
		[string] $zone
	)
	
	process {
		$zoneEntry = @((Get-R53HostedZones) | ? {$_.Name -eq "$($zone)."})
		
		if ($zoneEntry.count -eq 1) {
			$zoneEntry = $zoneEntry[0]
			$hostedZone = $zoneEntry.Id
			$DNSName = "$($record).$($zone)"
			$ExistingRecordSet = Get-R53ResourceRecordSet -HostedZoneId $hostedZone -StartRecordName "$($record).$($zone)" -MaxItems 1
			# Now that we have the record set - find out if it matches the record we are looking for.
			$ExistingRecords = @($ExistingRecordSet.ResourceRecordSets | ? { $_.Name -match $DNSName })
			if ( $ExistingRecords.Count -ne 0 ) {
				$ExistingValue = $ExistingRecordSet.ResourceRecordSets[0].ResourceRecords[0].Value
				New-Object -Type PSObject -Prop @{
					Record = $DNSName
					IPAddress = $ExistingValue
				}
			}
		}
	}
}

Function Get-AllR53RecordsInZone {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)]
		[string] $zone
	)
	
	process {
		$R53Zone = (Get-R53HostedZones) | ? {$_.Name -eq "${zone}." }
		$zoneId = $R53Zone.Id
		$count = $R53Zone.ResourceRecordSetCount
		
		$ResourceRecordSets = @()
		
		# First 100 records - 100 is the maximum records returned by Get-R53ResourceRecordSet
		$ResourceRecordSets += (Get-R53ResourceRecordSet -HostedZoneId $zoneId -MaxItems 100).ResourceRecordSets
		
		# If the returned count is less than the count in this zone, starting with the last returned record, grab the next 100, and repeat until we have all records
		While ( $ResourceRecordSets.Count -lt $count) {
			$LastRecord = $ResourceRecordSets[$ResourceRecordSets.Count - 1]
			$LastRecordName = $LastRecord.Name
			
			$NextRecordSet = Get-R53ResourceRecordSet -HostedZoneId $zoneId -StartRecordName $($LastRecordName) -MaxItems 100 
			
			# Don't include the Last Record from the previous set in the result set - we'll be adding 99 items to the array on each run
			$ResourceRecordSets += $NextRecordSet.ResourceRecordSets | Where { $_.Name -ne $LastRecordName }
		}
		
		$ResourceRecordSets
	}
}

Function Add-MissingrDNSRecords {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$True)]
		[String] $zonename,
		
		[Parameter(Mandatory=$True)]
		[string[]] $Subnet,		# 192.168.1
		
		[string] $RecordFilter,
		
		[int] $TTL = 28800
	)

	begin {
		# Variables a function imports
		Write-Verbose "Loading AWS functions"
		$AmazonFunctions = Join-Path $PSScriptRoot  "AmazonFunctions.ps1"
		Import-Module $AmazonFunctions
	}

	process {
		$ResourceRecordSets = Get-AllR53RecordsInZone -zone $zonename

		ForEach ( $IndSubnet in $Subnet ) {
			Write-Verbose "Starting $IndSubnet"
			# Reverse the IP Address for the reverse lookup zone
			$SubnetSplit = $IndSubnet.Split(".")
			[array]::Reverse($SubnetSplit)
			$rDNSZone = ($SubnetSplit -join ".") + ".in-addr.arpa"
			
			# Find all the A records in the specified zone that match the subnet, and any specified filters
			$AppServerRecords = $ResourceRecordSets | ? { $_.Type -eq "A" -and $_.ResourceRecords.Value -match $IndSubnet -and $_.Name -match $RecordFilter }

			# Loop through each record
			ForEach ( $Record in $AppServerRecords ) {
				$Name = $Record.Name
				$Target = $Name.Substring(0,$Name.Length -1 )
				$IPAddress = $Record.ResourceRecords.Value
				$LastOctet = $IPAddress.Split(".")[3]
				
				# Check to see if the record already exists
				$CheckRecord = Get-R53Record -zone $rDNSZone -record $LastOctet
				
				if ( $CheckRecord -eq $Null ) {
					# If the record doesn't exist, add it.
					Write-Verbose "Add-R53Record -record $LastOctet -type PTR -target $Target -TTL 28800 -zone $rDNSZone"
					Add-R53Record -record $LastOctet -type PTR -target $Target -TTL $TTL -zone $rDNSZone
				}
			}
		}
	}
}
