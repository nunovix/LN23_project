#!/bin/zsh

mkdir -p compiled images

rm -f ./compiled/*.fst ./images/*.pdf

# ############ Compile source transducers ############
for i in sources/*.txt tests/*.txt; do
	echo "Compiling: $i"
    fstcompile --isymbols=syms.txt --osymbols=syms.txt $i | fstarcsort > compiled/$(basename $i ".txt").fst
done

# ############ CORE OF THE PROJECT  ############

# mix2numerical.fst contains de compact transducer that then is created with the python script  compact2fst
fstconcat compiled/mmm2mm.fst <(python3 ./scripts/compact2fst.py scripts/dd_aaaa.txt | fstcompile --isymbols=syms.txt --osymbols=syms.txt | 
                    fstarcsort |  fstrmepsilon | fsttopsort) > compiled/mix2numerical.fst


# concatenations to join the month, day and year transducers, comma and slash transducers needed for formatting
fstconcat compiled/month.fst compiled/slash.fst > compiled/aux1.fst
fstconcat compiled/aux1.fst compiled/day.fst > compiled/aux2.fst
fstconcat compiled/aux2.fst compiled/slash.fst > compiled/aux3.fst
fstconcat compiled/aux3.fst compiled/comma.fst > compiled/aux4.fst
fstconcat compiled/aux4.fst compiled/year.fst > compiled/datenum2text.fst

# ############ generate PDFs  ############
echo "Starting to generate PDFs"
for i in compiled/*.fst; do
	echo "Creating image: images/$(basename $i '.fst').pdf"
   fstdraw --portrait --isymbols=syms.txt --osymbols=syms.txt $i | dot -Tpdf > images/$(basename $i '.fst').pdf
done



# ############      3 different ways of testing     ############
# ############ (you can use the one(s) you prefer)  ############

#1 - generates files
echo "\n***********************************************************"
echo "Testing datenum2text (the output is a transducer: fst and pdf)"
echo "***********************************************************"
for w in compiled/t-*.fst; do
    fstcompose $w compiled/datenum2text.fst | fstshortestpath | fstproject --project_type=output |
                  fstrmepsilon | fsttopsort > compiled/$(basename $w ".fst")-out.fst
done

for i in compiled/t-*-out.fst; do
	echo "Creating image: images/$(basename $i '.fst').pdf"
   fstdraw --portrait --isymbols=syms.txt --osymbols=syms.txt $i | dot -Tpdf > images/$(basename $i '.fst').pdf
done

#2 - present the output as an acceptor
echo "\n***********************************************************"
echo "Testing mmm2mm (output is a acceptor)"
echo "***********************************************************"
trans=mmm2mm.fst
echo "\nTesting $trans"
for w in "JAN" "FEB" "MAR" "APR" "MAY" "JUN" "JUL" "AUG" "SEP" "OCT" "NOV" "DEC"; do
    echo "\t $w"
    python3 ./scripts/word2fst.py $w | fstcompile --isymbols=syms.txt --osymbols=syms.txt | fstarcsort |
                     fstcompose - compiled/$trans | fstshortestpath | fstproject --project_type=output |
                     fstrmepsilon | fsttopsort | fstprint --acceptor --isymbols=syms.txt
done

echo "\n***********************************************************"
echo "Testing mix2numerical (output is a acceptor)"
echo "***********************************************************"
trans=mix2numerical.fst
echo "\nTesting $trans"
for w in "JAN/9/2020"; do
    echo "\t $w"
    python3 ./scripts/word2fst.py $w | fstcompile --isymbols=syms.txt --osymbols=syms.txt | fstarcsort |
                     fstcompose - compiled/$trans | fstshortestpath | fstproject --project_type=output |
                     fstrmepsilon | fsttopsort | fstprint --acceptor --isymbols=syms.txt
done

#3 - presents the output with the tokens concatenated (uses a different syms on the output)
fst2word() {
	awk '{if(NF>=3){printf("%s",$3)}}END{printf("\n")}'
}

trans=mmm2mm.fst
echo "\n***********************************************************"
echo "Testing mmm2mm  (output is a string  using 'syms-out.txt')"
echo "***********************************************************"
for w in "JAN" "FEB" "MAR" "APR" "MAY" "JUN" "JUL" "AUG" "SEP" "OCT" "NOV" "DEC"; do
    res=$(python3 ./scripts/word2fst.py $w | fstcompile --isymbols=syms.txt --osymbols=syms.txt | fstarcsort |
                       fstcompose - compiled/$trans | fstshortestpath | fstproject --project_type=output |
                       fstrmepsilon | fsttopsort | fstprint --acceptor --isymbols=./scripts/syms-out.txt | fst2word)
    echo "$w = $res"
done

trans=mix2numerical.fst
echo "\n***********************************************************"
echo "Testing mix2numerical  (output is a string  using 'syms-out.txt')"
echo "***********************************************************"
for w in "JAN/1/2018" "FEB/1/2018" "MAR/01/2018" "APR/01/2018" "MAY/01/2018" "JUN/01/2018" "JUL/01/2018" "AUG/01/2018" "SEP/01/2018" "OCT/01/2018" "NOV/01/2018" "DEC/01/2018"; do
    res=$(python3 ./scripts/word2fst.py $w | fstcompile --isymbols=syms.txt --osymbols=syms.txt | fstarcsort |
                       fstcompose - compiled/$trans | fstshortestpath | fstproject --project_type=output |
                       fstrmepsilon | fsttopsort | fstprint --acceptor --isymbols=./scripts/syms-out.txt | fst2word)
    echo "$w = $res"
done

trans=day.fst
echo "\n***********************************************************"
echo "Testing day  (output is a string  using 'syms-out.txt')"
echo "***********************************************************"
for w in "1" "02" "03" "4" "5" "6" "07" "08" "9" "10" "11" "14" "20" "22" "27" "30" "31"; do
    res=$(python3 ./scripts/word2fst.py $w | fstcompile --isymbols=syms.txt --osymbols=syms.txt | fstarcsort |
                       fstcompose - compiled/$trans | fstshortestpath | fstproject --project_type=output |
                       fstrmepsilon | fsttopsort | fstprint --acceptor --isymbols=./scripts/syms-out.txt | fst2word)
    echo "$w = $res"
done


trans=month.fst
echo "\n***********************************************************"
echo "Testing month  (output is a string  using 'syms-out.txt')"
echo "***********************************************************"
for w in "1" "02" "03" "4" "5" "6" "07" "08" "9" "10" "11" "12"; do
    res=$(python3 ./scripts/word2fst.py $w | fstcompile --isymbols=syms.txt --osymbols=syms.txt | fstarcsort |
                       fstcompose - compiled/$trans | fstshortestpath | fstproject --project_type=output |
                       fstrmepsilon | fsttopsort | fstprint --acceptor --isymbols=./scripts/syms-out.txt | fst2word)
    echo "$w = $res"
done

trans=year.fst
echo "\n***********************************************************"
echo "Testing year  (output is a string  using 'syms-out.txt')"
echo "***********************************************************"
for w in "2001" "2007" "2010" "2020" "2023" "2024" "2056" "2015" "2099" "2050" "2033" "2019"; do
    res=$(python3 ./scripts/word2fst.py $w | fstcompile --isymbols=syms.txt --osymbols=syms.txt | fstarcsort |
                       fstcompose - compiled/$trans | fstshortestpath | fstproject --project_type=output |
                       fstrmepsilon | fsttopsort | fstprint --acceptor --isymbols=./scripts/syms-out.txt | fst2word)
    echo "$w = $res"
done

trans=datenum2text.fst
echo "\n***********************************************************"
echo "Testing datenum2text  (output is a string  using 'syms-out.txt')"
echo "***********************************************************"
for w in "09/15/2001" "10/10/2007" "1/1/2001" "1/02/2020" "08/2/2099"; do
    res=$(python3 ./scripts/word2fst.py $w | fstcompile --isymbols=syms.txt --osymbols=syms.txt | fstarcsort |
                       fstcompose - compiled/$trans | fstshortestpath | fstproject --project_type=output |
                       fstrmepsilon | fsttopsort | fstprint --acceptor --isymbols=./scripts/syms-out.txt | fst2word)
    echo "$w = $res"
done


echo "\nThe end"
