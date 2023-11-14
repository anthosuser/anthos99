FROM mcr.microsoft.com/windows/servercore:ltsc2019
# Install NuGet CLI

ENV NUGET_VERSION 5.5.1
RUN mkdir "%ProgramFiles%\NuGet" `
    && curl -fSLo "%ProgramFiles%\NuGet\nuget.exe" https://dist.nuget.org/win-x86-commandline/v%NUGET_VERSION%/nuget.exe
    
#Installing Cygwin##
RUN powershell Write-Host "Install Cygwin..."
RUN powershell Invoke-WebRequest https://cygwin.com/setup-x86_64.exe -OutFile C:\setup-x86_64.exe -UseBasicParsing;
RUN powershell Start-Process C:\setup-x86_64.exe -Wait -NoNewWindow -ArgumentList '-q -n -l C:\cygwin64\packages -X -s http://ctm.crouchingtigerhiddenfruitbat.org/pub/cygwin/circa/64bit/2020/05/31/142136/ -R C:\cygwin64 -P dos2unix,make,perl,python27,python38,rsync,libxml2,pbzip2,mc';
RUN powershell Remove-Item C:\setup-x86_64.exe;
     
#Path Setup Cygwin##
RUN powershell Write-Host "Set path...";
RUN powershell $env:path = 'C:\cygwin64\bin;\cygwin\bin;' + $env:path;
RUN powershell [Environment]::SetEnvironmentVariable('PATH', $env:path, [EnvironmentVariableTarget]::Machine);
RUN powershell Write-Output $env:path;

# Install VS components
RUN `
    # Install VS Test Agent
    curl -fSLo vs_TestAgent.exe https://download.visualstudio.microsoft.com/download/pr/584a5fcf-dd07-4c36-add9-620e858c9a35/cd90750df4950dc9a6130937f4aaf7367f42944dea5fde2c78dbcb4bd8a7fa73/vs_TestAgent.exe `
    && start /w vs_TestAgent.exe --quiet --norestart --nocache --wait `
    && powershell -Command "if ($err = dir $Env:TEMP -Filter dd_setup_*_errors.log | where Length -gt 0 | Get-Content) { throw $err }" `
    && del vs_TestAgent.exe `
    `
    # Install VS Build Tools - C++
    && curl -fSLo vs_BuildTools.exe https://download.visualstudio.microsoft.com/download/pr/584a5fcf-dd07-4c36-add9-620e858c9a35/536a649978a0c34a78ca99a0c7b14a7b52e96b5a563d86efe6fdf9559b2886fb/vs_BuildTools.exe `
    # Installer won't detect DOTNET_SKIP_FIRST_TIME_EXPERIENCE if ENV is used, must use setx /M
    && setx /M DOTNET_SKIP_FIRST_TIME_EXPERIENCE 1 `
    && start /w vs_BuildTools.exe ^ `
        --add Microsoft.VisualStudio.Workload.MSBuildTools ^ `
        --add Microsoft.VisualStudio.Workload.NetCoreBuildTools ^ `
        --add Microsoft.VisualStudio.Workload.UniversalBuildTools ^ `
        --add Microsoft.VisualStudio.Workload.VCTools ^ `   
        --add Microsoft.VisualC.CppCodeProvider ^ `
        --add Microsoft.VisualStudio.Workload.VisualStudioExtensionBuildTools ^ `
        --add Microsoft.VisualStudio.Workload.XamarinBuildTools ^ `
        --add Microsoft.Net.Component.4.8.SDK ^ `
        --add Microsoft.Component.ClickOnce.MSBuild ^ `
        --add Microsoft.VisualStudio.Component.WebDeploy ^ `
        --quiet --norestart --nocache --wait `
    && powershell -Command "if ($err = dir $Env:TEMP -Filter dd_setup_*_errors.log | where Length -gt 0 | Get-Content) { throw $err }" `
    && del vs_BuildTools.exe `
    # Cleanup
    && rmdir /S /Q "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer" `
    && powershell Remove-Item -Force -Recurse "%TEMP%\*" `
    && rmdir /S /Q "%ProgramData%\Package Cache"

# Install web targets
RUN curl -fSLo MSBuild.Microsoft.VisualStudio.Web.targets.zip https://dotnetbinaries.blob.core.windows.net/dockerassets/MSBuild.Microsoft.VisualStudio.Web.targets.2020.05.zip `
    && tar -zxf MSBuild.Microsoft.VisualStudio.Web.targets.zip -C "%ProgramFiles(x86)%\Microsoft Visual Studio\2019\BuildTools\MSBuild\Microsoft\VisualStudio\v16.0" `
    && del MSBuild.Microsoft.VisualStudio.Web.targets.zip
RUN powershell Get-ChildItem -Path '"C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\MSBuild\Microsoft\VisualStudio\v16.0"' –Recurse


ENV DOTNET_USE_POLLING_FILE_WATCHER=true `ROSLYN_COMPILER_LOCATION="C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\MSBuild\Current\Bin\Roslyn" `
    # Ngen workaround: https://github.com/microsoft/dotnet-framework-docker/issues/231
    COMPLUS_NGenProtectedProcess_FeatureEnabled=0

# ngen assemblies queued by VS installers - must be done in cmd shell to avoid access issues
RUN `
    # Workaround for issues with 64-bit ngen 
    \Windows\Microsoft.NET\Framework64\v4.0.30319\ngen uninstall "%ProgramFiles(x86)%\Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.8 Tools\SecAnnotate.exe" `
    && \Windows\Microsoft.NET\Framework64\v4.0.30319\ngen uninstall "%ProgramFiles(x86)%\Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.8 Tools\WinMDExp.exe" `
    `
    && \Windows\Microsoft.NET\Framework64\v4.0.30319\ngen update

# Set PATH in one layer to keep image size down.
RUN powershell setx /M PATH $(${Env:PATH} `
    + \";${Env:ProgramFiles}\NuGet\" `
    + \";${Env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\TestAgent\Common7\IDE\CommonExtensions\Microsoft\TestWindow\" `
    + \";${Env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\BuildTools\MSBuild\Current\Bin\" `
    + \";${Env:ProgramFiles(x86)}\Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.8 Tools\" `
    + \";${Env:ProgramFiles(x86)}\Microsoft SDKs\ClickOnce\SignTool\")

