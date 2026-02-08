# CIMIS data preprocessing

Task description: https://github.com/PecanProject/pecan/issues/3762

## Inputs

### Design points

`design_points.csv`.

Maps location IDs (to `CCMMF_Irrigation_Parquet` location) onto coordinates.

```csv
id,lat,lon
84389254458b3a58,39.15317154882152,-120.95862855945161
9e3b1749179a4a68,37.99925059252099,-121.20417111702339
729a6ef989c5a277,35.96903914573576,-118.98552352403604
8c23aa17d5b211ed,37.23624485456503,-120.325416895509
57ea98e608333b76,36.9069695937337,-121.68079166613182
6c1e7a1eb4c36ea5,36.376933120111964,-119.45050526430943
```

### Hydrology data

- Previously:
    - Precipitation from CHIRPS
    - Evapotranspiration (ET) from OpenET

- Now:
    - Still CHIRPS for precip
    - ET -- Replace OpenET with CIMIS

#### CHIRPS data

Daily data at 0.05 degree resolution.
One NetCDF file per year.

```
netcdf chirps-v2.0.2020.days_p05 {
dimensions:
        longitude = 7200 ;
        latitude = 2000 ;
        time = 366 ;
variables:
        float latitude(latitude) ;
                latitude:units = "degrees_north" ;
                latitude:standard_name = "latitude" ;
                latitude:long_name = "latitude" ;
                latitude:axis = "Y" ;
        float longitude(longitude) ;
                longitude:units = "degrees_east" ;
                longitude:standard_name = "longitude" ;
                longitude:long_name = "longitude" ;
                longitude:axis = "X" ;
        float precip(time, latitude, longitude) ;
                precip:units = "mm/day" ;
                precip:standard_name = "convective precipitation rate" ;
                precip:long_name = "Climate Hazards group InfraRed Precipitation with Stations" ;
                precip:time_step = "day" ;
                precip:missing_value = -9999.f ;
                precip:_FillValue = -9999.f ;
                precip:geostatial_lat_min = -50.f ;
                precip:geostatial_lat_max = 50.f ;
                precip:geostatial_lon_min = -180.f ;
                precip:geostatial_lon_max = 180.f ;
        float time(time) ;
                time:units = "days since 1980-1-1 0:0:0" ;
                time:standard_name = "time" ;
                time:calendar = "gregorian" ;
                time:axis = "T" ;
```

## Outputs

### Water balance CSV

For every site (indicated by lat/lon coordinate), a water balance CSV file with columns:

- `time` (date)
- `et` -- evapotranspiration (from OpenET / CIMIS) [CIMIS unit is `mm day-1`]
- `precip` -- precipitation (from CHIRPS) [unit is `mm day-1`]
- `irr` -- irrigation (calculated) [unit is `cm day-1`]
- `runoff`-- runoff (calculated)
- `W_t` -- water balance (calculated)
- `year` -- year
- `week` -- week of the year (used for event files)
- `day_of_year` -- day of the year (used for event files)

```csv
time,et,precip,W_t,irr,runoff,year,week,day_of_year
2016-01-01,1.52,0.0,250.0,,,2016,53,1
2016-01-02,1.86,0.0,248.14,0.0,0.0,2016,53,2
2016-01-03,2.2,0.0,245.94,0.0,0.0,2016,53,3
2016-01-04,1.118,0.0,244.822,0.0,0.0,2016,1,4
2016-01-05,0.691,0.0,244.131,0.0,0.0,2016,1,5
2016-01-06,2.654,0.0,241.477,0.0,0.0,2016,1,6
2016-01-07,1.994,0.0,239.483,0.0,0.0,2016,1,7
```

The water balance is calculated as follows:

```python
# Constants
WHC = 500           # units: mm
W_min = 0.15 * WHC
field_capacity = WHC/2

W_t[0] = field_capacity

# For time t
W0_t[t] = W_t[t-1] + precip[t] - et[t]
irr[t] = max(W_min - W0_t_[t], 0)
runoff[t] = max(W0_t[t] - WHC, 0)
W_t[t] = W_t[t-1] + precip + irr - et - runoff
```

For a first pass, just use the ET values directly from CIMIS.
For a second pass, cross-reference crop types from LandIQ against CIMIS coefficients.

### Event files

SIPNET event files describing irrigation events.
These are space-separated tables with no header.

Columns are:

1. `loc` (fixed at 0)
2. `year` -- year
3. `doy` -- day of year, but aggregated by week. (I.e., any given week, take the first day of the year)
4. `event_type` -- type of event. Hard coded to `"irrig"`.
5. `irr` -- Amount of irrigation. (Check the units).
6. `type` -- some other type; hard-coded to 1.

Expanded and annotated for clarity:

```
loc     year    doy     event_type  irr     type
0       2016    4       irrig       0.0     1
0       2016    11      irrig       0.0     1
0       2016    18      irrig       0.0     1
0       2016    25      irrig       0.0     1
0       2016    32      irrig       0.0     1
0       2016    39      irrig       0.0     1
```

Actual format:

```
0 2016 4 irrig 0.0 1
0 2016 11 irrig 0.0 1
0 2016 18 irrig 0.0 1
0 2016 25 irrig 0.0 1
0 2016 32 irrig 0.0 1
0 2016 39 irrig 0.0 1
```

Helpful Python code for calculating this from the weekly files:

```python
#
eventfile_df = df.groupby(['year', 'week'], as_index = False).agg({
    'loc': 'first',
    'year': 'first',
    'day_of_year': 'first',
    'event_type': 'first',
    'irr': 'sum',
    'type': 'first'
})
```


## Workflow

- Read coordinates from `design_points.csv`
- Read ET data from CIMIS
- Read CHIRPS data from NetCDFs
- Produce per-location CSV files of daily water balance
- Produce event files (weekly aggregated)

