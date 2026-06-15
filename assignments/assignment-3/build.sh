#!/bin/bash

# Funciton that prepare the environment
export_variables() {

    unset ROOT_LABS_TMP
    unset LLVM_DIR_TMP

    # [EDIT] Manually select the root labs path
    #ROOT_LABS_TMP="$HOME/path/to/root/labs/"

    # [EDIT] Manually select the llvm libs folder
    #LLVM_DIR_TMP="/usr/lib/llvm-19/lib/"

    # Check if llvm installation path is supplied via argument
    if [ ! -z "$1" ]; then
        [ -d "$1" ] || { echo "Could not find the given llvm installation path: $1."; exit 1; }
        LLVM_DIR_TMP="$1"
    fi

    # Automatically get the script path, if ROOT_LABS_TMP is not set
    if [ -z "$ROOT_LABS_TMP" ]; then
        ROOT_LABS_TMP=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    fi

    # Automatically get the llvm libs folder, if LLVM_DIR_TMP is not set
    if [ -z "$LLVM_DIR_TMP" ]; then
        if command -v llvm-config &> /dev/null; then
            LLVM_DIR_TMP=$(llvm-config --libdir)
        elif command -v llvm-config-19 &> /dev/null; then
            LLVM_DIR_TMP=$(llvm-config-19 --libdir)
        else
            echo "Could not find the llvm lib folder automatically."
            exit 1
        fi
    fi

    # Print variables
    echo "Exporting env variables..."
    echo "-- ROOT_LABS=$ROOT_LABS_TMP"
    echo "-- LLVM_DIR=$LLVM_DIR_TMP"

    # Export variables
    export ROOT_LABS="$ROOT_LABS_TMP"
    export LLVM_DIR="$LLVM_DIR_TMP"
}

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "$1 is not installed. Install it before running the script again."
        exit 1
    fi
}

# Function to create directories if they do not exist
check_create_dir() {
    if [ ! -e "$1" ]; then
        mkdir "$1" || { echo "Failed to create $1 directory."; exit 1; }
    fi
}

# Function to check that commands exists
check_dependencies() {
    echo "Dependency check..."
    check_command cmake
    check_command make
    check_command opt
    check_command clang
    check_command llvm-dis
}

# Dependencies
check_dependencies

# Load Env Variables
export_variables "$1"

# Check if ROOT_LABS is set
if [ -z "$ROOT_LABS" ]; then
    echo "ROOT_LABS is not set."
    exit 1
fi

# Paths
SOURCES_DIR="$ROOT_LABS/sources"
MODULES_DIR="$ROOT_LABS/modules" # Real Module Dir
#MODULES_DIR="$ROOT_LABS/testing" # Test Module Dir
BUILD_DIR="$ROOT_LABS/build"

# Check dirs
check_create_dir "$SOURCES_DIR"
check_create_dir "$MODULES_DIR"
check_create_dir "$BUILD_DIR"

# [EDIT] Source File
SOURCE_FILE="licm-test"
IS_LL_FILE=false

# [EDIT] Assignment
ASSIGNMENT="LoopInvariantCodeMotion"

# Source File Path
SOURCE_FILE_PATH="$SOURCES_DIR/$SOURCE_FILE"

# Building

cd "$BUILD_DIR"
echo "Would you run cmake? (Y/n)"
read runcmake
if [ "${runcmake}" = "y" ] || [ "${runcmake}" = "Y" ] || [ "${runcmake}" = "" ]; then
    echo "Running cmake..."
    cmake -DLT_LLVM_INSTALL_DIR=$LLVM_DIR "$MODULES_DIR"
fi
echo "Running make..."
make
cd ..

# Processing

if [ "$IS_LL_FILE" = false ]; then
    # Running clang with optnone flag disabled for .ll generation
    clang -Xclang -disable-O0-optnone -O0 -S -emit-llvm -c "${SOURCE_FILE_PATH}.c" -o "${SOURCE_FILE_PATH}.ll"

    # Converting LLVM IR to SSA form using the mem2reg pass
    opt -p mem2reg "${SOURCE_FILE_PATH}.ll" -o "${SOURCE_FILE_PATH}.bc"

    # Running llvm-dis to convert .bc to .ll
    llvm-dis "${SOURCE_FILE_PATH}.bc" -o "${SOURCE_FILE_PATH}.ll"
fi

execute_passes() {
    # Running opt to apply passes
    opt -load-pass-plugin "${BUILD_DIR}/lib${ASSIGNMENT}.so" \
        -passes="$1" "${SOURCE_FILE_PATH}.ll" \
        -o "${SOURCE_FILE_PATH}.optimized.bc"

    # Running llvm-dis to convert .bc to .ll
    llvm-dis "${SOURCE_FILE_PATH}.optimized.bc" -o "${SOURCE_FILE_PATH}.optimized.ll"
}

echo "Running opt to apply pass..."; echo

execute_passes "-licm-pass"
#execute_passes "licm"

echo; echo "Build and processing completed."
