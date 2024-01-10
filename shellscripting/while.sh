a=20
while [[ $a -lt 30 ]]
do
echo "a value is less than 30 and the value is $a"
a=`expr $a + 1`
done
