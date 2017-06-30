Function Get-WmiDNSZone  {
	PARAM (
		[Parameter()]
		[string]
		$Computername = $ENV:COMPUTERNAME,
		
		[Parameter()]
		[string[]]
		$ZoneName,
		
		$Credential
	)
	
	BEGIN {
		# https://learn-powershell.net/2013/08/03/quick-hits-set-the-default-property-display-in-powershell-on-custom-objects/
		# http://blogs.microsoft.co.il/scriptfanatic/2012/04/13/custom-objects-default-display-in-powershell-30/
		$defaultDisplaySet = 'ZoneName','ZoneType','IsAutoCreated','IsDsIntegrated','IsReverseLookupZone','IsSigned'
		$defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet',[string[]]$defaultDisplaySet)
		$PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
	}
	
	PROCESS {
		$param = @{}
		ForEach ($Parameter in $PSBoundParameters.Keys) {
			if ( $Parameter -eq "ZoneName" ) {continue}
			$param.Add($Parameter,$PSBoundParameters.Item($Parameter))
		}
		
		$ScriptBlock = [scriptblock]::Create("Get-WmiObject -Namespace root\MicrosoftDNS -Class MicrosoftDNS_Zone")
		$param.Add("ScriptBlock",$ScriptBlock)
	
		$ZoneInfo = Invoke-Command @param
		
		if ( $PSBoundParameters.ContainsKey("ZoneName") ) {
			$ZoneInfo = $ZoneInfo | Where-Object {$ZoneName -contains $_.Name}
		}
		
		switch($ZoneInfo.ZoneType) {
			1 {$ZoneType = "Primary"}
			2 {$ZoneType = "Secondary"}
			default {$ZoneType = "Unknown"}
		}
		
		switch($zoneInfo.Notify) {
			2 {$Notify = "Notify"}
			default {$Notify = "Unknown"}
		}
		
		switch ($ZoneInfo.SecureSecondaries) {
			3 { $SecureSecondaries = "TransferToSecureServers"}
			default {$SecureSecondaries = "Unknown"}
		}
		$OutputObject = [PSCustomObject] @{
			NotifyServers						=	$ZoneInfo.NotifyServers
			SecondaryServers					=	$ZoneInfo.SecondaryServers
			AllowedDcForNsRecordsAutoCreation	=	""
			DistinguishedName					=	""	#Cim path
			IsAutoCreated						=	$ZoneInfo.AutoCreated
			IsDsIntegrated						=	$ZoneInfo.DsIntegrated
			IsPaused							=	$ZoneInfo.Paused
			IsReadOnly							=	""
			IsReverseLookupZone					=	$ZoneInfo.Reverse
			IsShutdown							=	$ZoneInfo.Shutdown
			ZoneName							=	$ZoneInfo.Name
			ZoneType							=	$ZoneType
			DirectoryPartitionName				=	""
			DynamicUpdate						=	""
			IsPluginEnabled						=	""
			IsSigned							=	""
			IsWinsEnabled						=	$ZoneInfo.UseWins
			Notify								=	$Notify
			ReplicationScope					=	""
			SecureSecondaries					=	$SecureSecondaries
			ZoneFile							=	$ZoneInfo.DataFile
			PSComputerName						= 	$Computername
		}
		
		$OutputObject.PSObject.TypeNames.Insert(0,"DNS.Information")
		$OutputObject | Add-Member MemberSet PSStandardMembers $PSStandardMembers
		$OutputObject
	}
}


Function Get-WmiDNSResourceRecordSet  {
	PARAM (
		[Parameter()]
		[string]
		$Computername = $ENV:COMPUTERNAME,
		
		[Parameter(Mandatory=$False)]
		[string]
		$ZoneName,
		
		[Parameter(Mandatory=$True)]
		[string]
		[Alias("RRType","Type")]
		[ValidateSet("MG","X25","AFSDB","PTR","KEY","SRV","MD","MB","AAAA","ISDN","MINFO","RP","SIG","MF","A","WKS","WINSR","SOA","MX","WINS","ATMA","NS","NXT","RT","CNAME","TXT","HINFO","MR")]
		$RecordType,
		
		$Credential
	)
	
	BEGIN {
		# https://learn-powershell.net/2013/08/03/quick-hits-set-the-default-property-display-in-powershell-on-custom-objects/
		# http://blogs.microsoft.co.il/scriptfanatic/2012/04/13/custom-objects-default-display-in-powershell-30/
		$defaultDisplaySet = 'HostName','RecordType','Timestamp','TimeToLive','RecordData'
		$defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet',[string[]]$defaultDisplaySet)
		$PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
	}
	
	PROCESS {
		$WmiQuery = "Get-WmiObject -Namespace root\MicrosoftDNS -Class MicrosoftDNS_{0}Type" -f $RecordType
		if ( $PSBoundParameters.ContainsKey("ZoneName") ) {
			$WmiQuery = '{0} -Filter "ContainerName = {2}{1}{2}"' -f $WmiQuery, $ZoneName, "'"
		}
		
		$ScriptBlock = [scriptBlock]::Create($WmiQuery)
		$param = @{}
		ForEach ($Parameter in $PSBoundParameters.Keys) {
			if ( $Parameter -eq "ZoneName" -or $Parameter -eq "RecordType") {continue}
			$param.Add($Parameter,$PSBoundParameters.Item($Parameter))
		}
		$param.Add("ScriptBlock",$ScriptBlock)
		
		$ResourceRecordSet = Invoke-Command @param
		
		ForEach ($ResourceRecord in $ResourceRecordSet) {
			# https://msdn.microsoft.com/en-us/library/windows/desktop/ms682713(v=vs.85).aspx
			switch ($ResourceRecord.RecordClass) {
				1 {$RecordClass = "IN"}
				2 {$RecordClass = "CS"}
				3 {$RecordClass = "CH"}
				4 {$RecordClass = "HS"}
				default {$RecordClass = "IN"}
			}
			$OutputObject = [PSCustomObject] @{
				DistinguishedName	=	""
				HostName			=	$ResourceRecord.OwnerName.Split(".")[0]
				RecordClass			=	$RecordClass
				RecordData			=	$ResourceRecord.RecordData
				RecordType			=	$RecordType
				Timestamp			=	$ResourceRecord.TimeStamp
				TimeToLive			=	$ResourceRecord.TTL
				PSComputerName		=	$Computername
			}
		
			$OutputObject.PSObject.TypeNames.Insert(0,"DNS.Information")
			$OutputObject | Add-Member MemberSet PSStandardMembers $PSStandardMembers
			$OutputObject
			
		}
	}
}