# Install Targeting Packs
RUN powershell " `
    $ErrorActionPreference = 'Stop'; `
    $ProgressPreference = 'SilentlyContinue'; `
    @('4.0', '4.5.2', '4.6.2', '4.7.2', '4.8') `
    | %{ `
        Invoke-WebRequest `
            -UseBasicParsing `
            -Uri https://dotnetbinaries.blob.core.windows.net/referenceassemblies/v${_}.zip `
            -OutFile referenceassemblies.zip; `
        Expand-Archive -Force referenceassemblies.zip -DestinationPath \"${Env:ProgramFiles(x86)}\Reference Assemblies\Microsoft\Framework\.NETFramework\"; `
        Remove-Item -Force referenceassemblies.zip; `
    }"

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG tmp2DIR="c:\tmp"

# Folders for binaries
RUN New-Item -ItemType Directory -Force -Path $env:tmp2Dir; `
    New-Item -ItemType Directory -Force -Path C:/ProgramData/ ; `
    New-Item -ItemType Directory -Force -Path C:/ProgramData/Jenkins ; `
    New-Item -ItemType Directory -Force -Path C:/cf ; `
    New-Item -ItemType Directory -Force -Path C:/Java ;

# OpenJDK here
RUN wget https://builds.openlogic.com/downloadJDK/openlogic-openjdk-jre/8u262-b10/openlogic-openjdk-jre-8u262-b10-windows-x64.zip -OutFile $env:tmp2Dir\\openlogic-openjdk-jre-8u262-b10-windows-x64.zip -UseBasicParsing ;
RUN powershell Expand-Archive $env:tmp2Dir\\openlogic-openjdk-jre-8u262-b10-windows-x64.zip -DestinationPath c:\Java ;
RUN powershell Get-ChildItem -Path C:\Java\openlogic-openjdk-jre-8u262-b10-win-64 ;
RUN `
    $env:path = 'C:\Java\openlogic-openjdk-jre-8u262-b10-win-64\bin;C:\Java\openlogic-openjdk-jre-8u262-b10-win-64;' + $env:path; `
    [Environment]::SetEnvironmentVariable('PATH', $env:path, [EnvironmentVariableTarget]::Machine); `
    Write-Output $env:path;
