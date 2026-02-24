<#
.SYNOPSIS
    Core helper functions for Key Vault JSON secret update operations.

.DESCRIPTION
    Contains pure functions used by Update-KeyVaultSecret.ps1 so they can be
    unit tested independently from Azure CLI interactions.
#>

function ConvertTo-Hashtable {
    param (
        [Parameter(Mandatory = $true)]
        $InputObject
    )

    if ($InputObject -is [PSCustomObject]) {
        $hashtable = @{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $hashtable[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value
        }
        return $hashtable
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $hashtable = @{}
        foreach ($key in $InputObject.Keys) {
            $hashtable[$key] = ConvertTo-Hashtable -InputObject $InputObject[$key]
        }
        return $hashtable
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
        $arrayItems = @()
        foreach ($item in $InputObject) {
            $arrayItems += ConvertTo-Hashtable -InputObject $item
        }
        return $arrayItems
    }

    return $InputObject
}

function Set-NestedValue {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Object,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        $Value
    )

    $keys = $Path -split '\.'
    $current = $Object

    for ($i = 0; $i -lt $keys.Count - 1; $i++) {
        $key = $keys[$i]

        if (-not $current.ContainsKey($key)) {
            $current[$key] = @{}
        }
        elseif ($current[$key] -isnot [hashtable]) {
            $current[$key] = @{}
        }

        $current = $current[$key]
    }

    $finalKey = $keys[-1]
    $current[$finalKey] = $Value
}

function Get-NestedValue {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Object,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $keys = $Path -split '\.'
    $current = $Object

    foreach ($key in $keys) {
        if ($current -is [hashtable] -and $current.ContainsKey($key)) {
            $current = $current[$key]
        }
        else {
            return $null
        }
    }

    return $current
}

function Parse-JsonUpdates {
    param (
        [Parameter(Mandatory = $true)]
        [string]$UpdateString
    )

    function Split-UpdatePairs {
        param([string]$InputText)

        $pairs = @()
        $builder = New-Object System.Text.StringBuilder
        $inQuotes = $false

        for ($index = 0; $index -lt $InputText.Length; $index++) {
            $char = $InputText[$index]
            $escapedQuote = $char -eq '"' -and $index -gt 0 -and $InputText[$index - 1] -eq '\'

            if ($char -eq '"' -and -not $escapedQuote) {
                $inQuotes = -not $inQuotes
            }

            if ($char -eq ',' -and -not $inQuotes) {
                $pairs += $builder.ToString()
                [void]$builder.Clear()
                continue
            }

            [void]$builder.Append($char)
        }

        if ($inQuotes) {
            throw "Invalid JsonUpdates format: unmatched double quote."
        }

        if ($builder.Length -gt 0) {
            $pairs += $builder.ToString()
        }

        return $pairs
    }

    function Validate-UpdateKey {
        param([string]$Key)

        if ([string]::IsNullOrWhiteSpace($Key)) {
            throw "Invalid JsonUpdates format: key cannot be empty."
        }

        if ($Key.Contains(" ")) {
            throw "Invalid update key '$Key': key cannot contain spaces."
        }

        if ($Key.StartsWith(".") -or $Key.EndsWith(".") -or $Key.Contains("..")) {
            throw "Invalid update key '$Key': dot notation segments cannot be empty."
        }
    }

    $updates = @{}

    $pairs = Split-UpdatePairs -InputText $UpdateString

    foreach ($pair in $pairs) {
        $pair = $pair.Trim()
        if ([string]::IsNullOrWhiteSpace($pair)) { continue }

        $eqIndex = $pair.IndexOf('=')
        if ($eqIndex -le 0) {
            throw "Invalid JsonUpdates entry. Expected format is key=value."
        }

        $key = $pair.Substring(0, $eqIndex).Trim()
        $value = $pair.Substring($eqIndex + 1).Trim()

        Validate-UpdateKey -Key $key

        if ($updates.ContainsKey($key)) {
            throw "Duplicate update key '$key' in JsonUpdates."
        }

        if ($value.StartsWith('"') -and $value.EndsWith('"') -and $value.Length -ge 2) {
            $value = $value.Substring(1, $value.Length - 2)
            $value = $value.Replace('\"', '"').Replace('\\', '\')
        }

        $updates[$key] = $value
    }

    return $updates
}

function Get-MaskedValue {
    param (
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return "(null)"
    }

    $text = [string]$Value

    if ($text.Length -eq 0) {
        return "(empty)"
    }

    if ($text.Length -le 4) {
        return "****"
    }

    return "{0}****{1}" -f $text.Substring(0, 2), $text.Substring($text.Length - 2)
}

function Test-ValueChanged {
    param (
        [AllowNull()]
        $OldValue,
        [AllowNull()]
        $NewValue
    )

    if ($null -eq $OldValue -and $null -eq $NewValue) {
        return $false
    }

    if ($null -eq $OldValue -or $null -eq $NewValue) {
        return $true
    }

    return ([string]$OldValue) -cne ([string]$NewValue)
}

