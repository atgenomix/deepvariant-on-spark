# DeepVariant-on-spark

deepvariant-on-spark is an analysis pipeline that ports deepvariant on
Apache Spark for pipeline acceleration.

## Why DeepVariant-on-Spark

*   DeepVariant is **highly accurate**. In 2016 DeepVariant won
    [PrecisionFDA Truth Challenge](https://precision.fda.gov/challenges/truth/results)
    in the best SNP Performance category.
*   Apache Spark is a lightning-fast unified analytics engine for
    large-scale data processing. Apache Spark achieves high performance
    for both batch and streaming data, using a state-of-the-art DAG
    scheduler, a query optimizer, and a physical execution engine.
*   DeepVariant (v0.7) hasn't support multiple GPUs yet. Through
    DeepVariant-on-Spark, all of GPU resource can be fully utilized.
    For example, nVidia DGX-1 has 8 Tesla V100.

## Documentation

*   [DeepVariant-on-Spark release notes](https://github.com/atgenomix/deepvariant-on-spark/releases)

### Quick start and Case studies

*   [DeepVariant-on-Spark quick start on Google Cloud vid DataProc](docs/deepvariant-on-spark-quick-start-dataproc.md)
*   [DeepVariant-on-Spark WGS case study](docs/wgs-case-study.md)
*   [Multiple GPU acceleration](docs/multiple-gpu-accerlations.md)

## Contributing

Interested in contributing? See [CONTRIBUTING](CONTRIBUTING.md).

## License

DeepVariant-on-Spark is licensed under the terms of the
[Apache 2.0 License](LICENSE).

## Acknowledgements

DeepVariant-on-Spark happily makes use of many open source packages.
We'd like to specifically call out a few key ones:

*   [DeepVariant - an analysis pipeline that uses a deep neural network
    to call genetic variants from next-generation DNA sequencing
    data](https://github.com/google/deepvariant)

*   [Adam -  a genomics analysis platform with specialized file formats
    built using Apache Avro, Apache Spark and
    Parquet.](https://github.com/bigdatagenomics/adam)


We thank all of the developers and contributors to these packages for their
work.


## Disclaimer

*   This is not an official Atgenomix product.