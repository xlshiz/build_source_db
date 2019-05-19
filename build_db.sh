#! /bin/bash

# buile_db.sh command:
# buile_db.sh config
# build_db.sh -a config	#all
# build_db.sh -t config	#tags
# build_db.sh -c config	#cscope
# build_db.sh -l config	#lookuptags
# build_db.sh -d config	#debug

# config file format:
# src=
# filetype=
# except=
# last=
# config file split by :

# fuctions---------------------------------------------------------------------
# for all path in SRC, to find files specified with FILTER, then print the filename filepath and 1(for vim's lookup plugin)
# you must give two parameters
# the first one is project list
# the second one is the filte
file_find()
{
	# check the parameter
	if [ $# -ne 2 ]; then
		echo "args must be 2" >&2
		return 1
	fi

	CP=`pwd`
	cd ${PRJP}

	# for all filter, combine the parameter for find command
	ARG=""
	for i in ${2}; do
		ARG="${ARG} -o -name \"${i}\" -printf \"%f\t%p\t1\n\""
	done

	# use the find command, to find files that you want in all PRO
	for i in ${1}; do
		if [ -e ${i} ]; then
			#COMM="find ${i} $(echo ${ARG} | sed -n "s/^-o //p") | sort -f"
			#echo $COMM | /bin/sh
			eval "find ${i} ${ARG:3} | sort -f"
		else
			echo "${1} is't exist" >&2
			cd ${CP}
			return 1
		fi
	done

	cd ${CP}
}

# remove some files and path you want(specify with EXCEPT)
# this function except 1 or 2 parameter. the first one is except list.
# if the second one exist, it is a file that include all the file which you want to process!. Or the function will read from standard input.
file_remove()
{
	# check parameters
	if [ $# -gt 2 ]; then
		echo "args must less than 2" >&2
		return 1
	fi

	CP=`pwd`
	cd ${PRJP}

	ARG=""
	for i in ${1}; do
		#TODO we should to check the filter, if it is a path
		ARG="${ARG} -e "\\:${i}:d""
	done
	local my_bak=IFS
	IFS=' '
	# If ${2} is empty, sed command will read from standard input
	sed ${ARG:-':.*:'} ${2}
	IFS=$my_bak

	cd ${CP}

}

# convert the lookupfile tags to cscope files
lookup2cscope () 
{
	# check parameters
	if [ $# -ne 2 ]; then
		echo "args must 2" >&2
		return 1
	fi

	CP=`pwd`
	cd ${PRJP}
	awk '{print $2}' $1 | sort -f > $2

	cd ${CP}
}

create_file_list()
{
	# to create the file-list ,which used by cscope!
	file_find "$SRC" "$FILTER" | file_remove "$EXCEPT" > ${PRJP}/lookuptags
	# in practice, you need the last chance to add something!
	if [[ $? -eq 0 ]]; then
		file_find "$LAST" "$FILTER" >> ${PRJP}/lookuptags
	else
		return 1
	fi
}

# Start------------------------------------------------------------------------
CON=''
opt=''
# get option and config file
if [[ $# -eq 0 ]]; then
	echo "usage: commond [-ltcadh] config" >&2
	exit 1
elif [[ $# -eq 1 ]]; then
	CON=${1}
	if [ ${CON} == "-h" ]; then
		echo "usage: commond [-ltcadh] config" >&2
		exit 1
	elif [ ! -e ${CON} ]; then
		echo "${CON} is not exit" >&2
		exit 1
	fi
	opt="-a"
elif [[ $# -eq 2 ]]; then
	CON=${2}
	if [ ! -e ${CON} ]; then
		echo "${CON} is not exit" >&2
		exit 1
	fi
	opt=${1}
else
	echo "usage: commond [-ltcadh] config"
	exit 1
fi

# get args
SRC=$(awk -F= '{if($1~/^[ \t]*\<[sS][rR][cC]\>/) print $2}' $CON)
FILTER=$(awk -F= '{if($1~/^[ \t]*\<[fF][iI][lL][tT][eE][rR]\>/) print $2}' $CON)
EXCEPT=$(awk -F= '{if($1~/^[ \t]*\<[eE][xX][cC][eE][pP][tT]\>/) print $2}' $CON)
LAST=$(awk -F= '{if($1~/^[ \t]*\<[lL][aA][sS][tT]\>/) print $2}' $CON)
PRJP=$(awk -F= '{if($1~/^[ \t]*\<[pP][rR][jJ][Pp]\>/) print $2}' $CON)

# echo $SRC
# echo $FILTER
# echo $EXCEPT
# echo $LAST
# echo $PRJP

if [ -z "$SRC" -o -z "$PRJP" ]; then
	echo "config file is wrong" >&2
	exit 1
fi
# now, we create the database file in the speccified path. so you must check it!
if [ ! -e ${PRJP} ]; then
	echo "${PRJP} do not exit" >&2
	exit 1
fi
if [ -z $FILTER ]; then
	FILTER="*.c:*.h:*.S"
fi

# deal with it
ifs_bak=$IFS
IFS=:
case ${opt} in
	"-l" )
		create_file_list
		;;
	"-t" )
		create_file_list
		lookup2cscope ${PRJP}/lookuptags ${PRJP}/cscope.files
		# ctags --fields=+S -L ${PRJP}/cscope.files -f ${PRJP}/tags
		ctags -L ${PRJP}/cscope.files -f ${PRJP}/tags
		;;
	"-c" )
		create_file_list
		lookup2cscope ${PRJP}/lookuptags ${PRJP}/cscope.files
		( cd ${PRJP}; cscope -bkq -i cscope.files )
		;;
	"-a" )
		create_file_list
		lookup2cscope ${PRJP}/lookuptags ${PRJP}/cscope.files
		( cd ${PRJP}; cscope -bkq -i cscope.files )
		ctags -L ${PRJP}/cscope.files -f ${PRJP}/tags
		;;
	"-d" )
		create_file_list
		lookup2cscope ${PRJP}/lookuptags ${PRJP}/cscope.files
		;;
	"-h" )
		echo "usage: commond [-ltcadh] config"
		;;
	* )
		echo "error option"
		;;
esac

IFS=$ifs_bak

exit 0
