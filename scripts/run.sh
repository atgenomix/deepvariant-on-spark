#!/usr/bin/env bash

# arguments
#########################################################################################
input_bam=$1
ref_version=$2
contig_style=$3


# variables
#########################################################################################
spark=/usr/bin/spark-submit
time=`date +"%s"`
alignment_parquet=hdfs:///${time}-alignment.parquet
alignment_bam=hdfs:///${time}-alignment.bam
make_example_dir=hdfs:///${time}-dv-I
call_variants_dir=hdfs:///${time}-dv-II
postprocess_variants_dir=hdfs:///${time}-dv-III
bed_path=hdfs:///bed/${ref_version}/contiguous_unmasked_regions_156_parts


# argument check
#########################################################################################
if [[ ${contig_style} != "HG" && ${contig_style} != "GRCH" ]]; then
  echo unsupported contig style -- ${contig_style}
  exit -1
fi

if [[ ${ref_version} == "38" ]]; then
    partition_array=(
    "-l 000=chr13:86230000-114364328 -l 001=chr13:58150000-86230000 -l 002=chr9:40000000-67950000 \
  -l 003=chr10:20000000-47810000  -l 004=chr14:79550000-107043718  -l 005=chr19:0-27220000 \
  -l 006=chr11:107990000-135086622  -l 007=chr4:31830000-58900000  -l 008=chr18:20000000-46990000 \
  -l 009=chr17:0-26910000  -l 010=chr21:20000000-46709983  -l 011=chr16:20000000-46350000 \
  -l 012=chr10:107810000-133797422 -l 013=chr8:20000000-45900000 -l 014=chr1:223580000-248956422 \
  -l 015=chr1:96810000-122010000 -l 016=chr2:217460000-242193529 -l 017=chr3:173680000-198295559 \
  -l 018=chr16:66350000-90338345 -l 019=chr15:0-23260000 -l 020=chr7:40000000-62480000 \
  -l 021=chrX:40000000-62440000  -l 022=chrX:134310000-156040895  -l 023=chr7:122480000-143680000 \
  -l 024=chr1:122010000-143160000 -l 025=chr15:63260000-84300000 -l 026=chr1:203160000-223580000 \
  -l 027=chr6:40000000-60210000 -l 028=chrY:20000000-40000000 -l 029=chrY:0-20000000"

    "-l 030=chrX:82440000-102440000 -l 031=chrX:62440000-82440000 -l 032=chrX:20000000-40000000 \
  -l 033=chrX:114310000-134310000 -l 034=chrX:0-20000000 -l 035=chr9:87950000-107950000 \
  -l 036=chr9:67950000-87950000 -l 037=chr9:20000000-40000000 -l 038=chr9:107950000-127950000 \
  -l 039=chr9:0-20000000 -l 040=chr8:85690000-105690000 -l 041=chr8:45900000-65900000 \
  -l 042=chr8:105690000-125690000 -l 043=chr8:0-20000000 -l 044=chr7:82480000-102480000 \
  -l 045=chr7:62480000-82480000 -l 046=chr7:20000000-40000000 -l 047=chr7:102480000-122480000 \
  -l 048=chr7:0-20000000 -l 049=chr6:95050000-115050000 -l 050=chr6:60210000-80210000 \
  -l 051=chr6:20000000-40000000 -l 052=chr6:135050000-155050000 -l 053=chr6:115050000-135050000 \
  -l 054=chr6:0-20000000 -l 055=chr5:90080000-110080000 -l 056=chr5:70080000-90080000 \
  -l 057=chr5:50080000-70080000 -l 058=chr5:20000000-40000000 -l 059=chr5:150080000-170080000"

    "-l 060=chr5:130080000-150080000 -l 061=chr5:110080000-130080000 -l 062=chr5:0-20000000 \
  -l 063=chr4:98900000-118900000 -l 064=chr4:78900000-98900000 -l 065=chr4:58900000-78900000 \
  -l 066=chr4:158900000-178900000 -l 067=chr4:138900000-158900000 -l 068=chr4:118900000-138900000 \
  -l 069=chr4:0-20000000 -l 070=chr3:93680000-113680000 -l 071=chr3:60000000-80000000 \
  -l 072=chr3:40000000-60000000 -l 073=chr3:20000000-40000000 -l 074=chr3:153680000-173680000 \
  -l 075=chr3:133680000-153680000 -l 076=chr3:113680000-133680000 -l 077=chr3:0-20000000 \
  -l 078=chr22:20000000-40000000 -l 079=chr22:0-20000000 -l 080=chr21:0-20000000 \
  -l 081=chr20:31140000-51140000 -l 082=chr20:0-20000000 -l 083=chr2:97460000-117460000 \
  -l 084=chr2:60000000-80000000 -l 085=chr2:40000000-60000000 -l 086=chr2:20000000-40000000 \
  -l 087=chr2:197460000-217460000 -l 088=chr2:177460000-197460000 -l 089=chr2:157460000-177460000"

    "-l 090=chr2:137460000-157460000 -l 091=chr2:117460000-137460000 -l 092=chr2:0-20000000 \
  -l 093=chr19:27220000-47220000 -l 094=chr18:46990000-66990000 -l 095=chr18:0-20000000 \
  -l 096=chr17:46910000-66910000 -l 097=chr17:26910000-46910000 -l 098=chr16:46350000-66350000 \
  -l 099=chr16:0-20000000 -l 100=chr15:43260000-63260000 -l 101=chr15:23260000-43260000 \
  -l 102=chr14:59550000-79550000 -l 103=chr14:39550000-59550000 -l 104=chr14:19550000-39550000 \
  -l 105=chr13:38150000-58150000 -l 106=chr13:18150000-38150000 -l 107=chr12:97100000-117100000 \
  -l 108=chr12:77100000-97100000 -l 109=chr12:57100000-77100000 -l 110=chr12:37100000-57100000 \
  -l 111=chr12:0-20000000 -l 112=chr11:87990000-107990000 -l 113=chr11:50850000-70850000 \
  -l 114=chr11:20000000-40000000 -l 115=chr11:0-20000000 -l 116=chr10:87810000-107810000 \
  -l 117=chr10:67810000-87810000 -l 118=chr10:47810000-67810000 -l 119=chr10:0-20000000"

    "-l 120=chr1:76810000-96810000 -l 121=chr1:56810000-76810000 -l 122=chr1:36810000-56810000 \
  -l 123=chr1:183160000-203160000 -l 124=chr1:16810000-36810000 -l 125=chr1:163160000-183160000 \
  -l 126=chr1:143160000-163160000 -l 127=chr8:65900000-85690000 -l 128=chr14:0-19550000 \
  -l 129=chr8:125690000-145138636 -l 130=chr13:0-18150000 -l 131=chr15:84300000-101991189 \
  -l 132=chr2:80000000-97460000 -l 133=chrY:40000000-57227415 -l 134=chr11:70850000-87990000 \
  -l 135=chr12:20000000-37100000 -l 136=chr1:0-16810000 -l 137=chr17:66910000-83257441 \
  -l 138=chr12:117100000-133275309 -l 139=chr6:155050000-170805979 -l 140=chr7:143680000-159345973 \
  -l 141=chr6:80210000-95050000 -l 142=chr3:80000000-93680000 -l 143=chr18:66990000-80373285 \
  -l 144=chr20:51140000-64444167 -l 145=chrX:102440000-114310000 -l 146=chr4:20000000-31830000 \
  -l 147=chr5:170080000-181538259 -l 148=chr19:47220000-58617616 -l 149=chr4:178900000-190214555 \
  -l 150=chr20:20000000-31140000 -l 151=chr11:40000000-50850000 -l 152=chr22:40000000-50818468 \
  -l 153=chr9:127950000-138394717 -l 154=chr5:40000000-50080000"
    )

