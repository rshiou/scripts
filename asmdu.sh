#!/bin/bash
#
# du of each subdirectory in a directory for ASM
#
D=$1
if [[ -z $D ]]
then
echo "Please provide a directory !"
exit 1
fi
(for DIR in `asmcmd ls ${D}`
do
echo ${DIR} `asmcmd du ${D}/${DIR} | tail -1`
done) | awk -v D="$D" ' BEGIN { printf("\n\t\t%40s\n\n", D " subdirectories size") ;
printf("%25s%16s%16s\n", "Subdir", "Used MB", "Mirror MB") ;
printf("%25s%16s%16s\n", "------", "-------", "---------") ;}
{
printf("%25s%16s%16s\n", $1, $2, $3) ;
use += $2 ;
mir += $3 ;
}
END { printf("\n\n%25s%16s%16s\n", "------", "-------", "---------");
printf("%25s%16s%16s\n\n", "Total", use, mir) ;} '

