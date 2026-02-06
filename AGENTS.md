# Agent instructions

## Dependency management:

This project uses the `pixi` package manager. Always attempt to install R packages using pixi first (e.g., to install `dplyr`, use `pixi add r-dplyr`); only fall back to `install.packages` if that fails. Ask before installing new packages. To see current project dependencies, refer to the `pixi.toml`. To see the full list of available libraries and their versions, see `pixi.lock`.

Run all R scripts, GDAL commands, etc. with `pixi run`  (e.g., `pixi run Rscript <script.R>`; `pixi run gdalinfo`).

## External data locations

For the purposes of local development, sample subsets of relevant data are located in `~/data`; specifically:

- CIMIS --- `~/data/CIMIS_raw`, in subdirectories year, month, day (`YYYY/MM/DD`). The ET data you need for CIMIS are in the `ET.asc.gz` file.
    - It should be possible to open the data directly with GDAL (and GDAL-based tools like R's `terra` package) using the `/vsigzip` virtual driver; e.g., `gdalinfo /vsigzip//~/data/CIMIS_raw/2025/12/01/ETo.asc.gz`. Assume this data is in California Albers (EPSG: 3310).
- CHIRPS --- `~/data/CHIRPS`. Data are daily, one file per year (e.g., `~/data/CHIRPS/chirps-v2.0.2024.days_p05.nc`), in NetCDF format. An example NetCDF header is provided in the `README.md`.

The root directories for all of these datasets should be configurable --- by either command line arguments or a simple configuration file (that R can read without external dependencies).

## Implementation

Use the R `targets` package to organize this workflow.
Follow targets best practices -- in particular, write functions and put them in the `R/` directory.

This workflow will eventually run on an HPC using Sun Grid Engine (SGE); `qsub`, etc. commands for job submission.
Prefer simple, single process tasks and local execution.
However, the workflow seems too big for local processing, plan on using targets + crew for execution on multiple HPC nodes.