elif [[ ${ref_version} == "19" ]]; then
    partition_array=(
    "-l 000=chrX:113540000-143530000 -l 001=chr7:100580000-130180000 -l 002=chr16:60900000-90354753 \
  -l 003=chr15:0-29180000 -l 004=chr7:130180000-159138663 -l 005=chr5:17550000-46430000 \
  -l 006=chr13:86790000-115169878 -l 007=chr21:20000000-48129895 -l 008=chr17:34700000-62440000 \
  -l 009=chr14:80000000-107349540 -l 010=chr3:66200000-93500000 -l 011=chr5:111660000-138810000 \
  -l 012=chr13:60000000-86790000 -l 013=chr2:61175000-87690000 -l 014=chr20:0-26340000 \
  -l 015=chr3:40000000-66200000 -l 016=chr18:52080000-78077248 -l 017=chr7:74740000-100580000 \
  -l 018=chr11:70810000-96310000 -l 019=chr4:50010000-75450000 -l 020=chr5:66430000-91660000 \
  -l 021=chr19:0-24660000 -l 022=chr1:123890000-148500000 -l 023=chr3:173500000-198022430 \
  -l 024=chr12:109400000-133851895 -l 025=chr7:50400000-74740000 -l 026=chr2:209720000-234030000 \
  -l 027=chr8:20000000-43860000 -l 028=chr8:63860000-86600000 -l 029=chr2:87690000-110130000"

    "-l 030=chr5:158810000-180915260 -l 031=chr6:135710000-157580000 -l 032=chrX:37120000-58610000 \
  -l 033=chr2:0-21175000 -l 034=chr16:20000000-40900000 -l 035=chr9:112370000-133100000 \
  -l 036=chr1:29900000-49900000 -l 037=chr1:49900000-69900000 -l 038=chr1:69900000-89900000 \
  -l 039=chr1:103890000-123890000 -l 040=chr1:148500000-168500000 -l 041=chr1:168500000-188500000 \
  -l 042=chr2:21175000-41175000 -l 043=chr2:41175000-61175000 -l 044=chr2:110130000-130130000 \
  -l 045=chr2:149720000-169720000 -l 046=chr2:169720000-189720000 -l 047=chr2:189720000-209720000 \
  -l 048=chr3:0-20000000 -l 049=chr3:20000000-40000000 -l 050=chr3:93500000-113500000 \
  -l 051=chr3:113500000-133500000 -l 052=chr3:133500000-153500000 -l 053=chr3:153500000-173500000 \
  -l 054=chr4:0-20000000 -l 055=chr4:20000000-40000000 -l 056=chr4:75450000-95450000 \
  -l 057=chr4:95450000-115450000 -l 058=chr4:115450000-135450000 -l 059=chr4:135450000-155450000"

    "-l 060=chr4:155450000-175450000 -l 061=chr5:46430000-66430000 -l 062=chr5:91660000-111660000 \
  -l 063=chr5:138810000-158810000 -l 064=chr6:0-20000000 -l 065=chr6:20000000-40000000 \
  -l 066=chr6:58110000-78110000 -l 067=chr6:95710000-115710000 -l 068=chr6:115710000-135710000 \
  -l 069=chr7:0-20000000 -l 070=chr7:20000000-40000000 -l 071=chr8:0-20000000 \
  -l 072=chr8:43860000-63860000 -l 073=chr8:86600000-106600000 -l 074=chr8:106600000-126600000 \
  -l 075=chr9:0-20000000 -l 076=chr9:20000000-40000000 -l 077=chr9:40000000-60000000 \
  -l 078=chr9:60000000-80000000 -l 079=chr9:92370000-112370000 -l 080=chr10:18000000-38000000 \
  -l 081=chr10:51160000-71160000 -l 082=chr10:71160000-91160000 -l 083=chr10:91160000-111160000 \
  -l 084=chr11:0-20000000 -l 085=chr11:20000000-40000000 -l 086=chr11:50810000-70810000 \
  -l 087=chr11:96310000-116310000 -l 088=chr12:0-20000000 -l 089=chr12:34880000-54880000"

    "-l 090=chr12:54880000-74880000 -l 091=chr12:74880000-94880000 -l 092=chr13:0-20000000 \
  -l 093=chr13:20000000-40000000 -l 094=chr13:40000000-60000000 -l 095=chr14:0-20000000 \
  -l 096=chr14:20000000-40000000 -l 097=chr14:40000000-60000000 -l 098=chr14:60000000-80000000 \
  -l 099=chr15:29180000-49180000 -l 100=chr15:49180000-69180000 -l 101=chr16:0-20000000 \
  -l 102=chr16:40900000-60900000 -l 103=chr17:0-20000000 -l 104=chr18:15440000-35440000 \
  -l 105=chr19:24660000-44660000 -l 106=chr20:26340000-46340000 -l 107=chr21:0-20000000 \
  -l 108=chr22:0-20000000 -l 109=chr22:20000000-40000000 -l 110=chrX:0-20000000 \
  -l 111=chrX:76680000-96680000 -l 112=chrY:0-20000000 -l 113=chrY:20000000-40000000 \
  -l 114=chr8:126600000-146364022 -l 115=chr15:82850000-102531392 -l 116=chr2:130130000-149720000 \
  -l 117=chrY:40000000-59373566 -l 118=chr17:62440000-81195210 -l 119=chr11:116310000-135006516"

    "-l 120=chr6:40000000-58110000 -l 121=chrX:58610000-76680000 -l 122=chr10:0-18000000 \
  -l 123=chr1:206000000-223770000 -l 124=chr6:78110000-95710000 -l 125=chr5:0-17550000 \
  -l 126=chr1:188500000-206000000 -l 127=chrX:20000000-37120000 -l 128=chrX:96680000-113540000 \
  -l 129=chr1:13090000-29900000 -l 130=chr20:46340000-63025520 -l 131=chr18:35440000-52080000 \
  -l 132=chr4:175450000-191154276 -l 133=chr18:0-15440000 -l 134=chr12:20000000-34880000 \
  -l 135=chr10:111160000-125900000 -l 136=chr17:20000000-34700000 -l 137=chr12:94880000-109400000 \
  -l 138=chr19:44660000-59128983 -l 139=chr1:235220000-249250621 -l 140=chr1:89900000-103890000 \
  -l 141=chr15:69180000-82850000 -l 142=chr6:157580000-171115067 -l 143=chr10:38000000-51160000 \
  -l 144=chr1:0-13090000 -l 145=chr9:80000000-92370000 -l 146=chrX:143530000-155270560 \
  -l 147=chr1:223770000-235220000 -l 148=chr22:40000000-51304566 -l 149=chr11:40000000-50810000 \
  -l 150=chr7:40000000-50400000 -l 151=chr4:40000000-50010000 -l 152=chr10:125900000-135534747 \
  -l 153=chr2:234030000-243199373 -l 154=chr9:133100000-141213431"
    )
