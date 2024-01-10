#/bin/bash

CORRECT=n
while [ “$CORRECT” == “n” ]
do

# loop discontinues when you enter y i.e., when your name is correct
# -p stands for prompt asking for the input

read -p “Enter your name:” NAME
read -p “Is ${NAME} correct? ” CORRECT
done