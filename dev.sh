#!/bin/bash

# Function to display help
show_help() {
    echo "Development Script for SerenityEcho"
    echo "Usage: ./dev.sh [command]"
    echo ""
    echo "Commands:"
    echo "  web        Start development on Chrome"
    echo "  ios        Start development on iOS Simulator"
    echo "  clean      Clean the project and pods"
    echo "  test       Run tests"
    echo "  commit     Create a detailed commit with bullet points"
    echo "  help       Show this help message"
}

# Function to start web development
start_web() {
    echo "Starting Chrome development server..."
    flutter run -d chrome --web-port 5000
}

# Function to start iOS development
start_ios() {
    echo "Starting iOS development..."
    flutter run -d iphone
}

# Function to clean project
clean_project() {
    echo "Cleaning project..."
    flutter clean
    cd ios
    rm -rf Pods Podfile.lock
    pod cache clean --all
    pod install
    cd ..
    flutter pub get
}

# Function to run tests
run_tests() {
    echo "Running tests..."
    flutter test
}

# Function to run custom commit
run_commit() {
    if [ "$#" -lt 2 ]; then
        echo "Error: Missing commit message or bullet points"
        echo "Usage: ./dev.sh commit \"<summary>\" \"<bullet_points>\""
        exit 1
    fi
    ./scripts/commit.sh "$2" "$3"
}

# Main script logic
case "$1" in
    "web")
        start_web
        ;;
    "ios")
        start_ios
        ;;
    "clean")
        clean_project
        ;;
    "test")
        run_tests
        ;;
    "commit")
        run_commit "$@"
        ;;
    "help"|"")
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use './dev.sh help' for usage information"
        exit 1
        ;;
esac 