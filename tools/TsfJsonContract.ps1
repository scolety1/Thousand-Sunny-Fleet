function Test-TsfContractProperty {
    param([AllowNull()][object]$Object, [Parameter(Mandatory)][string]$Name)
    return $null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name
}

function ConvertTo-TsfContractArray {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [array]) { return @($Value) }
    return @($Value)
}

function Get-TsfContractJsonHash {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Value)
    # -InputObject preserves an empty array as [] instead of allowing the
    # pipeline to enumerate it into no output (and therefore a null hash).
    $json = ConvertTo-Json -InputObject $Value -Depth 100 -Compress
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Get-TsfTextHash {
    param([Parameter(Mandatory)][string]$Text)
    return Get-TsfContractJsonHash -Value ([pscustomobject]@{ text = $Text })
}

function Test-TsfJsonType {
    param([AllowNull()][object]$Value, [Parameter(Mandatory)][string]$Type)
    switch ($Type) {
        'null' { return $null -eq $Value }
        'object' { return $null -ne $Value -and $Value -isnot [string] -and $Value -isnot [array] -and @($Value.PSObject.Properties).Count -ge 0 }
        'array' { return $Value -is [array] }
        'string' { return $Value -is [string] }
        'boolean' { return $Value -is [bool] }
        'integer' { return $Value -is [byte] -or $Value -is [int16] -or $Value -is [int32] -or $Value -is [int64] }
        'number' { return $Value -is [byte] -or $Value -is [int16] -or $Value -is [int32] -or $Value -is [int64] -or $Value -is [single] -or $Value -is [double] -or $Value -is [decimal] }
    }
    return $false
}

function Resolve-TsfSchemaRef {
    param([Parameter(Mandatory)][object]$Root, [Parameter(Mandatory)][string]$Reference)
    if ($Reference -notmatch '^#/(.+)$') { throw "Only local JSON Schema references are supported: $Reference" }
    $node = $Root
    foreach ($segment in ($Matches[1] -split '/')) {
        $name = $segment.Replace('~1', '/').Replace('~0', '~')
        if (!(Test-TsfContractProperty $node $name)) { throw "Unresolved JSON Schema reference: $Reference" }
        $node = $node.$name
    }
    return $node
}

