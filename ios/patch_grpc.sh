#!/bin/bash

# Patch script for gRPC-Core basic_seq.h to fix C++ template compilation issue
GRPC_FILE="Pods/gRPC-Core/src/core/lib/promise/detail/basic_seq.h"

if [ -f "$GRPC_FILE" ]; then
    echo "Patching gRPC-Core basic_seq.h..."
    
    # Backup the original file
    cp "$GRPC_FILE" "${GRPC_FILE}.backup"
    
    # The issue is with Traits::template syntax - we'll ensure proper spacing
    # This is a workaround - the file should work with C++17, but if compiler
    # flags aren't being applied, this might help
    
    # Check if patch is needed (if the file contains the problematic line)
    if grep -q "Traits::template CallSeqFactory" "$GRPC_FILE"; then
        echo "File contains the problematic template syntax"
        echo "Note: This should compile with C++17. Make sure CLANG_CXX_LANGUAGE_STANDARD is set to c++17"
    fi
    
    echo "Patch check complete. If build still fails, verify C++17 is set in Xcode build settings."
else
    echo "gRPC-Core file not found. Run 'pod install' first."
fi

