BeforeAll {
    $coreScript = Join-Path $PSScriptRoot ".." "scripts" "KeyVaultSecretUpdate.Core.ps1"
    . $coreScript
}

Describe "Parse-JsonUpdates" {
    It "parses simple key-value updates" {
        $result = Parse-JsonUpdates -UpdateString "apiKey=abc,environment=dev"
        $result.Count | Should -Be 2
        $result["apiKey"] | Should -Be "abc"
        $result["environment"] | Should -Be "dev"
    }

    It "handles quoted values containing commas" {
        $result = Parse-JsonUpdates -UpdateString "message=""hello,world"",env=prod"
        $result["message"] | Should -Be "hello,world"
        $result["env"] | Should -Be "prod"
    }

    It "handles values containing equals signs" {
        $result = Parse-JsonUpdates -UpdateString "connection=Server=a;Database=b"
        $result["connection"] | Should -Be "Server=a;Database=b"
    }

    It "throws on duplicate keys" {
        { Parse-JsonUpdates -UpdateString "apiKey=old,apiKey=new" } | Should -Throw
    }

    It "throws on malformed entries" {
        { Parse-JsonUpdates -UpdateString "apiKey=ok,broken-entry" } | Should -Throw
    }

    It "throws on unmatched quotes" {
        { Parse-JsonUpdates -UpdateString "apiKey=""unterminated,env=dev" } | Should -Throw
    }

    It "throws on invalid nested key syntax" {
        { Parse-JsonUpdates -UpdateString ".bad=value" } | Should -Throw
        { Parse-JsonUpdates -UpdateString "bad..path=value" } | Should -Throw
    }
}

Describe "Test-ValueChanged" {
    It "returns false when both values are null" {
        (Test-ValueChanged -OldValue $null -NewValue $null) | Should -BeFalse
    }

    It "returns true when exactly one value is null" {
        (Test-ValueChanged -OldValue "value" -NewValue $null) | Should -BeTrue
        (Test-ValueChanged -OldValue $null -NewValue "value" ) | Should -BeTrue
    }

    It "returns false when string representations are equal" {
        (Test-ValueChanged -OldValue "abc" -NewValue "abc") | Should -BeFalse
    }

    It "is case-sensitive by design" {
        (Test-ValueChanged -OldValue "Value" -NewValue "value") | Should -BeTrue
    }
}

