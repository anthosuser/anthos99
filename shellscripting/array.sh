#!/bin/bash

# Declare a static Array
arr=(“Jayesh” “Shivang” “1” “rishabh” “Vipul” “Nishtan”)

# Count the length of a particular element in the array
element_length=${#arr[2]}
echo “Length of element at index 2: $element_length”

# Count the length of the entire array
array_length=${#arr[@]}
echo “Length of the array: $array_length”

# Search in the array
search_result=$(echo “${arr[@]}” | grep -c “Jayesh”)
echo “Search result for ‘Jayesh’: $search_result”

# Search and replace in the array
replaced_element=$(echo “${arr[@]/Shivang/SHIVANG}”)
echo “Array after search & replace: ${replaced_element[*]}”

# Delete an element in the array (index 3)
unset arr[3]

echo “Array after deletion: ${arr[*]}”
