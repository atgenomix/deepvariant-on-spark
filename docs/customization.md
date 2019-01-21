# Customization of DeepVariant-on-Spark

## Adding more resources for parallelization

### Adaptive Data Paralleliztion (ADP)

SeqPiper leverages Adaptive Data Parallelization (ADP) for data sharding.
The default number of data sharding for WGS in DeepVariant-on-Spark is
`155`, so we won't gain performance improvement significantly when
adding workers from 8 to 16 (from 128 to 256 vcores).

If you are concerned about the turnaround time, you can customize the
 BED files (`hdfs:///bed/`) and replace them as yours on HDFS.

```
user@my-dos-w-0:~$ hadoop fs -ls -R /bed
drwxr-xr-x   - root hadoop          0 2019-01-21 03:08 /bed/19
-rw-r--r--   2 root hadoop       4950 2019-01-21 03:08 /bed/19/contiguous_unmasked_regions_156_parts
drwxr-xr-x   - root hadoop          0 2019-01-21 03:08 /bed/38
-rw-r--r--   2 root hadoop       4947 2019-01-21 03:08 /bed/38/contiguous_unmasked_regions_156_parts
```

### BED format

Here is the example from `/bed/19/contiguous_unmasked_regions_156_parts`:

```
chrX	113540000	143530000	000	1000
chr7	100580000	130180000	001	1000
chr16	60900000	90354753	002	1000
chr15	0	29180000	003	1000
chr7	130180000	159138663	004	1000
chr5	17550000	46430000	005	1000

...(skipped)...

chr11	40000000	50810000	149	1000
chr7	40000000	50400000	150	1000
chr4	40000000	50010000	151	1000
chr10	125900000	135534747	152	1000
chr2	234030000	243199373	153	1000
chr9	133100000	141213431	154	1000
```

The format of the supported BED file is

```
Format:
    <chromosome> <start> <end> <ID> <Padding>

Description:
    <chromosome> : the contig name of the genome reference
    <start> : the start position of this partition
    <end> : the end position of this partition
    <ID> : the ID of this partition (must be unique)
    <Padding> : the length for padding.

Example:
    chrX	113540000	143530000	000	1000

    The region of this partition (ID:000) is chrX:113539000-143531000.
```

