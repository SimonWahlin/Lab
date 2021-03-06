@{
    AllNodes = @(
        @{
            NodeName = '*';
            InterfaceAlias = 'Ethernet';
            DefaultGateway = '10.0.0.254';
            SubnetMask = 24;
            AddressFamily = 'IPv4';
            DnsServerAddress = '10.0.0.1';
            DomainName = 'corp.contoso.com';
            PSDscAllowPlainTextPassword = $true;
            #CertificateFile = "$env:AllUsersProfile\VirtualEngineLab\Certificates\LabClient.cer";
            #Thumbprint = '599E0BDA95ADED538154DC9FA6DE94920424BCB1';
            PSDscAllowDomainUser = $true; # Removes 'It is not recommended to use domain credential for node X' messages
            VirtualEngineLab_SwitchName = 'Corpnet';
            VirtualEngineLab_ProcessorCount = 1;
            VirtualEngineLab_Media = '2012R2_x64_Standard_EN_Eval';
        }
        @{
            NodeName = 'DC1';
            IPAddress = '10.0.0.1';
            DnsServerAddress = '127.0.0.1';
            Role = 'DC';
            VirtualEngineLab_ProcessorCount = 2;
        }
        @{
            NodeName = 'EDGE1';
            IPAddress = '10.0.0.2';
            SecondaryIPAddress = '131.107.0.2';
            SecondaryDnsServerAddress = '131.107.0.1';
            SecondaryInterfaceAlias = 'Ethernet 2';
            SecondarySubnetMask = 24;
            Role = 'EDGE';
            ## Windows sees the two NICs in reverse order, e.g. first switch is 'Ethernet 2' and second is 'Ethernet'!?
            VirtualEngineLab_SwitchName = 'Corpnet','Internet';
        }
        @{
            NodeName = 'APP1';
            IPAddress = '10.0.0.3';
            Role = 'APP';
        }
        @{
            NodeName = 'INET1';
            IPAddress = '131.107.0.1';
            DnsServerAddress = '127.0.0.1';
            DefaultGateway = '';
            Role = 'INET';
            VirtualEngineLab_SwitchName = 'Internet';
        }
        @{
            NodeName = 'CLIENT1';
            Role = 'CLIENT';
            VirtualEngineLab_Media = 'Win81_x64_Enterprise_EN_Eval';
            VirtualEngineLab_CustomBootStrap = @'
                ## Unattend.xml will set the Administrator password, but it won't enable the account on client OSes
                NET USER Administrator /active:yes;
                Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force;
                ## Kick-start PowerShell remoting on clients to permit applying DSC configurations
                Enable-PSRemoting -SkipNetworkProfileCheck -Force;
'@
        }
        @{
            NodeName = 'CLIENT2';
            Role = 'CLIENT';
            VirtualEngineLab_Media = 'Win10_x64_Enterprise_EN_Eval';
            VirtualEngineLab_CustomBootStrap = @'
                ## Unattend.xml will set the Administrator password, but it won't enable the account on client OSes
                NET USER Administrator /active:yes;
                Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force;
                ## Kick-start PowerShell remoting on clients to permit applying DSC configurations
                Enable-PSRemoting -SkipNetworkProfileCheck -Force;
'@
        }
    );
    NonNodeData = @{
        VirtualEngineLab = @{
            Media = @();
            Network = @(
                @{ Name = 'Corpnet'; Type = 'Internal'; }
                @{ Name = 'Internet'; Type = 'Internal'; }
                # @{ Name = 'Corpnet'; Type = 'External'; NetAdapterName = 'Ethernet'; AllowManagementOS = $true; }
                <# 
                    IPAddress: The desired IP address.
                    InterfaceAlias: Alias of the network interface for which the IP address should be set. <- Use NetAdapterName
                    DefaultGateway: Specifies the IP address of the default gateway for the host. <- Not needed for internal switch
                    SubnetMask: Local subnet size.
                    AddressFamily: IP address family: { IPv4 | IPv6 }
                #>
            );
        };
    };
};
