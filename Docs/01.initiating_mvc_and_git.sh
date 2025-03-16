#!/bin/bash

# Load .env variables
if [ -f "/etc/OutdoorsyCloudyMvc/.env" ]; then
    ENV_FILE="/etc/OutdoorsyCloudyMvc/.env"
elif [ -f "$HOME/.config/OutdoorsyCloudyMvc/.env" ]; then
    ENV_FILE="$HOME/.config/OutdoorsyCloudyMvc/.env"
elif [ -f "$HOME/AppData/Local/OutdoorsyCloudyMvc/.env" ]; then
    ENV_FILE="$HOME/AppData/Local/OutdoorsyCloudyMvc/.env"
else
    echo "No .env file found!"
    exit 1
fi

set -o allexport
source "$ENV_FILE"
set +o allexport

# Skip script if project already exists! After initial deployment, we can start with script 02.
if [ -d "$PROJECT_PATH" ]; then
    echo "MVC project and GitHub repo already exist. Skipping setup."
    exit 0
fi

echo "Starting SSH Agent..."
# Start ssh-agent if not already running
eval "$(ssh-agent -s)" >/dev/null 2>&1

# Add SSH key to agent if not already added
SSH_KEY="$HOME/.ssh/id_ed25519"

if ! ssh-add -l | grep -q "$SSH_KEY"; then
    ssh-add "$SSH_KEY"
    echo "SSH key added to agent."
else
    echo "SSH key already loaded."
fi

echo "Using .env file from: $ENV_FILE"

cd "$PROJECT_PATH" || { echo "Failed to enter project directory"; exit 1; }

# Check if .NET MVC project already exists
if [ ! -f "$PROJECT_PATH/$PROJECT_NAME.csproj" ]; then
    echo "Creating .NET MVC project..."
    dotnet new mvc -o "$PROJECT_NAME"
else
    echo ".NET MVC project already exists. Skipping creation."
fi

cd "$PROJECT_PATH" || { echo "Failed to enter .NET project directory: $PROJECT_PATH"; exit 1; }


# Check if Git is already initialized
if [ ! -d ".git" ]; then
    echo "Initializing Git repository..."
    git init
    git add .
    git commit -m "Initiated $PROJECT_NAME as a .NET Core MVC project"
else
    echo "Git repository already initialized. Skipping."
fi

# Check if GitHub repository already exists
if gh repo view "$GITHUB_USERNAME/$GITHUB_REPO_NAME" --json name &>/dev/null; then
    echo "GitHub repository already exists. Skipping creation."
else
    echo "Creating GitHub repository..."
    gh repo create "$GITHUB_REPO_NAME" --public --source=. --remote=origin --push
fi

# Ensure Git main branch is in sync with remote
git fetch origin main
if git rev-parse --verify main >/dev/null 2>&1; then
    git checkout main
    git pull origin main  # Pull the latest changes before pushing
else
    git checkout -b main
    git push -u origin main
fi

# Ensure Git dev branch is in sync with remote
git fetch origin dev
if git rev-parse --verify dev >/dev/null 2>&1; then
    git checkout dev
    git pull origin dev
else
    git checkout -b dev
    git push -u origin dev
fi

# Create README file if it doesn't exist
if [ ! -f "README.md" ]; then
    echo "# $PROJECT_NAME" > README.md
    git add README.md
    git commit -m "Added README"
    git push origin dev
else
    echo "README.md already exists. Skipping."
fi

# Validate and run .NET MVC project
echo "Running .NET MVC project..."
dotnet run &

# Open the local development URL
WEB_URL="http://localhost:5114"
echo "Opening: $WEB_URL"
start "$WEB_URL"

# Show Git remote URL for verification
git remote -v

echo ".NET MVC setup and GitHub repository configuration completed."