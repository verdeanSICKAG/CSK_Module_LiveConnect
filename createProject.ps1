# Adapter definitions
$appStudioProjectFolder = "project"
$gitIgnoreFile = ".gitignore"
$modules = ("v3.0.0", "modules/moduleDateTime", "https://github.com/SICKAppSpaceCodingStarterKit/CSK_Module_DateTime"),
			("v4.0.0", "modules/modulePersistentData", "https://github.com/SICKAppSpaceCodingStarterKit/CSK_Module_PersistentData")

# Add folder to the GIT ignore list if not already exist
Function addFolderToGitIgnore
{
	Param ($folderToAdd)
	
	$entry = "/" + $folderToAdd.replace("\", "/")
	if (Test-Path -Path $gitIgnoreFile -PathType Leaf)
	{
		foreach($line in Get-Content $gitIgnoreFile) 
		{
			if($line -match $regex)
			{
				if ($line -eq $entry)
				{
					return
				}
			}
		}
	}
	"Adding '" + $entry + "' to the GIT ignore list"
	Add-Content $gitIgnoreFile $entry
}

# Description
" "
"====================================================================================="
"For initial setup, please run the script without GIT update / commit." 
"Then the corresponding AppStudio project will be created under the folder '" + $appStudioProjectFolder + "'."
"====================================================================================="

# Script input promps
$updateSubtrees = Read-Host -Prompt "Add / update module epositories (add/pull GIT subtrees)? (y/n)"
$adapterUpdate = $false
if ($updateSubtrees -eq "y")
{
	$adapterUpdate = $true
}


# Create AppStudio project folder if not exist
if (-not(Test-Path -Path $appStudioProjectFolder))
{
	New-Item $appStudioProjectFolder -Type Directory
}

foreach($adapter in $modules)
{
	# GIT add / pull
	if ($adapterUpdate)
	{
		if (Test-Path -Path $adapter[1])
		{
			"===== Update " + $adapter[1] + " (pull from GIT) ====="
			git subtree pull --prefix $adapter[1] $adapter[2] $adapter[0]
		}
		else
		{
			"===== Add " + $adapter[1] + " (add from GIT) ====="
			git subtree add --prefix $adapter[1] $adapter[2] $adapter[0]
		}
	}
	
	# Create sym links if not exists
	foreach($app in Get-ChildItem $adapter[1] -Directory)
	{
		if (($app.name -match ".git") -or ($app.name -match "docu"))
		{
			continue
		}
		
		$source = $adapter[1] + '\' + $app.name
		$destination = $appStudioProjectFolder + '\' + $app.name
		
		if (-not(Test-Path -Path $destination))
		{
			"===== Create sym link for " + $app.name + " ====="
			New-Item -Path $destination -ItemType SymbolicLink -Value $source
		}
		
		# Add linked app to the GIT ignore list
		addFolderToGitIgnore($destination)
	}
	
	addFolderToGitIgnore($appStudioProjectFolder)
	
	
	
}

Write-Host -NoNewLine 'Press any key to exit...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');