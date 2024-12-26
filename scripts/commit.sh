#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print with color
print_color() {
    color=$1
    message=$2
    echo -e "${color}${message}${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 \"<summary>\" \"<bullet_points>\""
    echo "Example:"
    echo "$0 \"Update chat UI and fix scrolling\" \"-Implement auto-scroll\\n-Fix message order\\n-Improve styling\""
    exit 1
}

# Check if we have the required arguments
if [ "$#" -ne 2 ]; then
    show_usage
fi

summary=$1
bullet_points=$2

# Stage all changes
print_color $YELLOW "Staging all changes..."
git add .

# Show what's being committed
echo ""
print_color $YELLOW "Changes to be committed:"
git diff --cached --name-status | while read status file; do
    case $status in
        M) echo "Modified: $file" ;;
        A) echo "Added: $file" ;;
        D) echo "Deleted: $file" ;;
        R) echo "Renamed: $file" ;;
        C) echo "Copied: $file" ;;
        U) echo "Updated: $file" ;;
    esac
done

# Show the commit message
echo ""
print_color $YELLOW "Committing with message:"
echo -e "$summary\n\n$bullet_points"

# Perform the commit
git commit -m "$summary" -m "$bullet_points"

# Push to main
print_color $YELLOW "Pushing to main branch..."
git push origin main

# Check if successful
if [ $? -eq 0 ]; then
    print_color $GREEN "✓ Successfully committed and pushed changes!"
else
    print_color $RED "✗ Error pushing changes. Please check your connection and try again."
fi 