else
    echo unsupported ref version - ${ref_version}
    exit -1
fi


# main
##########################################################################################
# adam
${spark} \
  --master yarn \
  --deploy-mode cluster \
  --name AtgxTransform \
  --class org.bdgenomics.adam.cli.ADAMMain \
  --num-executors 10  \
  --driver-memory 1g \
  --driver-cores 1 \
  --executor-memory 35g \
  --executor-cores 4 \
  --queue default \
  --conf spark.hadoop.validateOutputSpecs=false \
  --conf spark.dynamicAllocation.enabled=false \
  --conf spark.dynamicAllocation.minExecutors=1 \
  --conf spark.executor.extraJavaOptions=-XX:+UseG1GC \
  --conf spark.serializer=org.apache.spark.serializer.KryoSerializer \
  --conf spark.kryo.registrator=org.bdgenomics.adam.serialization.ADAMKryoRegistrator \
  /usr/local/bin/adam.jar transformAlignments \
      ${input_bam} \
      ${alignment_parquet} \
      -force_load_bam -atgx_transform -parquet_compression_codec SNAPPY

if [[ $? != 0 ]]; then
    echo "###########################################################"
    echo
    echo "adam transform failed"
    echo
    echo "###########################################################"
    exit -1
fi


pids=""

for i in ${!partition_array[@]};
do
  echo ${i} --- ${partition_array[${i}]}
  ${spark} \
  --master yarn \
  --deploy-mode cluster \
  --class net.vartotal.piper.cli.PiperMain \
  --name SELECTOR-${i} \
  --driver-cores 1 \
  --driver-memory 1g \
  --num-executors 5 \
  --executor-cores 2 \
  --executor-memory 7g \
  --conf spark.hadoop.validateOutputSpecs=false \
  --conf spark.hadoop.dfs.replication=1 \
  --conf spark.dynamicAllocation.enabled=false \
  --conf spark.serializer=org.apache.spark.serializer.KryoSerializer \
  --conf spark.kryo.registrator=org.bdgenomics.adam.serialization.ADAMKryoRegistrator \
  --conf spark.executor.extraClassPath=/usr/local/seqslab/PiedPiper/target/PiedPiper.jar \
  /usr/local/seqslab/PiedPiper/target/PiedPiper.jar \
  newPosBinSelector \
      -i ${alignment_parquet} \
      -o ${alignment_bam} \
      -f bam \
      ${partition_array[${i}]} &

  pids+=" $!"
