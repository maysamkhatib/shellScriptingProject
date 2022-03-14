#Ask user to enter the file name
echo "Please enter the file name: "
read fileName

#Check if the file is exist or not
if [ ! -e $fileName ]
then
echo "Error, the file does not exist"
exit 1
fi

#Check if the format is not right
if [ !  $(echo $fileName | cut -d "." -f2) = "csv" ]
then 
echo "Error, the format is wrong"
exit 1
fi

#Check if the file is empty or not
if [ ! -s $fileName ]
then
echo "Error, the file is empty"
exit 1
fi

#Check if the file is readable and writable
if [ ! -r $fileName -o ! -w $fileName ]
then
echo "Error, the file is not readable or not writable"
exit 1
fi
      
#Removing empty lines
sed -i '/^$/d' $fileName

#Get the number of colomns and rows
NoCol=$( cat $fileName | head -1 | tr ',' '\n' | wc -l )
NoRows=$( expr $( cat $fileName | wc -l) - 1)

#Check if there is an empty columns (Empty columns are not allowed)
for ((i=1; i<=NoCol;i++)); do
      N=$(sed '1d' $fileName | cut -d ',' -f $i | sed '/^$/d' | wc -l)
      if [ $N -eq 0 ]; then
	echo "Error: Empty columns are not allowed (Column-$i is an Empty columns)!"
      	exit 1
      fi
      done

#Operations to be selected by the user
while true
do
echo "Choose an option:"
echo "D:  Print the dimensions"
echo "C:  Computing statistics"
echo "S:  Subsitution"
echo "E:  Exit"
read option

case "$option"
in
     #Print the dimensions which is the number of rows & columns
'D' ) echo "The Dimension is $NoRows X $NoCol ";; 
     #Print basic statistics:
      #Print the Minimum number of each column
'C' ) echo -n "Min,"
      for ((i=1;i<=NoCol;i++)); do 
      	#We take the first line of the column after sorting it
      	sed '1d' $fileName | cut -d ',' -f $i | sed '/^$/d' | sort -d | head -1; 
      done | paste -s -d ','
      #Print the Maximum number of each column
      echo -n "Max,"
      for ((i=1;i<=NoCol;i++)); do 
      	#We take the last line of the column after sorting it
      	sed '1d' $fileName | cut -d ',' -f $i | sed '/^$/d' | sort -d | tail -1; 
      done | paste -s -d ','
      #Print the mean value of each column
      echo -n "Mean,"
      for ((i=1;i<=NoCol;i++)); do 
      	#Get the number of values in the specific column
      	N=$(sed '1d' $fileName | cut -d ',' -f $i | sed '/^$/d' | wc -l); 
      	#Get the sum of values in the specific column by using bc command
      	sum=$(sed '1d' $fileName | cut -d ',' -f $i | sed '/^$/d' | paste -sd+ | bc);
      	#Calculate and print the mean value of each column 
      	echo "scale=2; $sum / $N" | bc -l; 
      done | paste -s -d ',' 
      #Print the standard deviation value of each column
      echo -n "STDEV,"
      for (( i=1; i<=NoCol; i++)); do
      	#Get the number of values in each column
	N=$(sed '1d' $fileName | cut -d ',' -f $i | sed '/^$/d' | wc -l)
	#Get the sum of values in the specific column by using bc command
      	sum=$(sed '1d' $fileName | cut -d ',' -f $i | sed '/^$/d' | paste -sd+ | bc)
      	#Get the mean of values in the specific column by using bc command
      	mean=$( echo "scale=2; $sum / $N" | bc -l)
      	#The sum of the series
      	seriesSum=0
      	for (( j=1; j<=N; j++)); do
      		#The number of the line that has a value
      		lineN=$( echo "$j + 1" | bc -l )
      		#The value of the number in the field
      		x=$( sed -n "$lineN p" $fileName | cut -d ',' -f $i | sed '/^$/d' )
      		if [ -z $x ]; then
      		continue
      		fi
      		#The summation series of (each value - the mean of this column) squared
      		seriesSum=$( echo "$seriesSum + ($x - $mean) ^ 2" | bc -l )
      	done
      	#Get the standrad deviation by the equation below:
      	standardDeviation=$( echo " sqrt($seriesSum / ($N - 1))" | bc -l)
      	printf "%.7f\n" "$standardDeviation"
      	done | paste -s -d ',' ;;
      #Subsitutes missing values
      #A temp directory for storing columns seperated in files
'S' ) mkdir columns
      #Flag variable to check if there's any subsitution process
      flag=0
      for ((i=1; i<=NoCol;i++)); do
        #Get the number of values in each column
      	N=$(sed '1d' $fileName | cut -d ',' -f $i | sed '/^$/d' | wc -l)
      	#Get the sum of values in the specific column by using bc command
      	sum=$(sed '1d' $fileName | cut -d ',' -f $i | sed '/^$/d' | paste -sd+ | bc)
      	#Get the mean of values in the specific column by using bc command
      	mean=$( echo "scale=2; $sum / $N" | bc -l)
      	#Store each column in a file separately
      	cut -d ',' -f $i $fileName > columns/col$i.csv
      	#If the number of values is less than the number of rows, then there's a missing value, subsitute it by the mean
      	if [ $N -lt $NoRows ]; then 
		sed -i "s/^$/$mean/g" columns/col$i.csv
		flag=1
      	fi
	done
	#Store all files in a variable
	files=$( ls columns )
	#Go inside the folder we want files from there
	cd columns
	#Merge files together
	paste -d',' $files > ../$fileName
	#Remove the temp directory
	cd ..
	rm -r columns
	if [ $flag -eq 0 ]; then
	echo "There is no missing values"
	else
	echo "The subsitution process accomplished successfully"
	fi;;
'E' ) break ;;
esac
done
