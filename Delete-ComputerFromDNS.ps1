#requires -version 4
[CmdletBinding()]
param(
	$Computer
)

Function Remove-DNSEntryFromZone
{
	[CmdletBinding()]
	param(
		$Computer,
		$DNSServer,
		$ZoneName
	)
	begin {

	}
	process {
		Write-Verbose "Check for existing DNS record(s) in $ZoneName"
		$NodeARecord = Get-DnsServerResourceRecord -ZoneName $ZoneName -ComputerName $DNSServer -Node $Computer -RRType A -ErrorAction SilentlyContinue
		$NodeARecord
		
		
		if($NodeARecord -eq $null){
			Write-Verbose "No A record found"
		} else {
			$IPAddress = $NodeARecord.RecordData.IPv4Address.IPAddressToString
			$IPAddressArray = $IPAddress.Split(".")
			
			# Build a reverse zone for /24 subnet
			$ReverseZoneStub = ($IPAddressArray[2] + "." + $IPAddressArray[1] + "." + $IPAddressArray[0] + ".in-addr.arpa")
			# Get a list of reverse lookup zones that match this subnet
			$ReverseZoneNames = @(Get-DnsServerZone -ComputerName $DNSServer | ? { $_.ZoneName -eq $ReverseZoneStub -and $_.IsReverseLookupZone -and -NOT($_.ZoneType -eq "Forwarder") } | select-object -expandproperty ZoneName)
			
			# If we didn't find any, lets look for /16
			if ( $ReverseZoneNames.Count -eq 0 ) {
				Write-Verbose "No Reverse zones found matching $ReverseZoneStub - checking for /16"
				$ReverseZoneStub = ($IPAddressArray[1] + "." + $IPAddressArray[0] + ".in-addr.arpa")
				$ReverseZoneNames = @(Get-DnsServerZone -ComputerName $DNSServer | ? { $_.ZoneName -match $ReverseZoneStub -and $_.IsReverseLookupZone -and -NOT($_.ZoneType -eq "Forwarder") } | select-object -expandproperty ZoneName)
			}
			Start-Sleep 2
			ForEach ( $ReverseZoneName in $ReverseZoneNames ) {
				# Now, determine the subnet mask of the reverse zone, so we can search for the reverse based on the correct number of octets
				$ReverseTrunc = $ReverseZoneName.Replace(".in-addr.arpa","")
				$OctetCount = $ReverseTrunc.Split(".").Count
				
				if ($OctetCount -eq 2 ) {
					$IPAddressFormatted = ($IPAddressArray[3] + "." + $IPAddressArray[2])
				} elseIf ( $OctetCount -eq 3 ) {
					$IPAddressFormatted = ($IPAddressArray[3])
				} else {
					# IP for zone is not /24 or /16 - skipping
					Write-Verbose "IP for zone is not /24 or /16 - skipping"
				}
				Write-Verbose "Check for $IPAddressFormatted pointer record(s) in $ReverseZoneName"
				$NodePTRRecord = Get-DnsServerResourceRecord -ZoneName $ReverseZoneName -ComputerName $DNSServer -Node $IPAddressFormatted -RRType Ptr -ErrorAction SilentlyContinue
				if($NodePTRRecord -eq $null){
					Write-Verbose "No PTR record found"
				} else {
					Remove-DnsServerResourceRecord -ZoneName $ReverseZoneName -ComputerName $DNSServer -InputObject $NodePTRRecord -Force
					Write-Host ("PTR record deleted: " + $IPAddressFormatted + " in " + $ReverseZoneName)
				}
			}
			Remove-DnsServerResourceRecord -ZoneName $ZoneName -ComputerName $DNSServer -InputObject $NodeARecord -Force
			Write-Host ("A record deleted: " + $NodeARecord.HostName)
		}
		
		Write-Verbose "Check for existing CNAME record(s) in $ZoneName"
		$CNAMERecord = Get-DnsServerResourceRecord -ZoneName $ZoneName -ComputerName $DNSServer -Node $Computer -RRType CName -ErrorAction SilentlyContinue
		if ( $CNAMERecord -ne $null ) {
			$CNAMERecord
			Remove-DnsServerResourceRecord -ZoneName $ZoneName -ComputerName $DNSServer -InputObject $NodeARecord -Force
			Write-Host ("CNAME record deleted: " + $CNAMERecord.HostName)
		}
	}
	end {
		Write-Verbose "Completed purging DNS entries."
	}
}  #END Function Remove-DNSEntryFromZone


# Find my currently connected DNS Server (Primary)
$DNSServer = Get-DnsClientServerAddress | select-object -expandproperty ServerAddresses | select -first 1

# Get a list of zones - we'll purge this computer from each of them.  No forward zone, and no reverse lookups (for now)
$ZoneNames = Get-DnsServerZone -ComputerName $DNSServer | ? { -NOT($_.IsReverseLookupZone) -and -NOT($_.ZoneType -eq "Forwarder") } | select-object -expandproperty ZoneName

ForEach ( $ZoneName in $ZoneNames ) {
	Remove-DNSEntryFromZone -Computer $Computer -DNSServer $DNSServer -ZoneName $ZoneName -Verbose:($PSBoundParameters['Verbose'] -eq $true)
}