done

for p in ${pids}; do
  if wait ${p}; then
    echo "BamSelector Process ${p} success"
  else
    echo "###########################################################"
    echo
    echo "BamSelector Process ${p} fail"
    echo
    echo "###########################################################"
    exit -1

  fi
done

# make_examples
${spark} \
  --master yarn \
  --deploy-mode cluster \
  --name make_examples \
  --class net.vartotal.piper.cli.PiperMain \
  --num-executors 78 \
  --driver-memory 1g \
  --driver-cores 1 \
  --executor-memory 1g \
  --executor-cores 2 \
  --queue default \
  --conf spark.executor.extraJavaOptions=-XX:+UseG1GC \
  --conf spark.dynamicAllocation.minExecutors=1 \
  --conf spark.serializer=org.apache.spark.serializer.KryoSerializer \
  --conf spark.kryo.registrator=net.vartotal.piper.serialization.ADAMKryoRegistrator \
  --conf spark.speculation=true \
  --conf spark.hadoop.validateOutputSpecs=false \
  --conf spark.yarn.executor.memoryOverhead=8g \
  /usr/local/seqslab/PiedPiper/target/PiedPiper.jar \
  bam2vcf \
      --caller-type make_example \
      --piper-script /usr/local/seqslab/SeqPiper/script/Bam2VcfPiperDeepVariantME.py \
      --bam-input-path ${alignment_bam}/bam \
      --vcf-output-path ${make_example_dir} \
      --bam-partition-bed-path ${bed_path} \
      --reference-version ${ref_version} \
      --workflow-type 1 \
      --is-pcr-free 0 \
      --extra-params '' \
      --reference-system ${contig_style} \
      --platform-type illumina \
      --java-mem-in-mb 5120

