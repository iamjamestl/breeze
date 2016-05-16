#!/bin/bash
# Open initial output.
# Prefer konsole if its there, otherwise fall back to xterminal.
#tty -s; if [ $? -ne 0 ]; then
#	if command -v konsole &>/dev/null; then
#		konsole -e "$0"; exit;
#		else
#		xterm -e "$0"; exit;
#	fi
#fi

cd "$( dirname "${BASH_SOURCE[0]}" )"
ALIASES="src/cursorList"
SIZES="24 32 40 48 64 96"


echo -ne "Checking requirements...\\r"
if  ! type "inkscape" > /dev/null ; then
	echo -e "\\nFAIL: inkscape must be installed"
	exit 1
fi

if  ! type "xcursorgen" > /dev/null ; then
	echo -e "\\nFAIL: xcursorgen must be installed"
	exit 1
fi
echo -e "Checking requirements... DONE"



preprocess_cursor_configs() {
	local template basename i size xhot yhot filename delay newxhot newyhot

	echo -ne "Preprocessing cursor configs...\\r"

	[ ! -d "build/config" ] && mkdir -p "build/config"

	for template in src/config/*.cursor.in; do
		basename=${template##*/}
		basename=${basename%%.*}
		rm -f "build/config/$basename.cursor"
		for i in $SIZES; do
			while read size xhot yhot filename delay; do
				newxhot=$(printf '%.0f' $(echo "$xhot * $i / $size" | bc -l))
				newyhot=$(printf '%.0f' $(echo "$yhot * $i / $size" | bc -l))
				echo "$i $newxhot $newyhot $i/$filename $delay" >> "build/config/$basename.cursor"
			done < $template
		done
	done

	echo -e "Preprocessing cursor configs... DONE"
}


generate_pixmaps() {
	local basename=$1
	local rawsvg=$2
	local outdir=$3
	local size

	for size in $SIZES; do
		if [ "$outdir/$size/$basename.png" -ot $rawsvg ] ; then
			inkscape -i $basename -d $(($size * 90 / 24)) -f $rawsvg -e "$outdir/$size/$basename.png" > /dev/null 2>&1
			if [ $? -ne 0 ]; then
				echo -e "\\nFAIL: inkscape failed to generate '$outdir/$size/$basename.png'"
				exit 1
			fi
		fi
	done
}


generate_cursor() {
	local name=$1
	local rawsvg="src/$name/cursors.svg"
	local index="src/$name/index.theme"
	local output cursor basename i error from to

	if [ ! -f $rawsvg ] ; then
		echo -e "\\nFAIL: '$rawsvg' missing"
		exit 1
	fi

	if [ ! -f $index ] ; then
		echo -e "\\nFAIL: '$index' missing"
		exit 1
	fi

	echo "Generating $name..."

	echo -ne "Making folders...\\r"
	output="$(grep --only-matching --perl-regex "(?<=Name\=).*$" $index)"
	output=${output// /_}
	mkdir -p "$output/cursors"
	for size in $SIZES; do mkdir -p "build/$name/$size"; done
	echo 'Making folders... DONE';


	for cursor in build/config/*.cursor; do
		basename=${cursor##*/}
		basename=${basename%.*}

		echo -ne "\033[0KGenerating simple cursor pixmaps... $basename\\r"
		generate_pixmaps $basename $rawsvg "build/$name"
	done
	echo -e "\033[0KGenerating simple cursor pixmaps... DONE"



	for i in 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23; do
		echo -ne "\033[0KGenerating animated cursor pixmaps... $i / 23 \\r"
		generate_pixmaps "progress-$i" $rawsvg "build/$name"
		generate_pixmaps "wait-$i" $rawsvg "build/$name"
	done
	echo -e "\033[0KGenerating animated cursor pixmaps... DONE"



	echo -ne "Generating cursor theme...\\r"
	for cursor in build/config/*.cursor; do
		basename=${cursor##*/}
		basename=${basename%.*}

		error="$( xcursorgen -p "build/$name" "$cursor" "$output/cursors/$basename" 2>&1 )"

		if [[ "$?" -ne "0" ]]; then
			echo "FAIL: $cursor $error"
		fi
	done
	echo -e "Generating cursor theme... DONE"



	echo -ne "Generating shortcuts...\\r"
	while read from to ; do
		if [ -e "$output/cursors/$from" ] ; then
			continue
		fi

		ln -s "$to" "$output/cursors/$from"
	done < $ALIASES
	echo -e "\033[0KGenerating shortcuts... DONE"



	echo -ne "Copying theme index...\\r"
		if ! [ -e "$output/$index" ] ; then
			cp $index "$output/index.theme"
	fi
	echo -e "\033[0KCopying theme index... DONE"

	echo -e "Generating $name... DONE"
}


preprocess_cursor_configs
echo
generate_cursor Breeze
echo
generate_cursor Breeze_Snow
echo


echo "COMPLETE!"