function Test-TsfSchemaNode {
    param(
        [AllowNull()][object]$Value,
        [Parameter(Mandatory)][object]$Schema,
        [Parameter(Mandatory)][object]$Root,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[string]]$Errors
    )

    if (Test-TsfContractProperty $Schema '$ref') {
        Test-TsfSchemaNode $Value (Resolve-TsfSchemaRef $Root ([string]$Schema.'$ref')) $Root $Path $Errors
        return
    }

    if (Test-TsfContractProperty $Schema 'anyOf') {
        $matched = $false
        foreach ($candidate in @(ConvertTo-TsfContractArray $Schema.anyOf)) {
            $candidateErrors = [Collections.Generic.List[string]]::new()
            Test-TsfSchemaNode $Value $candidate $Root $Path $candidateErrors
            if ($candidateErrors.Count -eq 0) { $matched = $true; break }
        }
        if (!$matched) { $Errors.Add("$Path does not satisfy anyOf.") | Out-Null; return }
    }

    if (Test-TsfContractProperty $Schema 'allOf') {
        foreach ($candidate in @(ConvertTo-TsfContractArray $Schema.allOf)) {
            Test-TsfSchemaNode $Value $candidate $Root $Path $Errors
        }
    }

    if (Test-TsfContractProperty $Schema 'const') {
        $actual = $Value | ConvertTo-Json -Compress -Depth 30
        $expected = $Schema.const | ConvertTo-Json -Compress -Depth 30
        if ($actual -cne $expected) { $Errors.Add("$Path must equal schema const.") | Out-Null; return }
    }

    if (Test-TsfContractProperty $Schema 'enum') {
        $actual = $Value | ConvertTo-Json -Compress -Depth 30
        $match = @($Schema.enum | Where-Object { ($_ | ConvertTo-Json -Compress -Depth 30) -ceq $actual }).Count -gt 0
        if (!$match) { $Errors.Add("$Path is not an allowed enum value.") | Out-Null; return }
    }

    if (Test-TsfContractProperty $Schema 'type') {
        $types = @(ConvertTo-TsfContractArray $Schema.type)
        if (@($types | Where-Object { Test-TsfJsonType $Value ([string]$_) }).Count -eq 0) {
            $Errors.Add("$Path has the wrong type; expected $($types -join '|').") | Out-Null
            return
        }
    }

    if ($null -eq $Value) { return }

    if ($Value -is [string]) {
        if ((Test-TsfContractProperty $Schema 'minLength') -and $Value.Length -lt [int]$Schema.minLength) { $Errors.Add("$Path is shorter than minLength.") | Out-Null }
        if ((Test-TsfContractProperty $Schema 'maxLength') -and $Value.Length -gt [int]$Schema.maxLength) { $Errors.Add("$Path is longer than maxLength.") | Out-Null }
        if ((Test-TsfContractProperty $Schema 'pattern') -and $Value -cnotmatch [string]$Schema.pattern) { $Errors.Add("$Path does not match the required pattern.") | Out-Null }
        if ((Test-TsfContractProperty $Schema 'format') -and [string]$Schema.format -eq 'date-time') {
            $dt = [datetimeoffset]::MinValue
            if (![datetimeoffset]::TryParse($Value, [ref]$dt)) { $Errors.Add("$Path is not a date-time.") | Out-Null }
        }
    }

    if (Test-TsfJsonType $Value 'number') {
        if ((Test-TsfContractProperty $Schema 'minimum') -and $Value -lt $Schema.minimum) { $Errors.Add("$Path is below minimum.") | Out-Null }
        if ((Test-TsfContractProperty $Schema 'maximum') -and $Value -gt $Schema.maximum) { $Errors.Add("$Path is above maximum.") | Out-Null }
    }

    if ($Value -is [array]) {
        if ((Test-TsfContractProperty $Schema 'minItems') -and $Value.Count -lt [int]$Schema.minItems) { $Errors.Add("$Path has fewer than minItems.") | Out-Null }
        if ((Test-TsfContractProperty $Schema 'maxItems') -and $Value.Count -gt [int]$Schema.maxItems) { $Errors.Add("$Path has more than maxItems.") | Out-Null }
        if ((Test-TsfContractProperty $Schema 'uniqueItems') -and [bool]$Schema.uniqueItems) {
            $items = @($Value | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 30 })
            $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            foreach ($item in $items) { if (!$seen.Add([string]$item)) { $Errors.Add("$Path contains duplicate items.") | Out-Null; break } }
        }
        if (Test-TsfContractProperty $Schema 'items') {
            for ($i = 0; $i -lt $Value.Count; $i++) { Test-TsfSchemaNode $Value[$i] $Schema.items $Root "$Path[$i]" $Errors }
        }
    }

    if (Test-TsfJsonType $Value 'object') {
        if (Test-TsfContractProperty $Schema 'required') {
            foreach ($required in @(ConvertTo-TsfContractArray $Schema.required)) {
                if (!(Test-TsfContractProperty $Value ([string]$required))) { $Errors.Add("$Path.$required is required.") | Out-Null }
            }
        }
        if (Test-TsfContractProperty $Schema 'properties') {
            $allowed = @($Schema.properties.PSObject.Properties.Name)
            if ((Test-TsfContractProperty $Schema 'additionalProperties') -and $Schema.additionalProperties -eq $false) {
                foreach ($name in @($Value.PSObject.Properties.Name)) { if ($allowed -notcontains $name) { $Errors.Add("$Path.$name is an additional property.") | Out-Null } }
            }
            foreach ($property in $Schema.properties.PSObject.Properties) {
                if (Test-TsfContractProperty $Value $property.Name) { Test-TsfSchemaNode $Value.($property.Name) $property.Value $Root "$Path.$($property.Name)" $Errors }
            }
        }
    }
}

function Test-TsfJsonContract {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Value, [Parameter(Mandatory)][string]$SchemaPath)
    $schema = Get-Content -LiteralPath $SchemaPath -Raw | ConvertFrom-Json
    $errors = [Collections.Generic.List[string]]::new()
    Test-TsfSchemaNode $Value $schema $schema '$' $errors
    return [pscustomobject]@{
        valid = $errors.Count -eq 0
        errors = @($errors)
        coverage = 'required,type,nested,array,enum,const,min/max,pattern,additionalProperties,nullability,uniqueItems,date-time,local-$ref,anyOf,allOf'
    }
}