RUN powershell del $env:tmp2Dir\\openlogic-openjdk-jre-8u262-b10-windows-x64.zip ;
RUN powershell java -version

ARG VERSION=4.3
ARG GIT_VERSION=2.28.0-rc1
ARG GIT_PATCH_VERSION=1
LABEL Description="This is a base image, which provides the Jenkins agent executable (agent.jar)" Vendor="Jenkins project" Version="${VERSION}"

# GIT here
RUN [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 ; `
    $url = $('https://github.com/git-for-windows/git/releases/download/v{0}.windows.{1}/MinGit-{0}-busybox-64-bit.zip' -f $env:GIT_VERSION, $env:GIT_PATCH_VERSION) ; `
    Write-Host "Retrieving $url..." ; `
    Invoke-WebRequest $url -OutFile 'mingit.zip' -UseBasicParsing ; `
    Expand-Archive mingit.zip -DestinationPath c:\mingit ; `
    Remove-Item mingit.zip -Force ; `
    setx /M PATH $('c:\mingit\cmd;{0}' -f $env:PATH)

# Jenkins stuff here


ARG user=jenkins
ARG AGENT_FILENAME=agent.jar
ARG AGENT_HASH_FILENAME=$AGENT_FILENAME.sha1

RUN net user "$env:user" /add /expire:never /passwordreq:no ; `
    net localgroup Administrators /add $env:user ; `
    Set-LocalUser -Name $env:user -PasswordNeverExpires $true;

ARG AGENT_ROOT=C:/Users/$user
ARG AGENT_WORKDIR=${AGENT_ROOT}/Work
ENV AGENT_WORKDIR=${AGENT_WORKDIR}

# Get the Agent from the Jenkins Artifacts Repository
RUN [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 ; `
    Invoke-WebRequest $('https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/{0}/remoting-{0}.jar' -f $env:VERSION) -OutFile $(Join-Path C:/ProgramData/Jenkins $env:AGENT_FILENAME) -UseBasicParsing ; `
    Invoke-WebRequest $('https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/{0}/remoting-{0}.jar.sha1' -f $env:VERSION) -OutFile (Join-Path C:/ProgramData/Jenkins $env:AGENT_HASH_FILENAME) -UseBasicParsing ; `
    if ((Get-FileHash (Join-Path C:/ProgramData/Jenkins $env:AGENT_FILENAME) -Algorithm SHA1).Hash -ne (Get-Content (Join-Path C:/ProgramData/Jenkins $env:AGENT_HASH_FILENAME))) {exit 1} ; `
    Remove-Item -Force (Join-Path C:/ProgramData/Jenkins $env:AGENT_HASH_FILENAME)

USER $user

RUN New-Item -Type Directory $('{0}/.jenkins' -f $env:AGENT_ROOT) | Out-Null ; `
    New-Item -Type Directory $env:AGENT_WORKDIR | Out-Null

# .NET 3.1 install

ENV `
    # Enable detection of running in a container
    DOTNET_RUNNING_IN_CONTAINER=true `
    # Enable correct mode for dotnet watch (only mode supported in a container)
    DOTNET_USE_POLLING_FILE_WATCHER=true `
    # Skip extraction of XML docs - generally not useful within an image/container - helps performance
    NUGET_XMLDOC_MODE=skip `
    # PowerShell telemetry for docker image usage
    POWERSHELL_DISTRIBUTION_CHANNEL=PSDocker-DotnetCoreSDK-NanoServer-1909

RUN Write-Output $env:path; `
    $env:path = 'c:\dotnet;' + $env:path; `
    [Environment]::SetEnvironmentVariable('PATH', $env:PATH, [EnvironmentVariableTarget]::Machine); `
    Write-Output $env:path;

RUN `
    Invoke-WebRequest 'https://dot.net/v1/dotnet-install.ps1' -OutFile 'dotnet-install.ps1'; `
    ./dotnet-install.ps1 -Channel 3.1 -InstallDir 'C:\dotnet' ;

# CF CLI support#
RUN `
    wget 'https://packages.cloudfoundry.org/stable?release=windows64-exe&source=github&version=v6' -OutFile $env:tmp2Dir\\cf-cli_6.53.0_winx64.zip -UseBasicParsing ; `
    Expand-Archive $env:tmp2Dir\\cf-cli_6.53.0_winx64.zip -DestinationPath c:\\cf ; `
    $env:path = 'c:\cf;' + $env:path; `
    [Environment]::SetEnvironmentVariable('PATH', $env:PATH, [EnvironmentVariableTarget]::Machine); `
    Write-Output $env:path;
    
# Dos2Unix EOL conversion tool
RUN `
     wget 'https://waterlan.home.xs4all.nl/dos2unix/dos2unix-7.4.2-win64.zip' -OutFile $env:tmp2Dir\\dos2unix-7.4.2-win64.zip -UseBasicParsing ; `
     Expand-Archive $env:tmp2Dir\\dos2unix-7.4.2-win64.zip -DestinationPath c:\\dos2unix ; `
     $env:path = 'c:\dos2unix\bin;' + $env:path; `
     [Environment]::SetEnvironmentVariable('PATH', $env:PATH, [EnvironmentVariableTarget]::Machine); `
     Write-Output $env:path;

VOLUME ${AGENT_ROOT}/.jenkins
VOLUME ${AGENT_WORKDIR}
WORKDIR ${AGENT_ROOT}

#RUN  NET USER my_admin /add
#RUN  NET LOCALGROUP Administrators /add my_admin
#USER my_admin
RUN Enable-PSRemoting -Force
#RUN winrm set winrm/config/client '@{TrustedHosts=”*”}'
#RuN Set-Item wsman:\localhost\client\trustedhosts *
#RUN `winrm set winrm/config/client '@{TrustedHosts=\"*\"}';`
RUN Set-Item WSMan:\localhost\Client\TrustedHosts -Force -Value *
#RUN winrm quickconfig -q 
#RUN winrm set winrm/config/service/Auth @{Basic=true}
#RUN winrm set winrm/config/service @{AllowUnencrypted=true}
#RUN winrm set winrm/config/winrs @{MaxMemoryPerShellMB=1024}
RUN Set-Service WinRM -StartMode Automatic
RUN Restart-Service WinRM
RUN Test-WsMan localhost

RUN `
    wget https://releases.hashicorp.com/vault/1.8.0/vault_1.8.0_windows_amd64.zip -OutFile $env:tmp2Dir\\vault-1.8.0.zip -UseBasicParsing ;`
    Expand-Archive $env:tmp2Dir\\vault-1.8.0.zip -DestinationPath c:\\vault ; `
    powershell Get-ChildItem -Path c:\\vault;`
    $env:path = 'C:\vault;' + $env:path; `
    [Environment]::SetEnvironmentVariable('PATH', $env:PATH, [EnvironmentVariableTarget]::Machine); `
    Write-Output $env:path;
RUN `
    wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-win64.exe -OutFile $env:tmp2Dir\\jq.exe -UseBasicParsing ;`
    mkdir c:\\jq;`
    Copy-Item -Path $env:tmp2Dir\\jq.exe -Destination c:\\jq\\jq.exe ;`
    powershell Get-ChildItem -Path c:\\jq;`
    $env:path = 'C:\jq;' + $env:path; `
    [Environment]::SetEnvironmentVariable('PATH', $env:PATH, [EnvironmentVariableTarget]::Machine); `
    Write-Output $env:path;

RUN Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
RUN choco install winscp -y
EXPOSE 1433
#RUN choco install ssdt15 -y
#
RUN `
    mkdir c:\\install; `
    (New-Object System.Net.WebClient).DownloadFile('https://go.microsoft.com/fwlink/?linkid=2139376', 'c:\install\SSDT-Setup-enu.exe');