if [[ $? != 0 ]]; then
    echo "###########################################################"
    echo
    echo "make_example failed"
    echo
    echo "###########################################################"
    exit -1
fi

${spark} \
  --master yarn \
  --deploy-mode cluster \
  --name call_variants \
  --class net.vartotal.piper.cli.PiperMain \
  --num-executors 78 \
  --driver-memory 1g \
  --driver-cores 1 \
  --executor-memory 1g \
  --executor-cores 2 \
  --queue default \
  --conf spark.executor.extraJavaOptions=-XX:+UseG1GC \
  --conf spark.dynamicAllocation.minExecutors=1 \
  --conf spark.serializer=org.apache.spark.serializer.KryoSerializer \
  --conf spark.kryo.registrator=net.vartotal.piper.serialization.ADAMKryoRegistrator \
  --conf spark.speculation=true \
  --conf spark.hadoop.validateOutputSpecs=false \
  --conf spark.yarn.executor.memoryOverhead=8g \
  /usr/local/seqslab/PiedPiper/target/PiedPiper.jar \
  bam2vcf \
      --caller-type call_variants \
      --piper-script /usr/local/seqslab/SeqPiper/script/Bam2VcfPiperDeepVariantCV.py \
      --bam-input-path ${make_example_dir} \
      --vcf-output-path ${call_variants_dir} \
      --bam-partition-bed-path ${bed_path} \
      --reference-version ${ref_version} \
      --workflow-type 1 \
      --is-pcr-free 0 \
      --extra-params '' \
      --reference-system ${contig_style} \
      --platform-type illumina \
      --java-mem-in-mb 5120

if [[ $? != 0 ]]; then
    echo "###########################################################"
    echo
    echo "call_variant failed"
    echo
    echo "###########################################################"
    exit -1
fi

${spark} \
  --master yarn \
  --deploy-mode cluster \
  --name postprocess_variants \
  --class net.vartotal.piper.cli.PiperMain \
  --num-executors 78 \
  --driver-memory 1g \
  --driver-cores 1 \
  --executor-memory 1g \
  --executor-cores 2 \
  --queue default \
  --conf spark.executor.extraJavaOptions=-XX:+UseG1GC \
  --conf spark.dynamicAllocation.minExecutors=1 \
  --conf spark.serializer=org.apache.spark.serializer.KryoSerializer \
  --conf spark.kryo.registrator=net.vartotal.piper.serialization.ADAMKryoRegistrator \
  --conf spark.speculation=true \
  --conf spark.hadoop.validateOutputSpecs=false \
  --conf spark.yarn.executor.memoryOverhead=8g \
  /usr/local/seqslab/PiedPiper/target/PiedPiper.jar \
  bam2vcf \
      --caller-type postprocess_variants \
      --piper-script /usr/local/seqslab/SeqPiper/script/Bam2VcfPiperDeepVariantPP.py \
      --bam-input-path ${make_example_dir} \
      --normal-bam-input-path ${call_variants_dir} \
      --vcf-output-path ${postprocess_variants_dir} \
      --bam-partition-bed-path ${bed_path} \
      --reference-version ${ref_version} \
      --workflow-type 1 \
      --is-pcr-free 0 \
      --extra-params '' \
      --reference-system ${contig_style} \
      --platform-type illumina \
      --java-mem-in-mb 5120

if [[ $? != 0 ]]; then
    echo "###########################################################"
    echo
    echo "postprocess_variant failed"
    echo
    echo "###########################################################"
    exit -1
fi

#python3 get_variants.py ${postprocess_variants_dir}
