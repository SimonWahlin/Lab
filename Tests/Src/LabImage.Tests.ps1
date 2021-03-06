#requires -RunAsAdministrator
#requires -Version 4

$moduleName = 'VirtualEngineLab';
if (!$PSScriptRoot) { # $PSScriptRoot is not defined in 2.0
    $PSScriptRoot = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
}
$repoRoot = (Resolve-Path "$PSScriptRoot\..\..").Path;

Import-Module (Join-Path -Path $RepoRoot -ChildPath "$moduleName.psm1") -Force;

Describe 'LabImage' {

    InModuleScope $moduleName {

        Context 'Validates "Get-LabImage" method' {
            
            It 'Returns all available parent images when no Id is specified' {
                $fakeConfigurationData = @{ ParentVhdPath = ResolvePathEx -Path 'TestDrive:\'; }
                $fakeDiskImage = [PSCustomObject] @{ Attached = $true; BaseName = 'x'; ImagePath = $ImagePath; LogicalSectorSize = 42; BlockSize = 42; Size = 42; }
                $testVMs = @('VM1','VM2','VM3');
                foreach ($vm in $testVMs) {
                    New-Item -Path "TestDrive:\$vm.vhdx" -ItemType File -Force -ErrorAction SilentlyContinue;
                }
                Mock GetConfigurationData -MockWith { return $fakeConfigurationData; }
                Mock Get-DiskImage -MockWith { return $fakeDiskImage; }

                $images = Get-LabImage;

                $images.Count | Should Be $testVMs.Count;
            }

            It 'Returns a single parent image when Id specified' {
                $fakeConfigurationData = @{ ParentVhdPath = ResolvePathEx -Path 'TestDrive:\'; }
                $fakeDiskImage = [PSCustomObject] @{ Attached = $true; BaseName = 'x'; ImagePath = $ImagePath; LogicalSectorSize = 42; BlockSize = 42; Size = 42; }
                $testVMs = @('VM1','VM2','VM3');
                foreach ($vm in $testVMs) {
                    New-Item -Path "TestDrive:\$vm.vhdx" -ItemType File -Force -ErrorAction SilentlyContinue;
                }

                Mock GetConfigurationData -MockWith { return $fakeConfigurationData; }
                Mock Get-DiskImage -MockWith { return $fakeDiskImage; }

                $image = Get-LabImage -Id ($testVMs[0]);

                $image | Should Not BeNullOrEmpty;
                $image.Count | Should BeNullOrEmpty;
            }

            It 'Returns null when there is no parent image when Id specified' {
                $fakeConfigurationData = @{ ParentVhdPath = ResolvePathEx -Path 'TestDrive:\'; }
                $fakeDiskImage = [PSCustomObject] @{ Attached = $true; BaseName = 'x'; ImagePath = $ImagePath; LogicalSectorSize = 42; BlockSize = 42; Size = 42; }
                $testVMs = @('VM1','VM2','VM3');
                foreach ($vm in $testVMs) {
                    New-Item -Path "TestDrive:\$vm.vhdx" -ItemType File -Force -ErrorAction SilentlyContinue;
                }
                Mock GetConfigurationData -MockWith { return $fakeConfigurationData; }
                Mock Get-DiskImage -MockWith { return $fakeDiskImage; }

                $image = Get-LabImage -Id 'NonExistentId';

                $image | Should BeNullOrEmpty;
            }

            It 'Returns null when there is are no parent images' {
                $fakeConfigurationData = @{ ParentVhdPath = ResolvePathEx -Path 'TestDrive:\EmptyPath'; }
                New-Item -Path 'TestDrive:\EmptyPath' -ItemType Directory -Force -ErrorAction SilentlyContinue;
                Mock GetConfigurationData -MockWith { return $fakeConfigurationData; }
                Mock Get-DiskImage -MockWith { }

                $images = Get-LabImage;

                $image | Should BeNullOrEmpty;
            }

        } #end context Validates "Get-LabImage" method

        Context 'Validates "Test-LabImage" method' {

            It 'Passes when parent image is found' {
                $testImageId = '42';
                Mock Get-LabImage -ParameterFilter { $Id -eq $testImageId } -MockWith { return $true; }

                Test-LabImage -Id $testImageId | Should Be $true;
            }

            It 'Fails when parent image is not found' {
                $testImageId = '42';
                Mock Get-LabImage -ParameterFilter { $Id -eq $testImageId } -MockWith { return $false; }

                Test-LabImage -Id $testImageId | Should Be $false;
            }

        } #end context 'Validates "Test-LabImage" method

        Context 'Validates "New-LabImage" method' {

            It 'Throws if image already exists' {
                $testImageId = '42';
                
                Mock Test-LabImage -MockWith { return $true; }

                { New-LabImage -Id $testImageId } | Should Throw;
            }

            It 'Deletes parent VHDX when image creation fails' {
                $testImageId = 'NewLabImage';
                $testParentImagePath = 'TestDrive:'
                $testImagePath = ResolvePathEx -Path "$testParentImagePath\$testImageId.vhdx";
                $testArchitecture = 'x64';
                $testWimImageName = 'Fake windows image';
                $fakeISOFileInfo = [PSCustomObject] @{ FullName = 'TestDrive:\TestIso.iso'; }
                $fakeMedia = [PSCustomObject] @{ Id = $testImageId; Description = 'Fake media'; Architecture = $testArchitecture; ImageName = $testWimImageName; }
                $fakeDiskImage = [PSCustomObject] @{ Attached = $true; BaseName = 'x'; ImagePath = $testImagePath; LogicalSectorSize = 42; BlockSize = 42; Size = 42; }
                $fakeVhdImage = [PSCustomObject] @{ Path = $testImagePath };
                $fakeConfigurationData = @{ ParentVhdPath = ResolvePathEx -Path $testParentImagePath; }
                New-Item -Path $testImagePath -ItemType File -Force -ErrorAction SilentlyContinue;
                Mock Test-LabImage -MockWith { return $false; }
                Mock Get-DiskImage -MockWith { return $fakeDiskImage; }
                Mock GetConfigurationData -MockWith { return $fakeConfigurationData; }
                Mock ResolveLabMedia -MockWith { return $fakeMedia; }
                Mock NewDiskImage -MockWith { Write-Error 'DOH!'; }
                Mock ExpandWindowsImage -MockWith { }
                Mock AddDiskImagePackage -MockWith { }
                Mock SetDiskImageBootVolume -MockWith { }
                Mock Dismount-VHD -MockWith { }
                Mock InvokeLabMediaImageDownload -MockWith { return $fakeISOFileInfo; }
            
                New-LabImage -Id $testImageId -ErrorAction SilentlyContinue -WarningAction SilentlyContinue;
            
                Test-Path -Path $testImagePath | Should Be $false;
            }

            It 'Deletes existing image if it already exists and -Force is specified' {
                $testImageId = 'NewLabImage';
                $testParentImagePath = 'TestDrive:'
                $testImagePath = ResolvePathEx -Path "$testParentImagePath\$testImageId.vhdx";
                $testArchitecture = 'x64';
                $testWimImageName = 'Fake windows image';
                $fakeISOFileInfo = [PSCustomObject] @{ FullName = 'TestDrive:\TestIso.iso'; }
                $fakeMedia = [PSCustomObject] @{ Id = $testImageId; Description = 'Fake media'; Architecture = $testArchitecture; ImageName = $testWimImageName; }
                $fakeDiskImage = [PSCustomObject] @{ Attached = $true; BaseName = 'x'; ImagePath = $testImagePath; LogicalSectorSize = 42; BlockSize = 42; Size = 42; }
                $fakeVhdImage = [PSCustomObject] @{ Path = $testImagePath };
                $fakeConfigurationData = @{ ParentVhdPath = ResolvePathEx -Path $testParentImagePath; }
                New-Item -Path $testImagePath -ItemType File -Force -ErrorAction SilentlyContinue;
                Mock Test-LabImage -MockWith { return $true; }
                Mock Get-DiskImage -MockWith { return $fakeDiskImage; }
                Mock GetConfigurationData -MockWith { return $fakeConfigurationData; }
                Mock ResolveLabMedia -MockWith { return $fakeMedia; }
                Mock NewDiskImage -MockWith { return $fakeVhdImage; }
                Mock ExpandWindowsImage -MockWith { }
                Mock AddDiskImagePackage -MockWith { }
                Mock SetDiskImageBootVolume -MockWith { }
                Mock Dismount-VHD -MockWith { }
                Mock InvokeLabMediaImageDownload -MockWith { return $fakeISOFileInfo; }
            
                New-LabImage -Id $testImageId -Force;
            
                Test-Path -Path $testImagePath | Should Be $false;
            }
           
            It 'Calls "InvokeLabMediaImageDownload" to download ISO media (if not present)' {
                $testImageId = 'NewLabImage';
                $testParentImagePath = 'TestDrive:'
                $testImagePath = ResolvePathEx -Path "$testParentImagePath\$testImageId.vhdx";
                $testArchitecture = 'x64';
                $testWimImageName = 'Fake windows image';
                $fakeISOFileInfo = [PSCustomObject] @{ FullName = 'TestDrive:\TestIso.iso'; }
                $fakeMedia = [PSCustomObject] @{ Id = $testImageId; Description = 'Fake media'; Architecture = $testArchitecture; ImageName = $testWimImageName; }
                $fakeDiskImage = [PSCustomObject] @{ Attached = $true; BaseName = 'x'; ImagePath = $testImagePath; LogicalSectorSize = 42; BlockSize = 42; Size = 42; }
                $fakeVhdImage = [PSCustomObject] @{ Path = $testImagePath };
                $fakeConfigurationData = @{ ParentVhdPath = ResolvePathEx -Path $testParentImagePath; }
                New-Item -Path $testImagePath -ItemType File -Force -ErrorAction SilentlyContinue;
                Mock Test-LabImage -MockWith { return $false; }
                Mock Get-DiskImage -MockWith { return $fakeDiskImage; }
                Mock GetConfigurationData -MockWith { return $fakeConfigurationData; }
                Mock ResolveLabMedia -MockWith { return $fakeMedia; }
                Mock NewDiskImage -MockWith { return $fakeVhdImage; }
                Mock ExpandWindowsImage -MockWith { }
                Mock AddDiskImagePackage -MockWith { }
                Mock SetDiskImageBootVolume -MockWith { }
                Mock Dismount-VHD -MockWith { }
                Mock InvokeLabMediaImageDownload -ParameterFilter { $Media.Id -eq $testImageId } -MockWith { return $fakeISOFileInfo; }

                New-LabImage -Id $testImageId

                Assert-MockCalled InvokeLabMediaImageDownload -ParameterFilter { $Media.Id -eq $testImageId } -Scope It;
            }

            It 'Calls "NewDiskImage" with -PassThru to leave VHDX mounted' {
                $testImageId = 'NewLabImage';
                $testParentImagePath = 'TestDrive:'
                $testImagePath = ResolvePathEx -Path "$testParentImagePath\$testImageId.vhdx";
                $testArchitecture = 'x64';
                $testWimImageName = 'Fake windows image';
                $fakeISOFileInfo = [PSCustomObject] @{ FullName = 'TestDrive:\TestIso.iso'; }
                $fakeMedia = [PSCustomObject] @{ Id = $testImageId; Description = 'Fake media'; Architecture = $testArchitecture; ImageName = $testWimImageName; }
                $fakeDiskImage = [PSCustomObject] @{ Attached = $true; BaseName = 'x'; ImagePath = $testImagePath; LogicalSectorSize = 42; BlockSize = 42; Size = 42; }
                $fakeVhdImage = [PSCustomObject] @{ Path = $testImagePath };
                $fakeConfigurationData = @{ ParentVhdPath = ResolvePathEx -Path $testParentImagePath; }
                $fakeConfigurationData = @{ ParentVhdPath = ResolvePathEx -Path $testImagePath; }
                New-Item -Path $testImagePath -ItemType File -Force -ErrorAction SilentlyContinue;
                Mock Test-LabImage -MockWith { return $false; }
                Mock Get-DiskImage -MockWith { return $fakeDiskImage; }
                Mock GetConfigurationData -MockWith { return $fakeConfigurationData; }
                Mock ResolveLabMedia -MockWith { return $fakeMedia; }
                Mock ExpandWindowsImage -MockWith { }
                Mock AddDiskImagePackage -MockWith { }
                Mock SetDiskImageBootVolume -MockWith { }
                Mock Dismount-VHD -MockWith { }
                Mock InvokeLabMediaImageDownload -MockWith { return $fakeISOFileInfo; }
                Mock NewDiskImage -ParameterFilter { $PassThru -eq $true } -MockWith { return $fakeVhdImage; }

                New-LabImage -Id $testImageId

                Assert-MockCalled NewDiskImage -ParameterFilter { $PassThru -eq $true } -Scope It;
            }

            It 'Uses "GPT" partition style for x64 media' {
                $testImageId = 'NewLabImage';
                $testParentImagePath = 'TestDrive:'
                $testImagePath = ResolvePathEx -Path "$testParentImagePath\$testImageId.vhdx";
                $testArchitecture = 'x64';
                $testWimImageName = 'Fake windows image';
                $fakeISOFileInfo = [PSCustomObject] @{ FullName = 'TestDrive:\TestIso.iso'; }
                $fakeMedia = [PSCustomObject] @{ Id = $testImageId; Description = 'Fake media'; Architecture = $testArchitecture; ImageName = $testWimImageName; }
                $fakeDiskImage = [PSCustomObject] @{ Attached = $true; BaseName = 'x'; ImagePath = $testImagePath; LogicalSectorSize = 42; BlockSize = 42; Size = 42; }
                $fakeVhdImage = [PSCustomObject] @{ Path = $testImagePath };
                $fakeConfigurationData = @{ ParentVhdPath = ResolvePathEx -Path $testParentImagePath; }
                New-Item -Path $testImagePath -ItemType File -Force -ErrorAction SilentlyContinue;
                Mock Test-LabImage -MockWith { return $false; }
                Mock Get-DiskImage -MockWith { return $fakeDiskImage; }
                Mock GetConfigurationData -MockWith { return $fakeConfigurationData; }
                Mock ResolveLabMedia -MockWith { return $fakeMedia; }
                Mock ExpandWindowsImage -MockWith { }
                Mock AddDiskImagePackage -MockWith { }
                Mock SetDiskImageBootVolume -MockWith { }
                Mock Dismount-VHD -MockWith { }
                Mock InvokeLabMediaImageDownload -MockWith { return $fakeISOFileInfo; }
                Mock NewDiskImage -ParameterFilter { $PartitionStyle -eq 'GPT' } -MockWith { return $fakeVhdImage; }

                New-LabImage -Id $testImageId

                Assert-MockCalled NewDiskImage -ParameterFilter { $PartitionStyle -eq 'GPT' } -Scope It;
            }

            It 'Uses "MBR" partition style for x86 media' {
                $testImageId = 'NewLabImage';
                $testParentImagePath = 'TestDrive:'
                $testImagePath = ResolvePathEx -Path "$testParentImagePath\$testImageId.vhdx";
                $testArchitecture = 'x86';
                $testWimImageName = 'Fake windows image';
                $fakeISOFileInfo = [PSCustomObject] @{ FullName = 'TestDrive:\TestIso.iso'; }
                $fakeMedia = [PSCustomObject] @{ Id = $testImageId; Description = 'Fake media'; Architecture = $testArchitecture; ImageName = $testWimImageName; }
                $fakeDiskImage = [PSCustomObject] @{ Attached = $true; BaseName = 'x'; ImagePath = $testImagePath; LogicalSectorSize = 42; BlockSize = 42; Size = 42; }
                $fakeVhdImage = [PSCustomObject] @{ Path = $testImagePath };
                $fakeConfigurationData = @{ ParentVhdPath = ResolvePathEx -Path $testParentImagePath; }
                New-Item -Path $testImagePath -ItemType File -Force -ErrorAction SilentlyContinue;
                Mock Test-LabImage -MockWith { return $false; }
                Mock Get-DiskImage -MockWith { return $fakeDiskImage; }
                Mock GetConfigurationData -MockWith { return $fakeConfigurationData; }
                Mock ResolveLabMedia -MockWith { return $fakeMedia; }
                Mock ExpandWindowsImage -MockWith { }
                Mock AddDiskImagePackage -MockWith { }
                Mock SetDiskImageBootVolume -MockWith { }
                Mock Dismount-VHD -MockWith { }
                Mock InvokeLabMediaImageDownload -MockWith { return $fakeISOFileInfo; }
                Mock NewDiskImage -ParameterFilter { $PartitionStyle -eq 'MBR' } -MockWith { return $fakeVhdImage; }

                New-LabImage -Id $testImageId

                Assert-MockCalled NewDiskImage -ParameterFilter { $PartitionStyle -eq 'MBR' } -Scope It;
            }

            It 'Calls "ExpandWindowsImage" with the media WIM image name' {
                $testImageId = 'NewLabImage';
                $testParentImagePath = 'TestDrive:'
                $testImagePath = ResolvePathEx -Path "$testParentImagePath\$testImageId.vhdx";
                $testArchitecture = 'x64';
                $testWimImageName = 'Fake windows image';
                $fakeISOFileInfo = [PSCustomObject] @{ FullName = 'TestDrive:\TestIso.iso'; }
                $fakeMedia = [PSCustomObject] @{ Id = $testImageId; Description = 'Fake media'; Architecture = $testArchitecture; ImageName = $testWimImageName; }
                $fakeDiskImage = [PSCustomObject] @{ Attached = $true; BaseName = 'x'; ImagePath = $testImagePath; LogicalSectorSize = 42; BlockSize = 42; Size = 42; }
                $fakeVhdImage = [PSCustomObject] @{ Path = $testImagePath };
                $fakeConfigurationData = @{ ParentVhdPath = ResolvePathEx -Path $testParentImagePath; }
                New-Item -Path $testImagePath -ItemType File -Force -ErrorAction SilentlyContinue;
                Mock Test-LabImage -MockWith { return $false; }
                Mock Get-DiskImage -MockWith { return $fakeDiskImage; }
                Mock GetConfigurationData -MockWith { return $fakeConfigurationData; }
                Mock ResolveLabMedia -MockWith { return $fakeMedia; }
                Mock AddDiskImagePackage -MockWith { }
                Mock SetDiskImageBootVolume -MockWith { }
                Mock Dismount-VHD -MockWith { }
                Mock InvokeLabMediaImageDownload -MockWith { return $fakeISOFileInfo; }
                Mock NewDiskImage -MockWith { return $fakeVhdImage; }
                Mock ExpandWindowsImage -ParameterFilter { $WimImageName -eq $testWimImageName } -MockWith { }

                New-LabImage -Id $testImageId

                Assert-MockCalled ExpandWindowsImage -ParameterFilter { $WimImageName -eq $testWimImageName } -Scope It;
            }

            It 'Calls "AddDiskImagePackage" to inject hotfixes' {
                $testImageId = 'NewLabImage';
                $testParentImagePath = 'TestDrive:'
                $testImagePath = ResolvePathEx -Path "$testParentImagePath\$testImageId.vhdx";
                $testArchitecture = 'x64';
                $testWimImageName = 'Fake windows image';
                $fakeISOFileInfo = [PSCustomObject] @{ FullName = 'TestDrive:\TestIso.iso'; }
                $fakeMedia = [PSCustomObject] @{ Id = $testImageId; Description = 'Fake media'; Architecture = $testArchitecture; ImageName = $testWimImageName; }
                $fakeDiskImage = [PSCustomObject] @{ Attached = $true; BaseName = 'x'; ImagePath = $testImagePath; LogicalSectorSize = 42; BlockSize = 42; Size = 42; }
                $fakeVhdImage = [PSCustomObject] @{ Path = $testImagePath };
                $fakeConfigurationData = @{ ParentVhdPath = ResolvePathEx -Path $testParentImagePath; }
                New-Item -Path $testImagePath -ItemType File -Force -ErrorAction SilentlyContinue;
                Mock Test-LabImage -MockWith { return $false; }
                Mock Get-DiskImage -MockWith { return $fakeDiskImage; }
                Mock GetConfigurationData -MockWith { return $fakeConfigurationData; }
                Mock ResolveLabMedia -MockWith { return $fakeMedia; }
                Mock SetDiskImageBootVolume -MockWith { }
                Mock Dismount-VHD -MockWith { }
                Mock InvokeLabMediaImageDownload -MockWith { return $fakeISOFileInfo; }
                Mock NewDiskImage -MockWith { return $fakeVhdImage; }
                Mock ExpandWindowsImage -MockWith { }
                Mock AddDiskImagePackage -ParameterFilter { $Id -eq $testImageId } -MockWith { }

                New-LabImage -Id $testImageId

                Assert-MockCalled AddDiskImagePackage -ParameterFilter { $Id -eq $testImageId } -Scope It;
            }

            It 'Calls "SetDiskImageBootVolume" to configure boot volume' {
                $testImageId = 'NewLabImage';
                $testParentImagePath = 'TestDrive:'
                $testImagePath = ResolvePathEx -Path "$testParentImagePath\$testImageId.vhdx";
                $testArchitecture = 'x64';
                $testWimImageName = 'Fake windows image';
                $fakeISOFileInfo = [PSCustomObject] @{ FullName = 'TestDrive:\TestIso.iso'; }
                $fakeMedia = [PSCustomObject] @{ Id = $testImageId; Description = 'Fake media'; Architecture = $testArchitecture; ImageName = $testWimImageName; }
                $fakeDiskImage = [PSCustomObject] @{ Attached = $true; BaseName = 'x'; ImagePath = $testImagePath; LogicalSectorSize = 42; BlockSize = 42; Size = 42; }
                $fakeVhdImage = [PSCustomObject] @{ Path = $testImagePath };
                $fakeConfigurationData = @{ ParentVhdPath = ResolvePathEx -Path $testParentImagePath; }
                New-Item -Path $testImagePath -ItemType File -Force -ErrorAction SilentlyContinue;
                Mock Test-LabImage -MockWith { return $false; }
                Mock Get-DiskImage -MockWith { return $fakeDiskImage; }
                Mock GetConfigurationData -MockWith { return $fakeConfigurationData; }
                Mock ResolveLabMedia -MockWith { return $fakeMedia; }
                Mock Dismount-VHD -MockWith { }
                Mock InvokeLabMediaImageDownload -MockWith { return $fakeISOFileInfo; }
                Mock NewDiskImage -MockWith { return $fakeVhdImage; }
                Mock ExpandWindowsImage -MockWith { }
                Mock AddDiskImagePackage -MockWith { }
                Mock SetDiskImageBootVolume -MockWith { }

                New-LabImage -Id $testImageId

                Assert-MockCalled SetDiskImageBootVolume -Scope It;
            }

            It 'Dismounts image' {
                $testImageId = 'NewLabImage';
                $testParentImagePath = 'TestDrive:'
                $testImagePath = ResolvePathEx -Path "$testParentImagePath\$testImageId.vhdx";
                $testArchitecture = 'x64';
                $testWimImageName = 'Fake windows image';
                $fakeISOFileInfo = [PSCustomObject] @{ FullName = 'TestDrive:\TestIso.iso'; }
                $fakeMedia = [PSCustomObject] @{ Id = $testImageId; Description = 'Fake media'; Architecture = $testArchitecture; ImageName = $testWimImageName; }
                $fakeDiskImage = [PSCustomObject] @{ Attached = $true; BaseName = 'x'; ImagePath = $testImagePath; LogicalSectorSize = 42; BlockSize = 42; Size = 42; }
                $fakeVhdImage = [PSCustomObject] @{ Path = $testImagePath };
                $fakeConfigurationData = @{ ParentVhdPath = ResolvePathEx -Path $testParentImagePath; }
                New-Item -Path $testImagePath -ItemType File -Force -ErrorAction SilentlyContinue;
                Mock Test-LabImage -MockWith { return $false; }
                Mock Get-DiskImage -MockWith { return $fakeDiskImage; }
                Mock GetConfigurationData -MockWith { return $fakeConfigurationData; }
                Mock ResolveLabMedia -MockWith { return $fakeMedia; }
                Mock InvokeLabMediaImageDownload -MockWith { return $fakeISOFileInfo; }
                Mock NewDiskImage -MockWith { return $fakeVhdImage; }
                Mock ExpandWindowsImage -MockWith { }
                Mock AddDiskImagePackage -MockWith { }
                Mock SetDiskImageBootVolume -MockWith { }
                Mock Dismount-VHD -ParameterFilter { $Path -eq $testImagePath } -MockWith { }

                New-LabImage -Id $testImageId

                Assert-MockCalled Dismount-VHD -ParameterFilter { $Path -eq $testImagePath } -Scope It;
            }
            
        } #end context Validates "New-LabImage" method

    } #end InModuleScope

} #end describe LabImage
