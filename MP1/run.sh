#!/bin/zsh

mkdir -p compiled images

rm -f ./compiled/*.fst ./images/*.pdf

# ############ Compile source transducers ############
for i in sources/*.txt tests/*.txt; do
	echo "Compiling: $i"
    fstcompile --isymbols=syms.txt --osymbols=syms.txt $i | fstarcsort > compiled/$(basename $i ".txt").fst
done

# ############ CORE OF THE PROJECT  ############


# a)
# the transducer dd_aaa.fst deals with the day and year parts (not changing them)
fstconcat compiled/mmm2mm.fst compiled/dd_aaaa.fst > compiled/mix2numerical.fst


####################################
# answer to b) We first concatenate the transpt2en.fst the same way as before. To translate from English to Portuguese we invert the transpt2en.fst generated and concatenate the result like before.
fstconcat compiled/transpt2en.fst compiled/dd_aaaa.fst > compiled/pt2en.fst

#fstinvert compiled/transpt2en.fst > compiled/transen2pt.fst
#fstconcat compiled/transen2pt.fst <(python3 ./scripts/compact2fst.py scripts/dd_aaaa.txt | fstcompile --isymbols=syms.txt --osymbols=syms.txt | fstarcsort |  fstrmepsilon | fsttopsort) > compiled/en2pt.fst

### vê se pode ficar assim
# acho que isto chega porque os outros arcos são todos iguais
fstinvert compiled/pt2en.fst > compiled/en2pt.fst

####################################
# c)

# concatenations to join the month, day and year transducers, comma and slash transducers needed for formatting
fstconcat compiled/month.fst compiled/slash.fst > compiled/aux1.fst
fstconcat compiled/aux1.fst compiled/day.fst > compiled/aux2.fst
fstconcat compiled/aux2.fst compiled/slash.fst > compiled/aux3.fst
fstconcat compiled/aux3.fst compiled/comma.fst > compiled/aux4.fst
fstconcat compiled/aux4.fst compiled/year.fst > compiled/datenum2text.fst

####################################
#answer to d)

#compose das parted que tratam do mês (pt2en e mmm2mm)
#fstcompose compiled/transpt2en.fst compiled/mmm2mm.fst > compiled/aux5.fst
#fstconcat compiled/aux5.fst compiled/dd_aaaa.fst | fstrmepsilon | fsttopsort > compiled/aux6.fst

# transducer that deals with a date in portuguese
# composition of pt2en, mix2numerical and datnum2text
fstcompose compiled/pt2en.fst compiled/mix2numerical.fst > compiled/aux6.fst
fstcompose compiled/aux6.fst compiled/datenum2text.fst > compiled/aux7.fst

# transducer that deals with a date in english
# composition of mix2numerical (which input is in english) and datenum2text
fstcompose compiled/mix2numerical.fst compiled/datenum2text.fst > compiled/aux8.fst

# union of the tranducers that deals with the dates in english and portuguese
fstunion compiled/aux7.fst compiled/aux8.fst > compiled/mix2text.fst

# union of the transducer that accepts a data in either english or portugues
# with datenum2text
fstunion compiled/mix2text.fst compiled/datenum2text.fst > compiled/date2text.fst

#fstunion compiled/pt2en.fst compiled/skip.fst | fstrmespsilon > compiled/tiagoaux1.fst
#fstcompose compiled/tiagoaux1.fst compiled/mix2numerical.fst > compiled/tiagoaux2.fst
#fstcompose compiled/tiagoaux2.fst compiled/datenum2text.fst > compiled/mix2text.fst
#this works fine
# fstcompose compiled/mix2numerical.fst compiled/datenum2text.fst | fstarcsort | fsttopsort| fstrmepsilon > compiled/tiagoaux5.fst


## Delete auxiliary transducers
for i in compiled/aux*; do
	echo "Deleting: $i"
    rm $i
done


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
    fstcompose $w compiled/date2text.fst | fstshortestpath | fstproject --project_type=output |
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
for w in "JUN/8/2018" "AUG/05/2018" "MAR/01/2018" "APR/01/2018" "MAY/01/2018" "JUN/01/2018" "JUL/01/2018" "AUG/01/2018" "SEP/01/2018" "OCT/01/2018" "NOV/01/2018" "DEC/01/2018"; do
    res=$(python3 ./scripts/word2fst.py $w | fstcompile --isymbols=syms.txt --osymbols=syms.txt | fstarcsort |
                       fstcompose - compiled/$trans | fstshortestpath | fstproject --project_type=output |
                       fstrmepsilon | fsttopsort | fstprint --acceptor --isymbols=./scripts/syms-out.txt | fst2word)
    echo "$w = $res"
done

trans=en2pt.fst
echo "\n***********************************************************"
echo "Testing en2pt  (output is a string  using 'syms-out.txt')"
echo "***********************************************************"
for w in "JUN/08/2018" "AUG/05/2018"; do
    res=$(python3 ./scripts/word2fst.py $w | fstcompile --isymbols=syms.txt --osymbols=syms.txt | fstarcsort |
                       fstcompose - compiled/$trans | fstshortestpath | fstproject --project_type=output |
                       fstrmepsilon | fsttopsort | fstprint --acceptor --isymbols=./scripts/syms-out.txt | fst2word)
    echo "$w = $res"
done

trans=pt2en.fst
echo "\n***********************************************************"
echo "Testing pt2en  (output is a string  using 'syms-out.txt')"
echo "***********************************************************"
for w in "JUN/08/2018" "AGO/05/2018"; do
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
for w in "08/5/2018" "6/8/2018" "1/1/2001" "1/02/2020" "08/2/2099"; do
    res=$(python3 ./scripts/word2fst.py $w | fstcompile --isymbols=syms.txt --osymbols=syms.txt | fstarcsort |
                       fstcompose - compiled/$trans | fstshortestpath | fstproject --project_type=output |
                       fstrmepsilon | fsttopsort | fstprint --acceptor --isymbols=./scripts/syms-out.txt | fst2word)
    echo "$w = $res"
done

trans=mix2text.fst
echo "\n***********************************************************"
echo "Testing mix2text  (output is a string  using 'syms-out.txt')"
echo "***********************************************************"
for w in "AGO/5/2018" "JUN/08/2018" "FEB/1/2001" "DEC/02/2020" "DEZ/2/2099"; do
    res=$(python3 ./scripts/word2fst.py $w | fstcompile --isymbols=syms.txt --osymbols=syms.txt | fstarcsort |
                       fstcompose - compiled/$trans | fstshortestpath | fstproject --project_type=output |
                       fstrmepsilon | fsttopsort | fstprint --acceptor --isymbols=./scripts/syms-out.txt | fst2word)
    echo "$w = $res"
done

trans=date2text.fst
echo "\n***********************************************************"
echo "Testing date2text  (output is a string  using 'syms-out.txt')"
echo "***********************************************************"
for w in "08/5/2018" "JUN/08/2018" "FEB/1/2001" "DEC/02/2020" "DEZ/2/2099" "12/2/2099" "3/2/2099" "03/2/2099" "MAR/2/2099" "ABR/2/2099" "APR/2/2099"; do
    res=$(python3 ./scripts/word2fst.py $w | fstcompile --isymbols=syms.txt --osymbols=syms.txt | fstarcsort |
                       fstcompose - compiled/$trans | fstshortestpath | fstproject --project_type=output |
                       fstrmepsilon | fsttopsort | fstprint --acceptor --isymbols=./scripts/syms-out.txt | fst2word)
    echo "$w = $res"
done


echo "\nThe end"
