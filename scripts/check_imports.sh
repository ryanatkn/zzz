#!/bin/bash

# Default search directory
DEFAULT_DIR="src"
SEARCH_DIR="${1:-$DEFAULT_DIR}"

echo "=== Import Path Checker ==="
echo "Checking all @import() statements in $SEARCH_DIR/ for validity..."
echo

# Function to check if an import path resolves correctly
check_import() {
    local file="$1"
    local import_line="$2"
    local import_path=$(echo "$import_line" | sed -n 's/.*@import("\([^"]*\)").*/\1/p')
    
    # Skip standard library imports
    if [[ "$import_path" == "std" || "$import_path" == "builtin" || "$import_path" == "root" ]]; then
        return
    fi
    
    if [[ -z "$import_path" ]]; then
        return
    fi
    
    # Get directory of the file doing the import
    local file_dir=$(dirname "$file")
    
    # Resolve the import path relative to the importing file
    local resolved_path="$file_dir/$import_path"
    
    # Check if the resolved path exists
    if [[ -f "$resolved_path" ]]; then
        echo "✅ $file"
        echo "   Import: $import_path"
        echo "   Resolves to: $resolved_path (EXISTS)"
    else
        echo "❌ $file"
        echo "   Import: $import_path"
        echo "   Resolves to: $resolved_path (NOT FOUND)"
        
        # Try to suggest corrections
        local filename=$(basename "$import_path")
        echo "   Suggestion: Looking for '$filename'..."
        
        # Search for files with the same name
        local found_files=$(find "$SEARCH_DIR" -name "$filename" -type f 2>/dev/null | head -3)
        if [[ -n "$found_files" ]]; then
            echo "   Found similar files:"
            while IFS= read -r found_file; do
                echo "     - $found_file"
            done <<< "$found_files"
        else
            echo "     No files named '$filename' found in $SEARCH_DIR"
        fi
    fi
    echo
}

# Check if search directory exists
if [[ ! -d "$SEARCH_DIR" ]]; then
    echo "❌ Error: Directory '$SEARCH_DIR' does not exist"
    echo "Usage: $0 [directory]"
    echo "Example: $0 src/lib/terminal"
    exit 1
fi

# Find all .zig files in the search directory
echo "Scanning .zig files in $SEARCH_DIR..."
file_count=$(find "$SEARCH_DIR" -name "*.zig" -type f | wc -l)
echo "Found $file_count .zig files"
echo

# Process each file
find "$SEARCH_DIR" -name "*.zig" -type f | sort | while read -r file; do
    # Extract all @import lines from the file
    import_lines=$(grep -n '@import(' "$file")
    if [[ -n "$import_lines" ]]; then
        while IFS=: read -r line_num line_content; do
            check_import "$file" "$line_content"
        done <<< "$import_lines"
    fi
done

echo "=== Summary ==="
echo "Scan complete for directory: $SEARCH_DIR"

# Count errors
error_count=$(find "$SEARCH_DIR" -name "*.zig" -type f -exec grep -l '@import(' {} \; | while read -r file; do
    grep '@import(' "$file" | while IFS= read -r line; do
        import_path=$(echo "$line" | sed -n 's/.*@import("\([^"]*\)").*/\1/p')
        if [[ "$import_path" != "std" && "$import_path" != "builtin" && "$import_path" != "root" && -n "$import_path" ]]; then
            file_dir=$(dirname "$file")
            resolved_path="$file_dir/$import_path"
            if [[ ! -f "$resolved_path" ]]; then
                echo "ERROR"
            fi
        fi
    done
done | wc -l)

echo "Import errors found: $error_count"

if [[ $error_count -eq 0 ]]; then
    echo "🎉 All imports are valid!"
else
    echo "⚠️  Some imports need attention"
fi