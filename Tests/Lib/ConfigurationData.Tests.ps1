#requires -RunAsAdministrator
#requires -Version 4

$moduleName = 'VirtualEngineLab';
if (!$PSScriptRoot) { # $PSScriptRoot is not defined in 2.0
    $PSScriptRoot = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
}
$repoRoot = (Resolve-Path "$PSScriptRoot\..\..").Path;

Import-Module (Join-Path -Path $RepoRoot -ChildPath "$moduleName.psm1") -Force;

Describe 'ConfigurationData' {
    
    InModuleScope $moduleName {

        Context 'Validates "GetConfigurationDataFromFilePath" method' {
            
            It 'Returns a "System.Collections.Hashtable" type' {
                $configurationDataPath = "TestDrive:\GetConfigurationDataFromFilePath.psd1";
                Set-Content -Path $configurationDataPath -Value '@{ Node = "Test"; }';
                $configurationData = GetConfigurationDataFromFilePath -ConfigurationData $configurationDataPath;
                $configurationData -is [System.Collections.Hashtable] | Should Be $true;
            }

            It 'Throws when passed a .psd1 file with invalid contents' {
                $configurationDataPath = "TestDrive:\GetConfigurationDataFromFilePath.psd1";
                Set-Content -Path $configurationDataPath -Value '@{ Node = Get-Date; }';
                { GetConfigurationDataFromFilePath -ConfigurationData $configurationDataPath } | Should Throw;
            }

        } #end context Validates "GetConfigurationDataFromFilePath" method

        Context 'Validates "ConvertToConfigurationData" method' {
            
            It 'Returns a "System.Collections.Hashtable" type' {
                $configurationData = ConvertToConfigurationData -ConfigurationData @{};
                $configurationData -is [System.Collections.Hashtable] | Should Be $true;
            }

            It 'Returns a "System.Collections.Hashtable" type from a file path' {
                $configurationDataPath = "TestDrive:\ConvertToConfigurationData.psd1";
                Set-Content -Path $configurationDataPath -Value '@{ Node = "Test"; }';
                $configurationData = ConvertToConfigurationData -ConfigurationData $configurationDataPath;
                $configurationData -is [System.Collections.Hashtable] | Should Be $true;
            }

            It 'Throws when passed a directory path' {
                { ConvertToConfigurationData -ConfigurationData TestDrive:\ } | Should Throw;
            }

            It 'Throws when passed a file path with an extension other than ".psd1"' {
                $testPath = "TestDrive:\ConfigurationData.ps1";
                New-Item -Path $testPath;
                { ConvertToConfigurationData -ConfigurationData $testPath } | Should Throw;
            }

            It 'Throws when passed a non-string or non-hashtable' {
                { ConvertToConfigurationData -ConfigurationData (Get-Date) } | Should Throw;
            }

        } #end context Validates "ConvertToConfigurationData" method

        Context 'Validates "ResolveConfigurationDataPath" method' {

            foreach ($config in @('Host','VM','Media')) {
                
                It "Resolves '$config' to module path when custom configuration does not exist" {
                    Mock Test-Path -MockWith { return $false }
                    $configurationPath = ResolveConfigurationDataPath -Configuration $config -IncludeDefaultPath;
                    $configurationPath -match $repoRoot | Should Be $true;
                }

                It "Resolves '$config' to %ALLUSERSPROFILE% path when custom configuration does exist" {
                    Mock Test-Path -MockWith { return $true }
                    $configurationPath = ResolveConfigurationDataPath -Configuration $config;
                    $allUsersProfile = ("$env:AllUsersProfile\$moduleName").Replace('\','\\');
                    $configurationPath -match $allUsersProfile | Should Be $true;
                }

            } #end foreach $config

        } #end context Validates "ResolveConfigurationDataPath" method

        Context 'Validates "GetConfigurationData" method' {

            It 'Resolves environment variables in path' {
                $testConfigurationFilename = 'TestConfiguration.json';
                $fakeConfiguration = '{ "ConfigurationPath": "%SYSTEMDRIVE%\\TestLab\\Configurations" }';
                Mock ResolveConfigurationDataPath -MockWith { return ('%SYSTEMROOT%\{0}' -f $testConfigurationFilename); }
                Mock Get-Content -ParameterFilter { $Path -eq "$env:SystemRoot\$testConfigurationFilename" } -MockWith { return $fakeConfiguration; }

                GetConfigurationData -Configuration Host;

                Assert-MockCalled Get-Content -ParameterFilter { $Path -eq "$env:SystemRoot\$testConfigurationFilename" } -Scope It;
            }

        } #end context Validates "GetConfigurationData" method

        Context 'Validates "SetConfigurationData" method' {

            It 'Resolves environment variables in path' {
                $testConfigurationFilename = 'TestConfiguration.json';
                $fakeConfiguration = '{ "ConfigurationPath": "%SYSTEMDRIVE%\\TestLab\\Configurations" }' | ConvertFrom-Json;
                Mock ResolveConfigurationDataPath -MockWith { return ('%SYSTEMROOT%\{0}' -f $testConfigurationFilename); }
                Mock NewDirectory -MockWith { }
                Mock Set-Content -ParameterFilter { $Path -eq "$env:SystemRoot\$testConfigurationFilename" } -MockWith { return $fakeConfiguration; }

                SetConfigurationData -Configuration Host -InputObject $fakeConfiguration;

                Assert-MockCalled Set-Content -ParameterFilter { $Path -eq "$env:SystemRoot\$testConfigurationFilename" } -Scope It;
            }

        } #end context Validates "GetConfigurationData" method

    } #end InModuleScope

} #end describe Bootstrap
