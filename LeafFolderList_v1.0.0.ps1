# LeafFolderList_v1.0.0.ps1

$configFile = Join-Path $PSScriptRoot "LeafFolderList.settings.json"

function Pause-AnyKey {
    Write-Host ""
    Write-Host "Press any key to continue..."
    [void][System.Console]::ReadKey($true)
}

function Read-ValueWithDefault {
    param(
        [string]$Prompt,
        [string]$DefaultValue
    )

    if ([string]::IsNullOrWhiteSpace($DefaultValue)) {
        do {
            $value = Read-Host $Prompt
        } until (-not [string]::IsNullOrWhiteSpace($value))

        return $value
    }

    $inputValue = Read-Host "$Prompt [$DefaultValue]"

    if ([string]::IsNullOrWhiteSpace($inputValue)) {
        return $DefaultValue
    }

    return $inputValue
}

function ConvertTo-CleanPath {
    param([string]$Path)
    return $Path.Trim().Trim('"')
}

function Get-DepthLimitedItems {
    param(
        [string]$Path,
        [Nullable[int]]$Depth,
        [string]$Mode
    )

    if ($null -eq $Depth) {
        if ($Mode -eq "Directory") {
            return Get-ChildItem -Path $Path -Directory -Recurse -Force -ErrorAction SilentlyContinue
        }
        elseif ($Mode -eq "File") {
            return Get-ChildItem -Path $Path -File -Recurse -Force -ErrorAction SilentlyContinue
        }
        else {
            return Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    else {
        if ($Mode -eq "Directory") {
            return Get-ChildItem -Path $Path -Directory -Recurse -Depth $Depth -Force -ErrorAction SilentlyContinue
        }
        elseif ($Mode -eq "File") {
            return Get-ChildItem -Path $Path -File -Recurse -Depth $Depth -Force -ErrorAction SilentlyContinue
        }
        else {
            return Get-ChildItem -Path $Path -Recurse -Depth $Depth -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-RelativePathSafe {
    param(
        [string]$BasePath,
        [string]$FullPath
    )

    if ([string]::IsNullOrWhiteSpace($BasePath)) {
        return $FullPath
    }

    if ([string]::IsNullOrWhiteSpace($FullPath)) {
        return ""
    }

    $base = [System.IO.Path]::GetFullPath($BasePath).TrimEnd('\', '/')
    $full = [System.IO.Path]::GetFullPath($FullPath)

    if ($full.Equals($base, [System.StringComparison]::OrdinalIgnoreCase)) {
        return ""
    }

    if ($full.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $full.Substring($base.Length).TrimStart('\', '/')
    }

    return $FullPath
}

function Get-PathDepth {
    param(
        [string]$BasePath,
        [string]$FullPath
    )

    $relative = Get-RelativePathSafe -BasePath $BasePath -FullPath $FullPath

    if ([string]::IsNullOrWhiteSpace($relative)) {
        return 0
    }

    return ($relative -split '[\\/]').Count
}

function New-DirectoryNode {
    param(
        [string]$Name,
        [string]$FullPath,
        [string]$RelativePath
    )

    return [PSCustomObject]@{
        Type         = "Folder"
        Name         = $Name
        FullPath     = $FullPath
        RelativePath = $RelativePath
        Folders      = @()
        Files        = @()
    }
}

function Add-FileToTree {
    param(
        [object]$RootNode,
        [string]$ScanRoot,
        [object]$File
    )

    if ($null -eq $RootNode) { return }
    if ([string]::IsNullOrWhiteSpace($ScanRoot)) { return }
    if ($null -eq $File) { return }
    if ([string]::IsNullOrWhiteSpace($File.FullPath)) { return }

    $relativePath = Get-RelativePathSafe -BasePath $ScanRoot -FullPath $File.FullPath

    if ([string]::IsNullOrWhiteSpace($relativePath)) {
        return
    }

    $parts = $relativePath -split '[\\/]'
    $currentNode = $RootNode

    if ($parts.Count -gt 1) {
        for ($i = 0; $i -lt $parts.Count - 1; $i++) {
            $folderName = $parts[$i]

            if ([string]::IsNullOrWhiteSpace($folderName)) {
                continue
            }

            $existingFolder = $currentNode.Folders |
                Where-Object { $_.Name -eq $folderName } |
                Select-Object -First 1

            if (-not $existingFolder) {
                $parentRelative = if ([string]::IsNullOrWhiteSpace($currentNode.RelativePath)) {
                    $folderName
                }
                else {
                    Join-Path $currentNode.RelativePath $folderName
                }

                $parentFull = Join-Path $ScanRoot $parentRelative
                $existingFolder = New-DirectoryNode -Name $folderName -FullPath $parentFull -RelativePath $parentRelative
                $currentNode.Folders += $existingFolder
            }

            $currentNode = $existingFolder
        }
    }

    $extension = ""
    if ($File.PSObject.Properties.Name -contains "Extension" -and $null -ne $File.Extension) {
        $extension = $File.Extension.ToString().ToLower()
    }

    $sizeBytes = $null
    if ($File.PSObject.Properties.Name -contains "SizeBytes") {
        $sizeBytes = $File.SizeBytes
    }
    elseif ($File.PSObject.Properties.Name -contains "Length") {
        $sizeBytes = $File.Length
    }

    $lastWrite = ""
    if ($File.PSObject.Properties.Name -contains "LastWrite" -and $null -ne $File.LastWrite) {
        $lastWrite = $File.LastWrite.ToString()
    }
    elseif ($File.PSObject.Properties.Name -contains "LastWriteTime" -and $null -ne $File.LastWriteTime) {
        $lastWrite = $File.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
    }

    $currentNode.Files += [PSCustomObject]@{
        Type         = "File"
        Name         = $File.Name
        Extension    = $extension
        FullPath     = $File.FullPath
        RelativePath = $relativePath
        SizeBytes    = $sizeBytes
        LastWrite    = $lastWrite
    }
}

function Add-FolderToTree {
    param(
        [object]$RootNode,
        [string]$ScanRoot,
        [object]$Folder
    )

    if ($null -eq $RootNode) { return }
    if ([string]::IsNullOrWhiteSpace($ScanRoot)) { return }
    if ($null -eq $Folder) { return }
    if ([string]::IsNullOrWhiteSpace($Folder.FullPath)) { return }

    $relativePath = Get-RelativePathSafe -BasePath $ScanRoot -FullPath $Folder.FullPath

    if ([string]::IsNullOrWhiteSpace($relativePath)) {
        return
    }

    $parts = $relativePath -split '[\\/]'
    $currentNode = $RootNode

    foreach ($folderName in $parts) {
        if ([string]::IsNullOrWhiteSpace($folderName)) {
            continue
        }

        $existingFolder = $currentNode.Folders |
            Where-Object { $_.Name -eq $folderName } |
            Select-Object -First 1

        if (-not $existingFolder) {
            $parentRelative = if ([string]::IsNullOrWhiteSpace($currentNode.RelativePath)) {
                $folderName
            }
            else {
                Join-Path $currentNode.RelativePath $folderName
            }

            $parentFull = Join-Path $ScanRoot $parentRelative
            $existingFolder = New-DirectoryNode -Name $folderName -FullPath $parentFull -RelativePath $parentRelative
            $currentNode.Folders += $existingFolder
        }

        $currentNode = $existingFolder
    }
}

function Invoke-Scanner {
    try {
        Clear-Host

        $config = @{
            ScanPaths          = ""
            OutputPath         = ""
            FileName           = ""
            ScanMode           = "both"
            SelectedExtensions = ""
        }

        if (Test-Path $configFile) {
            $loaded = Get-Content $configFile -Raw | ConvertFrom-Json

            if ($loaded.ScanPaths) { $config.ScanPaths = $loaded.ScanPaths }
            if ($loaded.OutputPath) { $config.OutputPath = $loaded.OutputPath }
            if ($loaded.FileName) { $config.FileName = $loaded.FileName }
            if ($loaded.ScanMode) { $config.ScanMode = $loaded.ScanMode }
            if ($loaded.SelectedExtensions) { $config.SelectedExtensions = $loaded.SelectedExtensions }
        }

        Write-Host ""
		Write-Host "Separate multiple scan paths with ;" -ForegroundColor Cyan
		Write-Host "Define depth per path using |"
		Write-Host "Depth 0 = scan only the root folder itself." -ForegroundColor Gray
		Write-Host "Depth 1 = scan one level below the root folder." -ForegroundColor Gray
		Write-Host "Leave depth empty for unlimited recursion." -ForegroundColor Gray
		Write-Host 'Example: "C:\Path 1"|3; D:\Path2|; E:\Path3|1' -ForegroundColor DarkGray
		Write-Host ""

        $scanPathsInput = Read-ValueWithDefault -Prompt "Scan Paths" -DefaultValue $config.ScanPaths
        $outputPath = ConvertTo-CleanPath (Read-ValueWithDefault -Prompt "Output Path" -DefaultValue $config.OutputPath)
        $fileName = ConvertTo-CleanPath (Read-ValueWithDefault -Prompt "Export Filename" -DefaultValue $config.FileName)

        Write-Host ""
        Write-Host "Scan Mode:"
        Write-Host "[1] Folders only"
        Write-Host "[2] Files only"
        Write-Host "[3] Both"

        $scanModeInput = Read-ValueWithDefault -Prompt "Scan Mode" -DefaultValue $config.ScanMode

        switch ($scanModeInput.ToLower()) {
            "1" { $scanMode = "folders" }
            "folders" { $scanMode = "folders" }
            "folder" { $scanMode = "folders" }

            "2" { $scanMode = "files" }
            "files" { $scanMode = "files" }
            "file" { $scanMode = "files" }

            "3" { $scanMode = "both" }
            "both" { $scanMode = "both" }

            default { throw "Invalid scan mode. Use 1, 2, 3, folders, files or both." }
        }

        if (-not $fileName.EndsWith(".txt", [System.StringComparison]::OrdinalIgnoreCase)) {
            $fileName += ".txt"
        }

        if (-not (Test-Path $outputPath -PathType Container)) {
            New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
        }

        $scanConfigs = @()

        foreach ($entry in ($scanPathsInput -split ';')) {
            if ([string]::IsNullOrWhiteSpace($entry)) { continue }

            $parts = $entry -split '\|', 2
            $path = ConvertTo-CleanPath $parts[0]

            $depthInput = ""
            if ($parts.Count -gt 1) {
                $depthInput = $parts[1].Trim()
            }

            if ([string]::IsNullOrWhiteSpace($depthInput)) {
                $depth = $null
            }
            elseif ($depthInput -match '^\d+$') {
                $depth = [int]$depthInput
            }
            else {
                throw "Invalid depth for path '$path'. Use empty or a number."
            }

            if (-not (Test-Path $path -PathType Container)) {
                throw "Scan path does not exist: $path"
            }

            $scanConfigs += [PSCustomObject]@{
                Path  = $path
                Depth = $depth
            }
        }

        if ($scanConfigs.Count -eq 0) {
            throw "No scan paths specified."
        }

        $outputFile = Join-Path $outputPath $fileName
        $csvFile = [System.IO.Path]::ChangeExtension($outputFile, ".csv")
        $jsonFile = [System.IO.Path]::ChangeExtension($outputFile, ".json")

        $allFolders = @()
        $allFiles = @()
        $treeRoots = @()

        foreach ($scan in $scanConfigs) {
            $rootNode = New-DirectoryNode -Name (($scan.Path.TrimEnd('\') -split '\\')[-1]) -FullPath $scan.Path -RelativePath ""

            if ($scanMode -eq "folders" -or $scanMode -eq "both") {
                $folders = Get-DepthLimitedItems -Path $scan.Path -Depth $scan.Depth -Mode "Directory"

                $leafFolders = $folders | Where-Object {
                    -not (Get-ChildItem -Path $_.FullName -Directory -Force -ErrorAction SilentlyContinue | Select-Object -First 1)
                }

                foreach ($folder in $leafFolders) {
                    Add-FolderToTree -RootNode $rootNode -ScanRoot $scan.Path -Folder $folder

                    $allFolders += [PSCustomObject]@{
                        Type         = "Folder"
                        ScanRoot     = $scan.Path
                        MaxDepth     = if ($null -eq $scan.Depth) { "Unlimited" } else { $scan.Depth }
                        Name         = $folder.Name
                        Extension    = ""
                        RelativePath = Get-RelativePathSafe -BasePath $scan.Path -FullPath $folder.FullPath
                        Depth        = Get-PathDepth -BasePath $scan.Path -FullPath $folder.FullPath
                        FullPath     = $folder.FullName
                    }
                }
            }

            if ($scanMode -eq "files" -or $scanMode -eq "both") {
                $files = Get-DepthLimitedItems -Path $scan.Path -Depth $scan.Depth -Mode "File"

                foreach ($file in $files) {
                    $allFiles += [PSCustomObject]@{
                        Type         = "File"
                        ScanRoot     = $scan.Path
                        MaxDepth     = if ($null -eq $scan.Depth) { "Unlimited" } else { $scan.Depth }
                        Name         = $file.Name
                        Extension    = $file.Extension.ToLower()
                        RelativePath = Get-RelativePathSafe -BasePath $scan.Path -FullPath $file.FullPath
                        Depth        = Get-PathDepth -BasePath $scan.Path -FullPath $file.FullPath
                        SizeBytes    = $file.Length
                        LastWrite    = $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
                        FullPath     = $file.FullName
                    }
                }
            }

            $treeRoots += [PSCustomObject]@{
                ScanRoot = $scan.Path
                MaxDepth = if ($null -eq $scan.Depth) { "Unlimited" } else { $scan.Depth }
                Tree     = $rootNode
            }
        }

        $selectedExtensions = @()

        if ($scanMode -eq "files" -or $scanMode -eq "both") {
            $extensions = $allFiles |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_.Extension) } |
                Select-Object -ExpandProperty Extension -Unique |
                Sort-Object

            if ($extensions.Count -gt 0) {
                $selectedExtensions = $config.SelectedExtensions -split ',' |
                    ForEach-Object { $_.Trim().ToLower() } |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

                $selectionValid = $false

                while (-not $selectionValid) {
                    Write-Host ""
                    Write-Host "Detected file extensions:" -ForegroundColor Cyan

                    for ($i = 0; $i -lt $extensions.Count; $i++) {
                        $ext = $extensions[$i]
                        $isSelected = $selectedExtensions -contains $ext

                        if ($isSelected) {
                            Write-Host ("[{0}] [x] {1}" -f ($i + 1), $ext)
                        }
                        else {
                            Write-Host ("[{0}] [ ] {1}" -f ($i + 1), $ext)
                        }
                    }

                    Write-Host ""
                    Write-Host "Selection:"
                    Write-Host " - Numbers separated with commas: 1,3,4"
                    Write-Host " - all = select all"
                    Write-Host " - empty = reuse previous selection"
                    Write-Host " - none = clear selection"

                    $extensionInput = Read-Host "Select extensions"

                    if ([string]::IsNullOrWhiteSpace($extensionInput)) {
                        if ($selectedExtensions.Count -gt 0) {
                            $selectionValid = $true
                        }
                        else {
                            Write-Host ""
                            Write-Host "No previous selection exists." -ForegroundColor Yellow
                        }
                    }
                    elseif ($extensionInput.ToLower() -eq "all") {
                        $selectedExtensions = $extensions
                        $selectionValid = $true
                    }
                    elseif ($extensionInput.ToLower() -eq "none") {
                        $selectedExtensions = @()
                        Write-Host ""
                        Write-Host "Selection cleared." -ForegroundColor Yellow
                    }
                    else {
                        $newSelection = foreach ($number in ($extensionInput -split ',')) {
                            $number = $number.Trim()

                            if ($number -match '^\d+$') {
                                $index = [int]$number - 1

                                if ($index -ge 0 -and $index -lt $extensions.Count) {
                                    $extensions[$index]
                                }
                            }
                        }

                        if ($newSelection.Count -gt 0) {
                            $selectedExtensions = $newSelection
                            $selectionValid = $true
                        }
                        else {
                            Write-Host ""
                            Write-Host "Invalid selection." -ForegroundColor Red
                        }
                    }
                }

                if ($selectedExtensions.Count -gt 0) {
                    $allFiles = $allFiles | Where-Object {
                        $selectedExtensions -contains $_.Extension.ToLower()
                    }
                }
                else {
                    $allFiles = @()
                }
            }
        }

        foreach ($treeRoot in $treeRoots) {
            $treeRoot.Tree = New-DirectoryNode -Name (($treeRoot.ScanRoot.TrimEnd('\') -split '\\')[-1]) -FullPath $treeRoot.ScanRoot -RelativePath ""

            foreach ($folder in @($allFolders | Where-Object { $_.ScanRoot -eq $treeRoot.ScanRoot })) {
                Add-FolderToTree -RootNode $treeRoot.Tree -ScanRoot $treeRoot.ScanRoot -Folder $folder
            }

            foreach ($file in @($allFiles | Where-Object { $_.ScanRoot -eq $treeRoot.ScanRoot })) {
                Add-FileToTree -RootNode $treeRoot.Tree -ScanRoot $treeRoot.ScanRoot -File $file
            }
        }

        $results = @()
        $results += $allFolders
        $results += $allFiles
        $results = $results | Sort-Object Type, FullPath

        $scanDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        $outputContent = @()
        $outputContent += "Date: $scanDate"
        $outputContent += "Scan Mode: $scanMode"
        $outputContent += "Paths:"

        foreach ($scan in $scanConfigs) {
            $depthText = if ($null -eq $scan.Depth) { "Unlimited" } else { $scan.Depth }
            $outputContent += " - $($scan.Path) | Depth: $depthText"
        }

        if ($scanMode -eq "files" -or $scanMode -eq "both") {
            $outputContent += "Selected Extensions: $($selectedExtensions -join ', ')"
        }

        $outputContent += "Results found: $($results.Count)"
        $outputContent += "Files found: $($allFiles.Count)"
        $outputContent += "Folders found: $($allFolders.Count)"
        $outputContent += ""
        $outputContent += "----------------------------------------"
        $outputContent += ""

        if ($allFiles.Count -gt 0) {
            $outputContent += "--- [Files] ---"

            foreach ($file in ($allFiles | Sort-Object FullPath)) {
                $outputContent += "[File] $($file.FullPath)"
            }

            $outputContent += ""
        }

        if ($allFolders.Count -gt 0) {
            $outputContent += "--- [Folders] ---"

            foreach ($folder in ($allFolders | Sort-Object FullPath)) {
                $outputContent += "[Folder] $($folder.FullPath)"
            }

            $outputContent += ""
        }

        $outputContent | Set-Content -Path $outputFile -Encoding UTF8

        $results |
            Select-Object Type, ScanRoot, MaxDepth, Name, Extension, RelativePath, Depth, SizeBytes, LastWrite, FullPath |
            Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8

        $jsonData = [PSCustomObject]@{
            Date               = $scanDate
            ScanMode           = $scanMode
            SelectedExtensions = $selectedExtensions
            Paths              = $scanConfigs | ForEach-Object {
                [PSCustomObject]@{
                    Path     = $_.Path
                    MaxDepth = if ($null -eq $_.Depth) { "Unlimited" } else { $_.Depth }
                }
            }
            ResultsCount = $results.Count
            Results      = $results
            Structure    = $treeRoots
        }

        $jsonData |
            ConvertTo-Json -Depth 100 |
            Set-Content -Path $jsonFile -Encoding UTF8

        $config = @{
            ScanPaths          = $scanPathsInput
            OutputPath         = $outputPath
            FileName           = $fileName
            ScanMode           = $scanMode
            SelectedExtensions = ($selectedExtensions -join ',')
        }

        $config | ConvertTo-Json -Depth 4 | Set-Content -Path $configFile -Encoding UTF8

        Write-Host ""
        Write-Host "Scan completed successfully." -ForegroundColor Green
        Write-Host "Results found: $($results.Count)"
        Write-Host "TXT Export: $outputFile"
        Write-Host "CSV Export: $csvFile"
        Write-Host "JSON Export: $jsonFile"

        Pause-AnyKey
    }
    catch {
        Write-Host ""
        Write-Host "Error while executing script:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red

        Pause-AnyKey
    }
}

while ($true) {
    Invoke-Scanner
}