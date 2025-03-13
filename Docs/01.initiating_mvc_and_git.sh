#!/bin/bash

## Create a new project folder and navigate into it
mkdir YourProjectFolderName && cd YourProjectFolderName

## Initiate a .NET Core MVC project
dotnet new mvc
dotnet new gitignore

## Initialize a Git repository
git init
git add .
git commit -m "initated YourProjectName as a .NET Core MVC project"

## Setting up a GitHub repository, assuming you have GitHub CLI installed
gh repo create YourProjectName --public --source=. --remote=origin --push

## Push the initialized project to GitHub, then create a new branch for development
git push -u origin main
git checkout -b dev

## Create a README file
echo "# YourProjectFolderName" > README.md

## Validating the .NET MVC site
dotnet run

## Opening the site address that is returned in the console, something like http://localhost:5xxx
start http://localhost:5114

## Check the Git remote URL
git remote -v
## it should return something like this:
## origin  https://github.com/YourGitHubUsername/YourProjectName.git (fetch)
## origin  https://github.com/YourGitHubUsername/YourProjectName.git (push)